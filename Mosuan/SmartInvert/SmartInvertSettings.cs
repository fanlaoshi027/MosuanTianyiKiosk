namespace Mosuan.SmartInvert;

/// <summary>
/// Configuration for Mosuan's teaching-video smart invert mode.
/// The mode is intentionally NOT RGB inversion:
/// bright, low-saturation pixels are mapped to ~90% black,
/// while colorful pixels are preserved.
/// </summary>
public sealed record SmartInvertSettings(
    bool Enabled = false,
    float WhiteLumaThreshold = 0.92f,
    float WhiteSaturationThreshold = 0.08f,
    byte TargetBlack = 26);

public static class SmartInvertAlgorithm
{
    public static bool IsWhiteLike(
        byte red,
        byte green,
        byte blue,
        SmartInvertSettings settings)
    {
        var max = Math.Max(red, Math.Max(green, blue));
        var min = Math.Min(red, Math.Min(green, blue));

        var luma =
            (0.2126f * red +
             0.7152f * green +
             0.0722f * blue) / 255f;

        var saturation = max == 0
            ? 0f
            : (max - min) / (float)max;

        return luma >= settings.WhiteLumaThreshold
            && saturation <= settings.WhiteSaturationThreshold;
    }

    public static (byte Red, byte Green, byte Blue) Transform(
        byte red,
        byte green,
        byte blue,
        SmartInvertSettings settings)
    {
        if (!settings.Enabled)
            return (red, green, blue);

        return IsWhiteLike(red, green, blue, settings)
            ? (settings.TargetBlack, settings.TargetBlack, settings.TargetBlack)
            : (red, green, blue);
    }
}
