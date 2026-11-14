# Plan: real-looking glasses + "try it" glasses simulator

## 1. The glasses (replace the current render)

**Problem:** the current model is a flat, goggle-like mask (thick visor, V bridge, matte grey).
The reference (Ray-Ban Meta, front view) is a glossy black Wayfarer-style acetate frame with
clear lenses, a soft keyhole bridge, slightly lifted outer corners, thin temples.

**Approach: trace the silhouette from the reference instead of guessing it.**
1. Extract the frame outline from the reference image (threshold the black frame →
   outer contour + two lens contours) with OpenCV/scikit-image. This gives the exact shape.
2. In Blender, use those contours as the 2D profile: extrude ~6 mm, rounded bevel, a slight
   forward curve (frames wrap around the face), keyhole bridge from the traced shape.
3. Material: glossy black acetate (low roughness, clear coat), clear lenses (no tint) with
   light reflections; thin straight temples; small hinge detail.
4. Smart-glasses details, generic: camera dot top-left, LED top-right, display glow in the
   right lens. **No Ray-Ban or Meta logos, no copied studs/branding.**
5. Studio lighting like product photography (white/grey softboxes, black background for the
   page), check a front still against the reference side by side **before** rendering 120 frames.
6. Keep the same dive animation and hand-over to the footage.

Effort: ~1.5–2 h (most of it render time). Acceptance: front still next to the reference reads
as "the same kind of glasses" without logos.

## 2. "Try it" simulator (no app, no glasses needed)

A section on the landing page that lets anyone experience Second Look in the browser.

```
┌──────────────── glasses view (left) ─────────────────┐ ┌── app (right) ──┐
│  oval lens view, dark around it                      │ │ ready / watching │
│  ▸ short real clip of the selected scenario          │ │ PROTECT ME FROM  │
│  ▸ red boxes appear on the detected signs            │ │ ( letters )      │
│  ▸ glasses-display card fades in                     │ │ ( messages ) ◀── │
│  one-line transcript: "Fake parcel text: pay 2.99 €  │ │ ( webshops )     │
│  at a look-alike address. Don't click."              │ │ ( calls )        │
└──────────────────────────────────────────────────────┘ │ on request | on  │
                                                          │ [check]          │
                                                          └──────────────────┘
```

**Behaviour**
- Right: the app's "protect me from" list becomes **single-select chips** (one at a time,
  clearly selected). Selecting one switches the left view to that scenario.
- Left: plays that scenario's short clip inside the lens, then the real detection result:
  boxes on the evidence, the glasses-display card, and the spoken warning (Kokoro voice,
  optional sound toggle). One-line transcript under the lens.
- On request: tap **check** (or "capture button") to run it. Always on: it runs automatically.
- Call: left shows a caller-ID screen + live caption; warns mid-call.
- Works on a phone too: lens view on top, app below.

**Scenarios and footage**
| Item | Clip | Have it? |
|---|---|---|
| Messages | Parcel SMS on a phone ("post-delivery-status.com") | Still image (yours) → need a 5–8 s glasses clip |
| Websites/webshops | Fake Ray-Ban shop, ray-band.com, €9.90 | ✅ phone clip |
| Email | Gmail "Account restricted, verify my account" | Still photo (yours) → need a glasses clip |
| Letters & bills | Paper invoice/letter with a changed IBAN | ❌ need a clip |
| QR codes | Parking/payment QR sticker | ❌ need a clip |
| Calls | "Bank security" call asking for a code | ✅ scripted audio + caption |

All boxes and verdicts come from running the real server on frames of each clip (like the
hero), saved as JSON, so the simulator shows Second Look's actual output.

**Effort:** ~2–3 h once the clips exist.

## Needed from you
- **Clips from the glasses** (now that glasses video works): 5–8 s each, looking at the
  scam steadily — parcel SMS on a phone, the Gmail phishing email, a paper letter/bill,
  a QR sticker. Record with the glasses (Meta AI) and AirDrop them to the Mac.
- OK to go ahead with the glasses rebuild as described.
