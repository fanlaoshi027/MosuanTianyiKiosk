using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Windows.Storage;

namespace UWPCloudPlayer.Cloud
{
    public sealed class SmbFileProvider : IFileProvider
    {
        public string Name => "SMB 局域网";

        public async Task<StorageFolder> GetFolderAsync(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
                throw new ArgumentException("SMB 路径不能为空。", nameof(path));

            return await StorageFolder.GetFolderFromPathAsync(path);
        }

        public async Task<IReadOnlyList<StorageFile>> GetVideoFilesAsync(StorageFolder folder)
        {
            var files = await folder.GetFilesAsync();
            return files
                .Where(IsVideo)
                .OrderBy(f => f.Name, StringComparer.OrdinalIgnoreCase)
                .ToList();
        }

        public async Task<IReadOnlyList<StorageFolder>> GetSubfoldersAsync(StorageFolder folder)
        {
            var folders = await folder.GetFoldersAsync();
            return folders.OrderBy(f => f.Name, StringComparer.OrdinalIgnoreCase).ToList();
        }

        private static bool IsVideo(StorageFile file)
        {
            var ext = file.FileType?.ToLowerInvariant();
            return ext == ".mp4" || ext == ".m4v" || ext == ".mov" || ext == ".mkv";
        }
    }
}
