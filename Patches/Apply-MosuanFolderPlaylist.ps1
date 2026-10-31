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

    public async Task<MosuanFolderPlaylist?> AddFolderFromPickerAsync()
    {
        var picker = new FolderPicker();
        picker.SuggestedStartLocation = PickerLocationId.VideosLibrary;
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
            existing.FolderToken = existing.Id;
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
        playlist.Files = await ScanFolderAsync(folder);
        State.Playlists.Insert(0, playlist);
        await SaveAsync();
        return playlist;
    }

    public async Task RefreshAsync(string playlistId)
    {
        var playlist = Find(playlistId);
        if (playlist is null || string.IsNullOrWhiteSpace(playlist.FolderToken)) return;

        try
        {
            var folder = await global::Windows.Storage.AccessCache.StorageApplicationPermissions.FutureAccessList.GetFolderAsync(playlist.FolderToken);
            playlist.FolderPath = folder.Path;
            playlist.Files = await ScanFolderAsync(folder);
            playlist.UpdatedAtUtc = DateTime.UtcNow;
            await SaveAsync();
        }
        catch (Exception)
        {
            // Keep the playlist entry so the user can re-authorize it later.
            playlist.Files = new();
            await SaveAsync();
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
        if (files.Count == 0) return;

        global::CommunityToolkit.Mvvm.Messaging.WeakReferenceMessenger.Default.Send(new PlayFilesMessage(files.Cast<IStorageItem>().ToArray()));
    }

    public MosuanFolderPlaylist? Find(string playlistId) =>
        State.Playlists.FirstOrDefault(x => x.Id == playlistId);

    public IReadOnlyList<string> GetFiles(string playlistId)
    {
        var playlist = Find(playlistId);
        if (playlist is null) return Array.Empty<string>();
        return playlist.Files;
    }

    private static async Task<List<string>> ScanFolderAsync(StorageFolder folder)
    {
        var files = await GetVideoFilesAsync(folder);
        return files.Select(x => x.Path).ToList();
    }

    private static async Task<IReadOnlyList<StorageFile>> GetVideoFilesAsync(StorageFolder folder)
    {
        var files = await folder.GetFilesAsync();
        return files
            .Where(x => IsVideoFile(x.Name))
            .OrderBy(x => x.Name, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    public static bool IsVideoFile(string path) =>
        VideoExtensions.Contains(Path.GetExtension(path), StringComparer.OrdinalIgnoreCase);
}
'@ | Set-Content -Path $target -Encoding UTF8

Write-Host 'Mosuan folder playlist service generated with FutureAccessList permissions.'
