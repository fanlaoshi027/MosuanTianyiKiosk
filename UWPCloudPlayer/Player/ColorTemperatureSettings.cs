namespace UWPCloudPlayer.Player
{
    public sealed class ColorTemperatureSettings
    {
        // 0 = neutral, negative = cooler, positive = warmer.
        public double Temperature { get; set; } = 0;
        public bool Enabled => Temperature != 0;

        public void Reset() => Temperature = 0;
    }
}
