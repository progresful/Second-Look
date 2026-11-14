"""Second Look, 60 s video v2: dark, fast, app shown, sourced stats.

Sources of every element:
- Camera footage: team's iPhone clips IMG_8789 (webshop), IMG_8790 (email).
- App screens: iOS simulator screen recordings of the real app (r1: options + demo check, r2: call mode
  with a scripted call fed into the real call check).
- Boxes / verdicts on footage: real server output (results.json). Overlay drawn to match the app.
- Stats: GASA Global State of Scams 2025; FBI IC3 2025 report (see LEDGER.md).
- Voice: Kokoro-82M. Music: Lyria 3 Pro (Gemini API).
"""
import json, os, subprocess, html

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(os.path.dirname(HERE), "app")
OUT = "/Users/test/Documents/GitHub/junction/second-look/presentation/video"
P = lambda *a: os.path.join(HERE, *a)
SHOP, MAIL = "/Users/test/Downloads/IMG_8789.MOV", "/Users/test/Downloads/IMG_8790.MOV"
R1, R2 = os.path.join(APP, "r1.mp4"), os.path.join(APP, "r2.mp4")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H, FPS = 1920, 1080, 30
TEMPO = 1.05
for d in ("png2", "seg2"):
    os.makedirs(P(d), exist_ok=True)
R = json.load(open(P("results.json")))


def sh(cmd):
    subprocess.run(cmd, check=True)


def dur(path):
    return float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                          "-of", "csv=p=0", path]).decode())


LINES = dict((k, t) for k, _, _, t in json.load(open(os.path.join(os.path.dirname(HERE), "kokoro", "lines_v2.json"))))
VD = {}
for k in LINES:
    dst = P("vo2", k + "_t.wav")
    sh(["ffmpeg", "-v", "error", "-y", "-i", P("vo2", k + ".wav"), "-af", f"atempo={TEMPO}", "-ar", "48000", dst])
    VD[k] = dur(dst)

# ---------- timeline ----------
CUES, S = [], {}
t = 0.0
def scene(name, keys, pre=0.1, gap=0.12, post=0.15, minlen=0.0):
    global t
    start = t; at = start + pre
    for k in keys:
        CUES.append((at, k)); at += VD[k] + gap
    end = max(at - gap + post, start + minlen)
    S[name] = (start, end); t = end

scene("cold", ["a1"], pre=0.35, post=0.2)
scene("s57", ["s1"]); scene("s1in4", ["s2"]); scene("s20b", ["s3"])
scene("where", ["s4"], minlen=4.9)
scene("meet", ["m1"], pre=0.15, post=0.35)
scene("shop", ["w1", "a2"], gap=0.25)
scene("call", ["c1", "a3"], gap=0.2)
scene("opts", ["o1"])
scene("benefits", ["b1"])
scene("tech", ["t1"])
scene("end", ["e1"], pre=0.2, post=0.7)
TOTAL = t
print("total", round(TOTAL, 2))
for k, v in S.items(): print(f"  {k:9s} {v[0]:6.2f} {v[1]:6.2f}")

# ---------- render ----------
FONT = "-apple-system, 'SF Pro Display', 'Helvetica Neue', sans-serif"
BASE = f"""<!DOCTYPE html><html><head><meta charset="utf-8"><style>
html,body{{margin:0;width:{W}px;height:{H}px;overflow:hidden;background:transparent;font-family:{FONT};color:#fff}}
.abs{{position:absolute}} .red{{color:#FF453A}} .yel{{color:#FFD60A}} .dim{{opacity:.62}}
.src{{position:absolute;left:120px;top:880px;font-size:22px;opacity:.55;letter-spacing:.2px}}
.kicker{{font-size:30px;font-weight:700;letter-spacing:6px;text-transform:uppercase;opacity:.6}}
.cap{{position:absolute;left:0;right:0;bottom:40px;text-align:center}}
.cap span{{display:inline-block;max-width:1400px;font-size:34px;font-weight:600;line-height:1.25;padding:10px 22px;border-radius:12px;background:rgba(0,0,0,.6)}}
.cap b{{color:#FFD60A}}
.tag{{position:absolute;font-size:21px;padding:9px 16px;border-radius:10px;background:rgba(255,255,255,.1);color:#ddd}}
</style></head><body>"""
DARK = "background:radial-gradient(ellipse at 50% 40%, #161a2a 0%, #0a0b10 60%, #050507 100%)"


