"""Build the 60 s Second Look video.

Footage: team's iPhone camera clips (IMG_8789 webshop, IMG_8790 email).
Boxes, labels, verdicts and explanations: real Second Look server output on frames of those clips
(results.json). App UI overlay is recreated in HTML from the app's live-scan design.
Voice: Kokoro-82M (af_heart narrator, bf_emma app voice).
"""
import json, os, subprocess, html

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = "/Users/test/Documents/GitHub/junction/second-look/presentation/video"
P = lambda *a: os.path.join(HERE, *a)
SHOP = "/Users/test/Downloads/IMG_8789.MOV"
MAIL = "/Users/test/Downloads/IMG_8790.MOV"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
TEMPO = 1.08
W, H = 1920, 1080
os.makedirs(P("png"), exist_ok=True)
os.makedirs(P("seg"), exist_ok=True)
R = json.load(open(P("results.json")))


def sh(cmd):
    subprocess.run(cmd, check=True)


def dur(path):
    return float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                          "-of", "csv=p=0", path]).decode())


# ---------- voice ----------
LINES = {
    "a1": "Hold on. This looks like a scam.",
    "n1": "Scams don't wait in your spam folder. They're on a laptop, on paper, in a text. Right when you're about to pay.",
    "n2": "Second Look gives you a second opinion. Right then.",
    "n3": "Just look at it. Your phone reads the text, and when something matters, Gemini checks what you see.",
    "a2": "Hold on. This looks like a scam. It uses the name Ray-Ban, but this address is ray band, with a D. Not the official website. And the price is far below normal. Please don't pay this.",
    "n4": "It doesn't just look for scary words. It checks whether the address copies a real shop, and whether the prices make sense.",
    "a3": "Hmm, something's off here. Huge discounts, guaranteed profits or easy daily income are classic bait.",
    "n5": "Twenty-four kinds of scam signs, each explained. In about two seconds.",
    "n6": "Nothing is stored. Personal numbers are removed first. And it never calls anything safe.",
    "n7": "Second Look. A second opinion, before you pay.",
}
VD = {}
for k in LINES:
    src, dst = P("vo", k + ".wav"), P("vo", k + "_t.wav")
    sh(["ffmpeg", "-v", "error", "-y", "-i", src, "-af", f"atempo={TEMPO},apad=pad_dur=0.02", "-ar", "48000", dst])
    VD[k] = dur(dst)

# ---------- timeline (seconds) ----------
G = 0.18
t = 0.0
S = {}  # segment start/end
CUES = []  # (start, line)
def cue(k, at):
    CUES.append((at, k)); return at + VD[k]

S["cold"] = [0.0]; e = cue("a1", 0.45); S["cold"].append(e + 0.25)
s = S["cold"][1]; S["problem"] = [s]; e = cue("n1", s + 0.15); S["problem"].append(e + G)
s = S["problem"][1]; S["logo"] = [s]; e = cue("n2", s + 0.2); S["logo"].append(e + G)
s = S["logo"][1]; S["shopplay"] = [s]; e = cue("n3", s + 0.1); S["shopplay"].append(max(e + G, s + 5.0))
s = S["shopplay"][1]; S["shopfreeze"] = [s]; e = cue("a2", s + 0.7); S["shopfreeze"].append(e + 0.3)
s = S["shopfreeze"][1]; S["compare"] = [s]; e = cue("n4", s + 0.15); S["compare"].append(e + G)
s = S["compare"][1]; S["mailplay"] = [s, s + 2.2]
s = S["mailplay"][1]; S["mailfreeze"] = [s]; e = cue("a3", s + 0.35); S["mailfreeze"].append(e + 0.2)
s = S["mailfreeze"][1]; S["how"] = [s]; e = cue("n5", s + 0.15); S["how"].append(e + G)
s = S["how"][1]; S["trust"] = [s]; e = cue("n6", s + 0.15); S["trust"].append(e + G)
s = S["trust"][1]; S["end"] = [s]; e = cue("n7", s + 0.2); S["end"].append(e + 0.6)
TOTAL = S["end"][1]
print("total", round(TOTAL, 2), {k: [round(x, 2) for x in v] for k, v in S.items()})

