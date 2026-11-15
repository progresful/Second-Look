/* Hero: rendered 3D glasses (Blender, web/3d/glasses_scroll.py), scrubbed by scroll.
   Frames 1-30 play on load; 30-150 follow the scroll: spin to face you, then push through the
   right lens. Each frame has a lens mask (m_*.webp), so the lenses are a window onto the
   simulator's first scene. A blue line sweeps once and the view becomes the "Try it" simulator. */
const html = document.documentElement, stage = document.getElementById('stage');
const hero = stage && stage.querySelector('.hero'), canvas = document.getElementById('gl');
const FIRST = 'emails', FIRST_IMG = 'media/sim/gmail.jpg?v=5';
const T = .8;                                               // share of the pinned scroll the transition uses; the rest holds the simulator in place
const N = 150, INTRO = 30, PUSH_END = .74;                  // scroll 0..PUSH_END maps to frames INTRO..N
const ss = (a, b, x) => { x = Math.min(1, Math.max(0, (x - a) / (b - a))); return x * x * (3 - 2 * x); };
const lerp = (a, b, t) => a + (b - a) * t;

let st = null, P = 0;
if (html.classList.contains('staged') && stage && canvas) {
  st = ScrollTrigger.create({ trigger: stage, start: 'top top', end: '+=400%', pin: true, scrub: .6, refreshPriority: 1,
    onUpdate(s) { P = Math.min(1, s.progress / T); } });
  ScrollTrigger.sort(); ScrollTrigger.refresh();
  // The transition plays as one move: any scroll inside the stage runs it to the end (or back to the top).
  let auto = null, cool = 0;
  const jump = y => scrollTo({ top: y, behavior: 'instant' });
  const endY = () => st.start + (st.end - st.start) * T;
  const inStage = () => scrollY < endY() - 40;
  function run(down) {
    if (auto || performance.now() < cool) return;
    const to = down ? endY() + 2 : 0, o = { y: scrollY }, d = Math.abs(to - scrollY) / (st.end - st.start);
    if (d < .002) return;
    auto = gsap.to(o, { y: to, duration: Math.max(.5, (down ? 7.5 : 3.2) * d), ease: 'power1.inOut',
      onUpdate() { jump(o.y); }, onComplete() { auto = null; cool = performance.now() + 350; } });
  }
  addEventListener('wheel', e => { if (html.classList.contains('vidopen')) return; if (auto) return e.preventDefault(); if (!inStage()) return;
    if (e.deltaY < 0 && scrollY <= 0) return; e.preventDefault(); if (Math.abs(e.deltaY) > 1) run(e.deltaY > 0); }, { passive: false });
  let ty = null;
  addEventListener('touchstart', e => { ty = e.touches[0].clientY; }, { passive: true });
  addEventListener('touchmove', e => { if (html.classList.contains('vidopen')) return; if (auto) return e.preventDefault(); if (!inStage() || ty == null) return;
    const dy = ty - e.touches[0].clientY; if (dy < 0 && scrollY <= 0) return;
    e.preventDefault(); if (Math.abs(dy) > 10) run(dy > 0); }, { passive: false });
  addEventListener('keydown', e => { if (html.classList.contains('vidopen')) return; if (e.target.closest && e.target.closest('input,textarea,select')) return;
    const dn = ['ArrowDown', 'PageDown', ' ', 'End'].includes(e.key), up = ['ArrowUp', 'PageUp', 'Home'].includes(e.key);
    if (!dn && !up) return; if (auto) return e.preventDefault(); if (!inStage() || (up && scrollY <= 0)) return;
    e.preventDefault(); run(dn); });
  document.querySelectorAll('a[href="#try"]').forEach(a => a.addEventListener('click', e => { e.preventDefault(); run(true); }));
  // A click on the hero before any scrolling plays a short clip in a small player; scrolling removes it.
  const clip = document.getElementById('heroclip');
  const stopClip = () => { if (clip && !clip.hidden) { clip.hidden = true; clip.innerHTML = ''; } };
  addEventListener('click', e => {
    if (!clip || scrollY > 4 || auto || !clip.hidden || e.target.closest('a,button,.heroclip')) return;
    clip.innerHTML = '<iframe src="https://www.youtube-nocookie.com/embed/FWlE78tru_Y?autoplay=1&start=3&playsinline=1&rel=0" title="Video clip" allow="autoplay; encrypted-media" referrerpolicy="strict-origin-when-cross-origin"></iframe>';
    clip.hidden = false; setTimeout(stopClip, 9000);
  });
  addEventListener('scroll', () => { if (scrollY > 4) stopClip(); }, { passive: true });
  if (window.SLSim) SLSim.prime(FIRST);
  init();
}

