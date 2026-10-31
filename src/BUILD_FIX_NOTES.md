# Openstrator V6 M6 — Layer/Object Workflows

- Added cycle-safe `LayerTreeV6` and shared `ResourceLibraryV6` core models with backward-compatible optional app fields.
- Added native hierarchy bridge and Layers panel workflows for nested groups, reorder/reparent, visibility/lock, rename, selection targeting and accents.
- Added clipping-group and opacity-mask compositing paths.
- Added Embedded Object, linked-asset, Symbol, Graphic Style/resource-library and async thumbnail runtimes.
- Expanded framework-free release preflight from **75 M5 checks to 87 M6 checks**; portable core suite is **126 tests**.
- Added M6 source contracts plus a macOS compiler-risk regression covering cross-file visibility, explicit module/AppKit imports, actor isolation and numeric bridges.
- Preserved M4 delete lifecycle and M5.1 macOS compiler repair regressions.

---

# Openstrator V6 M5.1 — native macOS compiler repair

- Imported `OpenstratorCore` in both raster runtime files so public Raster V6 types resolve in the app target.
- Split the raster brush pixel-scale expression into compiler-friendly typed subexpressions.
- Grouped Artboard/Raster/View menus into an `@MainActor Commands` type to avoid SwiftUI CommandsBuilder arity failure.
- Added and wired `scripts/m5_1_mac_compiler_regression.py`.

---

# Openstrator V6 M5 — Raster Engine + Image Placement

## M5 additions
- Added center-preserving, idempotent Portrait/Landscape active-artboard commands with normal undo/redo snapshots.
- Added backward-compatible optional raster asset/object fields so M4.1 documents still decode without raster keys.
- Added multi-image placement, URL drag/drop, embedded compressed bytes, bounded decode caching, and missing-image fallback.
- Added tiled RGBA8 crop/resample/composite, edge-clamped selections/masks, Paintbrush/Eraser pixel editing, and PNG re-embedding.
- Added non-destructive Core Image filter runtime and Raster Inspector/menu with preview transactions.
- Preserved M4.1 Swift 6 compiler regression checks and the selected-object delete lifecycle regression.

---

# Openstrator V6 M4.1 — Appearance / Live Effects + macOS compiler repair

M3 builds on the M1 reliability and M2 Bézier/vector foundation and replaces the old single-style text object with a backward-compatible professional typography subsystem.

- rich `TextDataV6` model with character, paragraph, run, glyph-transform, path, threading and warp data;
- old M2 text payloads decode into safe M3 defaults;
- native macOS installed-font family/face enumeration and CoreText variable-font axes applied through native font descriptors;
- deterministic missing-font fallback and native `NSSpellChecker` integration;
- area/vertical-area frame capacity, overflow flow, and safe linked-frame ordering;
- Type on Path follows Bézier length/tangents and supports offsets/flip;
- Touch Type persists per-glyph offset/scale/rotation;
- non-destructive warp geometry for 11 professional warp presets;
- all seven Type tool modes wired to editor actions;
- `TypographyRenderer` renders rich character/paragraph/path/vertical/glyph-transform/warp data;
- `TextOutliner` uses CoreText glyph paths and converts them to editable cubic Openstrator paths;
- detailed Typography Inspector and full macOS Type menu;
- SVG export now preserves M3 font/layout/path/vertical/warp information;
- framework-free release preflight expanded from **37 M2 checks to 49 M3 checks**;
- source-side core suite expanded from **72 M2 tests to 84 M3 tests**;
- Terminal builder remains XCTest-independent and explicitly builds only the Openstrator app product.

M1/M2 fixes remain intact: Delete/Backspace routing, canonical pointer conversion, stable transforms and modifier resizing, adaptive grid, transparent icon, cubic Bézier paths, Direct Selection, Pen/Curvature/Pencil, smart snapping, multi-artboards, and closed-seam Scissors cutting.
## M3.1 macOS compiler compatibility fixes

- Added a conditional explicit CoreGraphics import for `CGSize` default arguments under Swift 6 while preserving Linux verification.
- Bridged synchronous Canvas typography rendering through `MainActor.assumeIsolated`, matching the renderer's AppKit font-catalog isolation.
- Removed the Swift 6-invalid conditional downcast from `Any` to CoreFoundation `CTFont` in Create Outlines; the line uses the single CTFont already applied to its attributed string.
- Made `makeGlyphs` private because it returns the private `RenderGlyphV6` helper type.
- Replaced an unmutated `var Text` with `let`.
- Added `scripts/m3_macos_compile_regressions.py` to the acceptance gate so these exact regressions cannot silently return.


## V6 M4 delete lifecycle fix
- Inspector object bindings now keep a fallback snapshot and never force-unwrap a deleted object.
- Delete clears whole-object/direct-selection drag state before removing objects.
- Text-on-path and threaded-text references to deleted objects are repaired in the same delete transaction.

## V6 M4 Appearance / live effects
- Added ordered `AppearanceStackV6` with multiple fills/strokes and stable IDs.
- Added typed effect schemas, range/type validation and visual-bounds evaluation.
- Added M4 Appearance panel and Preview/Reset/Cancel/Apply transactions.
- Added vector-safe Expand Appearance and explicit M5 raster-expansion blocking.
- Preserved legacy M3.1 effects outside the M4 typed subset through the compatibility renderer.
- Added ordered M4 SVG paints plus full appearance metadata preservation.
- Framework-free preflight expanded to 61 checks; core suite expanded to 101 tests.

## V6 M4.1 macOS Swift 6 compiler fixes
- Split the invalid SwiftUI `.frame(width:minHeight:)` call into separate width and minimum-height modifiers.
- Restored an explicit `VectorEffect(id:kind:amount:enabled:)` compatibility initializer after M4's custom `init?(live:)` removed Swift's synthesized memberwise initializer. This keeps five legacy effect-creation paths compiling while they continue to migrate through the M4 Appearance bridge.
- Removed the unused `.color(let color)` binding reported by the macOS compiler.
- Added `scripts/m4_1_mac_compiler_regression.py` to the M4 acceptance gate to pin these exact failures.
