using System.Collections.Generic;
using System.IO;
using System.Runtime.Serialization.Json;
using System.Text;
using System.Threading.Tasks;
using Windows.Storage;
using UWPCloudPlayer.Models;

namespace UWPCloudPlayer.Services
{
    public sealed class UserDataStore
    {
        private const string FavoritesKey = "favorites";
        private const string PlaylistsKey = "playlists";

        public async Task<List<FavoriteFolder>> LoadFavoritesAsync()
        {
            return await LoadAsync<List<FavoriteFolder>>(FavoritesKey) ?? new List<FavoriteFolder>();
        }

        public Task SaveFavoritesAsync(List<FavoriteFolder> items)
        {
            return SaveAsync(FavoritesKey, items);
        }

        public async Task<List<Playlist>> LoadPlaylistsAsync()
        {
            return await LoadAsync<List<Playlist>>(PlaylistsKey) ?? new List<Playlist>();
        }

        public Task SavePlaylistsAsync(List<Playlist> items)
        {
            return SaveAsync(PlaylistsKey, items);
        }

        private static async Task SaveAsync<T>(string key, T value)
        {
            var file = await ApplicationData.Current.LocalFolder.CreateFileAsync(
                key + ".json", CreationCollisionOption.ReplaceExisting);

            var serializer = new DataContractJsonSerializer(typeof(T));
            using (var stream = new MemoryStream())
            {
                serializer.WriteObject(stream, value);
                var json = Encoding.UTF8.GetString(stream.ToArray(), 0, (int)stream.Length);
                await FileIO.WriteTextAsync(file, json).AsTask();
            }
        }

        private static async Task<T> LoadAsync<T>(string key)
        {
            try
            {
                var file = await ApplicationData.Current.LocalFolder.GetFileAsync(key + ".json").AsTask();
                var json = await FileIO.ReadTextAsync(file).AsTask();
                var bytes = Encoding.UTF8.GetBytes(json);
                var serializer = new DataContractJsonSerializer(typeof(T));
                using (var stream = new MemoryStream(bytes))
                {
                    return (T)serializer.ReadObject(stream);
                }
            }
            catch
            {
                return default(T);
            }
        }
    }
}
