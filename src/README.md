# Openstrator V6 — Milestone 6 Terminal build

M6 is the **Layer/Object Workflows** milestone. It preserves the complete M5.1 vector, typography, Appearance and raster stack while adding a real hierarchical Layers workflow, clipping groups, opacity masks, Embedded Objects, linked assets with embedded fallback, shared Symbols, Graphic Styles/resource libraries, and bounded asynchronous layer thumbnails.

## M6 build verification

1. Fully extract the ZIP for the matching Mac architecture.
2. Double-click `BUILD_OPENSTRATOR.command`.
3. The builder runs the **87-check framework-free M6 self-test**, compiles the native Openstrator product, verifies architecture, ad-hoc signs it, and publishes `Build Output/Openstrator.app` only after success.
4. Release packaging also runs the **126-test** portable OpenstratorCore suite plus M1→M6 source/acceptance regressions.
5. If native compilation fails, send `OPENSTRATOR_BUILD_LOG.txt`; diagnose the first compiler error first.

## M6 highlights

- Real nested layer/group tree with cycle-safe drag reparenting, reorder, expand/collapse, visibility, lock, rename, duplicate/delete, selection targeting, locate-selection, and layer accents.
- Clipping groups render through the selected clipping path; opacity masks support normal/inverted compositing and restore mask artwork when released.
- **Embedded Objects** preserve editable source payloads and original bounds, transform non-destructively, open in a separate editor window, support replace/expand, and guard nested recursion.
- Linked images keep a document-owned embedded fallback while optionally preferring a live external source; Links support state, Refresh, Relink and Embed.
- Symbols use shared definition payloads; instances update from one definition, can be placed/sprayed, and Detach expands them back to independent editable artwork.
- Graphic Styles store complete Appearance stacks and can be saved/applied. Resource libraries import/export reusable Embedded Objects, Links, Symbols and Graphic Styles as JSON.
- Layers use a bounded asynchronous `NSCache` thumbnail path so preview generation does not block canvas interaction or grow without limit.
- Existing M4 delete-lifecycle and M5.1 native compiler regressions remain mandatory release gates.

## Native verification note

This release is portable-verified in Linux for core logic, source/parser contracts, package parity and archive integrity. AppKit/SwiftUI native semantic compilation, linking, launch and runtime UI behavior remain authoritative on macOS via the included builder.

---

## Retained M5/M4 documentation

# Openstrator V6 — Milestone 5 Terminal build

M5 is the Raster Engine + Image Placement milestone. It preserves the M1–M4.1 vector, typography, Appearance, and delete-lifecycle work while adding embedded multi-image placement, Portrait/Landscape artboards, tiled RGBA raster operations, image paint/erase, pixel selections/masks, and a non-destructive Core Image filter stack.

## M5 build verification

1. Fully extract the ZIP on the matching Mac architecture.
2. Double-click `BUILD_OPENSTRATOR.command`.
3. The builder runs the **75-check framework-free M5 self-test**, builds only the native `Openstrator` app product, verifies architecture, ad-hoc signs it, and publishes `Build Output/Openstrator.app` only after success.
4. Development/release packaging also uses the **121-test** portable core suite and M1→M5 source/acceptance contracts.
5. If native compilation fails, send `OPENSTRATOR_BUILD_LOG.txt`; the first macOS compiler error is authoritative.

## M5 highlights

- Multi-select `File → Place Images…`, `Insert → Images…`, and Finder drag/drop through one import path.
- Original compressed image bytes embedded in `.openstrator`; each placed image has a separate object and asset UUID.
- Bounded preview decode cache; duplicate/copy-paste reuse embedded asset records instead of multiplying compressed bytes.
- Portrait/Landscape switching is idempotent, center-preserving, undoable, and does not rotate or move artwork.
- Sparse 256×256 RGBA8 tiles with crop, bilinear resample, source-over composite, pixel selections, 8-bit masks, Paintbrush and erase-to-alpha.
- Non-destructive Gaussian Blur, Motion Blur, Exposure, Brightness/Contrast, Saturation, Hue, Sepia, Sharpen, Noise, Pixelate, Crystallize, and Color Controls with preview/reset/cancel/apply.
- M4.1 compiler regressions and selected-object delete lifecycle checks remain mandatory release gates.

