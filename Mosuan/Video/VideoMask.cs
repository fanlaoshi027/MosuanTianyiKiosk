namespace Mosuan.Video;

/// <summary>
/// A video masking rectangle. Coordinates are percentages so masks remain
/// correct when the video resolution or window size changes.
/// </summary>
public sealed record VideoMask(
    Guid Id,
    double Left,
    double Top,
    double Right,
    double Bottom,
    bool IsVisible = true)
{
    public VideoMask Normalize()
    {
        var left = Math.Clamp(Left, 0d, 100d);
        var top = Math.Clamp(Top, 0d, 100d);
        var right = Math.Clamp(Right, 0d, 100d);
        var bottom = Math.Clamp(Bottom, 0d, 100d);

        if (right < left)
            (left, right) = (right, left);

        if (bottom < top)
            (top, bottom) = (bottom, top);

        return this with { Left = left, Top = top, Right = right, Bottom = bottom };
    }

    public double Width => Math.Max(0d, Right - Left);
    public double Height => Math.Max(0d, Bottom - Top);

    public static VideoMask Create(
        double left, double top, double right, double bottom) =>
        new(Guid.NewGuid(), left, top, right, bottom).Normalize();
}
