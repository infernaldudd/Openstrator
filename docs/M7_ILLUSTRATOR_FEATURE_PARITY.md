# Openstrator V6 → Illustrator-class capability matrix (M7 umbrella)
Last reviewed: 2026-11-22. Reference release: Adobe Illustrator 31.0 (November 2026).

This is a **functional-comparability target**, NOT a claim that Openstrator already has Adobe Illustrator parity. Openstrator remains independently designed; do not copy Adobe artwork, branding, proprietary code, UI trade dress, or service endpoints.

## Source of comparison
- [Adobe official toolbar tool reference (updated 2026-11-13)](https://helpx.adobe.com/illustrator/desktop/get-started/learn-the-basics/illustrator-tools-reference.html)
- [Illustrator 31.0 November 2026 release notes](https://helpx.adobe.com/illustrator/desktop/new-features/release-notes.html)
- [Adobe generative features FAQ](https://helpx.adobe.com/illustrator/desktop/use-generative-ai/generative-ai-faq-illustrator.html)
- [Openstrator V6 design spec](../src/docs/superpowers/specs/2026-09-23-openstrator-v6-design.md) (if present; check release source)

Status legend: **foundation** = core code/portable tests exist; **partial** = some workflows exist but equivalence unproven; **missing** = requires implementation; **unverified** = native UX/output needs inspection. A public feature must not be marketed as working until macOS launch, undo/redo, persistence, interaction and export tests pass.

| Domain | Illustrator-class coverage target | Openstrator at M6.1 | M7+ acceptance |
|---|---|---|---|
| Selection & navigation | Selection, direct/group select, magic wand, lasso, artboard, rotate view, print tiling, snapping, isolation | Foundation / partial | Geometric hit tests across nested groups, all zoom levels |
| Draw & edit paths | Pen, Curvature, Pencil, anchors, scissors, knife, smoothing, join, shaper, flares, complex shape tools | Foundation / partial | Editable Bézier topology and deterministic undo/export |
| Stroke/brush system | Brush definitions (calligraphic, art, scatter, pattern, bristle), stroke profiles, Width tool, live preview, pressure where supported | M7.1a implemented: 5 editable open-path width-profile presets, true outline geometry, Appearance/undo/save/SVG; other brush families and knot editing missing | Brush library, true variable-width geometry, live edit |
| Construction / fills | Shape Builder, Pathfinder, Live Paint, meshes, freeform/linear/radial gradients, pattern swatches | Partial / missing advanced systems | Real intersect/split/paint geometry; editable serialized swatches |
| Symbol family | Sprayer, shifter, scruncher, sizer, spinner, stainer, screener, styler, shared definitions | Shared definitions foundation; advanced tools missing | Definition edits update all instances; scatter transforms undoable |
| Perspective & warp | Perspective grid/selection, envelope distortion, Puppet Warp, liquify-family controls | Missing / incomplete | Editable geometry, inverse hit tests, export |
| Blends | Steps, specified distance, spine replace, orientation, smooth/easing controls, on-canvas handles | Unverified | Continuous interpolations, live edit and visual tests |
| Graphs & measurement | Column/stacked/bar/line/area/scatter/pie/radar, editable data, measure/dimension | Unverified / missing production graph engine | Data changes update chart; deterministic SVG/PDF |
| Typography | Point/area/path/vertical, touch type, variable fonts, text flow, glyphs, outlines, OpenType, paragraph | Foundation / partial | Font fidelity, text warp, transform bounds, RTL/CJK, import/export |
| Layers & appearance | Hierarchy, masks, clipping, isolation, appearance stack, symbols, graphic styles, resource libraries | Foundation / partial | Complete tree editing, transparency compositing, stable thumbnails |
| Raster & images | Place/embed/link, masks, painting, filters, image tracing, color adjustments | Foundation / partial; Image Trace not yet verified | Original pixels preserved, bounded cache, source-quality export |
| Effects & 3D | All vector/raster effect families; true 3D extrusion, revolve, materials, lighting, perspective, ray-trace-like quality modes | Partial simple effects; advanced 3D missing | Non-destructive parameterized effects with precision bounds |
| Document/color/print | Artboard setup, RGB/CMYK/spot swatches, overprint, proofing, bleed, print, slices | Partial / missing prepress | Color profiles explicit, output verified, no silent loss |
| Import/export | AI/PDF/SVG where legal/feasible, EPS, PNG/JPEG/TIFF, export selection/screens, batch, asset collection | Partial | Fidelity fixtures; clear loss reports for unsupported formats |
| UI/workspaces | Complete command registry, tool options, configurable toolbars, dockable panels, search, shortcuts | Partial | Every enabled command has behavior, history and validation |
| Accessibility/performance | Keyboard access, VoiceOver, multi-artboard perf, memory pressure, Intel/ARM parity | Unverified | QA measurements, typical working set target <3 GB |
| AI-assisted workflows | Vector generation, recolor, pattern generation, background removal, vector tracing, smart editing, assistant | Missing; service-dependent | Optional provider-agnostic and permission-based, not a copied Adobe service |

## M7 delivery sequence (umbrella; NOT one unreviewed mega-commit)
- [ ] **M7.0 correctness gate:** test the real Mac screenshots; artboard clipping, text transform/warp selection boundaries, save/reopen, native compile on both architectures.
- [ ] **M7.1 vector stroke system:** widths/profiles, brushes (all five families), brush library, pressure/tilt fallbacks.
- [ ] **M7.2 construction:** Shape Builder, Live Paint, compound paths, Pathfinder, image trace, color swatch upgrades.
- [ ] **M7.3 gradients/patterns:** freeform & mesh gradients, editable patterns, appearance integration.
- [ ] **M7.4 perspective/distortion:** perspective selection, envelope mesh, Puppet Warp, liquify tools and transform math.
- [ ] **M7.5 symbols/graphs/blends:** full symbol tool family, data-backed graph families, editable blend/easing controls.
- [ ] **M7.6 3D/effects:** 3D forms/materials/lighting, per-effect controls, effect quality tiers, safe expansion.
- [ ] **M7.7 document/export:** import/export fidelity, printing, slices, screen export, ICC/prepress where supported.
- [ ] **M7.8 menus/workspaces:** full command/toolbar parity and validation, contextual actions, accessibility.
- [ ] **M7.9 optional assisted workflows:** user-supplied/provider-based AI; permissions, provenance and failures handled honestly.

## Definition of Done for EVERY slice
1. RED test first, implementation, GREEN test and macOS build.
2. Undo/Redo, document save/reopen, duplicate, group/lock/isolate behavior.
3. Correct results at multiple zoom levels and on multiple artboards.
4. Native Apple Silicon and Intel compilation; no SwiftUI-only failures hidden by Linux syntax parsing.
5. Run earlier milestones' regressions, including delete lifecycle safety and document migration.
6. Reference image and numerical fixtures for output quality. Empty menu buttons do not count.
7. Update this matrix with precise shipped/versioned evidence, not optimistic checkmarks.

## Scope note
Adobe Illustrator has decades of independent tools and rendering/format workflows. All-class functional comparability is a long-running product objective. A single M7 ZIP cannot responsibly implement or verify everything; use the sub-milestone gates above.

## M7.1a delivered 2026-11-22

- [x] Open-line/curve variable stroke profiles with five presets and real fill geometry
- [x] Appearance Inspector, undo/redo snapshots, JSON persistence, classic/M4 renderer, expanded SVG export
- [x] 130 core tests, 91 framework-free self-checks; M5/M6 regressions green on Linux
- [ ] Native macOS Apple Silicon and Intel CI compilation + app launch/interaction verification
- [ ] Remaining brush families, custom width points and closed-path seam interpolation
