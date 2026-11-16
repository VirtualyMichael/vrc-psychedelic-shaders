// Trip Distortion - surface-anchored screen warp for VRChat avatars (PC).
//
// Put this on a Unity Quad parented to the head, with "Fullscreen" ON. Set the mesh bounds large
// (SkinnedMeshRenderer: Update When Offscreen, or a big Bounds) so it never gets frustum culled.
// The warp is computed in WORLD space from the depth buffer, so it sticks to surfaces (a carpet's fibres
// crawl in place) instead of sliding across the screen like a flat overlay.
//
// Needs a depth texture: in worlds without one, a realtime directional light with shadows enables it.
// Without depth the shader falls back to screen-space-only effects (crawl, echo, chroma, colour).
Shader "Ravens/Psychedelic/Trip Distortion"
{
    Properties
    {
        [PsyGroup(Master)]
        _Intensity ("Master Intensity", Range(0, 1)) = 1
        _Speed ("Time Speed", Range(0, 3)) = 1
        [Toggle] _Fullscreen ("Fullscreen Quad Mode", Float) = 1
        [Toggle] _HideInMirror ("Hide In Mirrors", Float) = 1
        [Toggle] _HideInCameras ("Hide In Handheld Cameras", Float) = 0
        _MaxDistance ("Effect Range (m, 0 = unlimited)", Range(0, 200)) = 40
        _SkyAffect ("Affect Sky", Range(0, 1)) = 0.3
        _Periphery ("Stronger In Periphery", Range(0, 3)) = 0.8

        [PsyGroup(Breathing And Warp)]
        _WarpAmount ("Warp Size (m)", Range(0, 0.4)) = 0.05
        _WarpScale ("Warp Scale (1/m)", Range(0.05, 6)) = 0.7
        _WarpTangent ("Slide Along Surface", Range(0, 1)) = 0.8
        _Breathe ("Breathing Push (m)", Range(0, 0.3)) = 0.03
        _BreatheSpeed ("Breathing Speed", Range(0, 4)) = 0.8

        [PsyGroup(Surface Drift)]
        _Drift ("Fine Drift Size (m)", Range(0, 0.1)) = 0.012
        _DriftScale ("Fine Drift Scale (1/m)", Range(1, 40)) = 9

        [PsyGroup(Texture Crawl)]
        _Crawl ("Crawl Strength", Range(0, 1)) = 0.5
        _CrawlRadius ("Crawl Detail Size (px)", Range(0.5, 6)) = 1.5
        _CrawlScale ("Crawl Patch Size (1/m)", Range(0.5, 20)) = 5
        _Enhance ("Texture Enhancement", Range(0, 3)) = 0.6

        [PsyGroup(Echo And Tracers)]
        _EchoCount ("Echo Count", Range(0, 3)) = 2
        _EchoAmount ("Echo Strength", Range(0, 1)) = 0.35
        _EchoDelay ("Echo Delay (s)", Range(0.05, 3)) = 0.6

        [PsyGroup(Holographic Surface)]
        _HoloAmount ("Holo Layer Strength", Range(0, 1)) = 0.0
        _HoloHeight ("Holo Layer Height (m)", Range(0, 0.15)) = 0.03
        _HoloWobble ("Holo Layer Wobble", Range(0, 1)) = 0.5
        _HoloFloorOnly ("Floor Surfaces Only", Range(0, 1)) = 0.7
        _HoloTint ("Holo Layer Hue Shift", Range(-0.5, 0.5)) = 0.08

        [PsyGroup(Colour)]
        _Chroma ("Colour Split", Range(0, 0.02)) = 0.002
        _HueShift ("Hue Shift", Range(0, 1)) = 0
        _HuePulse ("Hue Pulse Amount", Range(0, 0.5)) = 0.03
        _HuePulseSpeed ("Hue Pulse Speed", Range(0, 3)) = 0.4
        _Saturation ("Saturation", Range(0, 2.5)) = 1.2

        [PsyGroup(Symmetry)]
        _KaleidoAmount ("Kaleidoscope Amount", Range(0, 1)) = 0
        _KaleidoSegments ("Kaleidoscope Segments", Range(2, 16)) = 6
        _KaleidoSpin ("Kaleidoscope Spin", Range(-1, 1)) = 0.05

        [PsyGroup(Visual Snow)]
        _Snow ("Visual Snow", Range(0, 0.3)) = 0.0

        [PsyGroup(Safety)]
        _OcclusionGuard ("Silhouette Guard", Range(0, 1)) = 0.8
        _OcclusionTol ("Guard Tolerance (m)", Range(0.02, 1)) = 0.15
    }
    SubShader
    {
        Tags { "Queue" = "Overlay+100" "RenderType" = "Overlay" "IgnoreProjector" = "True" "DisableBatching" = "True" "VRCFallback" = "Hidden" }
        Cull Off
        ZWrite Off
        ZTest Always

        GrabPass { "_PsyGrab" }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.5
            #pragma multi_compile_instancing

            #include "PsyCommon.cginc"

            UNITY_DECLARE_SCREENSPACE_TEXTURE(_PsyGrab);
            UNITY_DECLARE_SCREENSPACE_TEXTURE(_CameraDepthTexture);

            float _Intensity, _Speed, _Fullscreen, _HideInMirror, _HideInCameras, _MaxDistance, _SkyAffect, _Periphery;
            float _WarpAmount, _WarpScale, _WarpTangent, _Breathe, _BreatheSpeed;
            float _Drift, _DriftScale;
            float _Crawl, _CrawlRadius, _CrawlScale, _Enhance;
            float _EchoCount, _EchoAmount, _EchoDelay;
            float _HoloAmount, _HoloHeight, _HoloWobble, _HoloFloorOnly, _HoloTint;
            float _Chroma, _HueShift, _HuePulse, _HuePulseSpeed, _Saturation;
            float _KaleidoAmount, _KaleidoSegments, _KaleidoSpin;
            float _Snow, _OcclusionGuard, _OcclusionTol;

            struct appdata
            {
                float4 vertex : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 screenPos : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                if (_Fullscreen > 0.5)
                    o.pos = float4(v.vertex.x * 2.0, v.vertex.y * 2.0 * _ProjectionParams.x, UNITY_NEAR_CLIP_VALUE, 1.0);
                else
                    o.pos = UnityObjectToClipPos(v.vertex);
                o.screenPos = ComputeScreenPos(o.pos);
                return o;
            }

            // ---- screen / world helpers --------------------------------------------------
            // "depth uv" is the orientation ComputeScreenPos gives (matches _CameraDepthTexture).
            // "grab uv" is flipped on platforms where UV starts at the top (DX11).
            float2 depthToGrab(float2 uv)
            {
                #if UNITY_UV_STARTS_AT_TOP
                    return float2(uv.x, 0.5 - (uv.y - 0.5) * _ProjectionParams.x);
                #else
                    return uv;
                #endif
            }

            float sampleEyeDepth(float2 uv)
            {
                float raw = UNITY_SAMPLE_SCREENSPACE_TEXTURE(_CameraDepthTexture, UnityStereoTransformScreenSpaceTex(saturate(uv))).r;
                return LinearEyeDepth(raw);
            }

            float3 sampleGrab(float2 depthUV)
            {
                float2 g = depthToGrab(saturate(depthUV));
                return UNITY_SAMPLE_SCREENSPACE_TEXTURE(_PsyGrab, UnityStereoTransformScreenSpaceTex(g)).rgb;
            }

            // reconstruct world position from depth-uv + eye depth. Handles asymmetric VR projections.
            float3 worldFromDepth(float2 uv, float eyeD)
            {
                float2 ndc = float2(uv.x * 2.0 - 1.0, (uv.y * 2.0 - 1.0) * _ProjectionParams.x);
                float4x4 P = UNITY_MATRIX_P;
                float3 vp = float3(eyeD * (ndc.x + P._m02) / P._m00, eyeD * (ndc.y + P._m12) / P._m11, -eyeD);
                return _WorldSpaceCameraPos + mul(transpose((float3x3)UNITY_MATRIX_V), vp);
            }

            float3 worldAt(float2 uv) { return worldFromDepth(uv, sampleEyeDepth(uv)); }

            // world position -> depth uv and expected eye depth
            float2 projectToDepthUV(float3 wp, out float eyeExp)
            {
                float4 vp = mul(UNITY_MATRIX_V, float4(wp, 1.0));
                eyeExp = -vp.z;
                float4 clip = mul(UNITY_MATRIX_P, vp);
                float2 ndc = clip.xy / max(clip.w, 1e-4);
                return float2(ndc.x * 0.5 + 0.5, ndc.y * _ProjectionParams.x * 0.5 + 0.5);
            }

            // ---- the warp ----------------------------------------------------------------
            float3 displace(float3 wp, float3 n, float t, float amp)
            {
                float3 f1 = psyFlow(wp * _WarpScale, t);
                float3 tang = f1 - n * dot(f1, n);
                float3 d = lerp(f1, tang, _WarpTangent) * _WarpAmount;
                float breathe = sin(t * _BreatheSpeed + dot(wp, float3(1.7, 2.3, 1.1)) * _WarpScale * 0.7) * 0.5 + f1.x * 0.5;
                d += n * breathe * _Breathe;
                float3 f2 = psyFlow(wp * _DriftScale + 7.0, t * 1.7);
                f2 -= n * dot(f2, n);
                d += f2 * _Drift;
                return d * amp;
            }

            // samples the grab at a world-displaced point, falling back to the original uv near silhouettes
            float3 sampleWarped(float3 wp2, float2 uv0, float sky, out float2 uvOut)
            {
                float eyeExp;
                float2 uv = projectToDepthUV(wp2, eyeExp);
                float dz = sampleEyeDepth(uv);
                float ok = saturate(1.0 - (abs(dz - eyeExp) - _OcclusionTol) / _OcclusionTol);
                ok = max(ok, sky);
                uv = lerp(uv0, uv, lerp(1.0, ok, _OcclusionGuard));
                float2 e = min(uv, 1.0 - uv);
                float edge = smoothstep(0.0, 0.04, min(e.x, e.y));
                uv = lerp(uv0, uv, edge);
                uvOut = uv;
                return sampleGrab(uv);
            }

            float3 hueSat(float3 c, float hueShift, float sat)
            {
                float3 hsv = psyRGBtoHSV(c);
                hsv.x = frac(hsv.x + hueShift);
                hsv.y = saturate(hsv.y * sat);
                return psyHSV(hsv.x, hsv.y, hsv.z);
            }

            fixed4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                if (_HideInMirror > 0.5 && _VRChatMirrorMode > 0.5) clip(-1);
                if (_HideInCameras > 0.5 && _VRChatCameraMode > 0.5) clip(-1);

                float t = _Time.y * _Speed;
                float2 uv0 = i.screenPos.xy / i.screenPos.w;
                float3 base = sampleGrab(uv0);

                float eyeRaw = sampleEyeDepth(uv0);
                float sky = step(_ProjectionParams.z * 0.98, eyeRaw);
                float range = (_MaxDistance > 0.5) ? _MaxDistance : 1000.0;
                float eyeD = min(eyeRaw, range);
                float fade = 1.0 - smoothstep(range * 0.6, range, eyeRaw);
                fade = lerp(fade, _SkyAffect, sky);
                float2 ndc0 = uv0 * 2.0 - 1.0;
                float amp = (1.0 + _Periphery * dot(ndc0, ndc0) * 0.5) * fade;

                float3 wp = worldFromDepth(uv0, eyeD);

                // surface normal from depth (picks the smaller difference on each axis to survive silhouettes)
                float2 px = _ScreenParams.zw - 1.0;
                float3 wR = worldAt(uv0 + float2(px.x, 0));
                float3 wL = worldAt(uv0 - float2(px.x, 0));
                float3 wU = worldAt(uv0 + float2(0, px.y));
                float3 wD = worldAt(uv0 - float2(0, px.y));
                float3 dx = (abs(wR.z - wp.z) + abs(wR.x - wp.x) < abs(wL.z - wp.z) + abs(wL.x - wp.x)) ? (wR - wp) : (wp - wL);
                float3 dy = (abs(wU.y - wp.y) + abs(wU.z - wp.z) < abs(wD.y - wp.y) + abs(wD.z - wp.z)) ? (wU - wp) : (wp - wD);
                float3 n = normalize(cross(dx, dy) + 1e-6);
                if (dot(n, _WorldSpaceCameraPos - wp) < 0) n = -n;
                if (sky > 0.5) n = normalize(_WorldSpaceCameraPos - wp);

                // main warped sample
                float2 uvW;
                float3 col = sampleWarped(wp + displace(wp, n, t, amp), uv0, sky, uvW);

                // texture crawl: slide detail along its own contours, in patches
                float3 cEnh = col;
                if (_Crawl > 0.001 || _Enhance > 0.001)
                {
                    float2 r = px * _CrawlRadius;
                    float3 tR = sampleGrab(uvW + float2(r.x, 0));
                    float3 tL = sampleGrab(uvW - float2(r.x, 0));
                    float3 tU = sampleGrab(uvW + float2(0, r.y));
                    float3 tD = sampleGrab(uvW - float2(0, r.y));
                    float3 third = float3(0.333, 0.333, 0.333);
                    float2 grad = float2(dot(tR - tL, third), dot(tU - tD, third));
                    float gm = length(grad);
                    float2 perp = float2(-grad.y, grad.x) / (gm + 1e-4);
                    float patch = psyNoise3(wp * _CrawlScale + float3(0.0, t * 0.35, 0.0)) * 2.0 - 1.0;
                    float2 crawl = perp * patch * _Crawl * smoothstep(0.0, 0.15, gm) * px * _CrawlRadius * 3.0 * amp;
                    float3 cc = sampleGrab(uvW + crawl);
                    float3 blur = (tR + tL + tU + tD) * 0.25;
                    col = cc + (cc - blur) * _Enhance * amp;
                    cEnh = col;
                }

                // echoes / tracers: the same surface where it was a moment ago
                int ne = (int)_EchoCount;
                [loop]
                for (int k = 1; k <= 3; k++)
                {
                    if (k > ne) break;
                    float2 uvE;
                    float3 e = sampleWarped(wp + displace(wp, n, t - k * _EchoDelay, amp * (1.0 + 0.4 * k)), uv0, sky, uvE);
                    col = lerp(col, e, _EchoAmount * pow(0.65, k - 1.0) * saturate(amp));
                }

                // holographic surface layer: a faint copy of the surface lifted off it
                if (_HoloAmount > 0.001)
                {
                    float wob = 1.0 + _HoloWobble * psyNoise3(wp * 3.0 + float3(0.0, t * 0.8, 0.0)) * 1.5;
                    float2 uvH;
                    float3 h = sampleWarped(wp + n * _HoloHeight * wob + displace(wp, n, t * 0.6, amp) * 0.5, uv0, sky, uvH);
                    h = hueSat(h, _HoloTint, 1.2);
                    float up = saturate(n.y);
                    float mask = lerp(1.0, smoothstep(0.5, 0.9, up), _HoloFloorOnly) * fade;
                    col = lerp(col, h, _HoloAmount * 0.6 * mask);
                }

                // colour split along the warp direction (radial)
                if (_Chroma > 0.00005)
                {
                    float2 dir = normalize(ndc0 + 1e-4) * _Chroma * (0.5 + amp);
                    col.r = lerp(col.r, sampleGrab(uvW + dir).r, saturate(amp));
                    col.b = lerp(col.b, sampleGrab(uvW - dir).b, saturate(amp));
                }

                // kaleidoscope symmetry
                if (_KaleidoAmount > 0.001)
                {
                    float2 q = uvW - 0.5;
                    float rr = length(q);
                    float a = atan2(q.y, q.x) + t * _KaleidoSpin;
                    float seg = PSY_TAU / floor(_KaleidoSegments);
                    a = abs(psyMod(a, seg) - seg * 0.5);
                    float2 uvK = 0.5 + rr * float2(cos(a), sin(a));
                    col = lerp(col, sampleGrab(uvK), _KaleidoAmount);
                }

                // colour
                float hs = _HueShift + sin(t * _HuePulseSpeed) * _HuePulse;
                col = hueSat(col, hs * _Intensity, lerp(1.0, _Saturation, _Intensity));

                // visual snow
                if (_Snow > 0.001)
                {
                    float nz = psyHash31(float3(i.pos.xy, floor(_Time.y * 45.0))) - 0.5;
                    col += nz * _Snow;
                }

                col = lerp(base, col, _Intensity);
                return fixed4(col, 1);
            }
            ENDCG
        }
    }
    CustomEditor "RavensPsyShaderGUI"
}