def render(name, body, bg=None):
    path = P("png2", name + ".html")
    pre = f'<div class="abs" style="inset:0;{bg}"></div>' if bg else ""
    open(path, "w").write(BASE + pre + body + "</body></html>")
    out = P("png2", name + ".png")
    sh([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--window-size={W},{H}",
        "--default-background-color=00000000", f"--screenshot={out}", "file://" + path],)
    return out


ICON = "file://" + P("AppIcon-1024.png")
render("bg", "", DARK)
render("s57", '''<div class="abs" style="left:120px;top:250px"><div class="kicker">Last year</div>
 <div style="font-size:300px;font-weight:900;line-height:1;letter-spacing:-10px" class="red">57%</div>
 <div style="font-size:64px;font-weight:700;margin-top:10px">of adults worldwide ran into a scam</div></div>
 <div class="src">Global Anti-Scam Alliance, Global State of Scams 2025 · 46,000 adults, 42 markets</div>''')
people = "".join(f'<div style="width:150px;height:300px;border-radius:75px 75px 30px 30px;background:{"#FF453A" if i == 0 else "rgba(255,255,255,.18)"}"></div>' for i in range(4))
render("s1in4", f'''<div class="abs" style="left:120px;top:270px"><div class="kicker">and</div>
 <div style="font-size:250px;font-weight:900;line-height:1;letter-spacing:-6px">1 in 4</div>
 <div style="font-size:64px;font-weight:700;margin-top:14px">lost money <span class="dim">(23%)</span></div></div>
 <div class="abs" style="right:150px;top:330px;display:flex;gap:34px">{people}</div>
 <div class="src">Global Anti-Scam Alliance, Global State of Scams 2025</div>''')
render("s20b", '''<div class="abs" style="left:120px;top:250px"><div class="kicker">In the US alone</div>
 <div style="font-size:290px;font-weight:900;line-height:1;letter-spacing:-8px" class="red">$20.9B</div>
 <div style="font-size:64px;font-weight:700;margin-top:10px">reported lost to online crime in one year</div></div>
 <div class="src">FBI Internet Crime Complaint Center, 2025 report · reported losses only</div>''')
for i, w in enumerate(["at checkout.", "in the mail.", "on the phone."]):
    render(f"where{i}", f'''<div class="abs" style="left:0;right:0;bottom:0;height:420px;background:linear-gradient(0deg,rgba(0,0,0,.85),rgba(0,0,0,0))"></div>
     <div class="abs" style="left:120px;bottom:120px;font-size:120px;font-weight:900;letter-spacing:-3px">
     <span class="dim" style="font-size:54px;font-weight:700;letter-spacing:0;display:block">Scams are</span>{w}</div>''')
render("meet", f'''<div class="abs" style="left:0;right:0;top:250px;text-align:center">
 <img src="{ICON}" style="width:260px;height:260px;border-radius:60px;box-shadow:0 30px 90px rgba(80,120,255,.45)">
 <div style="font-size:120px;font-weight:900;margin-top:40px;letter-spacing:-3px">Second Look</div>
 <div style="font-size:40px;margin-top:6px" class="dim">A second opinion, right when you're about to pay.</div></div>''', DARK)


