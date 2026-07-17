# Wave 2 — Editing Depth + Brand Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Parent doc: `docs/FEATURE_WAVES_MASTER_PLAN.md`; source roadmap items #4, #9, #5 in `docs/OPEN_SOURCE_FEATURE_ROADMAP.md`.

**Goal:** Ship three "editing depth + brand" features — a font-substitution pack with Core-14 AFM metrics that hardens the text editor, a procedural hanko stamp studio, and barcode/QR insert + scan. All offline; except bundled fonts, zero-dependency.

**Order E → F → G** (F reuses E's FontRegistrar; G independent, largest UI, last). 12 tasks total.

## Anchor drift vs master brief (re-verified 2026-07-17, branch friendly-helper-claude/app-feature-roadmap-6b4c71) — RE-GREP before editing
- `editingFamilyName(for:fallback:)` = ReadingCanvas.swift:4385 (not :4383); call sites :2862/:3937/:4253.
- Blind `"Helvetica"` default = WorkspaceViewModel.swift:3024 (not :2868); a SECOND blind default hides in ReadingCanvas.swift:4434 (`editingFont`).
- Subset-tag/style strip = WorkspaceViewModel.fontFamilyRoot(_:) :2940–2946 (private static; subset "+" rule distance==6).
- Package.swift resources :33–38 (exact).
- `beginStampPlacement(text:swatch:)` DEFINED in WorkspaceViewModel.swift:4393 (StampPalette.swift:81 only calls it); commit flow placeStamp(at:on:size:) :4553, undo replaceDecorations(_:actionName:) :4579.
- SignatureAppearanceRenderer glyph infra = Orifold/Signing/Appearance/SignatureAppearanceRenderer.swift textOutlinePath :195–232, CTFontCreatePathForGlyph :225; PDFAppearanceStream defined SigningContracts.swift:215.
- **FPDFPageObj_NewImageObj is NOT bound anywhere.** Only FPDFImageObj_SetBitmap (PDFCompressionService.swift:40, bitmap replace) + FPDFPage_InsertObjectAtIndex (PDFiumObjectBindings.swift:100). **Feature G must NOT attempt a PDFium image-object insert — use the decoration/CGContext bake pipeline.**
- PDFOCRService.renderedImage(for:) :277 is private static — expose for G3.
- Vermillion already defined: Color.dsSignatureAccent (DesignSystem.swift:87 "Shu-iro"). Baker uses *NS colors — may need dsSignatureAccentNS.
- OrifoldApp.swift applicationDidFinishLaunching(_:) :57 = font-registration site.

## Cross-cutting gotchas (apply every task)
- (a) xcstrings inserts ORDER-PRESERVING: Python OrderedDict round-trip, no sort_keys, insert at sorted position. Entry `{"extractionState":"manual","localizations":{lang:{"stringUnit":{"state":"translated","value":…}}}}` for en/es/fr/hi/ja/zh-Hans.
- (b) All user-facing strings via L10n.string(_, locale:); RawLocalizationKeyLeakTests fails on raw dotted keys in Text/Label/Button/Toggle/Menu/help/etc. Live-switch views must read @Environment(\.locale).
- (c) Safe bundle resolution mirroring L10n.swift:29–56 (probe Bundle.main/anchor URLs); NEVER trapping Bundle.module. FontRegistrar (E3) provides one shared resolver; F2 reuses.
- (d) CI-safe extraction: NEVER assert PDFPage.string equality (Xcode 16.4 quirk). Use PDFium FPDFText, attributedString, or thumbnail-pixel-brightness (NSBitmapImageRep.colorAt → brightnessComponent). Font checks via CTFontCopyPostScriptName/familyName.
- (e) Fonts need runtime registration: no existing CTFontManagerRegister* in repo. Register process-scope at launch via CTFontManagerRegisterFontsForURL before first editor render; idempotent (treat "already registered" as success).
- (f) Warm-cache focused tests during; ONE full `swift test` per feature; commit per task; DO NOT push (recovery branch).

## Medium-confidence risks / mandatory hands-on
- CJK/substituted-font EMBEDDING bloat: hanko + signatures render glyphs to vector CGPaths (no font embedded — appearance test asserts no /F1). E substitutes only in editor/display. E4 SIZE SPIKE: edit unembedded-Arial text, export, measure byte delta vs system font; flag if >2–3 MB/doc → constrain E to display-only substitution + export warning.
- Hands-on GUI unavoidable: E4 (editor shows Liberation metrics, no reflow), F3 (live hanko preview/placement/export survive), G2 (barcode placement+export), G3 (scan sheet, copy, open-link confirm).

---

## Feature E — Font-substitution pack + Core-14 AFM metrics

### Task E1: FontSubstitution table + service
- Create Orifold/Engine/Fonts/FontSubstitutionTable.swift + Tests/OrifoldTests/FontSubstitutionTableTests.swift
- `enum FontSubstitution { static func familyRoot(_:) -> String; static func substituteFamily(for pdfFontName:) -> String? }`. Table: ArialMT→Liberation Sans, TimesNewRomanPSMT→Liberation Serif, CourierNewPSMT→Liberation Mono, Calibri→Carlito, Cambria→Caladea; subset tag + style strip (mirror fontFamilyRoot distance==6); nil for unknown/already-substituted.
- Tests: familyRoot strips subset+style; maps core metric equivalents (incl subset-tagged + bold); unknown→nil. Commit: `feat: metric-compatible font substitution table`.

### Task E2: AFM Core-14 metrics parser
- Create Orifold/Engine/Fonts/AFMMetricsStore.swift + test. `struct AFMFont{fontName;glyphWidths;advanceWidth(glyphName:);width(of:)}`, `enum AFMMetricsStore{parse(_:)->AFMFont?; core14(_:)->AFMFont?}`. Parse `C <code> ; WX <w> ; N <glyph> ;` between StartCharMetrics/EndCharMetrics; FontName. Inline-fixture tests (Helvetica A=667, space=278); malformed→nil. Commit: `feat: AFM Core-14 metrics parser`.

### Task E3: Bundle fonts + AFMs, register at launch, wire fallback
- Create Orifold/Engine/Fonts/FontRegistrar.swift; add Orifold/Resources/Fonts/*.ttf (Liberation Sans/Serif/Mono OFL-1.1, Carlito OFL-1.1, Caladea Apache-2.0) + Fonts/AFM/*.afm (Core-14, Adobe AFM license file). Modify Package.swift resources (add `.copy("Resources/Fonts")`), OrifoldApp.swift:57 (call FontRegistrar.registerBundledFonts()), ReadingCanvas.swift:4385 + :4434, WorkspaceViewModel.swift:3024, THIRD-PARTY-NOTICES.md.
- `enum FontRegistrar { registerBundledFonts(); fontsDirectoryURL()->URL?; afmURL(forResource:)->URL? }` idempotent, L10n-style resolver, CTFontManagerRegisterFontsForURL(.process). Wire substituteFamily into editingFamilyName + replace blind Helvetica with `FontSubstitution.substituteFamily(for: fallback) ?? "Helvetica"`.
- Tests: bundled families resolve after registration; idempotent; bundled Helvetica AFM A=667. Commit: `feat: bundle + register substitution fonts, wire editor fallback`.

### Task E4: Verify substituted metrics + size spike
- Test FontSubstitutionRenderTests: unembedded ArialMT → "Liberation Sans" not "Helvetica" (assert via familyName, NOT PDFPage.string). Size spike: edit unembedded-Arial text, export, compare bytes vs system font; flag >2–3MB. Full swift test + hands-on. Commit: `test: edited text resolves to substituted metrics; embedding spike`.

---

## Feature F — Hanko stamp studio (depends on E's FontRegistrar)

### Task F1: HankoRenderer (pure geometry+glyph→CGPath/PDF)
- Create Orifold/Engine/Stamps/HankoRenderer.swift + test. `struct HankoConfig{Shape(.circle/.square);text;inkColor}`, `enum HankoRenderer{outlinePath(for:in:)throws->CGPath; pdfAppearanceStream(for:bounds:)throws->PDFAppearanceStream; draw(_:in:context:)throws}`, `HankoError{emptyText,invalidSize}`. Vertical CJK stack 1–4 glyphs; border CGPath(ellipseIn:)/(rect:). Reuse SignatureAppearanceRenderer glyph loop + scale-to-fit :157–172.
- Tests: deterministic path bounds; glyphs+border within bounds; appearance stream self-contained vector (contains " rg","f"; NO "/F1"); empty text throws. Commit: `feat: procedural hanko renderer (border + vertical glyphs → path/PDF)`.

### Task F2: Bundle Shippori Mincho + register
- Add Orifold/Resources/Fonts/ShipporiMincho-Regular.ttf (OFL-1.1). FontRegistrar already registers Fonts/. THIRD-PARTY-NOTICES OFL entry; dsSignatureAccentNS if baker needs it. Test: Shippori provides rich CJK glyph (path segments>12). Commit: `feat: bundle Shippori Mincho for hanko seals`.

### Task F3: StampPalette UI + PageDecoration .hanko + baker + placement
- Modify PageDecoration.swift (add .hanko Kind + shape/hankoText, migration-safe decodeIfPresent), PDFDecorationExportBaker.swift (drawHanko + validate/switch; AUDIT annotation-leak per 2026-07-07 lesson), WorkspaceViewModel.swift (pendingHankoOptions/beginHankoPlacement/placeHanko clone placeStamp:4553 → replaceDecorations actionName:"Place hanko"), StampPalette.swift (hanko sub-panel: name field, circle/square picker, live HankoRenderer preview, jitsuin disclaimer), ReadingCanvas.swift:712 gesture.
- Test HankoDecorationBakeTests: bake → thumbnail brightness at seal center redComponent>blueComponent (vermillion). Commit: `feat: hanko decoration + baker + placement wiring`.

### Task F4: L10n ×6 + hands-on
- Keys: hanko.title/.nameField/.shape.circle/.shape.square/.place/.disclaimer ("Decorative seal — not a registered jitsuin (実印)."). Coverage + RawLocalizationKeyLeak pass. Hands-on. Commit: `feat: hanko studio localization (6 languages)`.

---

## Feature G — Barcode/QR insert + scan (NO PDFium image-object; bake pipeline)

### Task G1: BarcodeGenerator (Core Image)
- Create Orifold/Engine/Barcode/BarcodeGenerator.swift + test. `enum BarcodeSymbology{qr,aztec,code128,pdf417}`, `image(for:symbology:scale:)throws->CGImage`, `BarcodeError{emptyPayload,payloadTooLong(max:),generationFailed}`. CIFilter (CIQRCodeGenerator/CIAztecCodeGenerator/CICode128BarcodeGenerator/CIPDF417BarcodeGenerator), integer upscale. Tests: non-empty per symbology; empty throws; oversize throws. Commit: `feat: Core Image barcode/QR generator`.

### Task G2: Insert as .image decoration (bake lane) + placement UI
- Modify PageDecoration.swift (.image Kind, imageData:Data? migration-safe — precedent SignaturePlacement.swift:90), PDFDecorationExportBaker.swift (drawImage: context.draw(cgImage,in:rect) like SignatureExportBakingSupport.drawPlacement:377, interpolationQuality=.none), WorkspaceViewModel.swift (beginBarcodePlacement/placeBarcode), StampPalette.swift or new BarcodeComposerView.swift. Store PNG Data on decoration; undo actionName:"Insert barcode".
- Test BarcodeInsertBakeTests: bake QR → thumbnail brightness<0.6 at module region. Commit: `feat: insert barcode as baked image decoration + composer UI`.

### Task G3: BarcodeScanner (Vision)
- Create Orifold/Engine/Barcode/BarcodeScanner.swift; expose PDFOCRService.renderedImage. `struct DetectedBarcode{payload;symbology}`, `scan(_ image:)->[…]`, `scan(page:)->[…]`. VNDetectBarcodesRequest (mirror PDFOCRService:210–216). Tests: generate→detect round-trip QR + Code128; blank→none. Commit: `feat: Vision barcode scanner (generate↔detect round-trip)`.

### Task G4: Toolbar/More-menu + result sheet + L10n ×6
- Modify ContentView.swift (More menu), create BarcodeScanResultSheet.swift. "Scan barcodes on this page" → list payloads, Copy each, Open-link behind explicit confirm (untrusted — show full URL, never auto-open). "Insert barcode/QR…" opens G2 composer. Keys: barcode.insert.title/.symbology.label/.payload.label/.scan.title/.result.copy/.result.openLink/.result.empty/.error.tooLong. Commit: `feat: barcode insert/scan menu + result sheet + localization`.

---

## Wave 2 close-out
- Bump version; write docs/release note. `swift build -c release` (silgen/WMO — G touches binding surface) + full swift test. Confirm DMG size delta from ~8MB font bundle. Delete stale Orifold.app, install fresh, click through E/F/G. Tick master Status rows. Hold pushes (recovery branch) unless instructed.
