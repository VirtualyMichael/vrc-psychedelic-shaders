// Psychedelic Fractal - SURFACE version (clothes, props, anything with a mesh).
// Based on "Persian Symettry 2" by NPWR (shadertoy.com/view/ldSXzc), reworked with seeded randomness,
// triplanar mapping, world/depth rainbow bands and an oil-slick film mode.
Shader "Ravens/Psychedelic/Fractal Surface Classic"
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
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #pragma multi_compile_instancing

            #define PSY_FRACTAL2D
            #include "PsyCommon.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _FractalMix, _Emission, _Alpha;
            float _Mapping, _Tiling, _Zoom, _TriSharp;
            float4 _PatternOffset;
            float _BandMode, _BandFreq, _BandWorldFreq, _AngleBands, _BandSpeed;
            float4 _BandDir;
            float _HueOffset, _HueDrift, _Sat;
            float4 _ValRange;
            float _OilMix, _FilmScale, _FilmFractal, _FilmOffset, _FilmSpeed, _OilFractalMask;

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

            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.wpos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.wnrm = UnityObjectToWorldNormal(v.normal);
                o.opos = v.vertex.xyz;
                o.onrm = v.normal;
                return o;
            }

            // Evaluates the fractal at one pattern-space coordinate and returns the colour.
            float3 shade(float2 coord, float3 wpos, float3 nrm, float3 viewDir, float t)
            {
                float x;
                float2 pf = psyFractal2D(coord, t, x);
                float len = length(pf);

                float src = x * _BandFreq;
                if (_BandMode > 0.5 && _BandMode < 1.5)      src = dot(wpos, _BandDir.xyz) * _BandWorldFreq;
                else if (_BandMode > 1.5 && _BandMode < 2.5) src = length(wpos - _WorldSpaceCameraPos) * _BandWorldFreq;
                else if (_BandMode > 2.5)                    src = len * _BandWorldFreq;

                float i = src + atan2(pf.y, pf.x) * _AngleBands + t * 0.003 * _BandSpeed * 100.0;
                float h = psyBandHue(i) + _HueOffset + t * _HueDrift;
                float v = smoothstep(_ValRange.x, _ValRange.y, len);
                float3 col = psyHSV(h, _Sat, v);

                if (_OilMix > 0.001)
                {
                    float ndv = saturate(dot(normalize(nrm), viewDir));
                    float film = (1.0 - ndv) * _FilmScale + len * _FilmFractal + _FilmOffset + t * _FilmSpeed;
                    float3 oil = psyPalette(film, float3(0.0, 0.33, 0.67));
                    oil *= lerp(1.0, v, _OilFractalMask);
                    col = lerp(col, oil, _OilMix);
                }
                return col;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float t = _Time.y;
                float3 nrm = normalize(i.wnrm);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.wpos);
                float3 fractalCol;

                if (_Mapping < 0.5)
                {
                    float2 p = (i.uv * _Tiling * 2.0 - 1.0 + _PatternOffset.xy) * _Zoom;
                    fractalCol = shade(p, i.wpos, nrm, viewDir, t);
                }
                else
                {
                    bool world = _Mapping > 1.5;
                    float3 pos = (world ? i.wpos : i.opos) + _PatternOffset.xyz;
                    float3 n = world ? nrm : normalize(i.onrm);
                    float3 w = pow(abs(n), _TriSharp);
                    w /= (w.x + w.y + w.z + 1e-5);
                    fractalCol = 0;
                    [branch] if (w.x > 0.02) fractalCol += w.x * shade(pos.zy * _Zoom, i.wpos, nrm, viewDir, t);
                    [branch] if (w.y > 0.02) fractalCol += w.y * shade(pos.xz * _Zoom, i.wpos, nrm, viewDir, t);
                    [branch] if (w.z > 0.02) fractalCol += w.z * shade(pos.xy * _Zoom, i.wpos, nrm, viewDir, t);
                }

                float4 tex = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw);
                float3 col = lerp(tex.rgb, fractalCol, _FractalMix) * _Emission;
                return fixed4(col, _Alpha * tex.a);
            }
            ENDCG
        }
    }
    CustomEditor "RavensPsyShaderGUI"
}