# ---------- HTML rendering ----------
FONT = "-apple-system, 'SF Pro Display', 'Helvetica Neue', sans-serif"
AURA = """background:
  radial-gradient(circle at 30% 35%, rgba(31,59,224,.95) 0%, rgba(31,59,224,0) 55%),
  radial-gradient(circle at 75% 70%, rgba(44,195,255,.85) 0%, rgba(44,195,255,0) 55%),
  radial-gradient(circle at 80% 20%, rgba(124,140,255,.9) 0%, rgba(124,140,255,0) 50%), #1a2a8a;"""
BASE = f"""<!DOCTYPE html><html><head><meta charset="utf-8"><style>
html,body{{margin:0;width:{W}px;height:{H}px;overflow:hidden;background:transparent;font-family:{FONT};color:#fff}}
.abs{{position:absolute}}
.chip{{position:absolute;left:64px;top:52px;display:flex;align-items:center;gap:14px;padding:16px 26px;border-radius:40px;
 background:rgba(30,30,30,.55);backdrop-filter:blur(10px);font-size:30px;font-weight:600}}
.dot{{width:16px;height:16px;border-radius:50%}}
.box{{position:absolute;border:5px solid #FF3B30;border-radius:10px;background:rgba(255,59,48,.16)}}
.lab{{position:absolute;background:#FF3B30;color:#fff;font-weight:700;font-size:28px;padding:6px 14px;border-radius:8px;white-space:nowrap}}
.region{{position:absolute;border:4px dashed #FFD60A;border-radius:22px}}
.card{{position:absolute;left:330px;right:330px;bottom:150px;border-radius:30px;padding:30px 38px}}
.card h1{{margin:0 0 10px;font-size:52px;font-weight:800}}
.card p{{margin:0;font-size:31px;line-height:1.3}}
.tag{{position:absolute;right:48px;top:58px;font-size:22px;padding:10px 18px;border-radius:12px;background:rgba(0,0,0,.45);color:#eee}}
.cap{{position:absolute;left:0;right:0;bottom:46px;text-align:center}}
.cap span{{display:inline-block;max-width:1500px;font-size:40px;font-weight:600;line-height:1.25;padding:12px 26px;border-radius:14px;
 background:rgba(0,0,0,.62)}}
.cap span.app{{background:rgba(20,20,20,.75);border:2px solid rgba(255,255,255,.25)}}
.cap b{{color:#9fb0ff;font-weight:700}}
</style></head><body>"""


def render(name, body, full=False):
    path = P("png", name + ".html")
    open(path, "w").write(BASE + body + "</body></html>")
    out = P("png", name + ".png")
    sh([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--window-size={W},{H}",
        "--default-background-color=00000000", f"--screenshot={out}", "file://" + path])
    return out


def bx(b):  # box_2d [ymin,xmin,ymax,xmax] 0-1000 -> px
    y0, x0, y1, x1 = b
    return x0 * W / 1000, y0 * H / 1000, (x1 - x0) * W / 1000, (y1 - y0) * H / 1000


def boxes_html(res, pad=10):
    out, seen = "", set()
    for b in res.get("boxes") or []:
        x, y, w, h = bx(b["box_2d"])
        x, y, w, h = x - pad, y - pad, w + 2 * pad, h + 2 * pad
        out += f'<div class="box" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px"></div>'
        if b["label"] not in seen:
            seen.add(b["label"])
            ly = y - 50 if y > 70 else y + h + 8
            out += f'<div class="lab" style="left:{x}px;top:{ly}px">{html.escape(b["label"])}</div>'
    return out


def chip(text, color):
    return f'<div class="chip"><div class="dot" style="background:{color}"></div>{text}</div>'


TAG = '<div class="tag">Real phone footage · real Second Look verdict · app overlay recreated</div>'


def card(res, color, word, style=""):
    sig = sorted([s for s in res["signals"] if s["weight"] > 0], key=lambda s: -s["weight"])
    why = sig[0]["explanation"] if sig else res.get("reason", "")
    summary = (why + " " if why else "") + "Don't pay. Check with the official number first."
    return (f'<div class="card" style="background:{color};{style}"><h1>{word}</h1>'
            f'<p>{html.escape(summary)}</p></div>')