function init() {
  const ctx = canvas.getContext('2d'), off = document.createElement('canvas'), octx = off.getContext('2d');
  const dir = innerWidth < 800 ? 'media/spin-s/' : 'media/spin/';
  const load = src => { const im = new Image(); im.decoding = 'async'; im.src = src; return im; };
  const num = i => String(i).padStart(4, '0');
  const frames = [], masks = [];
  for (let i = 1; i <= N; i++) { frames[i] = load(dir + 'f_' + num(i) + '.webp'); masks[i] = load('media/spin-m/m_' + num(i) + '.webp'); }
  const view = load(FIRST_IMG);
  const ok = im => im && im.complete && im.naturalWidth > 0;
  const nearest = (arr, i) => { for (let k = i; k >= 1; k--) if (ok(arr[k])) return arr[k]; return null; };

  const title = hero.querySelector('.herohead'), hint = hero.querySelector('.divehint'), beat = hero.querySelector('.beat'),
        bg = hero.querySelector('.herobg'), sweepEl = document.getElementById('sweep'),
        simLens = stage.querySelector('.sim-lens'), phone = stage.querySelector('.sim-phone'),
        head = stage.querySelector('.try .head'), line = stage.querySelector('.sim-line');
  let W = 0, H = 0, dpr = 1, started = false, last = '';
  function size() {
    W = hero.clientWidth; H = hero.clientHeight; dpr = Math.min(devicePixelRatio || 1, 2);
    canvas.width = off.width = Math.round(W * dpr); canvas.height = off.height = Math.round(H * dpr); last = '';
  }
  size(); addEventListener('resize', size);

  // draw `im` so it covers the box (x, y, w, h), cropping the overflow
  function cover(c, im, x, y, w, h) {
    const ar = im.naturalWidth / im.naturalHeight, bar = w / h; let sw = im.naturalWidth, sh = im.naturalHeight, sx = 0, sy = 0;
    if (bar > ar) { sh = sw / bar; sy = (im.naturalHeight - sh) / 2; } else { sw = sh * bar; sx = (im.naturalWidth - sw) / 2; }
    c.drawImage(im, sx, sy, sw, sh, x, y, w, h);
  }

  const intro = { f: 1 };
  gsap.fromTo(canvas, { opacity: 0 }, { opacity: 1, duration: 1.4, ease: 'power2.out' });
  gsap.to(intro, { f: INTRO, duration: 2.6, ease: 'power2.out', delay: .15 });

  function frame() {
    requestAnimationFrame(frame);
    const p = P, push = ss(.34, PUSH_END, p), sweep = ss(.58, .74, p), glide = ss(.76, .93, p);
    const f = p > 0 ? INTRO + (N - INTRO) * Math.min(1, p / PUSH_END) : intro.f, fi = Math.max(1, Math.min(N, Math.round(f)));

    // page furniture follows the scroll
    title.style.opacity = hint.style.opacity = 1 - ss(.02, .14, p);
    beat.style.opacity = ss(.4, .47, p) * (1 - ss(.54, .6, p));
    sweepEl.style.opacity = sweep > 0 && sweep < 1 ? 1 : 0; sweepEl.style.transform = `translateY(${sweep * 1.02 * H}px)`;
    bg.style.opacity = 1 - glide;
    const inn = ss(.82, .95, p);
    phone.style.opacity = inn; phone.style.transform = `translateX(${(1 - inn) * 70}px)`;
    simLens.style.opacity = ss(.9, .94, p);
    head.style.opacity = line.style.opacity = inn; head.style.transform = `translateY(${(1 - inn) * 24}px)`;
    if (p > .93 && !started) { started = true; if (window.SLSim) SLSim.start(FIRST); }
    hero.style.opacity = 1 - ss(.955, .995, p);
    if (p >= .995) return;                                            // simulator is on; nothing to draw

    const im = nearest(frames, fi), mk = nearest(masks, fi), lr = simLens.getBoundingClientRect(), hr = hero.getBoundingClientRect();
    const sig = [fi, p.toFixed(4), ok(view), im && im.src, mk && mk.src, lr.left | 0, lr.top | 0].join('|');
    if (sig === last) return; last = sig;                             // nothing changed

    const cw = canvas.width, ch = canvas.height;
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over';
    if (glide > 0) {                                                  // past the lens: the view shrinks into the simulator's lens
      ctx.clearRect(0, 0, cw, ch); if (!ok(view)) return;
      const x = lerp(0, lr.left - hr.left, glide) * dpr, y = lerp(0, lr.top - hr.top, glide) * dpr,
            w = lerp(W, lr.width, glide) * dpr, h = lerp(H, lr.height, glide) * dpr;
      ctx.save(); ctx.beginPath(); ctx.roundRect(x, y, w, h, lerp(0, parseFloat(getComputedStyle(simLens).borderTopLeftRadius) || 0, glide) * dpr); ctx.clip();
      cover(ctx, view, x, y, w, h); ctx.fillStyle = 'rgba(0,0,0,.14)'; ctx.fillRect(x, y, w, h); ctx.restore();
      return;
    }
    ctx.fillStyle = '#000'; ctx.fillRect(0, 0, cw, ch);
    if (!im) return;
    // the frame: wide screens cover the viewport; tall screens start zoomed out and ease to cover as you push in
    const sCover = Math.max(cw / 16, ch / 9), sFit = Math.min(sCover, cw * lerp(1.36, 1.72, ss(.04, .3, p)) / 16), s = lerp(sFit, sCover, push * push);
    const fw = 16 * s, fh = 9 * s, fx = (cw - fw) / 2, fy = (ch - fh) / 2 + (1 - ss(.02, .3, p)) * .14 * ch;   // the glasses start lower, clear of the title
    ctx.drawImage(im, fx, fy, fw, fh);
    // lenses: a dim window onto the scene, fixed to the screen
    const open = ss(.24, .42, p);
    if (open > 0 && mk && ok(view)) {
      octx.setTransform(1, 0, 0, 1, 0, 0); octx.globalCompositeOperation = 'source-over'; octx.clearRect(0, 0, cw, ch);
      octx.drawImage(mk, fx, fy, fw, fh);
      octx.globalCompositeOperation = 'source-in'; cover(octx, view, 0, 0, cw, ch);
      octx.globalCompositeOperation = 'source-atop'; octx.fillStyle = `rgba(0,0,0,${1 - lerp(.34, .56, push)})`; octx.fillRect(0, 0, cw, ch);
      ctx.globalAlpha = open; ctx.drawImage(off, 0, 0); ctx.globalAlpha = 1;
    }
    // the blue sweep switches the full view on, top to bottom
    if (sweep > 0 && ok(view)) {
      const hh = Math.min(ch, sweep * 1.02 * ch);
      ctx.save(); ctx.beginPath(); ctx.rect(0, 0, cw, hh); ctx.clip();
      cover(ctx, view, 0, 0, cw, ch); ctx.fillStyle = 'rgba(0,0,0,.14)'; ctx.fillRect(0, 0, cw, hh); ctx.restore();
    }
  }
  requestAnimationFrame(frame);
}
