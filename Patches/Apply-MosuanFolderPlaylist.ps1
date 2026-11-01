$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot '..\Screenbox\Screenbox'
$models = Join-Path $root 'Models'
New-Item -ItemType Directory -Force -Path $models | Out-Null
$target = Join-Path $models 'MosuanFolderPlaylistService.cs'

@'
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.Messaging;
using Screenbox.Core.Messages;
using Windows.Storage;
using Windows.Storage.AccessCache;
using Windows.Storage.Pickers;

namespace Screenbox.Models;

public sealed class MosuanFolderPlaylist
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string Name { get; set; } = "";
    public string FolderPath { get; set; } = "";
    public string FolderToken { get; set; } = "";
    public List<string> Files { get; set; } = new();
    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;
    public int FileCount => Files?.Count ?? 0;
    public int ScanWarningCount { get; set; }
    public string ScanWarningText => ScanWarningCount > 0 ? $"有 {ScanWarningCount} 个子文件夹暂时无法读取" : "扫描完整";
    public string UpdatedAtText => UpdatedAtUtc.ToLocalTime().ToString("yyyy-MM-dd HH:mm");
}

public sealed class MosuanFolderPlaylistState
{
    public int Version { get; set; } = 2;
    public List<MosuanFolderPlaylist> Playlists { get; set; } = new();
}

/// <summary>
/// Persistent folder playlists backed by Windows FutureAccessList permissions.
/// Use StorageFolder APIs rather than Directory APIs so picked folders remain
/// accessible inside the packaged app sandbox.
/// </summary>
public sealed class MosuanFolderPlaylistService
{
    private const string StoreName = "mosuan-folder-playlists.json";
    private static readonly string[] VideoExtensions =
        { ".mp4", ".mkv", ".mov", ".avi", ".wmv", ".m4v", ".webm", ".ts", ".m2ts" };

    public MosuanFolderPlaylistState State { get; private set; } = new();

    public async Task LoadAsync()
    {
        try
        {
            var file = await ApplicationData.Current.LocalFolder.CreateFileAsync(
                StoreName, CreationCollisionOption.OpenIfExists);
            var json = await FileIO.ReadTextAsync(file);
            State = JsonSerializer.Deserialize<MosuanFolderPlaylistState>(json) ?? new();
            State.Playlists ??= new();
            foreach (var playlist in State.Playlists)
                playlist.Files ??= new();
        }
        catch
        {
            State = new();
        }
    }

    public async Task SaveAsync()
    {
        var file = await ApplicationData.Current.LocalFolder.CreateFileAsync(
            StoreName, CreationCollisionOption.ReplaceExisting);
        await FileIO.WriteTextAsync(file, JsonSerializer.Serialize(State,
            new JsonSerializerOptions { WriteIndented = true }));
    }

    public Task<MosuanFolderPlaylist?> AddFolderFromPickerAsync() =>
        AddFolderFromPickerAsync(PickerLocationId.VideosLibrary);

    public Task<MosuanFolderPlaylist?> AddNetworkFolderFromPickerAsync() =>
        AddFolderFromPickerAsync(PickerLocationId.ComputerFolder);

    private async Task<MosuanFolderPlaylist?> AddFolderFromPickerAsync(PickerLocationId startLocation)
    {
        // The Windows picker handles network discovery and credentials. The selected
        // StorageFolder is then retained through FutureAccessList for later sessions.
        var picker = new FolderPicker();
        picker.SuggestedStartLocation = startLocation;
        picker.FileTypeFilter.Add("*");
        StorageFolder? folder = await picker.PickSingleFolderAsync();
        return folder is null ? null : await AddFolderAsync(folder);
    }