shop, mail = R["shop6"], R["mail"]
SHOP_REGION = '<div class="region" style="left:140px;top:100px;width:1440px;height:870px"></div>'
MAIL_REGION = '<div class="region" style="left:290px;top:95px;width:1200px;height:830px"></div>'
render("shop_watch", chip("watching", "#34C759") + SHOP_REGION + TAG)
render("shop_check", chip("checking", "#FFD60A") + SHOP_REGION + TAG)
render("shop_boxes", chip("checking", "#FFD60A") + SHOP_REGION + boxes_html(shop) + TAG)
render("shop_card", chip("watching", "#34C759") + boxes_html(shop) + card(shop, "rgba(220,38,38,.92)", "likely scam", "left:150px;right:auto;width:860px;bottom:auto;top:380px") + TAG)
render("mail_watch", chip("checking", "#FFD60A") + MAIL_REGION + TAG)
render("mail_card", chip("watching", "#34C759") + boxes_html(mail) + card(mail, "rgba(234,120,20,.93)", "be careful") + TAG)

ICON = "file://" + P("AppIcon-1024.png")
render("t_problem", f'''<div class="abs" style="inset:0;background:linear-gradient(90deg,rgba(8,12,40,.88) 0%,rgba(8,12,40,.7) 45%,rgba(8,12,40,0) 75%)"></div><div class="abs" style="left:110px;top:300px;font-size:96px;font-weight:800;line-height:1.05;
  text-shadow:0 4px 30px rgba(0,0,0,.5)">Scams don't wait in<br>your spam folder.</div>''')
render("c_logo", f'''<div class="abs" style="inset:0;{AURA}"></div>
 <div class="abs" style="left:0;right:0;top:250px;text-align:center">
 <img src="{ICON}" style="width:300px;height:300px;border-radius:68px;box-shadow:0 20px 60px rgba(0,0,0,.35)">
 <div style="font-size:110px;font-weight:800;margin-top:40px;letter-spacing:-2px">Second Look</div>
 <div style="font-size:40px;opacity:.9;margin-top:8px">a second opinion, right when you're about to pay</div></div>''')
render("c_compare", f'''<div class="abs" style="inset:0;background:rgba(10,14,40,.72)"></div>
 <div class="abs" style="left:0;right:0;top:170px;text-align:center;font-size:44px;opacity:.85">Not scary words. Facts that don't add up.</div>
 <div class="abs" style="left:200px;top:300px;width:700px;padding:44px;border-radius:30px;background:rgba(52,199,89,.18);border:3px solid #34C759">
   <div style="font-size:32px;opacity:.8">the real shop</div><div style="font-size:76px;font-weight:800">ray-ban.com</div></div>
 <div class="abs" style="left:1020px;top:300px;width:700px;padding:44px;border-radius:30px;background:rgba(255,59,48,.2);border:3px solid #FF3B30">
   <div style="font-size:32px;opacity:.8">the page you're on</div><div style="font-size:76px;font-weight:800">ray-ban<span style="color:#FF6B60;text-decoration:underline">d</span>.com</div></div>
 <div class="abs" style="left:200px;right:200px;top:620px;padding:40px;border-radius:30px;background:rgba(255,255,255,.1);text-align:center">
   <div style="font-size:60px;font-weight:800">Ray-Ban sunglasses for <span style="color:#FF6B60">€9.90</span></div>
   <div style="font-size:34px;opacity:.85;margin-top:10px">Price far below normal: a common fake-shop sign</div></div>''')
step = lambda n, t, s: f'''<div style="flex:1;padding:44px 36px;border-radius:30px;background:rgba(255,255,255,.14);border:2px solid rgba(255,255,255,.3)">
 <div style="font-size:30px;opacity:.75">{n}</div><div style="font-size:50px;font-weight:800;margin:10px 0">{t}</div><div style="font-size:30px;opacity:.9">{s}</div></div>'''
render("c_how", f'''<div class="abs" style="inset:0;{AURA}"></div>
 <div class="abs" style="left:120px;right:120px;top:200px;display:flex;gap:40px;align-items:stretch">
 {step("1", "Your phone reads", "the text on the device, twice a second")}
 {step("2", "Only if it matters", "one frame is checked by Gemini, in about 2 s")}
 {step("3", "You hear why", "in one short, plain sentence")}</div>
 <div class="abs" style="left:0;right:0;top:720px;text-align:center;font-size:54px;font-weight:800">24 kinds of scam signs, each explained</div>''')
