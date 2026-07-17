# PDFium Processing Backend

Orifold keeps PDFKit as the native display and composition engine. PDFKit owns `PDFView`, `PDFDocument`, `PDFPage`, `PDFAnnotation`, selection, search, printing, export assembly, and workspace page ownership.

PDFium is a supplemental, in-process local backend. It is bundled with the app—not a service, daemon, subprocess, document upload, or telemetry path—and currently provides:

- non-blocking PDF validation during import;
- glyph geometry and render-mode data for inline text editing;
- a bounded page-object inspection pass for text render regions, rule graphics, and editable-object maps;
- structural image/path/form-object transforms, restacking, and deletion;
- image downsampling during compression; and
- content regeneration plus `SaveAsCopy` for structural object commits.

## Shared page inspection

`PDFPageObjectInspection` owns the page-object enumeration loop and its safety cap. A single snapshot projects:

1. text-object bounds and render modes for `PDFTextAnalysisEngine`;
2. `PageGraphicsIndex` horizontal/vertical rules for underline and table-aware text logic; and
3. `PageObjectMap` entries for object selection and editing.

`PDFObjectDetectionEngine` supplies classification and stable identity, while `PDFPageObjectInspection` owns page lifecycle, enumeration, and degradation behavior. This prevents the text and object features from maintaining divergent PDFium loops.

## Deterministic edit replay

Inline text changes and structural object changes are persisted as operations, not treated as unrelated baked snapshots. `WorkspaceEditReplayEngine` rebuilds a member PDF from canonical base bytes by:

1. applying every object operation through `PDFObjectEditEngine`;
2. re-composing each page's text operations over the object-edited result;
3. restoring current rotations and non-bookkeeping annotations on every member page;
4. attaching a combined text+object bake stamp to edited pages; and
5. serializing the member once.

The same path serves direct commits and load/export reconciliation. If bytes and operations diverge, both operation lanes replay together, so repairing a stale text bake cannot revert an object move and an object commit cannot discard text.

## Structural-write safeguards

`PDFObjectEditEngine` holds the process-wide `pdfiumLock`, resolves targets by stable structural digest, applies mutations, touches parsed path fill/stroke colors before `FPDFPage_GenerateContent`, and saves one non-incremental copy. Unresolved object IDs are reported to the caller instead of being silently treated as applied.

The current Swift Package integration uses `Packages/PDFiumBinary`, which wraps the vendored macOS/iOS PDFium XCFramework. See `Orifold/Resources/THIRD-PARTY-NOTICES.md` for attribution and license details.
