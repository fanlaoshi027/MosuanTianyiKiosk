using System;
using System.Threading.Tasks;
using Windows.Storage;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Microsoft.Web.WebView2.Core;

namespace MosuanTianyiKiosk
{
    public sealed partial class MainPage : Page
    {
        private const string StartUrl = "https://cloud.189.cn/";
        private bool _scriptInjected;

        public MainPage()
        {
            InitializeComponent();
            Loaded += MainPage_Loaded;
        }

        private async void MainPage_Loaded(object sender, RoutedEventArgs e)
        {
            try
            {
                await Browser.EnsureCoreWebView2Async();
                ConfigureBrowser();
                Browser.CoreWebView2.NavigationCompleted += CoreWebView2_NavigationCompleted;
                Browser.CoreWebView2.NewWindowRequested += CoreWebView2_NewWindowRequested;
                Browser.CoreWebView2.Navigate(StartUrl);
            }
            catch (Exception ex)
            {
                await ShowErrorAsync("WebView2 初始化失败", ex.Message);
            }
        }

        private void ConfigureBrowser()
        {
            var settings = Browser.CoreWebView2.Settings;
            settings.IsStatusBarEnabled = false;
            settings.AreDefaultContextMenusEnabled = true;
            settings.IsZoomControlEnabled = true;
            settings.AreDevToolsEnabled = false;
            settings.IsPasswordAutosaveEnabled = true;
            settings.IsGeneralAutofillEnabled = true;
        }

        private void CoreWebView2_NewWindowRequested(object sender, CoreWebView2NewWindowRequestedEventArgs e)
        {
            e.Handled = true;
            if (!string.IsNullOrWhiteSpace(e.Uri))
                Browser.CoreWebView2.Navigate(e.Uri);
        }

        private async void CoreWebView2_NavigationCompleted(object sender, CoreWebView2NavigationCompletedEventArgs e)
        {
            if (!e.IsSuccess)
                return;

            _scriptInjected = false;
            await InjectMosuanPlayerAsync();
        }

        private async Task InjectMosuanPlayerAsync()
        {
            if (_scriptInjected || Browser.CoreWebView2 == null)
                return;

            try
            {
                var file = await StorageFile.GetFileFromApplicationUriAsync(
                    new Uri("ms-appx:///Web/MosuanPlayer.js"));
                var script = await FileIO.ReadTextAsync(file);
                await Browser.CoreWebView2.ExecuteScriptAsync(script);
                _scriptInjected = true;
            }
            catch
            {
                // Navigation can replace the document while injection is pending.
                // A later navigation will retry automatically.
            }
        }

        private async Task ShowErrorAsync(string title, string message)
        {
            var dialog = new ContentDialog
            {
                Title = title,
                Content = message,
                CloseButtonText = "确定"
            };
            await dialog.ShowAsync();
        }
    }
}