def side(name, kicker, title, lines, tag):
    li = "".join(f'<div style="font-size:44px;font-weight:600;margin-top:18px">{x}</div>' for x in lines)
    render(name, f'''<div class="abs" style="left:900px;top:250px;width:900px"><div class="kicker">{kicker}</div>
     <div style="font-size:96px;font-weight:900;letter-spacing:-2px;line-height:1.02;margin-top:14px">{title}</div>{li}</div>
     <div class="tag" style="left:900px;bottom:150px">{tag}</div>''')


side("t_call", "Call check", "Listens.<br>Warns <span class='red'>mid-call.</span>",
     ["Live caption of what's said", "Flags codes, “safe accounts”, remote access"], "Real app · iOS simulator · scripted call audio")
side("t_opts", "You choose", "What to <span class='yel'>guard.</span>",
     ["Letters · messages · websites", "Webshops · QR codes · calls", "On request — or always on"], "Real app · iOS simulator · sped up")
tile = lambda ic, t, s: f'''<div style="flex:1;padding:50px 40px;border-radius:34px;background:rgba(255,255,255,.07);border:1px solid rgba(255,255,255,.14)">
 <div style="width:90px;height:10px;border-radius:5px;background:{ic}"></div><div style="font-size:58px;font-weight:800;margin-top:16px">{t}</div><div style="font-size:32px;margin-top:10px" class="dim">{s}</div></div>'''
render("benefits", f'''<div class="abs" style="left:120px;right:120px;top:300px;display:flex;gap:40px">
 {tile("#5E8BFF", "Hands-free", "Look, hear the answer. Built for Meta AI glasses.")}
 {tile("#FFD60A", "Explains why", "One plain sentence, not just a red flag.")}
 {tile("#34C759", "Nothing stored", "Personal numbers removed before anything leaves the phone.")}</div>''', DARK)
tech = [("24", "kinds of scam signs, each explained", ""),
        ("<span class='red'>€9.90</span> Ray-Bans", "price far below normal", "Prices that don't add up"),
        ("ray-ban<span class='red'>d</span>.com", "is not ray-ban.com", "Look-alike addresses"),
        ("~2 s", "per live check", "Gemini judges only when it matters")]
for i, (big, small, k) in enumerate(tech):
    render(f"tech{i}", f'''<div class="abs" style="left:120px;top:330px"><div class="kicker">{k}</div>
     <div style="font-size:{230 if len(big) < 6 else 150}px;font-weight:900;letter-spacing:-5px;line-height:1.05">{big}</div>
     <div style="font-size:60px;font-weight:700;margin-top:10px" class="dim">{small}</div></div>''', DARK)
render("end", f'''<div class="abs" style="left:0;right:0;top:230px;text-align:center">
 <img src="{ICON}" style="width:220px;height:220px;border-radius:50px;box-shadow:0 30px 90px rgba(80,120,255,.45)">
 <div style="font-size:120px;font-weight:900;margin-top:36px;letter-spacing:-3px">Second Look</div>
 <div style="font-size:50px;margin-top:4px;font-weight:600">A second opinion before you pay.</div>
 <div style="font-size:26px;margin-top:70px" class="dim">Built for Meta AI glasses · demo on iPhone · Junction 2026</div></div>''', DARK)
# phone mask (rounded screen) for app recordings
PH_H = 960; PH_W = round(1206 * PH_H / 2622)
open(P("png2", "mask.html"), "w").write(f'<html><body style="margin:0;background:#000"><div style="width:{PH_W}px;height:{PH_H}px;border-radius:64px;background:#fff"></div></body></html>')
sh([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--window-size={PH_W},{PH_H}",
    f"--screenshot={P('png2', 'mask.png')}", "file://" + P("png2", "mask.html")])

