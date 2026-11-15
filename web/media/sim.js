/* Second Look "Try it" simulator: glasses view (left) + app (right), no install needed.
   Stills become a first-person "video": zoom in on load, slow head-like drift, mouse parallax.
   Boxes, verdicts and one-line reasons are Second Look's real output for each image
   (media/sim/detections.json, produced by the live server). */
(() => {
  const root = document.getElementById('try'); if (!root) return;
  const $ = s => root.querySelector(s);
  const lens = $('.sim-lens'), cam = $('.sim-cam'), img = $('.sim-img'), boxes = $('.sim-boxes'),
        scan = $('.sim-scan'), hud = $('.sim-hud'), line = $('.sim-line'), chip = $('.sim-status'),
        callView = $('.sim-call'), chips = $('.sim-chips'), modeBtn = $('.sim-mode'), checkBtn = $('.sim-check'),
        word = $('.sim-word'), para = $('.sim-para'), card = $('.sim-card'), screen = $('.sim-screen');
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

  const V = '?v=9';                   // bump when photos, detections or voice clips change (they are cached for a week)
  const SCENES = {
    messages: { label: 'messages', img: 'media/sim/sms.jpg', key: 'sms', short: 'Fake parcel text. Don’t open the link.' },
    emails:   { label: 'emails', img: 'media/sim/gmail.jpg', key: 'gmail', short: 'Fake security email. Don’t verify through the link.' },
    websites: { label: 'websites', img: 'media/sim/bank.jpg', key: 'bank', short: 'Fake bank alert. The link isn’t your bank.' },
    webshops: { label: 'webshops', img: 'media/sim/shop.jpg', key: 'shop', short: 'Fake Ray-Ban shop: ray-band.com, €9.90.' },
    letters:  { label: 'letters & bills', img: 'media/sim/letter.jpg', key: 'letter', short: 'A notice telling you to pay at once. Check with the office first.' },
    qr:       { label: 'qr codes', img: 'media/sim/qr.jpg', key: 'qr', short: 'A QR code alone can’t be judged. Don’t pay yet.' },
    calls:    { label: 'phone calls', call: true },
  };
  const ORDER = ['messages', 'emails', 'websites', 'webshops', 'letters', 'qr', 'calls'];
  let DET = {}, current = null, alwaysOn = true, tl = null, drift = null, timers = [];
  const later = (ms, f) => timers.push(setTimeout(f, ms));
  const clearTimers = () => { timers.forEach(clearTimeout); timers = []; };

  // ---- app side: single-select chips ----
  ORDER.forEach(k => {
    const b = document.createElement('button');
    b.className = 'sim-chip'; b.textContent = SCENES[k].label; b.dataset.k = k;
    b.onclick = () => select(k, true); chips.appendChild(b);
  });
  screen.classList.add('auto');
  modeBtn.onclick = () => {
    alwaysOn = !alwaysOn; modeBtn.classList.toggle('on', alwaysOn); screen.classList.toggle('auto', alwaysOn);
    modeBtn.querySelectorAll('span').forEach((s, i) => s.classList.toggle('sel', i === (alwaysOn ? 1 : 0)));
    select(current, false);
  };
  checkBtn.onclick = () => { if (current && !SCENES[current].call) detect(); else if (current) runCall(true); };

  // ---- the "video": cover-fit the still, then zoom + drift + parallax ----
  function fit() {
    const W = lens.clientWidth, H = lens.clientHeight, ar = (img.naturalWidth || 16) / (img.naturalHeight || 9);
    let w = W, h = W / ar; if (h < H) { h = H; w = H * ar; }
    Object.assign(cam.style, { width: w + 'px', height: h + 'px', left: (W - w) / 2 + 'px', top: (H - h) / 2 + 'px' });
  }
  function focusOf(det) {            // centre of all detected boxes (0-1), and how far to zoom
    if (!det || !det.boxes.length) return { x: .5, y: .5, z: 1.35 };
    let y0 = 1, x0 = 1, y1 = 0, x1 = 0;
    det.boxes.forEach(({ b }) => { y0 = Math.min(y0, b[0] / 1000); x0 = Math.min(x0, b[1] / 1000); y1 = Math.max(y1, b[2] / 1000); x1 = Math.max(x1, b[3] / 1000); });
    const span = Math.max(x1 - x0, (y1 - y0) * 1.3, .18);
    return { x: (x0 + x1) / 2, y: (y0 + y1) / 2, z: Math.min(1.9, Math.max(1.25, .55 / span)) };
  }
  function zoomTo(f, dur) {           // scale around the cam's top-left, then centre the focus point
    const W = lens.clientWidth, H = lens.clientHeight, w = cam.clientWidth, h = cam.clientHeight;
    const L = parseFloat(cam.style.left), T = parseFloat(cam.style.top);
    let x = W / 2 - L - f.x * w * f.z, y = H * .46 - T - f.y * h * f.z;
    // keep the image covering the lens
    x = Math.min(-L, Math.max(W - L - w * f.z, x)); y = Math.min(-T, Math.max(H - T - h * f.z, y));
    return gsap.to(cam, { scale: f.z, x, y, transformOrigin: '0 0', duration: dur, ease: 'power3.inOut' });
  }
  function startDrift() {              // slow, irregular head movement
    if (drift) drift.kill(); if (reduce) return;
    drift = gsap.timeline({ repeat: -1, yoyo: true, defaults: { ease: 'sine.inOut' } })
      .to('.sim-head', { x: 14, y: -8, rotation: .5, duration: 3.6 })
      .to('.sim-head', { x: -10, y: 6, rotation: -.4, duration: 4.2 })
      .to('.sim-head', { x: 6, y: 10, rotation: .2, duration: 3.1 });
  }
  lens.addEventListener('pointermove', e => {
    if (reduce) return; const r = lens.getBoundingClientRect();
    const dx = (e.clientX - r.left) / r.width - .5, dy = (e.clientY - r.top) / r.height - .5;
    gsap.to('.sim-look', { x: -dx * 46, y: -dy * 30, rotationY: dx * 4, rotationX: -dy * 3, duration: .9, ease: 'power2.out' });
  });
  lens.addEventListener('pointerleave', () => gsap.to('.sim-look', { x: 0, y: 0, rotationX: 0, rotationY: 0, duration: 1.2, ease: 'power2.out' }));

  // ---- states ----
  function setApp(state, text, verdict) {
    word.textContent = state; para.textContent = text;
    screen.dataset.mood = verdict === 'scam' ? 'scam' : verdict === 'suspicious' ? 'careful' : state === 'listening' ? 'listening' : state === 'checking' ? 'checking' : 'calm';
  }
  // The spoken alarm: one recorded line per scene, played when the alert appears.
  // Browsers keep audio silent until the visitor has clicked, tapped or pressed a key once. If the
  // alert fires before that, the line waits and plays on the first such action while the alert is up.
  let voice = null, waiting = null;
  const clips = {};
  function hush() { waiting = null; if (voice) { voice.pause(); voice = null; } }
  function say(k) {
    hush(); if (!k) return;
    voice = clips[k] || (clips[k] = new Audio('media/sim/voice/' + k + '.mp3' + V)); voice.currentTime = 0;
    voice.play().catch(() => { waiting = k; if (!line.textContent.includes('sound')) line.textContent += '  ·  Tap anywhere for sound'; });
  }
  ['pointerdown', 'keydown', 'touchend'].forEach(ev => addEventListener(ev, () => {
    if (waiting && screen.classList.contains('alerting')) { const k = waiting; later(0, () => say(k)); }
  }, { passive: true }));
  function resetView() {
    hush(); clearTimers(); if (tl) tl.kill();
    gsap.killTweensOf([cam, hud, card, line, scan]);
    screen.classList.remove('alerting'); boxes.innerHTML = ''; gsap.set(hud, { opacity: 0, y: 10 }); gsap.set(card, { opacity: 0, y: 14, display: 'none' });
    line.textContent = ''; chip.textContent = ''; chip.className = 'sim-status';
  }
  function select(k, user) {
    if (!k) return; current = k; const sc = SCENES[k];
    chips.querySelectorAll('.sim-chip').forEach(b => b.classList.toggle('sel', b.dataset.k === k));
    resetView();
    callView.classList.toggle('on', !!sc.call); lens.classList.toggle('calling', !!sc.call);
    if (sc.call) { runCall(alwaysOn); return; }
    if (sc.soon) {
      img.removeAttribute('src'); gsap.set(cam, { scale: 1, x: 0, y: 0 });
      setApp('ready', 'Example for ' + sc.label + ' coming soon. Try another one.');
      line.textContent = 'Example coming soon.';
      return;
    }
    gsap.set(cam, { scale: 1, x: 0, y: 0, opacity: 0 });
    img.onload = () => {
      fit(); gsap.to(cam, { opacity: 1, duration: .5 });
      setApp(alwaysOn ? 'watching' : 'ready', alwaysOn ? 'I check what you look at and only speak up if something looks wrong.' : 'Look at it and tap check, or press the capture button on your glasses.');
      chip.textContent = alwaysOn ? 'watching' : 'ready'; chip.className = 'sim-status ' + (alwaysOn ? 'live' : '');
      tl = gsap.timeline();
      const fz = focusOf(DET[sc.key]); cam.style.setProperty('--inv', (1 / fz.z).toFixed(3));
      tl.add(zoomTo(fz, reduce ? 0 : 1.8), .25).add(startDrift, '>-0.2');
      if (alwaysOn) later(reduce ? 0 : 2300, detect);
      else { checkBtn.classList.add('pulse'); line.textContent = 'Tap check, or press the capture button.'; }
    };
    img.src = sc.img + V;
  }
  function detect() {
    const sc = SCENES[current], det = DET[sc.key]; if (!det) return;
    checkBtn.classList.remove('pulse');
    chip.textContent = 'checking'; chip.className = 'sim-status checking';
    setApp('checking', "Reading what you're looking at.");
    gsap.fromTo(scan, { top: '-25%', opacity: 1 }, { top: '110%', duration: reduce ? 0 : 1.1, ease: 'power1.inOut', onComplete: () => gsap.set(scan, { opacity: 0 }) });
    later(reduce ? 0 : 1200, () => {
      boxes.innerHTML = '';
      // Merge overlapping boxes into one soft highlight with one short label.
      const pad = .012, regs = [];
      det.boxes.forEach(({ b, l }) => {
        const r = { x0: b[1] / 1000 - pad, y0: b[0] / 1000 - pad, x1: b[3] / 1000 + pad, y1: b[2] / 1000 + pad, ls: [l] };
        const hit = regs.find(q => !(r.x1 < q.x0 || r.x0 > q.x1 || r.y1 < q.y0 || r.y0 > q.y1));
        if (hit) { hit.x0 = Math.min(hit.x0, r.x0); hit.y0 = Math.min(hit.y0, r.y0); hit.x1 = Math.max(hit.x1, r.x1); hit.y1 = Math.max(hit.y1, r.y1); if (!hit.ls.includes(l)) hit.ls.push(l); }
        else regs.push(r);
      });
      regs.forEach(r => {
        const d = document.createElement('div'); d.className = 'sim-bx' + (det.verdict === 'suspicious' ? ' amber' : '');
        d.style.cssText = `left:${r.x0 * 100}%;top:${r.y0 * 100}%;width:${(r.x1 - r.x0) * 100}%;height:${(r.y1 - r.y0) * 100}%`;
        d.innerHTML = `<b>${r.ls.slice(0, 2).join(' · ')}</b>`;
        boxes.appendChild(d);
      });
      gsap.fromTo(boxes.children, { opacity: 0 }, { opacity: 1, duration: .8, stagger: .2, ease: 'power2.out' });
      const word2 = det.verdict === 'scam' ? 'LIKELY SCAM' : det.verdict === 'suspicious' ? 'BE CAREFUL' : det.verdict === 'not_sure' ? 'NOT SURE' : 'NO SCAM SIGNS';
      const act = det.verdict === 'scam' ? "Don't pay or reply." : det.verdict === 'not_sure' ? "Don't pay yet." : 'Check before you pay.';
      showHud(word2, act, det.signs.slice(0, 2).join(' · ') || 'Nothing to read around the code', det.verdict);
      chip.textContent = word2.toLowerCase(); chip.className = 'sim-status ' + det.verdict;
      typeLine(sc.short);
      setApp(word2.toLowerCase(), sc.short, det.verdict);
      showCard(word2, act, sc.short, det.signs.length ? det.signs.slice(0, 3) : ['Call the official number'], det.verdict);
    });
  }
  function showHud(w, a, s, verdict) {
    hud.className = 'sim-hud ' + verdict; hud.querySelector('.h span').textContent = w; hud.querySelector('.a').textContent = a; hud.querySelector('.w').textContent = s;
    hud.querySelector('svg').setAttribute('fill', verdict === 'suspicious' ? '#FF9F0A' : verdict === 'not_sure' ? '#9aa0ad' : '#FF453A');
    gsap.to(hud, { opacity: 1, y: 0, duration: .6, delay: .5, ease: 'power3.out' });
  }
  function showCard(w, a, why, signs, verdict) {
    card.className = 'card sim-card' + (verdict === 'suspicious' ? ' amber' : verdict === 'not_sure' ? ' grey' : '');
    card.querySelector('.ch span').textContent = w; card.querySelector('.ch b').textContent = verdict === 'not_sure' ? '?' : '!'; card.querySelector('.act').textContent = a;
    card.querySelector('.cwhy').textContent = why;
    card.querySelector('.cps').innerHTML = signs.slice(0, 2).map(x => `<span>${x}</span>`).join('');
    later(600, () => say(current));
    screen.classList.add('alerting'); gsap.set(card, { display: 'block' }); gsap.to(card, { opacity: 1, y: 0, duration: .6, delay: .7, ease: 'power3.out' });
  }
  // Close the alert: the app goes back to waiting, the marks in the glasses view stay.
  card.querySelector('.sim-x').addEventListener('click', () => {
    hush(); gsap.killTweensOf(card); gsap.set(card, { opacity: 0, y: 14, display: 'none' }); screen.classList.remove('alerting');
    setApp(alwaysOn ? 'watching' : 'ready', alwaysOn ? 'I check what you look at and only speak up if something looks wrong.' : 'Look at it and tap check, or press the capture button on your glasses.');
  });
  function typeLine(text) {
    const o = { n: 0 }; gsap.to(o, { n: text.length, duration: Math.min(2.4, text.length * .025), ease: 'none', delay: .3,
      onUpdate: () => { line.textContent = text.slice(0, Math.round(o.n)); } });
  }

  // ---- phone call: the view of holding the phone, live caption, warning mid-call ----
  const CALL = [
    "Hello, this is Anna from your bank's security team.",
    "We've stopped a suspicious payment from your account.",
    "To cancel it, read me the code we just sent you.",
    "Then we'll move your money to a safe account. Don't tell anyone.",
  ];
  function runCall(start) {
    const cap = callView.querySelector('.sim-captions'), timer = callView.querySelector('.sim-timer');
    cap.innerHTML = ''; setApp(start ? 'listening' : 'ready', start ? 'Listening to this call through the glasses mic.' : 'Tap the call button (or check) to let Second Look listen.');
    chip.textContent = start ? 'listening' : 'ready'; chip.className = 'sim-status ' + (start ? 'live' : '');
    gsap.fromTo('.sim-call .sim-hand', { y: 40, opacity: 0 }, { y: 0, opacity: 1, duration: .8, ease: 'power3.out' });
    if (!start) { checkBtn.classList.add('pulse'); line.textContent = 'Tap check to listen to this call.'; return; }
    let sec = 0; const tick = () => { sec++; timer.textContent = `0:${String(sec).padStart(2, '0')}`; later(1000, tick); }; later(1000, tick);
    CALL.forEach((t, i) => later(900 + i * 2300, () => {
      const p = document.createElement('p'); p.textContent = '“' + t + '”'; cap.appendChild(p);
      gsap.from(p, { opacity: 0, y: 8, duration: .4 });
      if (i === 2) {
        const why = 'A caller claiming to be your bank asks for a code and a “safe account” transfer. Hang up and call the number on your card.';
        callView.classList.add('alarm');
        showHud('LIKELY SCAM', 'Hang up. Don\'t share the code.', 'Asks for codes · “Safe account”', 'scam');
        chip.textContent = 'likely scam'; chip.className = 'sim-status scam';
        typeLine('Fake bank call. Never share a code.'); setApp('likely scam', 'Fake bank call. Never share a code.', 'scam');
        showCard('LIKELY SCAM', 'Hang up. Don\'t share the code.', why, ['Asks for codes or passwords', '“Safe account”'], 'scam');
      }
    }));
  }

  // used by the glasses intro: show a scene's still without running it, then start it
  function prime(k) {
    const sc = SCENES[k]; if (!sc || !sc.img) return; current = k;
    chips.querySelectorAll('.sim-chip').forEach(b => b.classList.toggle('sel', b.dataset.k === k));
    img.onload = () => { fit(); gsap.set(cam, { scale: 1, x: 0, y: 0, opacity: 1 }); };
    img.src = sc.img + V; setApp('watching', 'I check what you look at and only speak up if something looks wrong.');
  }
  window.SLSim = { prime, start: k => select(k, false) };

  addEventListener('resize', () => { if (current && !SCENES[current].call && img.naturalWidth) { fit(); } });
  fetch('media/sim/detections.json' + V).then(r => r.json()).then(d => { DET = d; }).finally(() => {
    // start when the section comes into view
    if (document.documentElement.classList.contains('staged')) return;   // the glasses intro starts it
    let started = false;
    const start = () => { if (started) return; started = true; if (!current) select('messages', false); };
    const io = new IntersectionObserver(es => { if (es.some(e => e.isIntersecting)) { io.disconnect(); start(); } }, { threshold: .15 });
    io.observe(root);
    const onScroll = () => { const r = root.getBoundingClientRect(); if (r.top < innerHeight * .6 && r.bottom > 0) { removeEventListener('scroll', onScroll); start(); } };
    addEventListener('scroll', onScroll, { passive: true }); onScroll();
  });
})();
