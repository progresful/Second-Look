"""Second Look hero: the scroll animation, rendered from the look scene (glasses_look.py).
Frames 1-30 play on load (the glasses drift in, turned); 30-150 are scrubbed by scroll:
spin to face the camera (30-85), then push through the right lens until it fills the frame (150).
Two passes per frame: f_####.png (picture) and m_####.png (alpha = the visible lens area), so the
page can show the simulator scene through the lenses.
Run:  Blender -b -P glasses_scroll.py -- <glasses.glb> <out_dir> [test]"""
import bpy, sys, os, math
argv = sys.argv[sys.argv.index("--") + 1:]; OUT = argv[1]; TEST = len(argv) > 2 and argv[2] == "test"
look = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "glasses_look.py")).read()
exec(look[:look.index("bpy.ops.wm.save_as_mainfile")])          # build the scene; skip the stills

for o in [o for o in bpy.data.objects if o.type == "MESH" and o.modifiers]:   # bake the rounding once
    bpy.ops.object.select_all(action="DESELECT"); o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.object.convert(target="MESH")
lens = bpy.data.objects["lens"]
xs = [v.co.x for v in lens.data.vertices if v.co.x > 0.02]; zs = [v.co.z for v in lens.data.vertices if v.co.x > 0.02]
LX, LZ = (min(xs) + max(xs)) / 2, (min(zs) + max(zs)) / 2; print("LENS", LX, LZ)

N, INTRO, FRONT = 150, 30, 85
scn.frame_start, scn.frame_end = 1, N
D = 1 / (0.5 * 2 * math.tan(math.atan(18 / 85)))               # glasses fill half the frame width at 85 mm
END = 0.42                                                       # close enough that the lens fills the frame
def key(ob, attr, f, v): setattr(ob, attr, v); ob.keyframe_insert(attr, frame=f)
R = math.radians
key(rig, "rotation_euler", 1, (R(12), R(-9), R(-62))); key(rig, "rotation_euler", INTRO, (R(9), R(-6), R(-40))); key(rig, "rotation_euler", FRONT, (0, 0, 0))
key(cam, "location", 1, (0, -D * 1.12, -0.16)); key(cam, "location", INTRO, (0, -D, -0.1)); key(cam, "location", FRONT, (0, -D, 0.0)); key(cam, "location", N, (LX, -END, LZ))
key(aim, "location", 1, (0.22, 0.35, 0)); key(aim, "location", INTRO, (0.2, 0.35, 0)); key(aim, "location", FRONT, (0, 0, 0)); key(aim, "location", N, (LX, 1.0, LZ))
cd.lens = 85; cd.dof.focus_object = None
key(cd.dof, "focus_distance", 1, D * 1.12); key(cd.dof, "focus_distance", FRONT, D); key(cd.dof, "focus_distance", N, END)
key(cd.dof, "aperture_fstop", FRONT, 5.6); key(cd.dof, "aperture_fstop", N, 16.0)

r = scn.render; r.image_settings.file_format = "PNG"
r.resolution_x, r.resolution_y = (800, 450) if TEST else (1600, 900)
scn.cycles.samples = 32 if TEST else 72
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "glasses_scroll.blend"))
frames = (1, INTRO, 58, FRONT, 118, 138, N) if TEST else range(1, N + 1)

def render(prefix):
    for f in frames:
        path = os.path.join(OUT, f"{prefix}_{f:04d}.png")
        if os.path.exists(path): continue                        # resumable
        scn.frame_set(f); r.filepath = path; bpy.ops.render.render(write_still=True)
r.image_settings.color_mode = "RGB"; r.film_transparent = False; scn.view_settings.exposure = 0.45
render("f")
# lens mask: lenses glow, everything else is a holdout, so alpha = lens area not hidden by the frame
hold = bpy.data.materials.new("hold"); hold.use_nodes = True; nt = hold.node_tree; nt.nodes.clear()
ho = nt.nodes.new("ShaderNodeHoldout"); mo = nt.nodes.new("ShaderNodeOutputMaterial"); nt.links.new(ho.outputs[0], mo.inputs["Surface"])
glow = bpy.data.materials.new("glow"); glow.use_nodes = True; nt = glow.node_tree; nt.nodes.clear()
em = nt.nodes.new("ShaderNodeEmission"); mo = nt.nodes.new("ShaderNodeOutputMaterial"); nt.links.new(em.outputs[0], mo.inputs["Surface"])
for o in bpy.data.objects:
    if o.type == "MESH": o.data.materials.clear(); o.data.materials.append(glow if o.name.startswith("lens") else hold)
r.film_transparent = True; r.image_settings.color_mode = "RGBA"; scn.cycles.samples = 12; scn.cycles.use_denoising = False
scn.view_settings.view_transform = "Standard"; scn.view_settings.look = "None"; scn.view_settings.exposure = 0
render("m")
print("done", OUT)
