"""Procedural car generator for Lycho (run with Blender's Python: `python3 gen_car.py <name>`).

Builds an original, realistically proportioned car from a lofted body (side profile +
plan view + cross-section), smooths it, assigns paint / glass / trim / light materials,
adds separate wheels for Godot's VehicleWheel3D, and exports a GLB.
Everything generated here is original work, free to use.
"""
import bpy, bmesh, math, sys, os
from mathutils import Vector

# ---------------------------------------------------------------- body types
# Lengths in metres. x = forward. Profiles are lists of (x_fraction 0=rear..1=front, value).
TYPES = {
    "sedan": dict(length=4.75, width=1.84, wheelbase=2.80, wheel_r=0.33, clearance=0.16,
                  shoulder=[(0, .80), (.06, .93), (.22, .98), (.66, .99), (.86, .88), (.97, .74), (1, .55)],
                  roof=[(.20, .98), (.30, 1.36), (.40, 1.45), (.56, 1.45), (.66, 1.38), (.76, .99)],
                  front_overhang=0.98),
    "hatch": dict(length=4.10, width=1.78, wheelbase=2.62, wheel_r=0.31, clearance=0.15,
                  shoulder=[(0, .86), (.05, .96), (.62, .99), (.84, .88), (.97, .72), (1, .55)],
                  roof=[(.02, .98), (.06, 1.36), (.14, 1.47), (.52, 1.47), (.64, 1.38), (.74, .99)],
                  front_overhang=0.86),
    "suv": dict(length=4.80, width=1.95, wheelbase=2.85, wheel_r=0.38, clearance=0.22,
                shoulder=[(0, .96), (.04, 1.08), (.60, 1.10), (.82, 1.03), (.96, .86), (1, .66)],
                roof=[(.02, 1.10), (.05, 1.62), (.12, 1.74), (.56, 1.74), (.66, 1.64), (.76, 1.11)],
                front_overhang=0.92),
    "van": dict(length=5.30, width=2.0, wheelbase=3.20, wheel_r=0.36, clearance=0.18,
                shoulder=[(0, 1.0), (.03, 1.10), (.72, 1.12), (.88, 1.02), (.97, .80), (1, .62)],
                roof=[(.01, 1.12), (.02, 1.95), (.70, 1.98), (.80, 1.80), (.88, 1.13)],
                front_overhang=0.80),
}

# Pre-made looks: body type, paint colour (linear-ish sRGB), metallic paint?
FLEET = {
    "sedan_black": ("sedan", (0.02, 0.022, 0.025), True),
    "sedan_silver": ("sedan", (0.55, 0.57, 0.6), True),
    "sedan_red": ("sedan", (0.45, 0.03, 0.03), True),
    "taxi": ("sedan", (0.95, 0.68, 0.06), False),
    "hatch_white": ("hatch", (0.86, 0.87, 0.86), False),
    "hatch_blue": ("hatch", (0.06, 0.16, 0.38), True),
    "suv_grey": ("suv", (0.18, 0.19, 0.2), True),
    "suv_green": ("suv", (0.07, 0.15, 0.1), True),
    "van_white": ("van", (0.9, 0.9, 0.88), False),
}


def interp(profile, f):
    if f <= profile[0][0]:
        return profile[0][1]
    for (a, va), (b, vb) in zip(profile, profile[1:]):
        if a <= f <= b:
            t = (f - a) / max(b - a, 1e-6)
            t = t * t * (3 - 2 * t)  # smoothstep for soft curvature
            return va + (vb - va) * t
    return profile[-1][1]


def lin(profile, f):
    """Linear interpolation, matching the SDF sculpt (numpy.interp)."""
    import numpy as np
    return float(np.interp(f, [p[0] for p in profile], [p[1] for p in profile]))


def mat(name, color, metallic=0.0, rough=0.5, alpha=1.0, emit=None, coat=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = rough
    if coat > 0 and "Coat Weight" in b.inputs:
        b.inputs["Coat Weight"].default_value = coat
        b.inputs["Coat Roughness"].default_value = 0.03
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND" if hasattr(m, "blend_method") else None
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = 3.0
    return m


def _smin(a, b, k):
    import numpy as np
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b + (a - b) * h - k * h * (1.0 - h)


def _smax(a, b, k):
    return -_smin(-a, -b, k)


def _round_rect(px, py, hx, hy, r):
    import numpy as np
    qx = np.abs(px) - hx + r
    qy = np.abs(py) - hy + r
    return np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2) + np.minimum(np.maximum(qx, qy), 0) - r


