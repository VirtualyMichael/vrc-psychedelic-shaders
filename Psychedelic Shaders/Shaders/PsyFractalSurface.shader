// Psychedelic Fractal - SURFACE version with 3D relief (clothes, props, anything with a mesh).
// Based on "Persian Symettry 2" by NPWR (shadertoy.com/view/ldSXzc, Shadertoy default licence CC BY-NC-SA 3.0).
// The rainbow bands are treated as a height map: hills and valleys light up, shift with parallax as you move,
// can physically push the mesh out, and travelling waves roll through the pattern.
// "Fractal Surface Classic" is the flat original-looking version.
Shader "Ravens/Psychedelic/Fractal Surface"
{
    Properties
    {
        [PsyGroup(Base)]
        _MainTex ("Base Texture", 2D) = "white" {}
        _FractalMix ("Fractal Amount", Range(0, 1)) = 1
        _Emission ("Brightness", Range(0, 4)) = 1
        _Alpha ("Alpha", Range(0, 1)) = 1

        [PsyGroup(Mapping)]
        [Enum(UV,0,Triplanar Object,1,Triplanar World,2)] _Mapping ("Mapping", Float) = 0
        _Tiling ("UV Tiling", Float) = 1
        _Zoom ("Zoom", Range(0.001, 2)) = 0.02
        _TriSharp ("Triplanar Sharpness", Range(1, 16)) = 4
        _PatternOffset ("Pattern Offset", Vector) = (0, 0, 0, 0)

        [PsyGroup(Fractal)]
        _Seed ("Seed", Float) = 0
        _Jitter ("Jitter (breaks repetition)", Range(0, 1)) = 0
        _Iterations ("Iterations", Range(1, 48)) = 32
        _Fold ("Fold", Vector) = (-0.5, -0.5, 0, 0)
        _Translate ("Translate", Vector) = (1.5, 1.5, 0, 0)
        _FScale ("Scale", Range(0.8, 2)) = 1.25
        _FlowSpeed ("Morph Speed", Range(0, 100)) = 8
        _RotBase ("Rotation Base", Range(0, 1)) = 0.10
        _RotAmp ("Rotation Amount", Range(0, 1)) = 0.50001
        _RotOff ("Rotation Offset", Range(0, 2)) = 0.501
        _RotPhase ("Rotation Phase / Iter", Range(0, 1)) = 0.251

        [PsyGroup(Waves)]
        _WaveAmp ("Wave Size", Range(0, 1)) = 0.06
        _WaveFreq ("Wave Frequency", Range(0.5, 30)) = 5
        _WaveSpeed ("Wave Speed", Range(-5, 5)) = 0.6
        _WaveDir ("Wave Direction (xy)", Vector) = (1, 0.4, 0, 0)

        [PsyGroup(Relief 3D)]
        _ReliefHeight ("Relief Height (m)", Range(0, 0.3)) = 0.03
        _BumpSoftness ("Hill Smoothness", Range(0.002, 0.1)) = 0.015
        _HeightRadius ("Hills From Fractal Radius", Range(0, 2)) = 1
        _HeightBands ("Ridges From Rainbow Bands", Range(0, 2)) = 0.5
        _Parallax ("Parallax Strength", Range(0, 3)) = 0.4
        _ParallaxPivot ("Parallax Pivot", Range(0, 1)) = 0.5
        _Displace ("Mesh Displacement (m)", Range(-0.1, 0.1)) = 0

        [PsyGroup(Lighting)]
        _Shading ("Hill Shading", Range(0, 1)) = 0.8
        [Toggle] _UseSceneLight ("Use Scene Directional Light", Float) = 0
        _LightDir ("Fixed Light Direction", Vector) = (0.4, 0.8, 0.3, 0)
        _SpecAmount ("Shine", Range(0, 2)) = 0.4
        _SpecPower ("Shine Tightness", Range(2, 200)) = 40

        [PsyGroup(Rainbow)]
        [Enum(Fractal Y,0,World Direction,1,Camera Distance,2,Fractal Radius,3)] _BandMode ("Band Source", Float) = 0
        _BandFreq ("Band Frequency (Fractal Y)", Float) = 500
        _BandWorldFreq ("Band Frequency (World / Depth)", Float) = 3
        _BandDir ("World Band Direction", Vector) = (0, 1, 0, 0)
        _AngleBands ("Angle Bands", Range(0, 4)) = 1
        _BandSpeed ("Band Scroll Speed", Range(-10, 10)) = 1
        _HueOffset ("Hue Offset", Range(0, 1)) = 0
        _HueDrift ("Hue Drift Speed", Range(-1, 1)) = 0
        _Sat ("Saturation", Range(0, 1)) = 1
        _ValRange ("Brightness Range (lo, hi)", Vector) = (-1, 3, 0, 0)

        [PsyGroup(Oil Slick)]
        _OilMix ("Oil Slick Amount", Range(0, 1)) = 0
        _FilmScale ("Film Angle Scale", Range(0, 6)) = 1.5
        _FilmFractal ("Film Follows Fractal", Range(0, 3)) = 0.4
        _FilmOffset ("Film Offset", Range(0, 1)) = 0
        _FilmSpeed ("Film Scroll Speed", Range(-2, 2)) = 0.1
        _OilFractalMask ("Fractal Darkens Oil", Range(0, 1)) = 0.5

        [PsyGroup(Rendering)]
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 0
        [Enum(Off,0,On,1)] _ZWrite ("ZWrite", Float) = 1
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "Queue" = "Geometry" "VRCFallback" = "Unlit" }
        Blend [_SrcBlend] [_DstBlend]
        ZWrite [_ZWrite]
        Cull [_Cull]

        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.5
            #pragma multi_compile_instancing

            #define PSY_FRACTAL2D
            #include "PsyCommon.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _FractalMix, _Emission, _Alpha;
            float _Mapping, _Tiling, _Zoom, _TriSharp;
            float4 _PatternOffset;
            float _WaveAmp, _WaveFreq, _WaveSpeed;
            float4 _WaveDir;
            float _BumpSoftness;
            float _ReliefHeight, _HeightRadius, _HeightBands, _Parallax, _ParallaxPivot, _Displace;
            float _Shading, _UseSceneLight, _SpecAmount, _SpecPower;
            float4 _LightDir;
            float _BandMode, _BandFreq, _BandWorldFreq, _AngleBands, _BandSpeed;
            float4 _BandDir;
            float _HueOffset, _HueDrift, _Sat;
            float4 _ValRange;
            float _OilMix, _FilmScale, _FilmFractal, _FilmOffset, _FilmSpeed, _OilFractalMask;
            float4 _LightColor0;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 wpos : TEXCOORD1;
                float3 wnrm : TEXCOORD2;
                float3 opos : TEXCOORD3;
                float3 onrm : TEXCOORD4;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            struct PsyS
            {
                float3 col;   // flat rainbow colour
                float h;      // height 0..~1
                float len;    // fractal radius (used by oil film)
                float2 dh;    // height gradient per screen pixel (x, y)
                float fade;   // 1 = pattern is resolved on screen, 0 = sub-pixel (relief fades out)
            };

            // Evaluates the fractal at one pattern-space coordinate (already scaled by Zoom).
            PsyS evalCore(float2 coord, float3 wpos, float t)
            {
                // travelling waves warp the pattern so hills roll across the surface
                if (_WaveAmp > 0.0001)
                {
                    float2 c = coord / _Zoom;
                    float ph = t * _WaveSpeed;
                    float2 d = normalize(_WaveDir.xy + float2(1e-5, 0));
                    float2 d2 = float2(-d.y, d.x);
                    c += _WaveAmp * float2(sin(dot(c, d) * _WaveFreq + ph), sin(dot(c, d2) * _WaveFreq * 1.37 - ph * 0.8));
                    coord = c * _Zoom;
                }

                float x;
                float2 pf = psyFractal2D(coord, t, x);
                float len = length(pf);

                float src = x * _BandFreq;
                if (_BandMode > 0.5 && _BandMode < 1.5)      src = dot(wpos, _BandDir.xyz) * _BandWorldFreq;
                else if (_BandMode > 1.5 && _BandMode < 2.5) src = length(wpos - _WorldSpaceCameraPos) * _BandWorldFreq;
                else if (_BandMode > 2.5)                    src = len * _BandWorldFreq;

                float i = src + atan2(pf.y, pf.x) * _AngleBands + t * 0.003 * _BandSpeed * 100.0;
                float hue = psyBandHue(i) + _HueOffset + t * _HueDrift;
                float v = smoothstep(_ValRange.x, _ValRange.y, len);

                PsyS r;
                r.col = psyHSV(hue, _Sat, v);
                r.len = len;
                float bandH = smoothstep(0.0, 0.4, frac(i * 6.0) * 1.02);
                r.h = _HeightRadius * v + _HeightBands * bandH;
                r.dh = 0;
                r.fade = 1;
                return r;
            }

            // evalCore plus a stable height gradient (finite difference in pattern space, then chained to screen pixels).
            // dcdx / dcdy: screen derivatives of the pattern coordinate.
            PsyS evalGrad(float2 c, float3 wpos, float t, float2 dcdx, float2 dcdy)
            {
                PsyS s = evalCore(c, wpos, t);
                float2 ux = dcdx / _Zoom, uy = dcdy / _Zoom;       // pattern units per pixel
                float pix = max(length(ux), length(uy));
                s.fade = saturate((0.08 - pix) / 0.05);
                if (_ReliefHeight > 0.00001 && s.fade > 0.001)
                {
                    float e = _BumpSoftness * _Zoom;
                    float hx = evalCore(c + float2(e, 0), wpos, t).h;
                    float hy = evalCore(c + float2(0, e), wpos, t).h;
                    float2 g = float2(hx - s.h, hy - s.h) / _BumpSoftness;
                    s.dh = float2(dot(g, ux), dot(g, uy));
                }
                return s;
            }

            // height only (vertex displacement)
            float heightAt(float2 uv, float3 opos, float3 onrm, float3 wpos, float t)
            {
                if (_Mapping < 0.5)
                    return evalCore((uv * _Tiling * 2.0 - 1.0 + _PatternOffset.xy) * _Zoom, wpos, t).h;
                float3 pos = opos + _PatternOffset.xyz;
                float3 w = pow(abs(onrm), _TriSharp);
                w /= (w.x + w.y + w.z + 1e-5);
                float h = 0;
                [branch] if (w.x > 0.02) h += w.x * evalCore(pos.zy * _Zoom, wpos, t).h;
                [branch] if (w.y > 0.02) h += w.y * evalCore(pos.xz * _Zoom, wpos, t).h;
                [branch] if (w.z > 0.02) h += w.z * evalCore(pos.xy * _Zoom, wpos, t).h;
                return h;
            }

            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                float3 wp0 = mul(unity_ObjectToWorld, v.vertex).xyz;
                float4 vert = v.vertex;
                if (abs(_Displace) > 0.00001)
                {
                    float h = heightAt(v.uv, v.vertex.xyz, v.normal, wp0, _Time.y);
                    vert.xyz += v.normal * (h - _ParallaxPivot) * _Displace;
                }
                o.pos = UnityObjectToClipPos(vert);
                o.uv = v.uv;
                o.wpos = mul(unity_ObjectToWorld, vert).xyz;
                o.wnrm = UnityObjectToWorldNormal(v.normal);
                o.opos = v.vertex.xyz;
                o.onrm = v.normal;
                return o;
            }

            // one triplanar plane (axis 0 = x-plane, 1 = y-plane, 2 = z-plane) with optional parallax
            PsyS evalPlane(int axis, float3 pos, float3 viewP, float3 wpos, float t)
            {
                float2 c; float3 vts;
                if (axis == 0)      { c = pos.zy; vts = viewP.zyx; }
                else if (axis == 1) { c = pos.xz; vts = viewP.xzy; }
                else                { c = pos.xy; vts = viewP.xyz; }
                c *= _Zoom;
                float2 dcx = ddx(c), dcy = ddy(c);
                PsyS s = evalGrad(c, wpos, t, dcx, dcy);
                if (_Parallax > 0.0001)
                {
                    // shift in metres (pattern units are metres in triplanar mode), tied to the relief height
                    float2 c2 = c + vts.xy / max(abs(vts.z), 0.25) * (s.h - _ParallaxPivot) * _ReliefHeight * _Parallax * s.fade * _Zoom;
                    s = evalGrad(c2, wpos, t, dcx, dcy);
                }
                return s;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float t = _Time.y;
                float3 N = normalize(i.wnrm);
                float3 V = normalize(_WorldSpaceCameraPos - i.wpos);
                PsyS s;

                if (_Mapping < 0.5)
                {
                    float2 c = (i.uv * _Tiling * 2.0 - 1.0 + _PatternOffset.xy) * _Zoom;
                    float2 dcx = ddx(c), dcy = ddy(c);
                    s = evalGrad(c, i.wpos, t, dcx, dcy);
                    if (_Parallax > 0.0001)
                    {
                        // tangent frame from screen derivatives
                        float3 dp1 = ddx(i.wpos), dp2 = ddy(i.wpos);
                        float2 du1 = ddx(i.uv), du2 = ddy(i.uv);
                        float3 dp2p = cross(dp2, N), dp1p = cross(N, dp1);
                        float3 T = normalize(dp2p * du1.x + dp1p * du2.x + 1e-8);
                        float3 B = normalize(dp2p * du1.y + dp1p * du2.y + 1e-8);
                        float3 vts = float3(dot(V, T), dot(V, B), dot(V, N));
                        // metres -> pattern units via the ratio of screen derivatives
                        float upm = max(length(dcx), length(dcy)) / _Zoom / max(max(length(dp1), length(dp2)), 1e-8);
                        float2 c2 = c + vts.xy / max(abs(vts.z), 0.25) * (s.h - _ParallaxPivot) * _ReliefHeight * _Parallax * s.fade * upm * _Zoom;
                        s = evalGrad(c2, i.wpos, t, dcx, dcy);
                    }
                }
                else
                {
                    bool world = _Mapping > 1.5;
                    float3 pos = (world ? i.wpos : i.opos) + _PatternOffset.xyz;
                    float3 n = world ? N : normalize(i.onrm);
                    float3 viewP = world ? V : normalize(mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1)).xyz - i.opos);
                    float3 w = pow(abs(n), _TriSharp);
                    w /= (w.x + w.y + w.z + 1e-5);
                    s.col = 0; s.h = 0; s.len = 0; s.dh = 0; s.fade = 0;
                    [branch] if (w.x > 0.02) { PsyS a = evalPlane(0, pos, viewP, i.wpos, t); s.col += w.x * a.col; s.h += w.x * a.h; s.len += w.x * a.len; s.dh += w.x * a.dh; s.fade += w.x * a.fade; }
                    [branch] if (w.y > 0.02) { PsyS a = evalPlane(1, pos, viewP, i.wpos, t); s.col += w.y * a.col; s.h += w.y * a.h; s.len += w.y * a.len; s.dh += w.y * a.dh; s.fade += w.y * a.fade; }
                    [branch] if (w.z > 0.02) { PsyS a = evalPlane(2, pos, viewP, i.wpos, t); s.col += w.z * a.col; s.h += w.z * a.h; s.len += w.z * a.len; s.dh += w.z * a.dh; s.fade += w.z * a.fade; }
                }

                // ---- relief: bump normal from the height field (unparametrised surface bump mapping)
                float3 n = N;
                if (_ReliefHeight > 0.00001)
                {
                    float3 dpdx = ddx(i.wpos), dpdy = ddy(i.wpos);
                    float dhdx = s.dh.x * _ReliefHeight * s.fade, dhdy = s.dh.y * _ReliefHeight * s.fade;
                    float3 r1 = cross(dpdy, N), r2 = cross(N, dpdx);
                    float det = dot(dpdx, r1);
                    float3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
                    // soft-limit so hard band edges do not blow the normal sideways
                    float3 tilt = grad / max(abs(det), 1e-12);
                    tilt *= rsqrt(1.0 + dot(tilt, tilt) * 0.15);
                    n = normalize(N - tilt);
                }

                float3 col = s.col;

                // oil slick follows the bumped surface, so the film flows over the hills
                if (_OilMix > 0.001)
                {
                    float ndv = saturate(dot(n, V));
                    float film = (1.0 - ndv) * _FilmScale + s.len * _FilmFractal + _FilmOffset + t * _FilmSpeed;
                    float3 oil = psyPalette(film, float3(0.0, 0.33, 0.67));
                    float vv = smoothstep(_ValRange.x, _ValRange.y, s.len);
                    oil *= lerp(1.0, vv, _OilFractalMask);
                    col = lerp(col, oil, _OilMix);
                }

                // hill shading
                float3 L = normalize(_LightDir.xyz + 1e-5);
                if (_UseSceneLight > 0.5 && dot(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz) > 1e-4)
                    L = normalize(_WorldSpaceLightPos0.xyz);
                float diff = saturate(dot(n, L) * 0.5 + 0.5);
                col *= lerp(1.0, 0.25 + 1.5 * diff * diff, _Shading);
                float spec = pow(saturate(dot(n, normalize(L + V))), _SpecPower) * _SpecAmount;
                col += spec * (0.4 + 0.6 * s.col) * _Shading;

                float4 tex = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw);
                col = lerp(tex.rgb, col, _FractalMix) * _Emission;
                return fixed4(col, _Alpha * tex.a);
            }
            ENDCG
        }
    }
    CustomEditor "RavensPsyShaderGUI"
}
