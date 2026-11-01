$ErrorActionPreference = 'Stop'
$videoViewRoot = Join-Path $PSScriptRoot '..\Screenbox\Screenbox.VideoView'
$videoViewPath = Join-Path $videoViewRoot 'VideoView.cs'
$probePath = Join-Path $videoViewRoot 'SwapChainPresentProbe.cs'
if (!(Test-Path $videoViewPath)) { throw "Required VideoView source not found: $videoViewPath" }

# Install a no-op Present interception probe. It must always call the original Present
# and must fail open so playback continues unchanged if the hook cannot be installed.
$code = Get-Content -Raw -Encoding UTF8 $videoViewPath
$nl = [Environment]::NewLine
if (!$code.Contains('private SwapChainPresentProbe? _presentProbe;')) {
    $anchor = '    private IDXGISwapChain1? _swapChain;'
    if (!$code.Contains($anchor)) { throw 'VideoView swapchain field anchor not found' }
    $code = $code.Replace($anchor, $anchor + $nl + '    private SwapChainPresentProbe? _presentProbe;')
}
if (!$code.Contains('SwapChainPresentProbe.TryInstall(_swapChain.NativePointer)')) {
    $anchor = '        this.SetSwapChain(_swapChain.NativePointer);'
    if (!$code.Contains($anchor)) { throw 'VideoView SetSwapChain anchor not found' }
    $code = $code.Replace($anchor, $anchor + $nl + $nl + '        _presentProbe = SwapChainPresentProbe.TryInstall(_swapChain.NativePointer);')
}
if (!$code.Contains('_presentProbe?.Dispose();')) {
    $anchor = '        _swapChain?.Dispose();'
    if (!$code.Contains($anchor)) { throw 'VideoView swapchain dispose anchor not found' }
    $code = $code.Replace($anchor, '        _presentProbe?.Dispose();' + $nl + '        _presentProbe = null;' + $nl + $anchor)
}
Set-Content -Path $videoViewPath -Value $code -Encoding UTF8

@'
using System;
using System.Diagnostics;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Threading;

namespace Screenbox.Controls;

/// <summary>
/// Experimental, fail-open probe for the LibVLC-owned DXGI swapchain.
/// The callback currently forwards Present unchanged and only counts calls.
/// It deliberately performs no GPU work until runtime interception is verified.
/// </summary>
internal sealed unsafe class SwapChainPresentProbe : IDisposable
{
    private const int PresentVtableIndex = 8;
    private const int Present1VtableIndex = 22;
    private const int SwapChain1VtableLength = 29;
    private const uint PageExecuteReadWrite = 0x40;

    private static IntPtr s_originalPresent;
    private static IntPtr s_originalPresent1;
    private static long s_presentCount;

    private readonly IntPtr _swapChain;
    private readonly IntPtr _originalVtable;
    private readonly IntPtr _hookedVtable;
    private bool _disposed;

    public static long PresentCount => Interlocked.Read(ref s_presentCount);

    private SwapChainPresentProbe(IntPtr swapChain, IntPtr originalVtable, IntPtr hookedVtable)
    {
        _swapChain = swapChain;
        _originalVtable = originalVtable;
        _hookedVtable = hookedVtable;
    }

    public static SwapChainPresentProbe? TryInstall(IntPtr swapChain)
    {
        if (swapChain == IntPtr.Zero)
            return null;

        IntPtr clone = IntPtr.Zero;
        try
        {
            IntPtr originalVtable = Marshal.ReadIntPtr(swapChain);
            if (originalVtable == IntPtr.Zero)
                return null;

            var entries = new IntPtr[SwapChain1VtableLength];
            Marshal.Copy(originalVtable, entries, 0, entries.Length);

            IntPtr originalPresent = entries[PresentVtableIndex];
            IntPtr originalPresent1 = entries[Present1VtableIndex];
            if (originalPresent == IntPtr.Zero || originalPresent1 == IntPtr.Zero)
                return null;

            clone = Marshal.AllocHGlobal(entries.Length * IntPtr.Size);
            entries[PresentVtableIndex] =
                (IntPtr)(delegate* unmanaged[Stdcall]<IntPtr, uint, uint, int>)&Present;
            entries[Present1VtableIndex] =
                (IntPtr)(delegate* unmanaged[Stdcall]<IntPtr, uint, uint, IntPtr, int>)&Present1;
            Marshal.Copy(entries, 0, clone, entries.Length);

            if (VirtualProtect(swapChain, (UIntPtr)IntPtr.Size, PageExecuteReadWrite, out uint oldProtect) == 0)
                throw new InvalidOperationException("VirtualProtect failed while installing the DXGI probe.");

            try
            {
                s_originalPresent = originalPresent;
                s_originalPresent1 = originalPresent1;
                Marshal.WriteIntPtr(swapChain, clone);
            }
            finally
            {
                VirtualProtect(swapChain, (UIntPtr)IntPtr.Size, oldProtect, out _);
            }

            return new SwapChainPresentProbe(swapChain, originalVtable, clone);
        }
        catch (Exception ex)
        {
            if (clone != IntPtr.Zero)
                Marshal.FreeHGlobal(clone);
            Debug.WriteLine($"Mosuan DXGI Present probe not installed; continuing without it: {ex}");
            return null;
        }
    }

    [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
    private static int Present(IntPtr self, uint syncInterval, uint flags)
    {
        Interlocked.Increment(ref s_presentCount);
        IntPtr original = s_originalPresent;
        if (original == IntPtr.Zero)
            return unchecked((int)0x80004005); // E_FAIL

        return ((delegate* unmanaged[Stdcall]<IntPtr, uint, uint, int>)original)(self, syncInterval, flags);
    }

    [UnmanagedCallersOnly(CallConvs = [typeof(CallConvStdcall)])]
    private static int Present1(IntPtr self, uint syncInterval, uint flags, IntPtr presentParameters)
    {
        Interlocked.Increment(ref s_presentCount);
        IntPtr original = s_originalPresent1;
        if (original == IntPtr.Zero)
            return unchecked((int)0x80004005); // E_FAIL

        return ((delegate* unmanaged[Stdcall]<IntPtr, uint, uint, IntPtr, int>)original)(self, syncInterval, flags, presentParameters);
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        _disposed = true;
        Debug.WriteLine($"Mosuan DXGI Present probe observed {PresentCount} Present/Present1 calls.");

        try
        {
            if (Marshal.ReadIntPtr(_swapChain) != _hookedVtable)
                return;

            if (VirtualProtect(_swapChain, (UIntPtr)IntPtr.Size, PageExecuteReadWrite, out uint oldProtect) == 0)
                return;

            try
            {
                Marshal.WriteIntPtr(_swapChain, _originalVtable);
            }
            finally
            {
                VirtualProtect(_swapChain, (UIntPtr)IntPtr.Size, oldProtect, out _);
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Mosuan DXGI Present probe could not restore the vtable: {ex}");
        }

        // Keep the cloned table allocated: a Present call may already have loaded its
        // function pointer on the VLC render thread when teardown restores the vtable.
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern int VirtualProtect(
        IntPtr address,
        UIntPtr size,
        uint newProtect,
        out uint oldProtect);
}
'@ | Set-Content -Path $probePath -Encoding UTF8

Write-Host 'Installed fail-open DXGI Present probe.'