def _polygon(px, py, verts):
    """Signed distance to a convex polygon (Inigo Quilez), vectorised."""
    import numpy as np
    d = (px - verts[0][0]) ** 2 + (py - verts[0][1]) ** 2
    s = np.ones_like(px)
    n = len(verts)
    for i in range(n):
        j = (i - 1) % n
        ex, ey = verts[j][0] - verts[i][0], verts[j][1] - verts[i][1]
        wx, wy = px - verts[i][0], py - verts[i][1]
        t = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey), 0, 1)
        bx, by = wx - ex * t, wy - ey * t
        d = np.minimum(d, bx * bx + by * by)
        c1 = py >= verts[i][1]
        c2 = py < verts[j][1]
        c3 = ex * wy > ey * wx
        flip = (c1 & c2 & c3) | (~c1 & ~c2 & ~c3)
        s = np.where(flip, -s, s)
    return s * np.sqrt(d)


def build_body(spec, paint, metallic):
    import numpy as np
    from skimage import measure
    L, W = spec["length"], spec["width"]
    clr, wr = spec["clearance"], spec["wheel_r"]
    fa = L / 2 - spec["front_overhang"]
    ra = fa - spec["wheelbase"]
    step = 0.02
    xs = np.arange(-L / 2 - 0.1, L / 2 + 0.1, step)
    ys = np.arange(-W / 2 - 0.1, W / 2 + 0.1, step)
    roof_max = max(v for _, v in spec["roof"])
    zs = np.arange(0.0, roof_max + 0.12, step)
    X, Y, Z = np.meshgrid(xs, ys, zs, indexing="ij")
    F = (X + L / 2) / L
    sh_max = max(v for _, v in spec["shoulder"])
    # Lower body: plan-rounded slab from sill to shoulder.
    zc = (clr + sh_max) / 2
    hz = (sh_max - clr) / 2
    rz = 0.09
    d2 = _round_rect(X, Y, L / 2 - rz, W / 2 - rz, 0.42)
    dz = np.abs(Z - zc) - (hz - rz)
    w0, w1 = d2 + 0, dz
    body = np.minimum(np.maximum(w0, w1), 0) + np.sqrt(np.maximum(w0, 0) ** 2 + np.maximum(w1, 0) ** 2) - rz
    # Hood and boot heights from the shoulder profile.
    top = np.interp(F, [p[0] for p in spec["shoulder"]], [p[1] for p in spec["shoulder"]])
    body = _smax(body, Z - top, 0.07)
    # Greenhouse: side profile polygon, extruded with tumblehome.
    rf = spec["roof"]
    x_of = lambda f: -L / 2 + f * L
    sh_r = np.interp(rf[0][0], [p[0] for p in spec["shoulder"]], [p[1] for p in spec["shoulder"]])
    sh_f = np.interp(rf[-1][0], [p[0] for p in spec["shoulder"]], [p[1] for p in spec["shoulder"]])
    poly = [(x_of(rf[0][0]), sh_r - 0.1)]
    for f, v in rf[1:-1]:
        poly.append((x_of(f), v))
    poly.append((x_of(rf[-1][0]), sh_f - 0.1))
    poly = poly[::-1]  # counter-clockwise
    dpoly = _polygon(X, Z, poly) - 0.0
    belt = np.interp(F, [p[0] for p in spec["shoulder"]], [p[1] for p in spec["shoulder"]])
    half_w = W / 2 * 0.93 - np.maximum(Z - belt, 0) * 0.42
    cabin = _smax(dpoly, np.abs(Y) - half_w, 0.06)
    cabin = _smax(cabin, -(Z - (belt - 0.12)), 0.02)
    body = _smin(body, cabin, 0.09)
    # Wheel arches cut into the flanks.
    for ax in (fa, ra):
        arch = np.sqrt((X - ax) ** 2 + (Z - wr) ** 2) - (wr + 0.07)
        arch = np.maximum(arch, (W / 2 - 0.34) - np.abs(Y))
        body = _smax(body, -arch, 0.02)
    verts, faces, normals, _ = measure.marching_cubes(body, level=0.0, spacing=(step, step, step))
    verts += np.array([xs[0], ys[0], zs[0]])
    mesh = bpy.data.meshes.new("Body")
    mesh.from_pydata(verts.tolist(), [], faces[:, ::-1].tolist() if False else faces.tolist())
    mesh.update()
    body_o = bpy.data.objects.new("Body", mesh)
    bpy.context.collection.objects.link(body_o)
    bpy.context.view_layer.objects.active = body_o
    body_o.select_set(True)
    dec = body_o.modifiers.new("Dec", "DECIMATE")
    dec.ratio = min(1.0, 40000 / max(len(faces), 1))
    bpy.ops.object.modifier_apply(modifier="Dec")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for p in body_o.data.polygons:
        p.use_smooth = True

    body_o.data.materials.append(mat("Body", paint, metallic=0.5, rough=0.3))
    return body_o, (fa, ra)