render("c_trust", f'''<div class="abs" style="inset:0;{AURA}"></div>
 <div class="abs" style="left:240px;top:230px;font-size:76px;font-weight:800;line-height:1.55">
 <div>✓ Nothing is stored</div><div>✓ Personal numbers removed first</div><div>✓ Never says "safe"</div></div>''')
render("c_end", f'''<div class="abs" style="inset:0;{AURA}"></div>
 <div class="abs" style="left:0;right:0;top:220px;text-align:center">
 <img src="{ICON}" style="width:240px;height:240px;border-radius:54px;box-shadow:0 20px 60px rgba(0,0,0,.35)">
 <div style="font-size:110px;font-weight:800;margin-top:36px;letter-spacing:-2px">Second Look</div>
 <div style="font-size:46px;margin-top:6px">A second opinion before you pay.</div>
 <div style="font-size:28px;opacity:.85;margin-top:60px">Built for Meta AI glasses · shown here on iPhone · Junction 2026</div></div>''')

# captions: one per sentence, timed by character share
CAPS = []
for at, k in CUES:
    text = LINES[k]
    parts, buf = [], ""
    for ch in text:
        buf += ch
        if ch in ".!?" and len(buf.strip()) > 2:
            parts.append(buf.strip()); buf = ""
    if buf.strip(): parts.append(buf.strip())
    total_chars = sum(len(p) for p in parts)
    tt = at
    for i, p in enumerate(parts):
        d = VD[k] * len(p) / total_chars
        name = f"cap_{k}_{i}"
        cls = "app" if k.startswith("a") else ""
        who = "<b>Second Look: </b>" if k.startswith("a") else ""
        p_disp = p.replace("ray band, with a D", "ray-ban<b>d</b>")
        render(name, f'<div class="cap"><span class="{cls}">{who}{html.escape(p_disp).replace("&lt;b&gt;", "<b>").replace("&lt;/b&gt;", "</b>")}</span></div>')
        CAPS.append((tt, tt + d, P("png", name + ".png")))
        tt += d

# ---------- video segments ----------
def seg(name, src_args, overlays, length, zoom=None):
    """src_args: ffmpeg input args for the background (length seconds). overlays: [(png, t0, t1, fade)]"""
    cmd = ["ffmpeg", "-v", "error", "-y"] + src_args
    for png, *_ in overlays:
        cmd += ["-loop", "1", "-t", f"{length:.3f}", "-i", png]
    f = f"[0:v]scale={W}:{H},setsar=1,fps=30"
    if zoom:
        f += f",scale={int(W*1.12)}:-1,zoompan=z='min(1+{zoom}*on/{int(length*30)},1+{zoom})':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s={W}x{H}:fps=30"
    f += "[v0]"
    last = "v0"
    for i, (png, t0, t1, fade) in enumerate(overlays, start=1):
        f += (f";[{i}:v]format=rgba,fade=t=in:st={t0:.3f}:d={fade}:alpha=1,"
              f"fade=t=out:st={max(t0, t1-0.2):.3f}:d=0.2:alpha=1[o{i}];"
              f"[{last}][o{i}]overlay=0:0:enable='between(t,{t0:.3f},{t1:.3f})'[v{i}]")
        last = f"v{i}"
    out = P("seg", name + ".mp4")
    cmd += ["-filter_complex", f, "-map", f"[{last}]", "-t", f"{length:.3f}", "-r", "30",
            "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-an", out]
    sh(cmd)
    return out


def still(img, length):
    return ["-loop", "1", "-t", f"{length:.3f}", "-i", img]


def clip(src, ss, length):
    return ["-ss", f"{ss:.3f}", "-t", f"{length:.3f}", "-i", src]


def L(k): return S[k][1] - S[k][0]
def rel(k, x): return x - S[k][0]
png = lambda n: P("png", n + ".png")

segs = []
segs.append(seg("cold", still(P("shop6.jpg"), L("cold")),
                [(png("shop_boxes"), 0.2, L("cold"), 0.15)], L("cold"), zoom=0.06))
