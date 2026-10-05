$ErrorActionPreference='Stop'
$root=Join-Path $PSScriptRoot '..\Screenbox\Screenbox'
$dir=Join-Path $root 'Models'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$file=Join-Path $dir 'MosuanFileBrowser.cs'
@'
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace Screenbox.Models;

public sealed class MosuanFileItem
{
    public string Name { get; init; } = "";
    public string Path { get; init; } = "";
    public bool IsFolder { get; init; }
}

public static class MosuanFileBrowser
{
    public static IReadOnlyList<MosuanFileItem> Enumerate(string path)
    {
        if (string.IsNullOrWhiteSpace(path) || !Directory.Exists(path)) return Array.Empty<MosuanFileItem>();
        try
        {
            var folders = Directory.EnumerateDirectories(path).Select(x => new MosuanFileItem { Name = Path.GetFileName(x), Path = x, IsFolder = true });
            var files = Directory.EnumerateFiles(path)
                .Where(x => IsVideo(x))
                .Select(x => new MosuanFileItem { Name = Path.GetFileName(x), Path = x, IsFolder = false });
            return folders.Concat(files).OrderBy(x => !x.IsFolder).ThenBy(x => x.Name, StringComparer.OrdinalIgnoreCase).ToList();
        }
        catch { return Array.Empty<MosuanFileItem>(); }
    }

    public static bool IsVideo(string path)
    {
        var ext = Path.GetExtension(path);
        return ext.Equals(".mp4", StringComparison.OrdinalIgnoreCase) || ext.Equals(".mkv", StringComparison.OrdinalIgnoreCase) || ext.Equals(".mov", StringComparison.OrdinalIgnoreCase) || ext.Equals(".avi", StringComparison.OrdinalIgnoreCase) || ext.Equals(".wmv", StringComparison.OrdinalIgnoreCase) || ext.Equals(".m4v", StringComparison.OrdinalIgnoreCase) || ext.Equals(".webm", StringComparison.OrdinalIgnoreCase);
    }
}
'@ | Set-Content -Encoding UTF8 $file
Write-Host 'Mosuan file browser foundation applied.'