    public async Task<MosuanFolderPlaylist> AddFolderAsync(StorageFolder folder)
    {
        if (folder is null) throw new ArgumentNullException(nameof(folder));

        var existing = State.Playlists.FirstOrDefault(x =>
            string.Equals(x.FolderPath, folder.Path, StringComparison.OrdinalIgnoreCase));
        if (existing is not null)
        {
            if (string.IsNullOrWhiteSpace(existing.FolderToken))
                existing.FolderToken = Guid.NewGuid().ToString("N");
            global::Windows.Storage.AccessCache.StorageApplicationPermissions.FutureAccessList.AddOrReplace(existing.FolderToken, folder);
            await RefreshAsync(existing.Id);
            return existing;
        }

        var playlist = new MosuanFolderPlaylist
        {
            Name = folder.DisplayName,
            FolderPath = folder.Path,
            FolderToken = Guid.NewGuid().ToString("N")
        };
        global::Windows.Storage.AccessCache.StorageApplicationPermissions.FutureAccessList.AddOrReplace(playlist.FolderToken, folder);
        playlist.Files = await ScanFolderAsync(folder, count => playlist.ScanWarningCount = count);
        State.Playlists.Insert(0, playlist);
        await SaveAsync();
        return playlist;
    }

    public async Task<bool> ReauthorizeAsync(string playlistId)
    {
        var playlist = Find(playlistId);
        if (playlist is null) return false;

        // Reopen the Windows picker so the user can restore access to an offline
        // or expired local/SMB folder without losing the playlist entry.
        var picker = new FolderPicker();
        picker.SuggestedStartLocation = PickerLocationId.ComputerFolder;
        picker.FileTypeFilter.Add("*");
        var folder = await picker.PickSingleFolderAsync();
        if (folder is null) return false;

        if (string.IsNullOrWhiteSpace(playlist.FolderToken))
            playlist.FolderToken = Guid.NewGuid().ToString("N");

        global::Windows.Storage.AccessCache.StorageApplicationPermissions.FutureAccessList
            .AddOrReplace(playlist.FolderToken, folder);
        playlist.Name = folder.DisplayName;
        playlist.FolderPath = folder.Path;
        playlist.Files = await ScanFolderAsync(folder, count => playlist.ScanWarningCount = count);
        playlist.UpdatedAtUtc = DateTime.UtcNow;
        await SaveAsync();
        return true;
    }

    public async Task RefreshAsync(string playlistId)
    {
        var playlist = Find(playlistId);
        if (playlist is null || string.IsNullOrWhiteSpace(playlist.FolderToken)) return;

        try
        {
            var folder = await global::Windows.Storage.AccessCache.StorageApplicationPermissions.FutureAccessList.GetFolderAsync(playlist.FolderToken);
            playlist.FolderPath = folder.Path;
            playlist.Files = await ScanFolderAsync(folder, count => playlist.ScanWarningCount = count);
            playlist.UpdatedAtUtc = DateTime.UtcNow;
            await SaveAsync();
        }
        catch
        {
            // Preserve the last known file list and let the UI report the access error.
            throw;
        }
    }

    public async Task RemoveAsync(string playlistId)
    {
        var playlist = Find(playlistId);
        if (playlist is null) return;
        if (!string.IsNullOrWhiteSpace(playlist.FolderToken) &&
            global::Windows.Storage.AccessCache.StorageApplicationPermissions.FutureAccessList.ContainsItem(playlist.FolderToken))
        {
            global::Windows.Storage.AccessCache.StorageApplicationPermissions.FutureAccessList.Remove(playlist.FolderToken);
        }
        State.Playlists.Remove(playlist);
        await SaveAsync();
    }

    public async Task PlayAsync(string playlistId)
    {
        var playlist = Find(playlistId);
        if (playlist is null || string.IsNullOrWhiteSpace(playlist.FolderToken)) return;

        var folder = await global::Windows.Storage.AccessCache.StorageApplicationPermissions.FutureAccessList.GetFolderAsync(playlist.FolderToken);
        var files = await GetVideoFilesAsync(folder);
        if (files.Count == 0)
            throw new InvalidOperationException("该文件夹中没有找到支持的视频文件，请先刷新列表或检查文件格式。");

        global::CommunityToolkit.Mvvm.Messaging.WeakReferenceMessenger.Default.Send(new PlayFilesMessage(files.Cast<IStorageItem>().ToArray()));
    }

    public MosuanFolderPlaylist? Find(string playlistId) =>
        State.Playlists.FirstOrDefault(x => x.Id == playlistId);

