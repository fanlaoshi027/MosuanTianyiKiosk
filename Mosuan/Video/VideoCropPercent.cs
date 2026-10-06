namespace Mosuan.Video;

/// <summary>
/// Resolution-independent crop rectangle expressed as percentages of the source video.
/// Values are always clamped to 0..100 and normalized internally by callers.
/// </summary>
public readonly record struct VideoCropPercent(
    double Left,
    double Top,
    double Right,
    double Bottom)
{
    public VideoCropPercent Normalize()
    {
        var left = Math.Clamp(Left, 0d, 100d);
        var top = Math.Clamp(Top, 0d, 100d);
        var right = Math.Clamp(Right, 0d, 100d);
        var bottom = Math.Clamp(Bottom, 0d, 100d);

        if (right < left)
            (left, right) = (right, left);

        if (bottom < top)
            (top, bottom) = (bottom, top);

        return new VideoCropPercent(left, top, right, bottom);
    }

    public double Width => Math.Max(0d, Right - Left);
    public double Height => Math.Max(0d, Bottom - Top);

    public double LeftNormalized => Normalize().Left / 100d;
    public double TopNormalized => Normalize().Top / 100d;
    public double RightNormalized => Normalize().Right / 100d;
    public double BottomNormalized => Normalize().Bottom / 100d;

    public static VideoCropPercent FullFrame => new(0, 0, 100, 100);
}
