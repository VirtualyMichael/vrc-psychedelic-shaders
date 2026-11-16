# VRChat Psychedelic Shaders

Psychedelic and trip-visual shaders for VRChat avatars (Unity 2022.3, Built-in render pipeline, PC only).
Drop the `Psychedelic Shaders` folder into your project's `Assets`.

| Shader | What it is |
|---|---|
| `Ravens/Psychedelic/Fractal Surface` | Seeded, randomisable folded fractal for clothes and props with 3D relief: rolling hills, shading, parallax, optional mesh displacement, travelling waves, triplanar mapping, world/depth rainbow bands and an oil-slick mode. |
| `Ravens/Psychedelic/Fractal Surface Classic` | The flat version that matches the original Shadertoy look, with the same randomisation, mapping and colour options. |
| `Ravens/Psychedelic/Fractal World` | Raymarched 3D fractal (kaleidoscopic blocks or twisted pillars) inside any mesh. *Work in progress.* |
| `Ravens/Psychedelic/Trip Distortion` | Surface-anchored screen warp for avatars: breathing, fine drift, texture crawl, echoes, holographic surface layer, colour split, kaleidoscope. Needs a depth texture in the world. *Work in progress.* |

All shaders use the custom inspector in `Editor/RavensPsyShaderGUI.cs` (foldouts, tooltips on every control, Randomize and preset buttons).

## Credits

The fractal shaders are derived from **"Persian Symettry 2"** by **NPWR**
(<https://www.shadertoy.com/view/ldSXzc>, 2014). Shadertoy shaders default to the
CC BY-NC-SA 3.0 licence, so treat the fractal shaders as non-commercial and share-alike unless you have
the original author's permission otherwise. No licence has been chosen for the rest of this repo yet.

## Updates and backups

`tools/sync-from-unity.ps1` copies the shaders out of the Unity project into this repo.
Tagged releases (`v0.x.y`) contain a zip of the `Psychedelic Shaders` folder as a backup.
