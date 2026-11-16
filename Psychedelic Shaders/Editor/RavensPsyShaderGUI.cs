using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

// [PsyGroup(Name)] in a shader only marks where a foldout starts. It draws nothing itself.
public class PsyGroupDecorator : MaterialPropertyDrawer
{
    public PsyGroupDecorator(string name) { }
    public override float GetPropertyHeight(MaterialProperty prop, string label, MaterialEditor editor) { return 0f; }
    public override void OnGUI(Rect position, MaterialProperty prop, string label, MaterialEditor editor) { }
}

// Inspector for the Ravens/Psychedelic/* shaders: foldout groups, a tooltip on every control,
// a Randomize button for the fractals and Light/Medium/Heavy presets for the distortion shader.
public class RavensPsyShaderGUI : ShaderGUI
{

    static readonly Dictionary<string, bool> Open = new Dictionary<string, bool>();

    static readonly Dictionary<string, string> Tips = new Dictionary<string, string>
    {
        // ---- shared / fractal surface
        {"_MainTex", "Optional base texture. Blended with the fractal using Fractal Amount."},
        {"_FractalMix", "0 = only your texture, 1 = only the fractal."},
        {"_Emission", "Overall brightness multiplier."},
        {"_Alpha", "Opacity. Only matters with a transparent blend mode."},
        {"_Mapping", "How the pattern is placed on the mesh. UV uses the mesh UVs. Triplanar projects from three directions so it works on any mesh with no UVs and no stretching."},
        {"_Tiling", "UV mapping only: repeats the pattern across the UV space."},
        {"_Zoom", "Size of the pattern. The original look is 0.02. Smaller = bigger pattern."},
        {"_TriSharp", "Triplanar only: how sharply the three projections blend. Higher = harder seams."},
        {"_PatternOffset", "Slides the pattern around. Triplanar uses xyz, UV uses xy."},
        {"_Seed", "Randomness seed. Same seed = same look, so you can save good ones. Press Randomize to roll a new one."},
        {"_Jitter", "Adds a different small random change on every fold step. 0 = the original perfectly repeating shader. Higher = organic, non-repeating."},
        {"_Iterations", "Number of fold steps. More = more intricate detail but slower."},
        {"_Fold", "Where each fold mirrors the pattern (xy). Changes the overall symmetry."},
        {"_Translate", "Shift applied after each fold (xy). Big effect on the shape."},
        {"_FScale", "Zoom applied each fold step. Close to 1 = smooth, higher = busier."},
        {"_FlowSpeed", "How fast the fractal morphs over time. The original was almost still."},
        {"_RotBase", "Base term of the per-step rotation. Small changes make big pattern changes."},
        {"_RotAmp", "How much the rotation breathes over time."},
        {"_RotOff", "Offset of the rotation. Keep it at least as big as Rotation Amount or the pattern snaps."},
        {"_RotPhase", "How much each fold step is out of phase with the one before."},
        {"_BandMode", "What drives the rainbow stripes. Fractal Y = original. World Direction = bands run through 3D space. Camera Distance = bands ripple outward from you. Fractal Radius = bands follow the fractal."},
        {"_BandFreq", "Stripe density. For the surface shader this applies to Fractal Y mode (original 500). For the world shader it applies to every mode."},
        {"_BandWorldFreq", "Stripe density in World Direction, Camera Distance and Fractal Radius modes."},
        {"_BandDir", "Direction the world-space bands travel along (xyz)."},
        {"_AngleBands", "How much the fractal's angle also shifts the colour. 1 = original."},
        {"_BandSpeed", "How fast the rainbow scrolls."},
        {"_HueOffset", "Rotates the whole rainbow around the colour wheel."},
        {"_HueDrift", "Slowly cycles the hue over time."},
        {"_Sat", "Colour saturation."},
        {"_ValRange", "x = fractal radius that is black, y = radius that is full bright. Narrow = harder contrast."},
        {"_OilMix", "Blends in an oil-slick / thin-film look that shifts colour with view angle. 0 = off."},
        {"_FilmScale", "How strongly the oil colours change with view angle."},
        {"_FilmFractal", "How much the fractal bends the oil colours."},
        {"_FilmOffset", "Shifts the starting colour of the oil film."},
        {"_FilmSpeed", "Scroll speed of the oil film colours."},
        {"_OilFractalMask", "How much dark fractal areas also darken the oil colours."},
        {"_SrcBlend", "Blend source. Defaults are fine. For a glow use One / One."},
        {"_DstBlend", "Blend destination."},
        {"_ZWrite", "Write to the depth buffer. Turn off for glowing transparent looks."},
        {"_Cull", "Which faces to draw. Off draws both sides."},
        // ---- surface: waves / relief / lighting
        {"_WaveAmp", "Size of the travelling waves that warp the fractal. This is what makes the hills roll and flow. 0 = no waves."},
        {"_WaveFreq", "How many waves fit across the surface. Higher = tighter ripples."},
        {"_WaveSpeed", "How fast the waves travel. Negative runs them backwards."},
        {"_WaveDir", "Direction of the main wave (xy)."},
        {"_ReliefHeight", "How tall the hills are, in metres, for lighting and shading. 0 = flat like the Classic version. This does not move the mesh, see Mesh Displacement for that."},
        {"_BumpSoftness", "How wide a slope is measured. Higher = smoother, broader hills. Lower = sharper but noisier. Relief automatically fades where the pattern is smaller than a pixel."},
        {"_HeightRadius", "How much the fractal's smooth brightness shapes the hills. The dark folded knots become valleys."},
        {"_HeightBands", "How much the rainbow bands add sharp ridges, like contour lines."},
        {"_Parallax", "Hills shift against the surface as you move your head, giving real depth. 1 = matches the Relief Height exactly, higher exaggerates. 0 = off. Needs Relief Height above 0 and costs a second fractal evaluation."},
        {"_ParallaxPivot", "Height that stays in place when you move. Lower values make more of the pattern appear to sink."},
        {"_Displace", "Really pushes the mesh in and out by the hill height, in metres. Needs a mesh with plenty of vertices. Use small values on clothes. 0 = off."},
        {"_Shading", "How much the hills darken and brighten with light. 0 = flat colours, 1 = fully shaded."},
        {"_UseSceneLight", "On = shade using the world's directional light. Off = use the fixed direction below, which looks the same everywhere."},
        {"_LightDir", "Direction the fixed light comes from (xyz, world space)."},
        {"_SpecAmount", "Glossy highlight on the hills."},
        {"_SpecPower", "Higher = smaller, sharper highlight."},
        // ---- fractal world
        {"_Shape", "Kaleidoscopic Blocks = 3D folded sponge-like geometry. Twisted Pillars = infinite fractal columns twisting along their height."},
        {"_Space", "World = pattern is fixed in the world, you see through the mesh like a window. Object = pattern moves with the object."},
        {"_Clip", "Limits the fractal to the mesh volume so a cube/sphere acts as a bounding box. None lets it march forever."},
        {"_Iter3D", "Number of fold steps. More = more detail, slower."},
        {"_Scale3D", "Scale per fold. 2 = sierpinski/menger style, higher = sparser."},
        {"_Offset3D", "Fold offset (xyz). Changes the structure a lot, try 0.8 to 1.4."},
        {"_Thickness", "Thickness of the solid parts."},
        {"_Round", "0 = sharp boxes, 1 = bubbly spheres."},
        {"_Twist", "Rotates the shape on every fold. Makes spirals."},
        {"_PillarTwist", "Pillars only: how much the columns twist as they rise."},
        {"_Repeat", "Tiles the fractal in a grid with this spacing. 0 = a single copy."},
        {"_Morph", "How fast the structure morphs over time."},
        {"_Spin", "How fast the whole fractal rotates."},
        {"_Steps", "Maximum ray steps. More = fewer holes at grazing angles, slower."},
        {"_StepScale", "Step safety. Lower is safer (fewer artefacts) but slower."},
        {"_Eps", "How close counts as a hit. Smaller = sharper but needs more steps."},
        {"_MaxDist", "How far the ray may travel."},
        {"_Ambient", "Base light level of solid parts."},
        {"_Rim", "Glowing edge light."},
        {"_AOStrength", "Fake ambient occlusion from step count. Darkens crevices."},
        {"_Glow", "Neon glow around the fractal."},
        {"_GlowFalloff", "Higher = tighter glow close to the surface."},
        {"_FogDist", "Fades the fractal out with distance. 0 = no fade."},
        // ---- distortion
        {"_Intensity", "Master strength. Animate this from your avatar menu for onset and comedown. 0 = completely off."},
        {"_Speed", "Speed of all motion."},
        {"_Fullscreen", "On = put this on a Unity Quad and it covers your whole view. Off = it renders on the mesh itself (e.g. a big inverted sphere)."},
        {"_HideInMirror", "Hide the effect in mirrors so other people looking at you do not see a blank screen."},
        {"_HideInCameras", "Hide the effect in handheld cameras and screenshots."},
        {"_MaxDistance", "Beyond this distance the effect fades out. 0 = unlimited."},
        {"_SkyAffect", "How much the sky/background is distorted. Depth-based warping cannot anchor to the sky, so keep it low."},
        {"_Periphery", "Distortion grows towards the edges of your view, like the real thing."},
        {"_WarpAmount", "How far surfaces wobble, in metres. This is the big slow warping. Surface stays where it is, it just shifts along itself."},
        {"_WarpScale", "Size of the wobbles. Lower = big slow waves, higher = tighter."},
        {"_WarpTangent", "1 = surfaces slide sideways along themselves (drifting). 0 = they push in and out in 3D."},
        {"_Breathe", "Surfaces swell in and out along their normal, like walls breathing."},
        {"_BreatheSpeed", "Speed of the breathing."},
        {"_Drift", "Fine, small-scale drift. This is the carpet-fibres-moving-in-place effect."},
        {"_DriftScale", "Size of the fine drift. Higher = finer detail moves."},
        {"_Crawl", "Detail slides along its own edges in patches, so textures look alive and crawling."},
        {"_CrawlRadius", "Size of detail the crawl reacts to, in pixels."},
        {"_CrawlScale", "Size of the patches that crawl together."},
        {"_Enhance", "Sharpens fine texture, like the hyper-detailed look of surfaces."},
        {"_EchoCount", "Number of ghost copies. Each is the surface as it looked a moment ago, giving trails and double vision."},
        {"_EchoAmount", "Strength of the echoes."},
        {"_EchoDelay", "How far back in time each echo reaches."},
        {"_HoloAmount", "A faint hovering copy of the surface a little above it. Often visible on floors."},
        {"_HoloHeight", "How high above the surface the holo copy floats, in metres. 0.025 is about an inch."},
        {"_HoloWobble", "Makes the holo layer height drift so it is not constant."},
        {"_HoloFloorOnly", "1 = only on upward-facing surfaces like floors. 0 = every surface."},
        {"_HoloTint", "Shifts the hue of the holo layer."},
        {"_Chroma", "Splits red and blue apart, like chromatic aberration. Stronger in the periphery."},
        {"_HueShift", "Rotates all colours."},
        {"_HuePulse", "Colours slowly pulse around the wheel by this amount."},
        {"_HuePulseSpeed", "Speed of the colour pulse."},
        {"_Saturation", "Colour saturation boost."},
        {"_KaleidoAmount", "Mirrors the view into symmetrical segments. 0 = off."},
        {"_KaleidoSegments", "Number of mirror segments."},
        {"_KaleidoSpin", "Rotation speed of the kaleidoscope."},
        {"_Snow", "Static noise over the view."},
        {"_OcclusionGuard", "Stops warped samples from pulling in things that are in front of the surface. Reduces smearing at silhouettes."},
        {"_OcclusionTol", "How different in depth a sample may be before it is rejected, in metres."},
    };

