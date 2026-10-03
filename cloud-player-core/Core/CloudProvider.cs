using System.Collections.Generic;
using System.Threading.Tasks;

namespace CloudPlayer.Core
{
    public sealed record CloudFile(string Id, string Name, bool IsFolder, string? PlaybackUrl = null);

    public interface ICloudProvider
    {
        Task<IReadOnlyList<CloudFile>> ListAsync(string? parentId = null);
        Task<string?> GetPlaybackUrlAsync(CloudFile file);
    }
}