## Native verification note

This package was verified in a Linux portable environment for Swift core logic, parsing, source contracts, packaging parity, and archive integrity. AppKit/SwiftUI/Core Image semantic compilation, linking, launch, picker/drop behavior, and runtime image editing still require the included builder on macOS.

---

## Retained M4.1 documentation

M4 is the Appearance / Live Effects milestone. It keeps the M1 reliability, M2 Bézier/vector core, and M3 typography system, fixes the selected-object delete crash, and adds a persistent ordered appearance stack with multiple fills, strokes, typed live effects, effect visual bounds, an Appearance panel, live preview transactions, and vector-safe Expand Appearance.

## Build

1. Fully extract the ZIP on the matching Mac architecture.
2. Double-click `BUILD_OPENSTRATOR.command`.
3. The builder runs the **61-check framework-free M4 self-test**, builds only the native `Openstrator` app product, verifies its architecture, ad-hoc signs it, and publishes `Build Output/Openstrator.app` only after success.
4. XCTest remains in source for development but is not required by the Terminal build.
5. If compilation fails, send `OPENSTRATOR_BUILD_LOG.txt` and start with the first compiler error.

### M4.1 compiler repair
M4.1 keeps M4 behavior unchanged and repairs the native macOS Swift 6 compile failures found after the framework-free self-test: the Appearance effect-sheet frame overload and legacy `VectorEffect(kind:amount:)` construction sites.

## M4 highlights

- Delete/Backspace lifecycle fix: the Inspector no longer force-unwraps selected objects after deletion; direct-selection drag state and text/path references are repaired in the same transaction.
- Ordered `AppearanceStackV6` with independent fills, strokes, live effects, object opacity/blend, stable entry IDs, enable/disable, reorder, duplicate and remove.
- Multiple solid/linear-gradient fills and strokes with independent opacity, blend, stroke width, dash/cap/join data.
- Typed effect registry with validated parameter schemas for Gaussian/Motion Blur, Drop Shadow, glows, inner shadow/glow, Roughen, Zig Zag, Pucker/Bloat, Transform, Offset Path, Round Corners, Convert-to-Shape and Warp.
- Visual bounds evaluator keeps geometric bounds separate from blur/shadow/glow/transform-copy inflation.
- Appearance panel generated from stable IDs; no stale index bindings when rows are reordered or deleted.
- Live effect editor uses Preview / Reset / Cancel / Apply. Preview slider events do not create undo entries; Apply creates one undo snapshot and Cancel restores the exact pre-preview object.
- Expand Appearance creates editable artwork for vector-safe multi-fill/multi-stroke appearances, Transform copies, Offset Path, Round Corners and Convert-to-Shape effects.
- Raster-dependent expansion is explicitly deferred to M5 instead of silently producing fake vector geometry.
- Existing M3.1 files remain decodable. Legacy effects outside the typed M4 subset are retained and continue through the legacy renderer when an M4 stack is activated.
- SVG export emits ordered M4 paint entries and embeds the complete appearance stack as base64 JSON metadata so unsupported live behavior is not discarded.

## Verification status

Portable release verification before packaging: **101/101 OpenstratorCore tests** and **61/61 framework-free checks**. `scripts/m4_acceptance.sh` also verifies the delete regression, legacy bridge, renderer route, Appearance UI, Expand Appearance, SVG metadata, builder behavior, Swift parsing, icon alpha and Package.swift.

The final SwiftUI/AppKit/CoreText compile/link/launch still has to run on macOS because this verification runtime is Linux.

## Current M4 limits