# captions (one per sentence)
CAPS = []
for at, k in CUES:
    parts, buf = [], ""
    for ch in LINES[k]:
        buf += ch
        if ch in ".!?" and len(buf.strip()) > 2: parts.append(buf.strip()); buf = ""
    if buf.strip(): parts.append(buf.strip())
    tot = sum(len(p) for p in parts); tt = at
    for i, p in enumerate(parts):
        d = VD[k] * len(p) / tot
        who = "<b>Second Look: </b>" if k.startswith("a") else ""
        txt = html.escape(p).replace("ray band, with a D", "ray-ban<b>d</b>")
        name = f"cap_{k}_{i}"
        render(name, f'<div class="cap"><span>{who}{txt}</span></div>')
        CAPS.append((tt, tt + d, P("png2", name + ".png"))); tt += d


# ---------- segments ----------
def enc(name, args, fc, length):
    out = P("seg2", name + ".mp4")
    sh(["ffmpeg", "-v", "error", "-y"] + args + ["-filter_complex", fc, "-map", "[out]", "-t", f"{length:.3f}",
        "-r", str(FPS), "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-an", out])
    return out


def slide(idx, base, t0, t1, dx=90, label="o"):
    """Overlay input idx on base with a slide-from-right + fade, between t0 and t1."""
    return (f"[{idx}:v]format=rgba,fade=t=in:st={t0:.3f}:d=0.3:alpha=1,fade=t=out:st={t1-0.18:.3f}:d=0.18:alpha=1[{label}];"
            f"[{base}][{label}]overlay=x='{dx}*pow(max(0,1-(t-{t0:.3f})/0.45),3)':y=0:enable='between(t,{t0:.3f},{t1:.3f})'")


def still_scene(name, png, length, zoom=0.04):
    fc = (f"[0:v]scale={int(W*1.1)}:-1,zoompan=z='1+{zoom}*on/{int(length*FPS)}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'"
          f":d=1:s={W}x{H}:fps={FPS},format=yuv420p[out]")
    return enc(name, ["-framerate", "30", "-loop", "1", "-t", f"{length:.3f}", "-i", png], fc, length)


def card_scene(name, png, length):  # dark bg + card slides in
    fc = f"[0:v]scale={W}:{H},fps={FPS}[b];" + slide(1, "b", 0.0, length + 1, dx=120) + ",format=yuv420p[out]"
    return enc(name, ["-framerate", "30", "-loop", "1", "-t", f"{length:.3f}", "-i", P("png2", "bg.png"),
                      "-framerate", "30", "-loop", "1", "-t", f"{length:.3f}", "-i", png], fc, length)


def phone_scene(name, rec, ss, src_len, length, text_png):
    speed = src_len / length
    fc = (f"[0:v]scale={W}:{H},fps={FPS}[b];"
          f"[1:v]trim=start={ss}:duration={src_len},setpts=(PTS-STARTPTS)/{speed:.4f},fps={FPS},scale={PH_W}:{PH_H},format=rgba[ph];"
          f"[2:v]scale={PH_W}:{PH_H},format=gray[m];[ph][m]alphamerge[phm];"
          f"[b][phm]overlay=x='300-60*pow(max(0,1-t/0.5),3)':y={(H-PH_H)//2}[b2];"
          + slide(3, "b2", 0.15, length + 1) + ",format=yuv420p[out]")
    return enc(name, ["-framerate", "30", "-loop", "1", "-t", f"{length:.3f}", "-i", P("png2", "bg.png"), "-i", rec,
                      "-framerate", "30", "-loop", "1", "-t", f"{length:.3f}", "-i", P("png2", "mask.png"),
                      "-framerate", "30", "-loop", "1", "-t", f"{length:.3f}", "-i", text_png], fc, length)


