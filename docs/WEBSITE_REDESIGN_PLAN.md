# Orifold Landing — World-Class Origami Redesign (Rev 4)

**Status:** Planning → executing this session. Merge to main after a bug/perf loop.
**Why:** the current premium page is close but three things read as "cheap": (1) the hero mark is the crane-fold animation frozen on the flat app-icon square (looks like a big pixel-blue tile), (2) the story leans on the beige "Sample Proposal" app screenshots, (3) the pets are static bystanders. This redesign replaces the cheap parts with bespoke origami craft, weaves the pets in as living guides, and rewrites the story to feel like a brand experience — while keeping scroll buttery and the docs untouched.

**Keep (foundation is good):** the Astro route (`docs-site/src/pages/index.astro`), the design tokens, the scoped-to-`body.landing` architecture, the floating glass nav, the 7-act spine. This is a craft/asset/story overhaul, not a re-plumb.

---

## 1. Experience concept

**"One sheet, folded into flight."** The whole page is a single sheet of washi that folds, act by act, into a crane that finally takes off. The visitor is never shown a "dashboard of features" — they're walked through a calm studio where paper becomes something finished and signed. Two paper companions, **Gami** (warm, guides everyday users) and **Ori** (precise, guides the trust/dev story), live in the margins and react as you scroll — never blocking, always alive.

Tone: calm, confident, quietly premium. Apple product-theater restraint + Japanese *ma*. No SaaS blobs, no neon, no clutter.

---

## 2. Rewritten story (7 acts — new copy)

| Act | id | Eyebrow | Headline | One-line promise |
|---|---|---|---|---|
| Hero | `#sheet` | ORIFOLD · FOR MACOS | **Fold chaos into one clean PDF.** | A calm PDF workspace that never leaves your Mac. |
| Gather | `#gather` | FIRST FOLD · GATHER | **Fifty messy files. One quiet stack.** | Drag in the pile; broken files heal on the way. |
| Shape | `#shape` | SECOND FOLD · SHAPE | **Edit the page itself.** | Real glyphs, not sticky notes over a picture. |
| Seal | `#seal` | THIRD FOLD · SEAL | **A signature that holds up.** | Cryptographic PAdES, sealed like a hanko. |
| Keep | `#keep` | FOURTH FOLD · KEEP | **The studio has no windows.** | Nothing uploads. No account. No telemetry. |
| Why | `#ma` | 間 · THE MARGIN | **Why it folds this way.** | Document work shouldn't need a subscription. |
| Home | `#download` | FINAL FOLD · TAKE FLIGHT | **Take it home.** | One download. One calm first launch. |

