using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Windows.Media.Core;
using Windows.Storage;
using Windows.Storage.Pickers;
using Windows.UI.ViewManagement;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using UWPCloudPlayer.Models;
using UWPCloudPlayer.Services;

namespace UWPCloudPlayer
{
    public sealed partial class MainPage : Page
    {
        private readonly UserDataStore _store = new UserDataStore();
        private readonly PlaybackStateStore _playbackStore = new PlaybackStateStore();
        private List<FavoriteFolder> _favorites = new List<FavoriteFolder>();
        private List<Playlist> _playlists = new List<Playlist>();
        private List<StorageFile> _currentQueue = new List<StorageFile>();
        private int _currentIndex = -1;
        private StorageFile _currentFile;
        private bool _inverted;

        public MainPage()
        {
            InitializeComponent();
            Loaded += MainPage_Loaded;
            Player.MediaPlayer.MediaEnded += MediaPlayer_MediaEnded;
            Player.MediaPlayer.CurrentStateChanged += MediaPlayer_CurrentStateChanged;
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
            picker.FileTypeFilter.Add(".mkv");
            var file = await picker.PickSingleFileAsync();
            if (file != null)
            {
                _currentQueue = new List<StorageFile> { file };
                _currentIndex = 0;
                await PlayCurrentAsync();
            }
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
            catch { }
        }

        private async Task LoadFolderAsync(StorageFolder folder)
        {
            var files = await folder.GetFilesAsync();
            _currentQueue = files.Where(IsVideo).OrderBy(x => x.Name, StringComparer.OrdinalIgnoreCase).ToList();
            _currentIndex = _currentQueue.Count > 0 ? 0 : -1;
            PlaylistList.ItemsSource = _currentQueue;
            if (_currentIndex >= 0)
                await PlayCurrentAsync();
        }

        private async Task PlayCurrentAsync()
        {
            if (_currentIndex < 0 || _currentIndex >= _currentQueue.Count) return;
            _currentFile = _currentQueue[_currentIndex];
            Player.Source = MediaSource.CreateFromStorageFile(_currentFile);
            var state = await _playbackStore.GetAsync(_currentFile.Path);
            Player.MediaPlayer.Play();
            if (state != null && state.PositionSeconds > 3)
                Player.MediaPlayer.Position = TimeSpan.FromSeconds(state.PositionSeconds);
        }

        private async void MediaPlayer_MediaEnded(Windows.Media.PlaybackMediaPlayer sender, object args)
        {
            await SaveCurrentPositionAsync();
            if (_currentIndex + 1 < _currentQueue.Count)
            {
                _currentIndex++;
                await PlayCurrentAsync();
            }
        }

        private async void MediaPlayer_CurrentStateChanged(Windows.Media.PlaybackMediaPlayer sender, object args)
        {
            if (sender.CurrentState == Windows.Media.PlaybackMediaPlayerState.Paused ||
                sender.CurrentState == Windows.Media.PlaybackMediaPlayerState.None)
                await SaveCurrentPositionAsync();
        }

        private async Task SaveCurrentPositionAsync()
        {
            if (_currentFile == null) return;
            try
            {
                await _playbackStore.SetAsync(_currentFile.Path, Player.MediaPlayer.Position.TotalSeconds);
            }
            catch { }
        }

        private static bool IsVideo(StorageFile file)
        {
            var ext = file.FileType?.ToLowerInvariant();
            return ext == ".mp4" || ext == ".m4v" || ext == ".mov" || ext == ".mkv";
        }

        private void RefreshLists()
        {
            FavoritesList.ItemsSource = null;
            FavoritesList.ItemsSource = _favorites;
            PlaylistList.ItemsSource = _currentQueue;
        }

        private void TemperatureSlider_ValueChanged(object sender, Windows.UI.Xaml.Controls.Primitives.RangeBaseValueChangedEventArgs e) { }

        private void InvertButton_Click(object sender, RoutedEventArgs e)
        {
            _inverted = !_inverted;
        }

        private void CropButton_Click(object sender, RoutedEventArgs e) { }

        private void FullscreenButton_Click(object sender, RoutedEventArgs e)
        {
            var view = ApplicationView.GetForCurrentView();
            if (view.IsFullScreenMode) view.ExitFullScreenMode();
            else view.TryEnterFullScreenMode();
        }
    }
}
