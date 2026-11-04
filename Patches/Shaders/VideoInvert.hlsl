Texture2D VideoTexture : register(t0);
SamplerState VideoSampler : register(s0);

struct VertexOutput
{
    float4 Position : SV_Position;
    float2 TexCoord : TEXCOORD0;
};

// Full-screen triangle generated from SV_VertexID.
VertexOutput VSMain(uint vertexId : SV_VertexID)
{
    VertexOutput output;
    float2 position = float2((vertexId << 1) & 2, vertexId & 2);
    output.TexCoord = float2(position.x, 1.0 - position.y);
    output.Position = float4(position * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    return output;
}

float4 PSMain(float4 position : SV_Position, float2 texCoord : TEXCOORD0) : SV_Target
{
    float4 color = VideoTexture.Sample(VideoSampler, texCoord);
    color.rgb = 1.0 - color.rgb;
    return color;
}
