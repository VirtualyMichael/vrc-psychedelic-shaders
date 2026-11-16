// Psychedelic Fractal - WORLD version (raymarched 3D fractal inside any mesh).
// Put it on a cube / sphere / flattened box. The mesh acts as a window or bounding volume.
// Shapes: kaleidoscopic IFS blocks, or twisted fractal pillars. Rainbow can follow orbit trap, world position or depth.
Shader "Ravens/Psychedelic/Fractal World"
{
    Properties
    {
        [PsyGroup(Shape)]
        [Enum(Kaleidoscopic Blocks,0,Twisted Pillars,1)] _Shape ("Shape", Float) = 0
        [Enum(World,0,Object,1)] _Space ("Pattern Space", Float) = 0
        [Enum(None,0,Object Cube,1,Object Sphere,2)] _Clip ("Clip To Mesh Volume", Float) = 1
        _Seed ("Seed", Float) = 0
        _Jitter ("Jitter (breaks repetition)", Range(0, 1)) = 0
        _Zoom ("Zoom (pattern size)", Range(0.05, 4)) = 1
        _Iter3D ("Fold Iterations", Range(1, 12)) = 6
        _Scale3D ("Fold Scale", Range(1.1, 3.5)) = 2
        _Offset3D ("Fold Offset", Vector) = (1, 1, 1, 0)
        _Thickness ("Thickness", Range(0.01, 2)) = 0.9
        _Round ("Roundness (box to sphere)", Range(0, 1)) = 0
        _Twist ("Twist Per Fold", Range(-1.5, 1.5)) = 0.25
        _PillarTwist ("Pillar Twist Along Height", Range(-3, 3)) = 0.5
        _Repeat ("Repeat Spacing (0 = none)", Range(0, 20)) = 0
        _Morph ("Morph Speed", Range(0, 2)) = 0.15
        _Spin ("Spin Speed", Range(-2, 2)) = 0.1

        [PsyGroup(Raymarch)]
        _Steps ("Max Steps", Range(16, 160)) = 80
        _StepScale ("Step Scale (lower = safer)", Range(0.3, 1)) = 0.8
        _Eps ("Hit Precision", Range(0.0002, 0.02)) = 0.002
        _MaxDist ("Max Distance", Range(1, 200)) = 30

        [PsyGroup(Rainbow)]
        [Enum(Orbit Trap,0,World Direction,1,Camera Distance,2,Surface Normal,3)] _BandMode ("Band Source", Float) = 0
        _BandFreq ("Band Frequency", Range(0.1, 40)) = 5
        _BandDir ("World Band Direction", Vector) = (0, 1, 0, 0)
        _BandSpeed ("Band Scroll Speed", Range(-5, 5)) = 0.3
        _HueOffset ("Hue Offset", Range(0, 1)) = 0
        _Sat ("Saturation", Range(0, 1)) = 1
        _Emission ("Brightness", Range(0, 4)) = 1.2

        [PsyGroup(Oil Slick)]
        _OilMix ("Oil Slick Amount", Range(0, 1)) = 0
        _FilmScale ("Film Angle Scale", Range(0, 6)) = 2
        _FilmSpeed ("Film Scroll Speed", Range(-2, 2)) = 0.1

        [PsyGroup(Light And Glow)]
        _Ambient ("Ambient", Range(0, 1)) = 0.25
        _Rim ("Rim Light", Range(0, 4)) = 1
        _AOStrength ("Fake AO", Range(0, 1)) = 0.6
        _Glow ("Glow", Range(0, 4)) = 0.6
        _GlowFalloff ("Glow Tightness", Range(1, 40)) = 8
        _FogDist ("Distance Fade", Range(0, 100)) = 25

        [PsyGroup(Rendering)]
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 10
        [Enum(Off,0,On,1)] _ZWrite ("ZWrite", Float) = 0
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2
    }
    SubShader
    {
        Tags { "RenderType" = "Transparent" "Queue" = "Transparent" "VRCFallback" = "Hidden" "DisableBatching" = "True" }
        Blend [_SrcBlend] [_DstBlend]
        ZWrite [_ZWrite]
        Cull [_Cull]

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.5

            #define PSY_FRACTAL3D
            #include "PsyCommon.cginc"

            float _Shape, _Space, _Clip, _Seed, _Jitter, _Zoom, _Iter3D, _Scale3D, _Thickness, _Round;
            float _Twist, _PillarTwist, _Repeat, _Morph, _Spin;
            float4 _Offset3D;
            float _Steps, _StepScale, _Eps, _MaxDist;
            float _BandMode, _BandFreq, _BandSpeed, _HueOffset, _Sat, _Emission;
            float4 _BandDir;
            float _OilMix, _FilmScale, _FilmSpeed;
            float _Ambient, _Rim, _AOStrength, _Glow, _GlowFalloff, _FogDist;

            struct appdata
            {
                float4 vertex : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 wpos : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.wpos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            static float3 g_trap; // orbit trap of the last DE call

            // Distance estimate. p is in pattern space.
            float psyDE(float3 p, float t)
            {
                p *= _Zoom;
                float3 off = _Offset3D.xyz;
                float spin = t * _Spin;
                float morph = t * _Morph;
                p.xz = psyRot(p.xz, spin);
                if (_Repeat > 0.001) p = p - _Repeat * round(p / _Repeat);

                int n = (int)_Iter3D;
                float sc = 1.0;
                g_trap = float3(1e3, 1e3, 1e3);

                if (_Shape < 0.5)
                {
                    [loop]
                    for (int i = 0; i < 12; i++)
                    {
                        if (i >= n) break;
                        float fi = (float)i;
                        float3 j = (psyHash31v(fi + _Seed * 7.13) - 0.5) * _Jitter;
                        p = abs(p);
                        if (p.x < p.y) p.xy = p.yx;
                        if (p.x < p.z) p.xz = p.zx;
                        if (p.y < p.z) p.yz = p.zy;
                        float3 o3 = off + j * 0.5;
                        p = p * _Scale3D - o3 * (_Scale3D - 1.0);
                        if (p.z < -0.5 * o3.z * (_Scale3D - 1.0)) p.z += o3.z * (_Scale3D - 1.0);
                        p.xy = psyRot(p.xy, _Twist + sin(morph + fi * 1.3) * 0.2 + j.x);
                        p.yz = psyRot(p.yz, _Twist * 0.5 + cos(morph * 0.7 + fi) * 0.15 + j.y);
                        sc *= _Scale3D;
                        g_trap = min(g_trap, abs(p));
                    }
                }
                else
                {
                    // twisted pillars: 2D kaleidoscopic fold on xz, extruded along y with twist
                    float2 q = psyRot(p.xz, p.y * _PillarTwist);
                    [loop]
                    for (int i = 0; i < 12; i++)
                    {
                        if (i >= n) break;
                        float fi = (float)i;
                        float2 j = (psyHash21(fi + _Seed * 7.13) - 0.5) * _Jitter;
                        q = abs(q);
                        if (q.x < q.y) q = q.yx;
                        q = q * _Scale3D - (off.xz + j * 0.5) * (_Scale3D - 1.0);
                        q = psyRot(q, _Twist + sin(morph + fi * 1.3) * 0.2 + j.x);
                        sc *= _Scale3D;
                        g_trap = min(g_trap, float3(abs(q), abs(p.y)));
                    }
                    p = float3(q.x, p.y * sc, q.y); // keep y proportional so the column stays solid
                }

                float3 a = abs(p);
                float box = max(a.x, max(a.y, a.z)) - _Thickness;
                float sph = length(p) - _Thickness;
                return lerp(box, sph, _Round) / sc / _Zoom;
            }

            float3 psyNormal(float3 p, float t, float e)
            {
                float2 k = float2(1, -1);
                return normalize(k.xyy * psyDE(p + k.xyy * e, t) + k.yyx * psyDE(p + k.yyx * e, t) +
                                 k.yxy * psyDE(p + k.yxy * e, t) + k.xxx * psyDE(p + k.xxx * e, t));
            }

            fixed4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                float t = _Time.y;
                float3 ro = i.wpos;
                float3 rd = normalize(i.wpos - _WorldSpaceCameraPos);
                float objScale = length(unity_ObjectToWorld._m00_m10_m20);

                float dist = 0;
                float glow = 0;
                bool hit = false;
                float3 pos = ro;
                float3 trapHit = 0;
                int steps = (int)_Steps;
                int used = 0;

                [loop]
                for (int s = 0; s < 160; s++)
                {
                    if (s >= steps) break;
                    pos = ro + rd * dist;
                    float3 pp = pos;
                    if (_Space > 0.5) pp = mul(unity_WorldToObject, float4(pos, 1)).xyz;

                    if (_Clip > 0.5)
                    {
                        float3 op = mul(unity_WorldToObject, float4(pos, 1)).xyz;
                        if (_Clip < 1.5) { if (max(abs(op.x), max(abs(op.y), abs(op.z))) > 0.5005) break; }
                        else { if (length(op) > 0.5005) break; }
                    }

                    float d = psyDE(pp, t);
                    if (_Space > 0.5) d *= objScale;
                    glow += exp(-max(d, 0.0) * _GlowFalloff) * (0.02 + d * 0.0) ;
                    used = s;
                    if (d < _Eps) { hit = true; trapHit = g_trap; break; }
                    dist += d * _StepScale;
                    if (dist > _MaxDist) break;
                }

                float3 col = 0;
                float alpha = 0;
                if (hit)
                {
                    float3 pp = pos;
                    if (_Space > 0.5) pp = mul(unity_WorldToObject, float4(pos, 1)).xyz;
                    float3 n = psyNormal(pp, t, _Eps * 2.0);
                    if (_Space > 0.5) n = normalize(mul((float3x3)unity_ObjectToWorld, n));

                    float src = 0;
                    if (_BandMode < 0.5)        src = (trapHit.x + trapHit.y * 0.7 + trapHit.z * 0.4) * _BandFreq;
                    else if (_BandMode < 1.5)   src = dot(pos, _BandDir.xyz) * _BandFreq;
                    else if (_BandMode < 2.5)   src = dist * _BandFreq * 0.2;
                    else                        src = (n.x * 0.5 + n.y * 0.8 + n.z * 0.3) * _BandFreq;
                    float h = psyBandHue(src * 0.2 + t * _BandSpeed * 0.1) + _HueOffset;
                    float3 base = psyHSV(h, _Sat, 1.0);

                    float ndv = saturate(dot(n, -rd));
                    if (_OilMix > 0.001)
                    {
                        float3 oil = psyPalette((1.0 - ndv) * _FilmScale + src * 0.05 + t * _FilmSpeed, float3(0.0, 0.33, 0.67));
                        base = lerp(base, oil, _OilMix);
                    }

                    float ao = 1.0 - _AOStrength * saturate((float)used / max(steps * 0.6, 1.0));
                    float rim = pow(1.0 - ndv, 3.0) * _Rim;
                    float3 L = normalize(float3(0.4, 0.8, 0.3));
                    float diff = saturate(dot(n, L)) * 0.6 + _Ambient;
                    col = base * diff * ao + base * rim;
                    alpha = 1.0;
                }

                float3 gcol = psyHSV(psyBandHue(dist * 0.1 + t * _BandSpeed * 0.1) + _HueOffset, _Sat, 1.0);
                col += gcol * glow * _Glow;
                alpha = saturate(alpha + glow * _Glow);

                float fade = (_FogDist > 0.01) ? saturate(1.0 - dist / _FogDist) : 1.0;
                return fixed4(col * _Emission * fade, alpha * fade);
            }
            ENDCG
        }
    }
    CustomEditor "RavensPsyShaderGUI"
}
