using System.Collections.Generic;
using System.Threading.Tasks;
using Windows.Storage;

namespace UWPCloudPlayer.Cloud
{
    public interface IFileProvider
    {
        string Name { get; }
        Task<StorageFolder> GetFolderAsync(string path);
        Task<IReadOnlyList<StorageFile>> GetVideoFilesAsync(StorageFolder folder);
        Task<IReadOnlyList<StorageFolder>> GetSubfoldersAsync(StorageFolder folder);
    }
}
