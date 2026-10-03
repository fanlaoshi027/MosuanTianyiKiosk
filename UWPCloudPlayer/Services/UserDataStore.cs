using System;
using System.Collections.Generic;
using System.Linq;
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
            var list = await LoadAsync<List<FavoriteFolder>>(FavoritesKey);
            return list ?? new List<FavoriteFolder>();
        }

        public async Task SaveFavoritesAsync(List<FavoriteFolder> items)
        {
            await SaveAsync(FavoritesKey, items);
        }

        public async Task<List<Playlist>> LoadPlaylistsAsync()
        {
            var list = await LoadAsync<List<Playlist>>(PlaylistsKey);
            return list ?? new List<Playlist>();
        }

        public async Task SavePlaylistsAsync(List<Playlist> items)
        {
            await SaveAsync(PlaylistsKey, items);
        }

        private static async Task SaveAsync<T>(string key, T value)
        {
            var file = await ApplicationData.Current.LocalFolder.CreateFileAsync(key + ".json", CreationCollisionOption.ReplaceExisting);
            var json = Newtonsoft.Json.JsonConvert.SerializeObject(value);
            await FileIO.WriteTextAsync(file, json);
        }

        private static async Task<T> LoadAsync<T>(string key)
        {
            try
            {
                var file = await ApplicationData.Current.LocalFolder.GetFileAsync(key + ".json");
                var json = await FileIO.ReadTextAsync(file);
                return Newtonsoft.Json.JsonConvert.DeserializeObject<T>(json);
            }
            catch
            {
                return default(T);
            }
        }
    }
}