def add_box(name, loc, size, material):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(material)
    return o


def _surface_x(body, y, z, front=True):
    """Ray-cast along X to find where the body surface is at (y, z)."""
    import mathutils
    origin = mathutils.Vector((10.0 if front else -10.0, y, z))
    direction = mathutils.Vector((-1.0 if front else 1.0, 0, 0))
    deps = bpy.context.evaluated_depsgraph_get()
    hit, loc, normal, *_ = bpy.context.scene.ray_cast(deps, origin, direction)
    return (loc.x, normal) if hit else (None, None)


def _surface_y(body, x, z, side):
    import mathutils
    origin = mathutils.Vector((x, 10.0 * side, z))
    deps = bpy.context.evaluated_depsgraph_get()
    hit, loc, normal, *_ = bpy.context.scene.ray_cast(deps, origin, mathutils.Vector((0, -side, 0)))
    return loc.y if hit else None


def add_lights(spec, paint, body):
    L, W = spec["length"], spec["width"]
    sh_front = interp(spec["shoulder"], 0.985)
    sh_rear = interp(spec["shoulder"], 0.015)
    head = mat("Headlight", (0.85, 0.88, 0.92), rough=0.08, emit=(1.0, 0.97, 0.9))
    tail = mat("Taillight", (0.45, 0.02, 0.02), rough=0.15, emit=(1.0, 0.04, 0.02))
    grille = mat("Grille", (0.01, 0.01, 0.012), rough=0.35, metallic=0.5)
    plate = mat("Plate", (0.86, 0.86, 0.82), rough=0.5)
    parts = [
        # (name, y, z, front?, size(depth, width, height), material)
        ("HeadL", W * 0.32, sh_front - 0.07, True, (0.08, 0.36, 0.075), head),
        ("HeadR", -W * 0.32, sh_front - 0.07, True, (0.08, 0.36, 0.075), head),
        ("Grille", 0.0, sh_front - 0.2, True, (0.06, W * 0.4, 0.13), grille),
        ("PlateF", 0.0, spec["clearance"] + 0.24, True, (0.03, 0.5, 0.11), plate),
        ("TailL", W * 0.35, sh_rear - 0.06, False, (0.07, 0.34, 0.08), tail),
        ("TailR", -W * 0.35, sh_rear - 0.06, False, (0.07, 0.34, 0.08), tail),
        ("PlateR", 0.0, sh_rear - 0.24, False, (0.03, 0.5, 0.11), plate),
    ]
    for name, y, z, front, size, m in parts:
        x, _ = _surface_x(body, y, z, front)
        if x is None:
            continue
        x += (-size[0] * 0.35) if front else (size[0] * 0.35)
        add_box(name, (x, y, z), size, m)
    mirror = mat("MirrorPaint", paint, metallic=0.5, rough=0.3)
    f_mirror = spec["roof"][-1][0] - 0.035
    x_mirror = -L / 2 + f_mirror * L
    z_mirror = interp(spec["shoulder"], f_mirror) + 0.09
    for sd in (-1, 1):
        y = _surface_y(body, x_mirror, z_mirror, sd)
        if y is None:
            continue
        add_box("Mirror", (x_mirror, y + sd * 0.07, z_mirror), (0.12, 0.15, 0.09), mirror)


