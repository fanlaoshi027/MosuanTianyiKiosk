using System;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;

namespace MosuanTianyiKiosk
{
    public sealed partial class MainPage : Page
    {
        private const string TianyiUrl = "https://cloud.189.cn/";

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
                var settings = Browser.CoreWebView2.Settings;
                settings.IsStatusBarEnabled = false;
                settings.AreDevToolsEnabled = false;
                settings.IsZoomControlEnabled = true;
                Browser.CoreWebView2.Navigate(TianyiUrl);
            }
            catch (Exception ex)
            {
                await new ContentDialog
                {
                    Title = "墨算天翼云播放器",
                    Content = "WebView2 初始化失败：\n\n" + ex.Message,
                    CloseButtonText = "确定"
                }.ShowAsync();
            }
        }
    }
}
