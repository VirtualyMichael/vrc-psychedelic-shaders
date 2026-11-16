// PsyCommon.cginc - shared helpers for the Ravens Midnight psychedelic shader set.
// Define PSY_FRACTAL2D and/or PSY_FRACTAL3D before including to pull in the fractal code + its uniforms.
#ifndef PSY_COMMON_INCLUDED
#define PSY_COMMON_INCLUDED

#include "UnityCG.cginc"

#define PSY_PI 3.14159265
#define PSY_TAU 6.28318531

// GLSL-style mod (HLSL fmod is different for negatives)
float psyMod(float x, float y) { return x - y * floor(x / y); }
float2 psyMod2(float2 x, float y) { return x - y * floor(x / y); }

// ---------------------------------------------------------------- hashes / noise
float psyHash11(float n) { return frac(sin(n * 127.1 + 311.7) * 43758.5453); }
float2 psyHash21(float n) { return float2(psyHash11(n), psyHash11(n + 17.31)); }
float3 psyHash31v(float n) { return float3(psyHash11(n), psyHash11(n + 17.31), psyHash11(n + 41.93)); }

float psyHash31(float3 p)
{
    p = frac(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return frac((p.x + p.y) * p.z);
}

float psyNoise3(float3 x)
{
    float3 i = floor(x);
    float3 f = frac(x);
    f = f * f * (3.0 - 2.0 * f);
    float a = psyHash31(i);
    float b = psyHash31(i + float3(1, 0, 0));
    float c = psyHash31(i + float3(0, 1, 0));
    float d = psyHash31(i + float3(1, 1, 0));
    float e = psyHash31(i + float3(0, 0, 1));
    float g = psyHash31(i + float3(1, 0, 1));
    float h = psyHash31(i + float3(0, 1, 1));
    float k = psyHash31(i + float3(1, 1, 1));
    return lerp(lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y),
                lerp(lerp(e, g, f.x), lerp(h, k, f.x), f.y), f.z);
}

// signed 3-vector noise in [-1,1]
float3 psyNoise3v(float3 x)
{
    return float3(psyNoise3(x), psyNoise3(x + 31.4), psyNoise3(x + 71.9)) * 2.0 - 1.0;
}

// Domain-warped drifting flow field. Never loops visibly, smooth in space and time.
float3 psyFlow(float3 p, float t)
{
    float3 q = psyNoise3v(p + t * float3(0.31, 0.17, -0.23));
    return psyNoise3v(p + q * 1.5 + t * float3(-0.13, 0.21, 0.19));
}

float2 psyRot(float2 p, float a)
{
    float s, c;
    sincos(a, s, c);
    return float2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// ---------------------------------------------------------------- colour
float3 psyHSV(float h, float s, float v)
{
    return lerp(float3(1, 1, 1), saturate(abs(frac(h + float3(3, 2, 1) / 3.0) * 6.0 - 3.0) - 1.0), s) * v;
}

// cosine palette, used for oil-slick / thin film colours
float3 psyPalette(float t, float3 phase)
{
    return 0.5 + 0.5 * cos(PSY_TAU * (t + phase));
}

float3 psyRGBtoHSV(float3 c)
{
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// The hue banding step from the original "Persian Symettry 2" shader
float psyBandHue(float i)
{
    float h = floor(i * 6.0) / 5.0 + 0.1;
    h += smoothstep(0.0, 0.4, psyMod(i * 6.0 / 5.0, 1.0 / 5.0) * 5.10) / 5.10 - 1.1;
    return h;
}

// ---------------------------------------------------------------- 2D folded fractal (Persian Symettry 2, randomisable)
#ifdef PSY_FRACTAL2D
float4 _Fold;          // xy
float4 _Translate;     // xy
float _FScale;
float _Seed;
float _Jitter;
float _Iterations;
float _FlowSpeed;
float _RotBase, _RotAmp, _RotOff, _RotPhase;

// p: pattern-space position. x: out, the un-folded y (used for rainbow banding). Returns folded p.
float2 psyFractal2D(float2 p, float t, out float x)
{
    x = p.y;
    p = abs(psyMod2(p, 2.0) - 1.0);
    int n = (int)_Iterations;
    float tt = t * 0.0022 * _FlowSpeed;
    [loop]
    for (int i = 0; i < 48; i++)
    {
        if (i >= n) break;
        float fi = (float)i;
        // per-iteration jitter: breaks the exact repetition. 0 = original shader.
        float2 j = (psyHash21(fi + _Seed * 13.37) - 0.5) * _Jitter;
        float2 fold = _Fold.xy + j;
        p = abs(p - fold) + fold;
        p = p * (_FScale + j.x * 0.3) - (_Translate.xy + j.yx);
        float den = max(_RotBase + sin(tt + fi * (_RotPhase + j.y * 0.2)) * _RotAmp + _RotOff, 0.05);
        p = psyRot(p, PSY_PI / den);
    }
    return p;
}
#endif

// ---------------------------------------------------------------- VRChat helpers
float _VRChatMirrorMode;   // 0 = normal view, 1 = VR mirror, 2 = desktop mirror (set by VRChat)
float _VRChatCameraMode;   // 0 = normal, 1/2 = handheld camera, 3 = screenshot

#endif