    public async Task PlayFileAsync(string playlistId, string filePath)
    {
        var playlist = Find(playlistId);
        if (playlist is null || string.IsNullOrWhiteSpace(playlist.FolderToken))
            throw new InvalidOperationException("找不到文件夹播放列表或访问权限已失效。");

        var folder = await global::Windows.Storage.AccessCache.StorageApplicationPermissions
            .FutureAccessList.GetFolderAsync(playlist.FolderToken);
        var files = await GetVideoFilesAsync(folder);
        var selected = files.FirstOrDefault(x =>
            string.Equals(x.Path, filePath, StringComparison.OrdinalIgnoreCase));
        if (selected is null)
            throw new FileNotFoundException("视频文件不存在或当前不可访问，请刷新播放列表。", filePath);

        global::CommunityToolkit.Mvvm.Messaging.WeakReferenceMessenger.Default.Send(
            new PlayFilesMessage(new IStorageItem[] { selected }));
    }

    public async Task<bool> OpenFolderAsync(string playlistId)
    {
        var playlist = Find(playlistId);
        if (playlist is null || string.IsNullOrWhiteSpace(playlist.FolderToken)) return false;

        var folder = await global::Windows.Storage.AccessCache.StorageApplicationPermissions
            .FutureAccessList.GetFolderAsync(playlist.FolderToken);
        return await global::Windows.System.Launcher.LaunchFolderAsync(folder);
    }

    public async Task<bool> RenameAsync(string playlistId, string name)
    {
        var playlist = Find(playlistId);
        var normalized = name?.Trim();
        if (playlist is null || string.IsNullOrWhiteSpace(normalized)) return false;

        playlist.Name = normalized;
        await SaveAsync();
        return true;
    }

    public async Task<bool> MoveAsync(string playlistId, int offset)
    {
        var index = State.Playlists.FindIndex(x => x.Id == playlistId);
        if (index < 0) return false;

        var target = index + offset;
        if (target < 0 || target >= State.Playlists.Count) return false;

        var playlist = State.Playlists[index];
        State.Playlists.RemoveAt(index);
        State.Playlists.Insert(target, playlist);
        await SaveAsync();
        return true;
    }

    public IReadOnlyList<string> GetFiles(string playlistId)
    {
        var playlist = Find(playlistId);
        if (playlist is null) return Array.Empty<string>();
        return playlist.Files;
    }

    private static async Task<List<string>> ScanFolderAsync(StorageFolder folder, Action<int>? onSkipped = null)
    {
        var skipped = new List<string>();
        var files = await GetVideoFilesAsync(folder, skipped);
        onSkipped?.Invoke(skipped.Count);
        return files.Select(x => x.Path).ToList();
    }

    // Scan the whole folder tree. An inaccessible nested directory should not
    // prevent the rest of a local/SMB playlist from being usable.
    private static async Task<IReadOnlyList<StorageFile>> GetVideoFilesAsync(
        StorageFolder folder, List<string>? skippedFolders = null)
    {
        var result = new List<StorageFile>();
        await CollectVideoFilesAsync(folder, result, skippedFolders);
        return result
            .OrderBy(x => x.Path, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static async Task CollectVideoFilesAsync(
        StorageFolder folder, List<StorageFile> result, List<string>? skippedFolders = null)
    {
        var files = await folder.GetFilesAsync();
        foreach (var file in files)
        {
            if (IsVideoFile(file.Name))
                result.Add(file);
        }

        var folders = await folder.GetFoldersAsync();
        foreach (var child in folders.OrderBy(x => x.Name, StringComparer.OrdinalIgnoreCase))
        {
            try
            {
                await CollectVideoFilesAsync(child, result, skippedFolders);
            }
            catch (UnauthorizedAccessException)
            {
                skippedFolders?.Add(child.Path);
            }
            catch (IOException)
            {
                skippedFolders?.Add(child.Path);
            }
        }
    }

    public static bool IsVideoFile(string path) =>
        VideoExtensions.Contains(Path.GetExtension(path), StringComparer.OrdinalIgnoreCase);
}
'@ | Set-Content -Path $target -Encoding UTF8

Write-Host 'Mosuan folder playlist service generated with FutureAccessList permissions.'
