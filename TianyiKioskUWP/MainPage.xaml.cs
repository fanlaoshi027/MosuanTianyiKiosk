using System;
using Windows.UI.Xaml.Controls;

namespace TianyiKioskUWP
{
    public sealed partial class MainPage : Page
    {
        private const string TianyiUrl = "https://cloud.189.cn/";

        public MainPage()
        {
            InitializeComponent();
            Browser.NavigationFailed += Browser_NavigationFailed;
            Browser.Navigate(new Uri(TianyiUrl));
        }

        private void Browser_NavigationFailed(object sender, WebViewNavigationFailedEventArgs e)
        {
            // Keep the shell alive if the network is temporarily unavailable.
        }
    }
}