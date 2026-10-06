cbuffer SmartInvertConstants : register(b0)
{
    float WhiteLumaThreshold;
    float WhiteSaturationThreshold;
    float TargetBlack;
    float Enabled;
};

Texture2D VideoTexture : register(t0);
SamplerState VideoSampler : register(s0);

struct PixelInput
{
    float4 Position : SV_POSITION;
    float2 TexCoord : TEXCOORD0;
};

float Luma(float3 rgb)
{
    return dot(rgb, float3(0.2126, 0.7152, 0.0722));
}

float Saturation(float3 rgb)
{
    float hi = max(rgb.r, max(rgb.g, rgb.b));
    float lo = min(rgb.r, min(rgb.g, rgb.b));
    return hi <= 0.0001 ? 0.0 : (hi - lo) / hi;
}

float4 SmartInvertPixel(PixelInput input) : SV_TARGET
{
    float4 sample = VideoTexture.Sample(VideoSampler, input.TexCoord);

    if (Enabled < 0.5)
        return sample;

    float luma = Luma(sample.rgb);
    float saturation = Saturation(sample.rgb);

    if (luma >= WhiteLumaThreshold &&
        saturation <= WhiteSaturationThreshold)
    {
        sample.rgb = float3(TargetBlack, TargetBlack, TargetBlack);
    }

    return sample;
}
