"""Second Look hero: studio look for the logo-free glasses model (media/glasses.glb).
Builds the scene (matte black frame, dark lenses, soft floor reflection, rim lights) and
renders review stills.  Run:  Blender -b -P glasses_look.py -- <glasses.glb> <out_dir>"""
import bpy, sys, math
src, out = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
scn = bpy.context.scene

def mat(name, color, rough, metal=0.0, coat=0.0, coat_rough=0.3):
    m = bpy.data.materials.new(name); m.use_nodes = True; b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1); b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal; b.inputs["Coat Weight"].default_value = coat; b.inputs["Coat Roughness"].default_value = coat_rough
    return m
M_FRAME = mat("frame", (0.014, 0.014, 0.015), 0.56)     # matte satin black
M_LENS = mat("lens", (0.03, 0.031, 0.034), 0.22, coat=1.0, coat_rough=0.06)                       # dark glossy lens
M_GLASS = mat("camglass", (0.01, 0.012, 0.02), 0.03, metal=0.8)
rig = bpy.data.objects.new("rig", None); scn.collection.objects.link(rig)
INFLATE = 0.0065
DEPTH = 1.7                                              # front is a thin slab in the source: thicken it like the real frame
for o in [o for o in bpy.data.objects if o.type == "MESH"]:
    n = o.name; o.data.materials.clear(); o.parent = rig
    if n.startswith(("cam", "disc")): bpy.data.objects.remove(o, do_unlink=True); continue      # rebuilt below
    o.data.materials.append(M_LENS if n.startswith("lens") else M_FRAME)
    if n.startswith("lens"):                             # tuck the lens edge inside the rim
        dl = o.modifiers.new("grow", "DISPLACE"); dl.strength = 0.009; dl.mid_level = 0.0
        for v in o.data.vertices: v.co.y += 0.006        # sit a little deeper, so the edge meets the rim out of sight
    if n == "front":
        for v in o.data.vertices: v.co.y *= DEPTH
    if n in ("front", "arms"):                           # soft, pillowy edges: voxel remesh, then smooth
        r = o.modifiers.new("remesh", "REMESH"); r.mode = "VOXEL"; r.voxel_size = 0.0014; r.use_smooth_shade = True
        if n == "front":                                 # chunkier rims, like the real frame
            d = o.modifiers.new("inflate", "DISPLACE"); d.strength = INFLATE; d.mid_level = 0.0
        sm = o.modifiers.new("smooth", "LAPLACIANSMOOTH"); sm.lambda_factor = 1.0; sm.iterations = 7; sm.use_volume_preserve = True
FY = -0.016 * DEPTH - INFLATE + 0.0022
M_RING = mat("ring", (0.035, 0.035, 0.04), 0.4, metal=1.0)
def cyl(name, r, d, loc, m):
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=r, depth=d, location=loc, rotation=(math.radians(90), 0, 0))
    o = bpy.context.object; o.name = name; o.data.materials.append(m); o.parent = rig
    try: bpy.ops.object.shade_auto_smooth(angle=math.radians(40))
    except Exception: pass
    return o
for sx in (-1, 1):                                       # camera (and its twin, the capture light): ring, glass, inner lens
    x, z = sx * 0.460, 0.117
    cyl("camring", 0.0215, 0.006, (x, FY, z), M_RING)                      # outer ring, flush with the frame
    cyl("camglass", 0.0185, 0.006, (x, FY - 0.0004, z), M_GLASS)           # glass cover
    if sx > 0:
        cyl("caminner", 0.0100, 0.006, (x, FY - 0.0008, z), M_RING)        # lens barrel
        cyl("campupil", 0.0062, 0.006, (x, FY - 0.0012, z), M_GLASS)       # the lens itself
    else:
        cyl("led", 0.0030, 0.006, (x, FY - 0.0008, z), M_RING)             # capture light