    static readonly Dictionary<string, string> Blurbs = new Dictionary<string, string>
    {
        {"Ravens/Psychedelic/Fractal Surface", "3D relief version for clothes and props: the rainbow becomes rolling hills with shading, parallax, optional mesh displacement and travelling waves. Seeded, UV or triplanar. Based on Persian Symettry 2 by NPWR."},
        {"Ravens/Psychedelic/Fractal Surface Classic", "The flat version, matching the original Shadertoy look. Seeded fractal with UV or triplanar mapping, world/depth rainbow bands and oil-slick mode. Based on Persian Symettry 2 by NPWR."},
        {"Ravens/Psychedelic/Fractal World", "Raymarched 3D fractal in world space. Put on a cube or sphere as a window into pillars and kaleidoscopic geometry."},
        {"Ravens/Psychedelic/Trip Distortion", "Surface-anchored screen warp for your avatar. Put on a Quad on your head with Fullscreen on. Needs a depth texture in the world (a realtime directional light with shadows)."},
    };

    // name -> value presets for the distortion shader
    static readonly string[] PresetNames = { "Off", "Light", "Medium", "Heavy" };
    static readonly Dictionary<string, float[]> PresetValues = new Dictionary<string, float[]>
    {
        //                          Off   Light  Med   Heavy
        {"_Intensity",     new[] { 0f,    1f,    1f,   1f }},
        {"_WarpAmount",    new[] { 0f,    0.02f, 0.05f,0.12f }},
        {"_Breathe",       new[] { 0f,    0.01f, 0.03f,0.08f }},
        {"_Drift",         new[] { 0f,    0.006f,0.012f,0.03f }},
        {"_Crawl",         new[] { 0f,    0.25f, 0.5f, 0.9f }},
        {"_Enhance",       new[] { 0f,    0.3f,  0.6f, 1.4f }},
        {"_EchoAmount",    new[] { 0f,    0.15f, 0.35f,0.6f }},
        {"_Chroma",        new[] { 0f,    0.001f,0.002f,0.006f }},
        {"_Saturation",    new[] { 1f,    1.1f,  1.2f, 1.5f }},
        {"_HuePulse",      new[] { 0f,    0.01f, 0.03f,0.08f }},
    };

