namespace Mosuan.SmartInvert;

/// <summary>
/// Constant-buffer values shared by the future D3D11 smart-invert shader.
/// Values are normalized to the shader's 0..1 range.
/// </summary>
public readonly record struct SmartInvertGpuConstants(
    float WhiteLumaThreshold,
    float WhiteSaturationThreshold,
    float TargetBlack,
    float Enabled)
{
    public static SmartInvertGpuConstants FromSettings(SmartInvertSettings settings) =>
        new(
            settings.WhiteLumaThreshold,
            settings.WhiteSaturationThreshold,
            settings.TargetBlack / 255f,
            settings.Enabled ? 1f : 0f);
}
