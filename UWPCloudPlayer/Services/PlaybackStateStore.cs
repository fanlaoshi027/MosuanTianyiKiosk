using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.Serialization.Json;
using System.Text;
using System.Threading.Tasks;
using Windows.Storage;
using UWPCloudPlayer.Models;

namespace UWPCloudPlayer.Services
{
    public sealed class PlaybackStateStore
    {
        private const string FileName = "playback-state.json";

        public async Task<PlaybackState> GetAsync(string path)
        {
            var all = await LoadAsync();
            PlaybackState state;
            return all.TryGetValue(path, out state) ? state : null;
        }

        public async Task SetAsync(string path, double seconds)
        {
            var all = await LoadAsync();
            all[path] = new PlaybackState
            {
                Path = path,
                PositionSeconds = Math.Max(0, seconds),
                UpdatedUtc = DateTime.UtcNow
            };
            await SaveAsync(all);
        }

        private static async Task<Dictionary<string, PlaybackState>> LoadAsync()
        {
            try
            {
                var file = await ApplicationData.Current.LocalFolder.GetFileAsync(FileName);
                var json = await FileIO.ReadTextAsync(file);
                var serializer = new DataContractJsonSerializer(typeof(Dictionary<string, PlaybackState>));
                using (var stream = new MemoryStream(Encoding.UTF8.GetBytes(json)))
                    return (Dictionary<string, PlaybackState>)serializer.ReadObject(stream);
            }
            catch
            {
                return new Dictionary<string, PlaybackState>(StringComparer.OrdinalIgnoreCase);
            }
        }

        private static async Task SaveAsync(Dictionary<string, PlaybackState> value)
        {
            var file = await ApplicationData.Current.LocalFolder.CreateFileAsync(FileName, CreationCollisionOption.ReplaceExisting);
            var serializer = new DataContractJsonSerializer(typeof(Dictionary<string, PlaybackState>));
            using (var stream = new MemoryStream())
            {
                serializer.WriteObject(stream, value);
                await FileIO.WriteTextAsync(file, Encoding.UTF8.GetString(stream.ToArray()));
            }
        }
    }
}
