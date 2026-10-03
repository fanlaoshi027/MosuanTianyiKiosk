using Windows.ApplicationModel;
using Windows.UI.Xaml;

namespace TianyiKioskUWP
{
    sealed partial class App : Application
    {
        public App()
        {
            InitializeComponent();
            Suspending += OnSuspending;
        }

        protected override void OnLaunched(LaunchActivatedEventArgs e)
        {
            var rootFrame = Window.Current.Content as Windows.UI.Xaml.Controls.Frame;
            if (rootFrame == null)
            {
                rootFrame = new Windows.UI.Xaml.Controls.Frame();
                Window.Current.Content = rootFrame;
            }

            if (rootFrame.Content == null)
                rootFrame.Navigate(typeof(MainPage), e.Arguments);

            Window.Current.Activate();
        }

        private void OnSuspending(object sender, SuspendingEventArgs e) { }
    }
}