M4 establishes the real Appearance graph but does not claim Illustrator-identical proprietary effect algorithms. Raster/pixel expansion belongs to M5. Roughen/Zig Zag/Pucker-Bloat/Warp have editable live parameters and lightweight display approximations; only effects with a safe geometry evaluator are expanded to vectors. Native text fills participate in M4; text stroke expansion is best performed after Create Outlines. Old effects outside the typed M4 registry remain available through **All Effects** and keep their previous lightweight renderer until later dedicated engines replace them.

---

# Openstrator 0.5 Pro Toolkit

Openstrator is an original, native macOS vector-design application written in SwiftUI/Core Graphics. It uses familiar professional vector-editing concepts while keeping its own name, icon, source code, visual design, and interaction details.

## Start it — Terminal

Double-click `BUILD_OPENSTRATOR.command` and follow its on-screen progress. On a successful compile, look for `Build Output/Openstrator.app`. Compiler errors remain in `OPENSTRATOR_BUILD_LOG.txt`.

## Pro Toolkit pass

Version 0.5 expands Openstrator to **89 selectable tools** and **124 effects/effect equivalents**. The compact left rail keeps common tools visible; use **••• → All Tools** to browse the complete tool library by category. The M4 **Appearance** panel exposes typed live effects plus **All Effects**, grouped by category, so the full legacy effect inventory remains reachable while deeper engines are migrated milestone by milestone.

Highlights include:

- Selection, Direct Selection, Group Selection, Magic Wand, Lasso
- Pen and anchor-point family, Curvature, Pencil, Paintbrush, Blob Brush, Smooth, Path Eraser, Join, Scissors, Knife, Shaper
- Rectangle, Rounded Rectangle, Ellipse, Polygon, Star, Line, Arc, Spiral, Rectangular/Polar Grid, Flare
- Full family of Type/Area/Path/Vertical/Touch Type tools
- Rotate, Reflect, Scale, Shear, Width, Reshape, Free Transform, liquify-style tools, Puppet Warp
- Gradient, mesh-style appearance, Eyedropper, Measure
- Blend, Shape Builder-style merge, Live Paint-style fill/selection
- Symbol Sprayer plus Shifter/Scruncher/Sizer/Spinner/Stainer/Screener/Styler
- Column/Stacked/Bar/Line/Area/Scatter/Pie/Radar graph tools
- Perspective, Artboard, Slice, Dimension, Objects-on-Path, Hand, Print Tiling, Rotate View, Zoom
- Reorderable, duplicate-able, toggleable non-destructive effect stacks
- Convert-to-Shape, Stylize, Blur, Color, Distort & Transform, Warp, Path, Pathfinder, 3D, Artistic, Brush Strokes, Raster Distort, Pixelate, Sketch, Texture, Video, Rasterize and SVG-filter-style effects

See `PRO_TOOLKIT.md` for the complete tool/effect inventory and `FEATURES.md` for implementation details and current limits.

## Files and export

- Native `.openstrator` JSON document format
- Open / Save / Save As
- Autosave recovery snapshot
- SVG export
- PNG export
- PDF export

## Performance

Openstrator is native SwiftUI/AppKit/Core Graphics with no Electron or embedded web runtime. Ordinary artwork remains compact vector model data. Intel and Apple Silicon projects use separate architecture settings and history/memory profiles. The requested 3 GB target is treated as a design guardrail rather than an absolute guarantee, because macOS ultimately controls process memory and unusually large documents can exceed any fixed target.

## Compatibility

- macOS 13 Ventura or later
- Xcode 15+ recommended
- No Adobe installation/runtime required

## Important scope note

The tool/effect names are used as a functional coverage checklist for common professional vector-editor workflows. Openstrator does **not** contain Adobe code or proprietary effect algorithms. Complex items such as gradient-mesh topology, exact Illustrator liquify/pathfinder mathematics, full Appearance graph semantics, advanced OpenType shaping, Illustrator `.ai` round-trip, and Adobe's proprietary 3D/material rendering are implemented as original lightweight equivalents or remain partial engine work. That keeps this project honest and maintainable instead of shipping buttons that falsely claim binary-identical behavior.

For commercial distribution, review `LEGAL-NOTES.md` and obtain appropriate legal advice.