# no floor: the glasses float in a black void
w = bpy.data.worlds.new("w"); scn.world = w; w.use_nodes = True
# black to the camera; a faint sky-to-floor gradient for reflections, so lenses and frame get a soft sheen
nt = w.node_tree; N = nt.nodes; bgc = N["Background"]; bgc.inputs["Color"].default_value = (0, 0, 0, 1)
tc = N.new("ShaderNodeTexCoord"); sep = N.new("ShaderNodeSeparateXYZ"); mr = N.new("ShaderNodeMapRange")
mr.inputs["From Min"].default_value = -0.15; mr.inputs["From Max"].default_value = 0.9; mr.inputs["To Min"].default_value = 0.0; mr.inputs["To Max"].default_value = 0.09
bgr = N.new("ShaderNodeBackground"); bgr.inputs["Color"].default_value = (0.9, 0.93, 1, 1)
lp = N.new("ShaderNodeLightPath"); mix = N.new("ShaderNodeMixShader")
nt.links.new(tc.outputs["Generated"], sep.inputs[0]); nt.links.new(sep.outputs["Z"], mr.inputs["Value"]); nt.links.new(mr.outputs["Result"], bgr.inputs["Strength"])
nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs["Fac"]); nt.links.new(bgr.outputs[0], mix.inputs[1]); nt.links.new(bgc.outputs[0], mix.inputs[2])
nt.links.new(mix.outputs[0], N["World Output"].inputs["Surface"])
def light(name, loc, rot, size, energy, color=(1, 1, 1)):
    l = bpy.data.lights.new(name, "AREA"); l.shape = "RECTANGLE"; l.size, l.size_y = size; l.energy = energy; l.color = color
    o = bpy.data.objects.new(name, l); o.location = loc; o.rotation_euler = [math.radians(a) for a in rot]
    o.visible_camera = False; scn.collection.objects.link(o); return o
def spread(o, deg): o.data.spread = math.radians(deg); return o
spread(light("top", (0, 0.1, 1.5), (0, 0, 0), (2.2, 1.0), 34), 110)                               # soft overhead: broad top highlight
spread(light("rimL", (-1.9, 1.5, 0.5), (84, 0, -128), (0.4, 1.6), 5), 70)                       # gentle edge lights from behind
spread(light("rimR", (1.9, 1.5, 0.5), (84, 0, 128), (0.4, 1.6), 4, (0.85, 0.9, 1)), 70)
spread(light("sideL", (-2.4, -1.2, 0.5), (80, 0, -62), (0.8, 1.4), 7), 90)                      # soft side fill: shows the form
sheen = light("sheen", (0.9, -2.2, 1.5), (58, 0, 22), (2.2, 1.6), 22)                            # big soft box: a gradient in the lenses
sheen.data.energy = 10
spread(light("under", (0, -1.0, -1.4), (150, 0, 0), (2.0, 1.0), 5), 120)                              # faint fill from below: no floor to bounce light
cd = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cd); scn.collection.objects.link(cam); scn.camera = cam
aim = bpy.data.objects.new("aim", None); scn.collection.objects.link(aim)
t = cam.constraints.new("TRACK_TO"); t.target = aim; t.track_axis = "TRACK_NEGATIVE_Z"; t.up_axis = "UP_Y"
cd.dof.use_dof = True; cd.dof.focus_object = aim; cd.dof.aperture_fstop = 4.0; cd.sensor_width = 36
scn.render.engine = "CYCLES"; scn.cycles.device = "GPU"
try:
    p = bpy.context.preferences.addons["cycles"].preferences; p.compute_device_type = "METAL"; p.get_devices()
    for d in p.devices: d.use = True
except Exception as e: print("GPU:", e); scn.cycles.device = "CPU"
scn.cycles.samples = 96; scn.cycles.use_denoising = True
scn.view_settings.view_transform = "AgX"; scn.view_settings.look = "AgX - Medium High Contrast"
scn.render.resolution_x, scn.render.resolution_y = 1280, 720
bpy.ops.wm.save_as_mainfile(filepath=out + "/glasses_look.blend")
shots = {  # rig rotation (deg), camera position, aim, focal length, f-stop
    "look1_threequarter": ((9, -6, -40), (0.2, -4.3, -0.1), (0.2, 0.35, -0.01), 85, 5.6),
    "look2_front_low":    ((0, 0, 0),    (0, -3.6, 0.0), (0, 0, 0), 85, 5.6),
    "look3_closeup":      ((0, 0, -14),  (0.5, -1.25, 0.06), (0.26, 0, 0.03), 70, 4.0),
}
for name, (rot, loc, target, lens, fstop) in shots.items():
    rig.rotation_euler = [math.radians(a) for a in rot]; cam.location = loc; aim.location = target
    cd.lens = lens; cd.dof.aperture_fstop = fstop
    scn.render.filepath = f"{out}/{name}.png"; bpy.ops.render.render(write_still=True)
