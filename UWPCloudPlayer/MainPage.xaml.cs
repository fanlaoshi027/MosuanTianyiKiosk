using System;
using System.Collections.Generic;
using System.Linq;
using Windows.Storage;
using Windows.Storage.Pickers;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using UWPCloudPlayer.Models;
using UWPCloudPlayer.Services;

namespace UWPCloudPlayer
{
    public sealed partial class MainPage : Page
    {
        private readonly UserDataStore _store = new UserDataStore();
        private List<FavoriteFolder> _favorites = new List<FavoriteFolder>();
        private List<Playlist> _playlists = new List<Playlist>();
        private bool _inverted;

        public MainPage()
        {
            InitializeComponent();
            Loaded += MainPage_Loaded;
        }

        private async void MainPage_Loaded(object sender, RoutedEventArgs e)
        {
            _favorites = await _store.LoadFavoritesAsync();
            _playlists = await _store.LoadPlaylistsAsync();
            RefreshLists();
        }

        private async void OpenButton_Click(object sender, RoutedEventArgs e)
        {
            var picker = new FileOpenPicker { SuggestedStartLocation = PickerLocationId.Videos };
            picker.FileTypeFilter.Add(".mp4");
            picker.FileTypeFilter.Add(".m4v");
            picker.FileTypeFilter.Add(".mov");
            var file = await picker.PickSingleFileAsync();
            if (file != null)
                await PlayFileAsync(file);
        }

        private async void OpenSmbButton_Click(object sender, RoutedEventArgs e)
        {
            var picker = new FolderPicker { SuggestedStartLocation = PickerLocationId.ComputerFolder };
            picker.FileTypeFilter.Add("*");
            var folder = await picker.PickSingleFolderAsync();
            if (folder == null) return;

            StorageApplicationPermissions.FutureAccessList.AddOrReplace("smb-root", folder);
            await LoadFolderAsync(folder);
        }

        private async void FavoriteFolderButton_Click(object sender, RoutedEventArgs e)
        {
            var picker = new FolderPicker { SuggestedStartLocation = PickerLocationId.ComputerFolder };
            picker.FileTypeFilter.Add("*");
            var folder = await picker.PickSingleFolderAsync();
            if (folder == null) return;

            if (!_favorites.Any(x => string.Equals(x.Path, folder.Path, StringComparison.OrdinalIgnoreCase)))
            {
                _favorites.Add(new FavoriteFolder { Name = folder.Name, Path = folder.Path, Provider = "SMB/Windows" });
                await _store.SaveFavoritesAsync(_favorites);
                RefreshLists();
            }
        }

        private async void FavoritesList_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            var item = FavoritesList.SelectedItem as FavoriteFolder;
            if (item == null) return;
            try
            {
                var folder = await StorageFolder.GetFolderFromPathAsync(item.Path);
                await LoadFolderAsync(folder);
            }
            catch
            {
                // The network location may currently be offline.
            }
        }

        private async System.Threading.Tasks.Task LoadFolderAsync(StorageFolder folder)
        {
            var files = await folder.GetFilesAsync();
            var videos = files.Where(IsVideo).OrderBy(x => x.Name, StringComparer.OrdinalIgnoreCase).ToList();
            PlaylistList.ItemsSource = videos;
            if (videos.Count > 0)
                await PlayFileAsync(videos[0]);
        }

        private async System.Threading.Tasks.Task PlayFileAsync(StorageFile file)
        {
            Player.Source = Windows.Media.Core.MediaSource.CreateFromStorageFile(file);
            await System.Threading.Tasks.Task.CompletedTask;
        }

        private static bool IsVideo(StorageFile file)
        {
            var ext = file.FileType?.ToLowerInvariant();
            return ext == ".mp4" || ext == ".m4v" || ext == ".mov";
        }

        private void RefreshLists()
        {
            FavoritesList.ItemsSource = null;
            FavoritesList.ItemsSource = _favorites;
            PlaylistList.ItemsSource = _playlists.Select(x => x.Name).ToList();
        }

        private void TemperatureSlider_ValueChanged(object sender, Windows.UI.Xaml.Controls.Primitives.RangeBaseValueChangedEventArgs e)
        {
            // Rendering pipeline hook. The actual GPU color-temperature effect is added with the video effects layer.
        }

        private void InvertButton_Click(object sender, RoutedEventArgs e)
        {
            _inverted = !_inverted;
            // Rendering pipeline hook for the native video effect layer.
        }

        private void CropButton_Click(object sender, RoutedEventArgs e)
        {
            // Opens the native percentage-based crop mode in the next player layer.
        }

        private void FullscreenButton_Click(object sender, RoutedEventArgs e)
        {
            ApplicationView.GetForCurrentView().TryEnterFullScreenMode();
        }
    }
}