    public override void OnGUI(MaterialEditor editor, MaterialProperty[] props)
    {
        var mat = (Material)editor.target;
        var shader = mat.shader;

        EditorGUILayout.Space(2);
        string blurb;
        if (Blurbs.TryGetValue(shader.name, out blurb))
            EditorGUILayout.HelpBox(blurb, MessageType.None);

        if (HasProp(props, "_Iterations") || HasProp(props, "_Iter3D"))
            DrawFractalTools(editor, mat);
        if (HasProp(props, "_WarpAmount"))
            DrawDistortionTools(editor, mat);
        if (HasProp(props, "_ReliefHeight"))
            DrawReliefTools(mat);

        // walk properties, start a new foldout at each [PsyGroup(...)]
        bool visible = true;
        string group = null;
        for (int i = 0; i < props.Length; i++)
        {
            var p = props[i];
            if ((p.flags & MaterialProperty.PropFlags.HideInInspector) != 0) continue;

            int idx = shader.FindPropertyIndex(p.name);
            string g = ReadGroup(shader, idx);
            if (g != null)
            {
                group = g;
                string key = shader.name + "/" + g;
                bool o;
                if (!Open.TryGetValue(key, out o)) o = true;
                EditorGUILayout.Space(2);
                o = EditorGUILayout.BeginFoldoutHeaderGroup(o, g);
                EditorGUILayout.EndFoldoutHeaderGroup();
                Open[key] = o;
                visible = o;
            }
            if (!visible) continue;

            string tip;
            Tips.TryGetValue(p.name, out tip);
            editor.ShaderProperty(p, new GUIContent(p.displayName, tip));
        }

        EditorGUILayout.Space(6);
        editor.RenderQueueField();
        editor.EnableInstancingField();
    }

