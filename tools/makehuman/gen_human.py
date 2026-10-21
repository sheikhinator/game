import importlib, sys, bpy, os, json
def imp(pkg, key):
    for m in list(sys.modules):
        if m.endswith(pkg):
            return getattr(importlib.import_module(m), key)
    raise ValueError(pkg)
bpy.ops.preferences.addon_enable(module="bl_ext.user_default.mpfb")
HumanService = imp("mpfb.services.humanservice", "HumanService")
AssetService = imp("mpfb.services.assetservice", "AssetService")
ExportService = imp("mpfb.services.exportservice", "ExportService")
ObjectService = imp("mpfb.services.objectservice", "ObjectService")
TargetService = imp("mpfb.services.targetservice", "TargetService")

cfg = json.load(open(sys.argv[-1]))
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)

macro = TargetService.get_default_macro_info_dict()
macro.update(cfg.get("macros", {}))
basemesh = HumanService.create_human(macro_detail_dict=macro)

skin = AssetService.find_asset_absolute_path(cfg["skin"], asset_subdir="skins")
HumanService.set_character_skin(skin, basemesh, skin_type="GAMEENGINE")
HumanService.add_builtin_rig(basemesh, "game_engine")
for subdir, fname, atype in cfg["assets"]:
    p = AssetService.find_asset_absolute_path(fname, asset_subdir=subdir)
    if p is None:
        print("MISSING", subdir, fname); continue
    HumanService.add_mhclo_asset(p, basemesh, asset_type=atype, material_type="GAMEENGINE")

root = ExportService.create_character_copy(basemesh, name_suffix="_export")
bm = ObjectService.find_object_of_type_amongst_nearest_relatives(root, "Basemesh")
# Freeze the body shape (macro targets) so the glTF mesh matches the fitted clothes.
for ob in [bm] + list(ObjectService.get_list_of_children(root)):
    if ob.type == "MESH" and ob.data.shape_keys:
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
ExportService.bake_modifiers_remove_helpers(bm, bake_masks=True, bake_subdiv=False, remove_helpers=True, also_proxy=True)
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
for c in ObjectService.get_list_of_children(root):
    c.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(filepath=cfg["out"], use_selection=True, export_format="GLB", export_animations=False,
    export_image_format="JPEG", export_jpeg_quality=88, export_apply=True)
arm = root if root.type == "ARMATURE" else None
print("BONES", [b.name for b in (arm.data.bones if arm else [])][:70])
print("WROTE", cfg["out"])