Copy voice rules: short, concrete, fold metaphors, no superlatives, no invented capabilities. Timestamp claims stay stubbed (the §2.7 TSA fix isn't confirmed on main).

---

## 3. Visual system (frozen)

- **Palette (tokens only):** dark cinematic `--of-canvas`; cool `--of-accent`/`--of-accent-bright`; moon-white/graphite paper (`--of-paper` cool, never cream); **one red** `--of-tancho` — hanko seal + crane crown ONLY.
- **Type:** system stack. Display headline `clamp(3rem…6.5rem)`, weight 720, tracking −0.04em, line-height 0.95, `text-wrap: balance`. Body `1.05–1.2rem`, line-height **1.7**, max **60ch**. Eyebrows: pill, 0.72rem, tracking 0.16em. **Generous vertical rhythm**: act padding `clamp(7rem…12rem)`; header→body gap `clamp(1.25rem…2rem)`; never let a headline touch its body.
- **Surfaces:** radii 28/20/12; hairline `color-mix(text-1 14%)`; soft layered shadows; glass (`backdrop-filter`) **only** on nav + hero focal (perf).
- **Grid:** content max 1180px; comfortable gutters `clamp(2rem…6rem)`.

### 3a. Shared bespoke-SVG style spec (every new asset obeys this — for coherence)
- **Aesthetic:** flat, faceted geometric origami (paper planes of a few triangles), NOT skeuomorphic or gradient-mesh. Think folded-paper facets with subtle fold-shade between planes.
- **Colors:** use `currentColor` + a small set of CSS custom props (`--paper`, `--paper-2`, `--edge`, `--accent`, `--tancho`) so one asset re-themes via CSS; default fills reference the token hexes (paper `#eef1f5`/`#dfe5ec`, edge `#c3ccd6`, accent `#4fc3e8`, tancho `#e5564a`). Cool paper, no cream.
- **Line:** where strokes are used, 1.5 at a 24 grid (scales with viewBox). Corners crisp.
- **viewBox:** icons `0 0 24 24`; crane `0 0 400 320`; vignettes `0 0 640 420`.
- **A11y:** decorative → `aria-hidden`; meaningful → `<title>`. No raster embeds. Each ≤ target budget (§6).
- **Motion:** any animation is SMIL or CSS transform/opacity, finite, `prefers-reduced-motion`-safe.

---

## 4. Asset manifest (bespoke — replaces the cheap bits)

| Asset | File | Purpose | Author |
|---|---|---|---|
| **Hero crane** | `docs-site/src/assets/crane-hero.svg` | crisp faceted origami crane, subtle finite fold-settle + one tancho crown. Replaces the app-icon look. | me |
| **Feature icon set (6)** | `docs-site/src/assets/icons/*.svg` (or one sprite) | cohesive 24-grid origami line/facet icons: OCR, Compress, Forms, Stamps, Reader, Languages. Replaces CJK-glyph boxes. | agent |
| **Product vignettes (4)** | `docs-site/src/assets/vig/{gather,shape,seal,keep}.svg` | stylized origami "product moments" — scattered sheets → stack; a sheet with a live-edited line; a sheet with a hanko seal + verify ticks; a windowless studio with a sheet inside. Replaces beige screenshots as the primary visual. | agent |
| **Pet motion** | reuse `orifold-dog-wag.svg`/`orifold-cat-twitch.svg` inline + new idle/enter choreography | Gami & Ori animated, appearing/reacting per act. | me |
| **Decorative artifacts** | inline in CSS/markup | crease hairlines, folded corners, washi grain, fold-shadow drift. | me |

**Screenshot policy:** keep at most **one** real capture, in gorgeous framing, as an honesty proof low on the page ("this is the real app") — cropped to the cleanest UI, beige minimized. Everything else is bespoke SVG. No beige "Sample Proposal" hero.

---

## 5. Motion & pets (the "alive" requirement)

- **Scroll:** buttery — IntersectionObserver reveals only (no scroll listeners), transform/opacity, `will-change` used transiently. `scroll-behavior: smooth` (auto under reduced-motion).
- **Pets as living guides:**
  - Enter each act from the margin (`pet-arrive`, once), settle, then a **finite idle** (Gami tail-wag ×3 → rest; Ori ear-twitch/tail-sway ×3 → rest) via the existing SMIL, JS-gated so it plays on entry and stops (WCAG 2.2.2-clean, ≤1 pet animating at a time).
  - A speech line per act (≤12 words, in-voice) as accessible flow text.
  - Gami→Ori handoff at Seal (warm accent shift), same as before but smoother.
  - Reduced-motion/no-JS: static figures + visible bubbles.
- **Hero crane:** finite fold-settle on load, freezes; crown pops once (tancho).
- **Ambient:** ≤3 concurrent, finite, composited-only; disabled on mobile.

---

## 6. Performance budget (smooth is a feature)

- CSS ≤ 34KB raw; JS ≤ 6KB raw (IO-driven only, no scroll handlers).
- `backdrop-filter` ≤ 4 elements (nav + hero focal). None on scrolling cards/vignettes.
- Bespoke SVGs: crane ≤ 6KB, each icon ≤ 1KB, each vignette ≤ 5KB, pets as-is.
- Zero raster in the hero; the one real screenshot via `astro:assets` optimized.
- LCP = hero headline (text). No layout shift (explicit dims on media).
- Lighthouse ≥ 95 perf & a11y, both themes.

---

## 7. Build steps

1. Author `crane-hero.svg` (me).
2. Asset workflow (parallel, coherent groups): feature-icon set; 4 product vignettes; pet-motion inline snippets. Each follows §3a.
3. Rebuild `index.astro`: new story copy, bespoke crane hero with icon CTAs + generous spacing, vignette-led acts, pets woven in, one real-capture proof, refined footer.
4. New/rewritten stylesheet(s): keep `landing-premium.css` as the base but overhaul spacing/hierarchy/hero/CTA/icons/vignettes; remove the app-icon-crane + cheap-screenshot framing.
5. Verify (eval-based; screenshots blank on scroll here) across dark/light/mobile.
6. Bug/perf loop (workflow), build-gated.
7. Merge to main.

## 8. Guardrails
- Docs/Starlight untouched (premium + redesign scoped to `body.landing`, loaded only on the route).
- Honesty: real captures get chrome; stylized vignettes get an "Illustration" caption. No timestamp claims. No invented features. Version/stats stay dynamic.
- One tancho red. Cool paper only. Reduced-motion + no-JS fallbacks intact.
