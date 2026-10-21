# Generating realistic humans

Characters are generated with MakeHuman (MPFB2 for Blender) from CC0 asset packs, then
exported to `assets/humans/*.glb`. Godot retargets them to its humanoid skeleton on import
(`assets/retarget/mh_bonemap.tres`), so every animation in `assets/animations` plays on them.

1. `pip install bpy` (Blender as a Python module) and install MPFB2 as an extension.
2. Unzip the CC0 packs (makehuman_system_assets, skins01/02, shirts01, pants01, shoes01, hair01,
   eyebrows01, eyelashes01) into MPFB's user data folder.
3. `python3 gen_human.py male_a.json`

Never use skins whose names include "with_genitals".