def add_wheel(name, x, y, r, width):
    tyre = bpy.data.materials.get("Tyre") or mat("Tyre", (0.02, 0.02, 0.02), rough=0.85)
    rim = bpy.data.materials.get("Rim") or mat("Rim", (0.75, 0.76, 0.78), metallic=1.0, rough=0.25)
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=r, depth=width, location=(0, 0, 0), rotation=(math.pi / 2, 0, 0))
    t = bpy.context.active_object
    t.data.materials.append(tyre)
    bev = t.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.05
    bev.segments = 4
    bpy.ops.object.modifier_apply(modifier="Bevel")
    for p in t.data.polygons:
        p.use_smooth = True
    side = 1 if y > 0 else -1
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=r * 0.66, depth=0.04, location=(0, side * width * 0.48, 0), rotation=(math.pi / 2, 0, 0))
    disc = bpy.context.active_object
    disc.data.materials.append(rim)
    for k in range(5):
        a = k * 2 * math.pi / 5
        bpy.ops.mesh.primitive_cube_add(size=1, location=(math.cos(a) * r * 0.33, side * width * 0.52, math.sin(a) * r * 0.33))
        sp = bpy.context.active_object
        sp.scale = (r * 0.52, 0.03, 0.07)
        sp.rotation_euler = (0, -a, 0)
        sp.data.materials.append(rim)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=r * 0.12, depth=0.06, location=(0, side * width * 0.54, 0), rotation=(math.pi / 2, 0, 0))
    hub = bpy.context.active_object
    hub.data.materials.append(rim)
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.collection.objects:
        if o.name.startswith(("Cylinder", "Cube")) or o == t:
            o.select_set(True)
    bpy.context.view_layer.objects.active = t
    bpy.ops.object.join()
    t.name = name
    t.location = (x, y, r)
    return t


def build(name, out_dir):
    kind, paint, metallic = FLEET[name]
    spec = TYPES[kind]
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    body, (fa, ra) = build_body(spec, paint, metallic)
    add_lights(spec, paint, body)
    # Join lights, plates, grille and mirrors into one "Details" mesh (keeps its own materials).
    bpy.ops.object.select_all(action="DESELECT")
    details = [o for o in bpy.context.collection.objects if o != body]
    for o in details:
        o.select_set(True)
    if details:
        bpy.context.view_layer.objects.active = details[0]
        bpy.ops.object.join()
        bpy.context.view_layer.objects.active.name = "Details"
    track = spec["width"] / 2 - 0.16
    ww = 0.24 if kind != "van" else 0.26
    for wname, x, y in (("wheel_fl", fa, track), ("wheel_fr", fa, -track), ("wheel_rl", ra, track), ("wheel_rr", ra, -track)):
        add_wheel(wname, x, y, spec["wheel_r"], ww)
    # Blender is Z-up / X-forward; glTF export converts to Y-up. In Godot the car faces -Z.
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    for o in list(bpy.context.collection.objects):
        if o != root:
            o.parent = root
    root.rotation_euler = (0, 0, math.pi / 2)
    bpy.ops.object.select_all(action="SELECT")
    import json
    shp, rf = spec["shoulder"], spec["roof"]
    samples = [i / 63 for i in range(64)]
    meta = {
        "length": spec["length"], "width": spec["width"], "clearance": spec["clearance"],
        "wheel_r": spec["wheel_r"], "axle_front": fa, "axle_rear": ra,
        "cabin_start": rf[0][0], "cabin_end": rf[-1][0],
        "belt": [lin(shp, f) for f in samples],
        "roof": [lin(rf, f) if rf[0][0] <= f <= rf[-1][0] else lin(shp, f) for f in samples],
        "paint": list(paint), "metallic": metallic, "kind": kind,
    }
    with open(os.path.join(out_dir, name + ".json"), "w") as fh:
        json.dump(meta, fh)
    path = os.path.join(out_dir, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, use_selection=True)
    print("WROTE", path)


if __name__ == "__main__":
    out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "."
    names = [a for a in sys.argv[1:] if a in FLEET] or list(FLEET)
    for n in names:
        build(n, out)
