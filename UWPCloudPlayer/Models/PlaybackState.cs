using System;

namespace UWPCloudPlayer.Models
{
    public sealed class PlaybackState
    {
        public string Path { get; set; }
        public double PositionSeconds { get; set; }
        public DateTime UpdatedUtc { get; set; }
    }
}
