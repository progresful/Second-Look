"""Second Look landing: "put them on" dive, rendered as frames for scroll playback.

Generic smart glasses (no brand shapes or logos), studio lit on black. The lenses reflect
the scam webshop. The camera turns to the right lens, dives through it and ends on the
first frame of the hero footage (a backdrop plane that exactly fills the last frame),
so the page can cross-fade from the frames to the real <video>.

Run:  Blender -b -P glasses_dive.py -- <assets_dir> <out_dir> [preview]
"""
import bpy, math, sys, os
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ASSETS = argv[0] if argv else "."
OUT = argv[1] if len(argv) > 1 else "./frames"
PREVIEW = len(argv) > 2 and argv[2] == "preview"
FRAMES = 120

bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene
scn.frame_start, scn.frame_end = 1, FRAMES
scn.render.fps = 30

# ---------- materials ----------
def mat(name, **kw):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    for k, v in kw.items():
        key = {"color": "Base Color", "rough": "Roughness", "metal": "Metallic", "trans": "Transmission Weight",
               "ior": "IOR", "coat": "Coat Weight", "coat_rough": "Coat Roughness", "emit": "Emission Color",
               "emit_s": "Emission Strength", "alpha": "Alpha"}[k]
        b.inputs[key].default_value = v
    return m

M_FRAME = mat("frame", color=(0.003, 0.003, 0.004, 1), rough=0.55, coat=0.18, coat_rough=0.2)
M_LENS = mat("lens", color=(0.62, 0.66, 0.72, 1), rough=0.02, trans=1.0, ior=1.52)
M_METAL = mat("metal", color=(0.55, 0.56, 0.6, 1), rough=0.25, metal=1.0)
M_CAMGLASS = mat("camglass", color=(0.0, 0.0, 0.0, 1), rough=0.05, coat=1.0, coat_rough=0.0)
M_LED = mat("led", color=(1, 1, 1, 1), emit=(1.0, 1.0, 1.0, 1), emit_s=0.0)

def image_emission_mat(name, path, strength=1.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = bpy.data.images.load(path); tex.extension = "CLIP"
    em = nt.nodes.new("ShaderNodeEmission"); em.inputs["Strength"].default_value = strength
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(tex.outputs["Color"], em.inputs["Color"]); nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m, em

# ---------- geometry helpers ----------
def superellipse(cx, cz, a, b, n=4.0, taper=0.08, pts=96, notch=None, lift=0.0, side=0):
    out = []
    for i in range(pts):
        t = 2 * math.pi * i / pts
        c, s = math.cos(t), math.sin(t)
        x = a * math.copysign(abs(c) ** (2 / n), c)
        z = b * math.copysign(abs(s) ** (2 / n), s)
        x *= 1 + taper * (z / b)            # wider at the top, like classic frames
        if lift and z > 0:                  # upswept outer top corners (Wayfarer-style brow)
            reach = (x / a) if side > 0 else (-x / a) if side < 0 else abs(x / a)
            if reach > 0: z += lift * (z / b) * reach ** 3
        if notch and z < 0 and abs(x) < notch[0]:  # bridge notch at the bottom middle
            k = (1 - (abs(x) / notch[0]) ** 2)
            z = z + (notch[1] - z) * k
        out.append((cx + x, cz + z))
    return out

def plate(name, splines, depth, bevel, material):
    cu = bpy.data.curves.new(name, "CURVE"); cu.dimensions = "2D"; cu.fill_mode = "BOTH"
    cu.extrude = depth; cu.bevel_depth = bevel; cu.bevel_resolution = 4
    for poly in splines:
        sp = cu.splines.new("POLY"); sp.points.add(len(poly) - 1)
        for p, (x, z) in zip(sp.points, poly): p.co = (x, z, 0, 1)
        sp.use_cyclic_u = True
    ob = bpy.data.objects.new(name, cu); bpy.context.collection.objects.link(ob)
    ob.rotation_euler = (math.radians(90), 0, 0)   # into the XZ plane, facing -Y
    ob.data.materials.append(material)
    return ob

rig = bpy.data.objects.new("rig", None); bpy.context.collection.objects.link(rig)

# Wayfarer-style smart glasses in the spirit of Ray-Ban Display (no logos): heavy brow,
# trapezoid lenses, chunky arms, camera left, capture light right, display in the right lens.
LX, LA, LB = 0.0335, 0.0258, 0.0205           # lens centre x, half width, half height (m)
lensL = superellipse(-LX, -0.0010, LA, LB, n=4.2, taper=0.26, lift=0.0035, side=-1)
lensR = superellipse(+LX, -0.0010, LA, LB, n=4.2, taper=0.26, lift=0.0035, side=1)
outer = superellipse(0.0, 0.0022, 0.0698, 0.0268, n=5.0, taper=0.27, pts=220, notch=(0.0115, -0.0150), lift=0.0060)
FD = 0.0045
front = plate("front", [outer, lensL, lensR], FD, 0.0018, M_FRAME); front.parent = rig
for nm, poly in (("lensL", lensL), ("lensR", lensR)):
    ln = plate(nm, [poly], 0.0010, 0.0004, M_LENS); ln.parent = rig

# arms: chunky near the hinge (battery and speakers), tapering towards the ear
for side in (-1, 1):
    bpy.ops.mesh.primitive_cube_add(size=1)
    t = bpy.context.object; t.name = f"temple{side}"
    t.scale = (0.0068, 0.140, 0.0135); t.location = (side * 0.0668, 0.0735, 0.0115)
    bpy.ops.object.transform_apply(scale=True)
    bev = t.modifiers.new("bev", "BEVEL"); bev.width = 0.0026; bev.segments = 5
    tw = t.modifiers.new("taper", "SIMPLE_DEFORM"); tw.deform_method = "TAPER"; tw.factor = -0.42; tw.deform_axis = "Y"
    t.data.materials.append(M_FRAME); t.parent = rig
    bpy.ops.object.shade_smooth()
    bpy.ops.mesh.primitive_cylinder_add(radius=0.0018, depth=0.010, location=(side * 0.0668, 0.0040, 0.0115))
    h = bpy.context.object; h.name = f"hinge{side}"; h.data.materials.append(M_METAL); h.parent = rig

# camera (left top corner) and capture light (right top corner), set into the front
CY = -(FD + 0.0018) - 0.0004
bpy.ops.mesh.primitive_cylinder_add(radius=0.0034, depth=0.0012, location=(-0.0655, CY, 0.0228), rotation=(math.radians(90), 0, 0))
cam_ring = bpy.context.object; cam_ring.data.materials.append(M_METAL); cam_ring.parent = rig
bpy.ops.mesh.primitive_cylinder_add(radius=0.0025, depth=0.0014, location=(-0.0655, CY - 0.0003, 0.0228), rotation=(math.radians(90), 0, 0))
cam_glass = bpy.context.object; cam_glass.data.materials.append(M_CAMGLASS); cam_glass.parent = rig
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.0012, location=(0.0655, CY, 0.0228))
led = bpy.context.object; led.data.materials.append(M_LED); led.parent = rig

