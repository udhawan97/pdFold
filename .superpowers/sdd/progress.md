# SDD Progress Ledger — Open-Source Feature Waves

Branch: friendly-helper-claude/app-feature-roadmap-6b4c71 (base 875b8f4 = origin/main). Repo path /Users/umang/Documents/development/github/Orifold is a SYMLINK → Orifold.nosync (user's anti-iCloud fix; both work).
Mode: continuous, all 4 waves, no inter-task check-ins. Then /update-docs + v0.9.0 release + merge to main.

## User decisions (2026-07-17)
- BLOCKED feature → skip, note, keep going. RELEASE → ship whatever built+green+merged. VERSION → v0.9.0. Ask layman Qs w/ options at genuine forks.

## Environment: iCloud evicted the repo mid-run → user turned off iCloud sync + renamed to Orifold.nosync (symlink). Recovered via bundle + fresh clone. Recovery backups at /private/tmp/orifold-recovery/. All 4 wave plans committed to docs/.

## ✅ WAVE 1 COMPLETE (787 tests pass)
- A spell-check: DONE+review-clean (331e38e/d8a09df/7533c1e)
- B metadata editor: DONE+reviewed+FIXED (B1-4 7cd11c3/12f374d/64cb411/43fb865/59782d9; fixes ecf04cb/8bfd618/bf3209a for export-drops-metadata, XMP-lie, undo-stale)
- D CC0 sample doc: DONE+reviewed+FIXED (e265162/e7faaad; fix 0b19c9b register in project.yml; +typesetMarkdown engine fix verified safe)
- C read-aloud: DONE (7748ed2/7cc4da7/bea3651/7bb3bb1). Review found 2 CRITICAL crash risks (unclamped NSRange→page.selection crash; no defense vs doc-mutation-while-speaking) + 2 IMPORTANT (delegate main-hop; eager synth). FIX QUEUED — brief /private/tmp/orifold-recovery/feature-C-fix-brief.md, dispatch as sole builder after Feature E. Not "done well" until fixed.

## ▶ WAVE 2 IN PROGRESS — plan docs/WAVE_2_PLAN.md. Order E→F→G (12 tasks).
- E fonts (subst pack + AFM): DONE (4883277/406fdeb/6e6b499/f96620a), 810 pass. 20 TTF + 14 AFM ~7.8MB. E4 SPIKE: export delta -1.2KB (CoreGraphics subsets glyphs, NO bloat) → substitution safe on export + DE-RISKS Wave 4 Feature O embedding. Caladea now OFL-1.1 upstream (cited). project.yml Fonts as type:folder + xcodegen verified. Review IN PROGRESS (a8449ed3).
- C-FIX: DONE (e4f3f5a/9432d55/dc2386e/a069149), 815 pass. Both criticals TDD'd (clamp + auto-stop-on-doc-change). Feature C now done well.
- E-FIX: DONE (e9a5c61/ec5ae66), 818 pass. Raw /BaseFont name plumbed; Calibri→Carlito & Cambria→Caladea now fire uninstalled (seam-tested). Feature E done well.
- F hanko: DONE + review CLEAN (no fix). 826 pass. Minor non-bug notes for final sweep: add legacy-PageDecoration decode fixture test (hankoShape default); stale doc comment (HankoRenderer.pdfAppearanceStream is dead code, real path = drawHanko→draw); bake pixel test can't tell glyph-missing from border-only.
- G barcode: DONE (d48e993/b0ddd8e/8fac691/d7d54d8), 835 pass, +9 tests. Bake-pipeline .image decoration; open-link behind confirm; no bindings. Review IN PROGRESS (a45925e1). Minor notes: sync scan ~1s warmup; "characters" wording vs UTF-8 bytes.
- ✅ WAVE 2 COMPLETE (835 pass). Status ticked 017c0e1. Build verified green 1.24s.
- G-FIX (do INLINE after J + release-gate, ~10 lines): (1) BarcodeGenerator.swift:32 QR maxPayloadBytes 2953→2331 (advertises Level-L cap but generates at Level-M → 2332-2953 band silently .generationFailed with no preview/error) + test the band throws payloadTooLong; (2) WorkspaceViewModel.swift:~4765 scanBarcodesOnCurrentPage wrap in Task.detached + main hop for barcodeScanResults (sync Vision on main = ~1s UI freeze; repo OCR uses Task.detached). Wording "characters"→bytes optional.

## ▶ WAVE 3 IN PROGRESS — plan docs/WAVE_3_PLAN.md. Order J→I→K (H BLOCKED).
- J booklet/N-up: DONE (e659ec8/d911e25/89ad8e8/92ee9eb), 847 pass, +12 tests. Added 4 bindings (3 planned + FPDFPage_New for odd-count blank leaves), each bound once, zero re-decls. Flowed imposed bytes THROUGH sanitize+encrypt (good deviation). RELEASE-BUILD GATE RUNNING (bg b8mihfv06) — must pass before building on top. Review pending (diff-only).
- RELEASE-BUILD GATE: ✅ PASSED (84.6s, linked) — J's 4 bindings release-clean.
- G-FIX: DONE inline (f9f7a26) — QR cap 2953→2331 (Level-M) + async off-main barcode scan. Feature G done well.
- J review: DONE. Bindings+math CLEAN (4 bindings byte-verified, no leak/double-free, booklet math n=4/5/8/12 ok, no security bypass). 1 IMPORTANT: imposition silently drops comments (live annots) + unlocked form values; print path uses lockFormAnswers=false; disclosure only names stamps/sig/markup. J-FIX QUEUED (brief /private/tmp/orifold-recovery/feature-J-fix-brief.md) = force-flatten forms when imposition active + fix print options + disclose comments/forms. Dispatch after I, before K.
- I attachments: IN PROGRESS (sole builder aebfdf56) — 0 new bindings (qpdf name-tree walk + qpdfjob add/remove). Then K scan cleanup (0 bindings). H compression BLOCKED (skip).
- E review DONE: found CRITICAL (conf90) — substitution fed already-normalized fontName, so Calibri→Carlito & Cambria→Caladea DEAD, Arial/Times/Courier work only incidentally. + test-assertion gap. E-FIX QUEUED (brief /private/tmp/orifold-recovery/feature-E-fix-brief.md) = plumb raw /BaseFont name to substitution. Dispatch after C-fix.
- REVIEW POLICY (velocity): new features get diff-only review (they keep finding real bugs); FIXES trusted via their TDD RED→GREEN proof + full suite + FINAL whole-branch review backstop (no per-fix re-review).
- F hanko studio: PENDING (reuses E's FontRegistrar — now exists). G barcode/QR: PENDING (insert via decoration-bake, NOT PDFium image-obj — FPDFPageObj_NewImageObj unbound). FontRegistrar (F2 Shippori) ready to reuse.

## Waves 3 & 4 — planned, NOT started
- Wave 3 (docs/WAVE_3_PLAN.md, 14 tasks, order J→I→K→H): I attachments (0 bindings, qpdf), J booklet/N-up (+3 bindings FPDF_ImportNPagesToOne/ImportPages/CreateNewDocument), K scan cleanup (0 bindings, Vision+vImage), **H compression = BLOCKED (from-source qpdf rebuild, ship inert wiring only, skip per user)**.
- Wave 4 (docs/WAVE_4_PLAN.md, 19 tasks, order N→M→L→P→O): L translation (macOS15 #available, repo's first), M archival hints (+1 binding FPDFCatalog_IsTagged), N structure inspector (+9 StructTree bindings), O CJK pack (SPIKE-GATED embed-bloat, NEEDS Wave 2 FontRegistrar → after Wave 2), P CBZ (NEW DEP ZIPFoundation MIT).

## CROSS-CUTTING LESSONS (apply every feature)
- Any bundled resource / SPM dep → BOTH Package.swift AND project.yml, then `xcodegen generate` + commit pbxproj (else ships dead in Xcode build — bit Feature D).
- New PDFium symbols need @_silgen_name bindings (don't re-declare existing — release-build dup-type hazard). Release build (swift build -c release) after any wave that adds bindings (3-J, 4-M/N/O) + final before release.
- CI-safe: never assert PDFPage.string (Xcode 16.4 quirk); use FPDFText / thumbnail-brightness. L10n.string everywhere; xcstrings order-preserving inserts. Safe bundle resolution (never Bundle.module).
- Single .build per checkout → ONE builder at a time (implementers serial); diff-only reviews + /tmp-writing planners run parallel.

## EXECUTION MODEL
- One implementer subagent per feature (sole builder), TDD, commit-per-task, no push. Diff-only review per feature. Fix bugs found (sole builder) before feature counts done.
- After all doable features: full swift test + swift build -c release + tick master Status + /update-docs + v0.9.0 (project.yml/Package.swift + docs/release-v0.9.0.md) + merge to main.

## Close-out checklist (pending): Wave 1/2/3/4 status ticks in docs/FEATURE_WAVES_MASTER_PLAN.md; release build; /update-docs (README, docs-site, changelog); v0.9.0; merge+push main.