L = lambda k: S[k][1] - S[k][0]
png = lambda n, d="png2": P(d, n + ".png")
segs = []
# 1 cold open: frozen webshop frame, real verdict boxes
c = L("cold")
segs.append(enc("cold", ["-framerate", "30", "-loop", "1", "-t", f"{c:.3f}", "-i", P("shop6.jpg"), "-framerate", "30", "-loop", "1", "-t", f"{c:.3f}", "-i", png("shop_boxes", "png")],
    f"[0:v]scale={int(W*1.1)}:-1,zoompan=z='1.0+0.08*on/{int(c*FPS)}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s={W}x{H}:fps={FPS}[b];"
    f"[1:v]format=rgba,fade=t=in:st=0.15:d=0.12:alpha=1[o];[b][o]overlay=0:0,format=yuv420p[out]", c))
# 2-4 stats
for k in ("s57", "s1in4", "s20b"):
    segs.append(card_scene(k, png(k), L(k)))
# 5 where: three fast cuts
w = L("where") / 3
for i, (src, ss) in enumerate([(SHOP, 9.0), (MAIL, 0.5), (R2, 11.0)]):
    if src == R2:
        fc = (f"[0:v]scale={W}:{H},fps={FPS}[b];[1:v]trim=start={ss}:duration={w},setpts=PTS-STARTPTS,fps={FPS},scale={PH_W}:{PH_H},format=rgba[ph];"
              f"[2:v]scale={PH_W}:{PH_H},format=gray[m];[ph][m]alphamerge[phm];[b][phm]overlay=x={W-PH_W-260}:y={(H-PH_H)//2}[b2];"
              + slide(3, "b2", 0.0, w + 1, dx=60) + ",format=yuv420p[out]")
        segs.append(enc(f"where{i}", ["-framerate", "30", "-loop", "1", "-t", f"{w:.3f}", "-i", P("png2", "bg.png"), "-i", R2,
                                      "-framerate", "30", "-loop", "1", "-t", f"{w:.3f}", "-i", P("png2", "mask.png"),
                                      "-framerate", "30", "-loop", "1", "-t", f"{w:.3f}", "-i", png(f"where{i}")], fc, w))
    else:
        fc = (f"[0:v]scale={W}:{H},fps={FPS},eq=brightness=-0.05:saturation=1.1[b];" + slide(1, "b", 0.0, w + 1, dx=60) + ",format=yuv420p[out]")
        segs.append(enc(f"where{i}", ["-ss", str(ss), "-t", f"{w:.3f}", "-i", src, "-framerate", "30", "-loop", "1", "-t", f"{w:.3f}", "-i", png(f"where{i}")], fc, w))
# 6 meet
segs.append(still_scene("meet", png("meet"), L("meet"), 0.05))
# 7 shop: play, then freeze with real verdict
sl = L("shop"); play = VD["w1"] + 0.2; fz = sl - play
segs.append(enc("shop_play", ["-ss", f"{6.0-play:.3f}", "-t", f"{play:.3f}", "-i", SHOP, "-framerate", "30", "-loop", "1", "-t", f"{play:.3f}", "-i", png("shop_watch", "png")],
    f"[0:v]scale={W}:{H},fps={FPS}[b];[1:v]format=rgba,fade=t=in:st=0.3:d=0.3:alpha=1[o];[b][o]overlay=0:0,format=yuv420p[out]", play))
segs.append(enc("shop_freeze", ["-framerate", "30", "-loop", "1", "-t", f"{fz:.3f}", "-i", P("shop6.jpg"),
    "-framerate", "30", "-loop", "1", "-t", f"{fz:.3f}", "-i", png("shop_boxes", "png"), "-framerate", "30", "-loop", "1", "-t", f"{fz:.3f}", "-i", png("shop_card", "png")],
    f"[0:v]scale={int(W*1.1)}:-1,zoompan=z='1+0.04*on/{int(fz*FPS)}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s={W}x{H}:fps={FPS}[b];"
    f"[1:v]format=rgba,fade=t=in:st=0:d=0.12:alpha=1,fade=t=out:st=0.7:d=0.15:alpha=1[o1];[b][o1]overlay=0:0:enable='lt(t,0.85)'[b1];"
    f"[2:v]format=rgba,fade=t=in:st=0.7:d=0.2:alpha=1[o2];[b1][o2]overlay=0:0:enable='gte(t,0.7)',format=yuv420p[out]", fz))