# the display: a small bright panel in the lower right of the right lens, showing the alert
bpy.ops.mesh.primitive_plane_add(size=1, location=(LX + 0.0055, 0.0016, -0.0060), rotation=(math.radians(90), 0, 0))
disp = bpy.context.object; disp.name = "display"; disp.scale = (0.0175, 0.0093, 1); disp.parent = rig
m_disp, em_disp = image_emission_mat("display", os.path.join(ASSETS, "hud.png"), 0.0)
disp.data.materials.append(m_disp)
disp.visible_glossy = False; disp.visible_diffuse = False
for f, v in ((36, 0.0), (46, 2.2), (98, 2.2), (104, 0.0)):
    em_disp.inputs["Strength"].default_value = v; em_disp.inputs["Strength"].keyframe_insert("default_value", frame=f)

# ---------- the view behind the glasses (hand-over frame) ----------
CAM_END_Y, PLANE_Y, FOCAL, SENSOR = 0.045, 1.2, 35.0, 36.0
dist = PLANE_Y - CAM_END_Y
pw = SENSOR / FOCAL * dist; ph = pw * 9 / 16
bpy.ops.mesh.primitive_plane_add(size=1, location=(LX, PLANE_Y, 0.0), rotation=(math.radians(90), 0, 0))
view = bpy.context.object; view.name = "view"; view.scale = (pw, ph, 1)
m_view, em_view = image_emission_mat("viewimg", os.path.join(ASSETS, "first.jpg"), 1.0)
view.data.materials.append(m_view)
view.visible_glossy = False   # never shows up in reflections
# fade the world in only as we approach the lens
em_view.inputs["Strength"].default_value = 0.0; em_view.inputs["Strength"].keyframe_insert("default_value", frame=50)
em_view.inputs["Strength"].default_value = 0.6; em_view.inputs["Strength"].keyframe_insert("default_value", frame=88)
em_view.inputs["Strength"].default_value = 1.0; em_view.inputs["Strength"].keyframe_insert("default_value", frame=FRAMES)

# reflection card: the scam webshop, behind the camera, seen only in the lenses
bpy.ops.mesh.primitive_plane_add(size=1, location=(0.0, -0.9, 0.08), rotation=(math.radians(-90), 0, 0))
card = bpy.context.object; card.scale = (0.9, 0.5, 1)
m_card, _ = image_emission_mat("reflect", os.path.join(ASSETS, "reflect.jpg"), 7.0)
card.data.materials.append(m_card)
card.visible_camera = False; card.visible_diffuse = False

# ---------- lights: soft key, cool and warm rims ----------
def area(name, loc, rot, size, energy, color):
    l = bpy.data.lights.new(name, "AREA"); l.size = size[0]; l.shape = "RECTANGLE"; l.size_y = size[1]
    l.energy = energy; l.color = color
    o = bpy.data.objects.new(name, l); o.location = loc; o.rotation_euler = [math.radians(a) for a in rot]
    bpy.context.collection.objects.link(o); return o