half = L("problem") / 2
segs.append(seg("problem", ["-ss", "0.0", "-t", f"{half:.3f}", "-i", MAIL, "-ss", "0.0", "-t", f"{half:.3f}", "-i", SHOP], [], 0) if False else None)
# problem: two wide clips back to back, title on top
p1 = seg("problem_a", clip(MAIL, 0.0, half), [(png("t_problem"), 0.3, half, 0.4)], half)
p2 = seg("problem_b", clip(SHOP, 0.0, L("problem") - half), [(png("t_problem"), 0.0, L("problem") - half, 0.01)], L("problem") - half)
segs = [segs[0], p1, p2]
segs.append(seg("logo", still(png("c_logo"), L("logo")), [], L("logo"), zoom=0.04))
shop_play_len = L("shopplay")
segs.append(seg("shopplay", clip(SHOP, max(0.0, 6.0 - shop_play_len), shop_play_len),
                [(png("shop_watch"), 0.8, shop_play_len, 0.3)], shop_play_len))
fz = L("shopfreeze")
segs.append(seg("shopfreeze", still(P("shop6.jpg"), fz),
                [(png("shop_check"), 0.0, 0.75, 0.01), (png("shop_boxes"), 0.75, 1.3, 0.15),
                 (png("shop_card"), 1.3, fz, 0.25)], fz, zoom=0.03))
segs.append(seg("compare", ["-loop", "1", "-t", f"{L('compare'):.3f}", "-i", P("shop6.jpg")],
                [(png("c_compare"), 0.0, L("compare"), 0.3)], L("compare"), zoom=0.05))
segs.append(seg("mailplay", clip(MAIL, 1.8, L("mailplay")), [(png("mail_watch"), 0.6, L("mailplay"), 0.3)], L("mailplay")))
mz = L("mailfreeze")
segs.append(seg("mailfreeze", still(P("mail.jpg"), mz),
                [(png("mail_watch"), 0.0, 0.3, 0.01), (png("mail_card"), 0.3, mz, 0.25)], mz, zoom=0.03))
for k, n in [("how", "c_how"), ("trust", "c_trust"), ("end", "c_end")]:
    segs.append(seg(k, still(png(n), L(k)), [], L(k), zoom=0.03))

# concat video
lst = P("seg", "list.txt")
open(lst, "w").write("".join(f"file '{s}'\n" for s in segs))
base = P("seg", "base.mp4")
sh(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", base])

# captions over the whole video
cmd = ["ffmpeg", "-v", "error", "-y", "-i", base]
for _, _, pth in CAPS:
    cmd += ["-loop", "1", "-t", f"{TOTAL:.3f}", "-i", pth]
f, last = "", "0:v"
for i, (t0, t1, _) in enumerate(CAPS, start=1):
    f += f"[{last}][{i}:v]overlay=0:0:enable='between(t,{t0:.3f},{t1:.3f})'[c{i}];"
    last = f"c{i}"
capped = P("seg", "captioned.mp4")
cmd += ["-filter_complex", f.rstrip(";"), "-map", f"[{last}]", "-c:v", "libx264", "-crf", "18", "-preset", "medium",
        "-pix_fmt", "yuv420p", "-t", f"{TOTAL:.3f}", capped]
sh(cmd)

# audio: voice lines at cue times + a soft two-tone chime when red boxes appear
chime = P("seg", "chime.wav")
sh(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "sine=f=880:d=0.12", "-f", "lavfi", "-i", "sine=f=1318:d=0.22",
    "-filter_complex", "[0][1]concat=n=2:v=0:a=1,afade=t=out:st=0.2:d=0.14,volume=0.25,aresample=48000", chime])
ain = ["-i", capped]
mix, n = "", 0
for at, k in CUES:
    n += 1; ain += ["-i", P("vo", k + "_t.wav")]
    mix += f"[{n}:a]adelay={int(at*1000)}|{int(at*1000)},volume=1.0[a{n}];"
for at in [0.2, S["shopfreeze"][0] + 0.75, S["mailfreeze"][0] + 0.3]:
    n += 1; ain += ["-i", chime]
    mix += f"[{n}:a]adelay={int(at*1000)}|{int(at*1000)}[a{n}];"
mix += "".join(f"[a{i}]" for i in range(1, n + 1)) + f"amix=inputs={n}:normalize=0,loudnorm=I=-16:TP=-1.5,apad[aout]"
final = os.path.join(OUT, "second-look-60s.mp4")
sh(["ffmpeg", "-v", "error", "-y"] + ain + ["-filter_complex", mix, "-map", "0:v", "-map", "[aout]",
    "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-t", f"{TOTAL:.3f}", "-movflags", "+faststart", final])
print("wrote", final, round(dur(final), 2), "s")