    static bool HasProp(MaterialProperty[] props, string name)
    {
        foreach (var p in props) if (p.name == name) return true;
        return false;
    }

    static string ReadGroup(Shader shader, int idx)
    {
        if (idx < 0) return null;
        foreach (var a in shader.GetPropertyAttributes(idx))
            if (a.StartsWith("PsyGroup(") && a.EndsWith(")")) return a.Substring(9, a.Length - 10);
        return null;
    }

    // ------------------------------------------------------------ fractal tools
    void DrawFractalTools(MaterialEditor editor, Material mat)
    {
        EditorGUILayout.BeginHorizontal();
        if (GUILayout.Button(new GUIContent("Randomize", "Rolls a brand new fractal: new seed, fold, translate, scale and colours. Keep clicking until you like it. The seed is saved in the material."), GUILayout.Height(24)))
            Randomize(mat);
        if (GUILayout.Button(new GUIContent("Reroll Seed Only", "Changes only the seed (the per-step jitter pattern), keeps your other settings. Does nothing visible if Jitter is 0."), GUILayout.Height(24)))
        {
            Undo.RecordObject(mat, "Reroll Seed");
            mat.SetFloat("_Seed", Mathf.Floor(Random.value * 1000f));
            EditorUtility.SetDirty(mat);
        }
        if (mat.HasProperty("_Fold") && GUILayout.Button(new GUIContent("Original Look", "Resets the fractal settings to the original Persian Symettry 2 shader."), GUILayout.Height(24)))
            ResetOriginal(mat);
        EditorGUILayout.EndHorizontal();
    }

    static void SetV(Material m, string n, float x, float y)
    {
        if (m.HasProperty(n)) m.SetVector(n, new Vector4(x, y, 0, 0));
    }
    static void SetF(Material m, string n, float v)
    {
        if (m.HasProperty(n)) m.SetFloat(n, v);
    }
    static float R(float a, float b) { return Random.Range(a, b); }