area("key", (0.0, -0.35, 0.45), (38, 0, 0), (0.6, 0.25), 11, (1.0, 0.98, 0.95))
area("rimL", (-0.45, 0.25, 0.10), (90, 0, -115), (0.04, 0.8), 40, (0.55, 0.7, 1.0))
area("rimR", (0.45, 0.25, 0.08), (90, 0, 115), (0.04, 0.8), 30, (1.0, 0.82, 0.65))
area("top", (0.0, 0.05, 0.6), (0, 0, 0), (0.9, 0.4), 3, (0.9, 0.93, 1.0))

world = bpy.data.worlds.new("w"); scn.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.0, 0.0, 0.0, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0

# ---------- animation ----------
def key(ob, attr, frame, value):
    setattr(ob, attr, value); ob.keyframe_insert(attr, frame=frame)

# glasses: arrive turned and tilted, settle square to the camera
key(rig, "rotation_euler", 1, (math.radians(10), 0, math.radians(-34)))
key(rig, "location", 1, (0, 0.03, -0.004))
key(rig, "rotation_euler", 46, (math.radians(2), 0, math.radians(-6)))
key(rig, "location", 46, (0, 0, 0))
key(rig, "rotation_euler", 78, (0, 0, 0))

# capture light blinks once: checking has started
for f, s in ((24, 0.0), (27, 6.0), (31, 6.0), (34, 0.0)):
    M_LED.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = s
    M_LED.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].keyframe_insert("default_value", frame=f)

cam_data = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cam_data)
bpy.context.collection.objects.link(cam); scn.camera = cam
cam_data.sensor_width = SENSOR; cam_data.clip_start = 0.002
aim = bpy.data.objects.new("aim", None); bpy.context.collection.objects.link(aim)
tr = cam.constraints.new("TRACK_TO"); tr.target = aim; tr.track_axis = "TRACK_NEGATIVE_Z"; tr.up_axis = "UP_Y"

key(cam, "location", 1, (0.0, -0.40, 0.035)); key(cam_data, "lens", 1, 85.0)
key(cam, "location", 46, (0.0, -0.34, 0.012)); key(cam_data, "lens", 46, 70.0)
key(cam, "location", 80, (LX * 0.9, -0.15, 0.004)); key(cam_data, "lens", 80, 50.0)
key(cam, "location", 104, (LX, -0.028, 0.0)); key(cam_data, "lens", 104, 38.0)
key(cam, "location", FRAMES, (LX, CAM_END_Y, 0.0)); key(cam_data, "lens", FRAMES, FOCAL)
key(aim, "location", 1, (0.0, 0.0, 0.002))
key(aim, "location", 60, (LX * 0.6, 0.0, 0.0))
key(aim, "location", 96, (LX, 0.3, 0.0))
key(aim, "location", FRAMES, (LX, PLANE_Y, 0.0))
# keyframes default to smooth Bezier easing
for o in bpy.data.objects:
    if o.name.startswith(("temple", "hinge")):
        o.hide_render = False; o.keyframe_insert("hide_render", frame=105)
        o.hide_render = True; o.keyframe_insert("hide_render", frame=106)

# depth of field: on the glasses early, on the view at the end
cam_data.dof.use_dof = True; cam_data.dof.aperture_fstop = 2.2
key(cam_data.dof, "focus_distance", 1, 0.40)
key(cam_data.dof, "focus_distance", 80, 0.15)
key(cam_data.dof, "focus_distance", 104, 0.03)
key(cam_data.dof, "focus_distance", FRAMES, dist)
key(cam_data.dof, "aperture_fstop", 100, 2.2)
key(cam_data.dof, "aperture_fstop", FRAMES, 22.0)

# ---------- render ----------
r = scn.render
r.engine = "CYCLES"
scn.cycles.device = "GPU"
prefs = bpy.context.preferences.addons["cycles"].preferences
try:
    prefs.compute_device_type = "METAL"; prefs.get_devices()
    for d in prefs.devices: d.use = True
except Exception as e:
    print("GPU setup:", e); scn.cycles.device = "CPU"
scn.cycles.samples = 24 if PREVIEW else 28
scn.cycles.use_denoising = True
scn.cycles.max_bounces = 8; scn.cycles.transmission_bounces = 8; scn.cycles.glossy_bounces = 4
r.resolution_x, r.resolution_y = (960, 540) if PREVIEW else (1440, 810)
r.use_motion_blur = not PREVIEW; r.motion_blur_shutter = 0.35
r.film_transparent = False
scn.view_settings.view_transform = "AgX"; scn.view_settings.look = "AgX - Medium High Contrast"
r.image_settings.file_format = "PNG"; r.image_settings.color_mode = "RGB"
os.makedirs(OUT, exist_ok=True)
r.filepath = os.path.join(OUT, "f_")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "glasses_dive.blend"))
print("scene ready", OUT)