# 8 call: real app, scripted call, listening -> likely scam (r2 9.5s..21.5s)
segs.append(phone_scene("call", R2, 16.5, 8.0, L("call"), png("t_call")))
# 9 options: r1 3s..34s sped up
segs.append(phone_scene("opts", R1, 2.5, 31.0, L("opts"), png("t_opts")))
# 10 benefits, 11 tech (4 fast cards), 12 end
segs.append(still_scene("benefits", png("benefits"), L("benefits"), 0.03))
tl = L("tech") / 4
for i in range(4):
    segs.append(card_scene(f"tech{i}", png(f"tech{i}"), tl))
segs.append(still_scene("end", png("end"), L("end"), 0.04))

lst = P("seg2", "list.txt")
open(lst, "w").write("".join(f"file '{s}'\n" for s in segs))
base = P("seg2", "base.mp4")
sh(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", base])
print("video", round(dur(base), 2), "vs timeline", round(TOTAL, 2))

# captions
cmd = ["ffmpeg", "-v", "error", "-y", "-i", base]
for *_, pth in CAPS: cmd += ["-framerate", "30", "-loop", "1", "-t", f"{TOTAL:.3f}", "-i", pth]
f, last = "", "0:v"
for i, (t0, t1, _) in enumerate(CAPS, start=1):
    f += f"[{last}][{i}:v]overlay=0:0:enable='between(t,{t0:.3f},{t1:.3f})'[c{i}];"; last = f"c{i}"
capped = P("seg2", "captioned.mp4")
sh(cmd + ["-filter_complex", f.rstrip(";"), "-map", f"[{last}]", "-c:v", "libx264", "-crf", "18", "-preset", "medium",
          "-pix_fmt", "yuv420p", "-t", f"{TOTAL:.3f}", capped])

# audio: voice + chimes, music ducked under the voice
chime = P("seg2", "chime.wav")
sh(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "sine=f=880:d=0.12", "-f", "lavfi", "-i", "sine=f=1318:d=0.22",
    "-filter_complex", "[0][1]concat=n=2:v=0:a=1,afade=t=out:st=0.2:d=0.14,volume=0.3,aresample=48000", chime])
ain, mix, n = [], "", 0
for at, k in CUES:
    n += 1; ain += ["-i", P("vo2", k + "_t.wav")]
    mix += f"[{n}:a]adelay={int(at*1000)}|{int(at*1000)}[a{n}];"
for at in [0.15, S["shop"][0] + VD["w1"] + 0.2, S["call"][0] + 5.0]:
    n += 1; ain += ["-i", chime]; mix += f"[{n}:a]adelay={int(at*1000)}|{int(at*1000)}[a{n}];"
n += 1; ain += ["-i", P("music60.mp3")]; mi = n
mix += "".join(f"[a{i}]" for i in range(1, mi)) + f"amix=inputs={mi-1}:normalize=0,asplit=2[voice][key];"
mix += (f"[{mi}:a]aresample=48000,volume=0.55,afade=t=out:st={TOTAL-1.6:.2f}:d=1.6[mus];"
        "[mus][key]sidechaincompress=threshold=0.03:ratio=8:attack=20:release=350[duck];"
        "[voice][duck]amix=inputs=2:normalize=0,loudnorm=I=-15:TP=-1.5[aout]")
final = os.path.join(OUT, "second-look-60s.mp4")
sh(["ffmpeg", "-v", "error", "-y", "-i", capped] + ain + ["-filter_complex", mix.replace("[1:a]", "[1:a]", 1), "-map", "0:v", "-map", "[aout]",
    "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-t", f"{TOTAL:.3f}", "-movflags", "+faststart", final])
print("wrote", final, round(dur(final), 2))
