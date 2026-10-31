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
using Windows.Storage;

namespace Screenbox.Models;

public sealed class MosuanFolderPlaylist
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string Name { get; set; } = "";
    public string FolderPath { get; set; } = "";
    public List<string> Files { get; set; } = new();
    public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;
}

public sealed class MosuanFolderPlaylistState
{
    public int Version { get; set; } = 1;
    public List<MosuanFolderPlaylist> Playlists { get; set; } = new();
}

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

    public async Task<MosuanFolderPlaylist> AddFolderAsync(string folderPath, string? displayName = null)
    {
        if (string.IsNullOrWhiteSpace(folderPath) || !Directory.Exists(folderPath))
            throw new DirectoryNotFoundException($"播放列表文件夹不存在：{folderPath}");

        var existing = State.Playlists.FirstOrDefault(x =>
            string.Equals(x.FolderPath, folderPath, StringComparison.OrdinalIgnoreCase));
        if (existing != null)
        {
            await RefreshAsync(existing.Id);
            return existing;
        }

        var playlist = new MosuanFolderPlaylist
        {
            Name = string.IsNullOrWhiteSpace(displayName) ? Path.GetFileName(folderPath.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)) : displayName,
            FolderPath = folderPath
        };
        playlist.Files = ScanFolder(folderPath);
        State.Playlists.Add(playlist);
        await SaveAsync();
        return playlist;
    }

    public async Task RefreshAsync(string playlistId)
    {
        var playlist = Find(playlistId);
        if (playlist == null) return;
        playlist.Files = ScanFolder(playlist.FolderPath);
        playlist.UpdatedAtUtc = DateTime.UtcNow;
        await SaveAsync();
    }

    public async Task RemoveAsync(string playlistId)
    {
        State.Playlists.RemoveAll(x => x.Id == playlistId);
        await SaveAsync();
    }

    public MosuanFolderPlaylist? Find(string playlistId) =>
        State.Playlists.FirstOrDefault(x => x.Id == playlistId);

    public IReadOnlyList<string> GetFiles(string playlistId) =>
        Find(playlistId)?.Files ?? Array.Empty<string>();

    private static List<string> ScanFolder(string folderPath)
    {
        try
        {
            return Directory.EnumerateFiles(folderPath, "*", SearchOption.TopDirectoryOnly)
                .Where(IsVideoFile)
                .OrderBy(x => Path.GetFileName(x), StringComparer.OrdinalIgnoreCase)
                .ToList();
        }
        catch (UnauthorizedAccessException) { return new(); }
        catch (IOException) { return new(); }
    }

    public static bool IsVideoFile(string path) =>
        VideoExtensions.Contains(Path.GetExtension(path), StringComparer.OrdinalIgnoreCase);
}
'@ | Set-Content -Path $target -Encoding UTF8

Write-Host 'Mosuan folder playlist service generated.'
