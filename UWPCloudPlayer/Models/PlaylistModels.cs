using System;
using System.Collections.Generic;

namespace UWPCloudPlayer.Models
{
    public sealed class FavoriteFolder
    {
        public string Name { get; set; }
        public string Path { get; set; }
        public string Provider { get; set; }
    }

    public sealed class PlaylistItem
    {
        public string Name { get; set; }
        public string Path { get; set; }
        public string Provider { get; set; }
    }

    public sealed class Playlist
    {
        public string Name { get; set; }
        public List<PlaylistItem> Items { get; set; } = new List<PlaylistItem>();
    }
}