    static void Randomize(Material m)
    {
        Undo.RecordObject(m, "Randomize Fractal");
        SetF(m, "_Seed", Mathf.Floor(R(0f, 1000f)));
        SetF(m, "_HueOffset", R(0f, 1f));
        if (m.HasProperty("_Iterations")) // 2D folded fractal
        {
            SetV(m, "_Fold", R(-0.85f, -0.15f), R(-0.85f, -0.15f));
            SetV(m, "_Translate", R(1.0f, 2.0f), R(1.0f, 2.0f));
            SetF(m, "_FScale", R(1.12f, 1.5f));
            SetF(m, "_RotPhase", R(0.12f, 0.45f));
            SetF(m, "_RotBase", R(0.06f, 0.2f));
        }
        else // 3D fractal
        {
            SetF(m, "_Scale3D", R(1.6f, 2.7f));
            if (m.HasProperty("_Offset3D")) m.SetVector("_Offset3D", new Vector4(R(0.7f, 1.4f), R(0.7f, 1.4f), R(0.7f, 1.4f), 0));
            SetF(m, "_Twist", R(-0.6f, 0.6f));
            SetF(m, "_PillarTwist", R(-1.5f, 1.5f));
            SetF(m, "_Thickness", R(0.5f, 1.2f));
            SetF(m, "_Round", R(0f, 0.6f));
        }
        EditorUtility.SetDirty(m);
    }

    static void ResetOriginal(Material m)
    {
        Undo.RecordObject(m, "Reset Fractal");
        SetV(m, "_Fold", -0.5f, -0.5f);
        SetV(m, "_Translate", 1.5f, 1.5f);
        SetF(m, "_FScale", 1.25f);
        SetF(m, "_Iterations", 32f);
        SetF(m, "_Jitter", 0f);
        SetF(m, "_Seed", 0f);
        SetF(m, "_RotBase", 0.10f);
        SetF(m, "_RotAmp", 0.50001f);
        SetF(m, "_RotOff", 0.501f);
        SetF(m, "_RotPhase", 0.251f);
        SetF(m, "_HueOffset", 0f);
        EditorUtility.SetDirty(m);
    }

    // ------------------------------------------------------------ relief presets
    static void DrawReliefTools(Material mat)
    {
        EditorGUILayout.BeginHorizontal();
        GUILayout.Label("3D Look", GUILayout.Width(50));
        if (GUILayout.Button(new GUIContent("Flat", "No relief, no waves: the original flat look.")))
            SetRelief(mat, 0f, 0f, 0f, 0f, 0f);
        if (GUILayout.Button(new GUIContent("Soft Hills", "Gentle rolling hills with a little parallax.")))
            SetRelief(mat, 0.02f, 0.04f, 0.3f, 0.6f, 0.4f);
        if (GUILayout.Button(new GUIContent("Deep Hills", "Tall hills, strong waves and deeper parallax.")))
            SetRelief(mat, 0.06f, 0.1f, 0.6f, 0.8f, 0.8f);
        EditorGUILayout.EndHorizontal();
    }

    static void SetRelief(Material m, float height, float wave, float parallax, float shading, float spec)
    {
        Undo.RecordObject(m, "Relief Preset");
        SetF(m, "_ReliefHeight", height);
        SetF(m, "_WaveAmp", wave);
        SetF(m, "_Parallax", parallax);
        SetF(m, "_Shading", shading);
        SetF(m, "_SpecAmount", spec);
        EditorUtility.SetDirty(m);
    }

    // ------------------------------------------------------------ distortion tools
    void DrawDistortionTools(MaterialEditor editor, Material mat)
    {
        EditorGUILayout.BeginHorizontal();
        GUILayout.Label("Presets", GUILayout.Width(50));
        for (int i = 0; i < PresetNames.Length; i++)
        {
            if (GUILayout.Button(new GUIContent(PresetNames[i], "Sets the main sliders to a " + PresetNames[i].ToLower() + " level. You can fine tune afterwards.")))
            {
                Undo.RecordObject(mat, "Distortion Preset");
                foreach (var kv in PresetValues) SetF(mat, kv.Key, kv.Value[i]);
                EditorUtility.SetDirty(mat);
            }
        }
        EditorGUILayout.EndHorizontal();
        EditorGUILayout.HelpBox("To drive this from your avatar menu, animate any property here as material._Intensity, material._WarpAmount etc. on the renderer.", MessageType.None);
    }
}
