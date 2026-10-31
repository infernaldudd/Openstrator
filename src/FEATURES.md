# Openstrator V6 M6 — feature matrix

## M6 Layer/Object Workflows

- Hierarchical Layers tree: nested groups/layers, reorder/reparent, visibility/lock, inline rename, selection targeting, locate selection, accents and expand/collapse.
- Clipping groups and opacity masks with live compositing and release/invert workflows.
- Embedded Objects with preserved editable payloads, non-destructive proxy transforms, separate content editor, replace/expand and recursion protection.
- Linked image assets with embedded fallback, missing/modified state, refresh/relink/embed.
- Shared Symbol definitions/instances, definition replacement, placement/spraying and detach-to-editable-artwork.
- Graphic Styles backed by full Appearance stacks.
- Import/export reusable Openstrator resource libraries.
- Bounded asynchronous layer thumbnails.
- Backward-compatible optional M6 fields: M5.1 documents continue decoding without hierarchy/resource keys.

---

# Openstrator V6 M5 — feature matrix

## M5 Raster / image placement

- Multi-select image placement plus Finder drag/drop, with one undo snapshot per batch.
- Embedded compressed image assets survive source-file moves/deletion and remain distinct by UUID.
- Image objects participate in selection, move, resize, duplicate, delete, z-order, persistence, and SVG embedding.
- Portrait/Landscape active-artboard switching preserves center and existing artwork coordinates.
- Bounded NSCache-backed preview decoding and visible missing-asset placeholder.
- Sparse 256×256 RGBA8 tiles; transparent defaults; crop; bilinear resample; source-over compositing.
- Rectangular/elliptical pixel selection masks, edge clamping, mask-clipped painting, and erase-to-alpha.
- Paintbrush/Eraser enter raster edit mode only for a selected image; vector behavior remains otherwise.
- Non-destructive Core Image filter records with clamped typed parameters and ≤2048 px preview tier.
- M1–M4.1 vector, typography, Appearance, compatibility, and delete lifecycle behavior retained.

## Retained M4.1 feature matrix

## M4 Appearance / live effects

- Ordered persistent multi-fill / multi-stroke / live-effect `AppearanceStackV6` with stable entry IDs.
- Independent entry enable/disable, opacity, blend, reorder, duplicate and remove operations.
- Typed validated effect schemas instead of one anonymous amount slider for the M4 effect families.
- Appearance visual bounds separate from geometric bounds for blur/shadow/glow/Transform copies.
- Professional Appearance Inspector with add Fill / Stroke / Effect, gradients, width, root opacity/blend and stable ID-based editing.
- Preview / Reset / Cancel / Apply effect transactions with one undo checkpoint on Apply.
- Vector-safe Expand Appearance for ordered paints, Transform copies, Offset Path, Round Corners and Convert-to-Shape.
- Explicit M5 handoff for raster-dependent expansion.
- Legacy M3.1 appearance/effect compatibility and full legacy **All Effects** access retained.
- Ordered M4 SVG paint export with complete appearance-stack metadata preservation.
- Selected-object deletion crash fixed by lifecycle-safe Inspector bindings and coherent deletion transactions.

# Openstrator V6 M3 — feature matrix

## V6 M3 professional typography

- Backward-compatible `TextDataV6` payload with point/area/path and horizontal/vertical layout modes.
- Native installed macOS font families/faces through `NSFontManager` and CoreText variable-axis discovery.
- Deterministic missing-font fallback and recent/favorite font persistence.
- Character style: font family/face/PostScript name, size, weight compatibility, leading, tracking, kerning, baseline shift, H/V scale, glyph rotation, underline, strikethrough, capitalization, super/subscript metadata, OpenType feature flags, variable axes.
- Paragraph style: alignment, left/right/first-line indents, spacing before/after, line spacing, tabs, bullets/numbering, hyphenation, writing direction.
- Point Type, Area Type, Type on Path, Vertical Type, Vertical Area Type, Vertical Type on Path, and Touch Type are all wired to editor actions.
- Threaded frame core preserves overflow and rejects cycles.
- Path text follows Bézier distance and tangent; Touch Type persists per-glyph transforms.
- Text warp data/rendering for Arc, Arch, Bulge, Flag, Fish, Inflate, Rise, Shell Lower/Upper, Squeeze, and Wave.
- CoreText Create Outlines converts glyph contours into editable cubic paths.
- Native spelling check via `NSSpellChecker`.
- Detailed Typography Inspector and macOS Type command menu.
- SVG text export preserves font/layout metadata, text paths, vertical writing mode, and Openstrator warp metadata.

## V6 M2 vector core retained

- True cubic Bézier storage with independent incoming/outgoing handles and corner/smooth/symmetric modes.
- Direct Selection for anchors, handles, and curved path segments.
- Pen, Curvature, Pencil, Add/Delete Anchor, Smooth, Join, Split/Scissors/Knife, reverse and open/close path operations.
- Smart snapping for grid, guides, anchors, artboard edges and centers.
- Multi-artboard add/duplicate/remove/activate core operations.
- Star, Arc, Spiral, Rectangular Grid and Polar Grid create Bézier-backed geometry.
- Cubic SVG export and legacy flattened point compatibility.

## Tool / appearance surface retained

- 89 discoverable tool entries across Selection, Drawing, Shapes, Type, Transform, Color & Appearance, Construction and Navigation.
- 124 effect/effect-equivalent entries in 17 categories with editable non-destructive stacks.
- Solid/gradient fills, strokes, dashes, cap/join, opacity, transforms and blend modes.
- Group/ungroup, cut/copy/paste, duplicate/delete, z-order, alignment/distribution, visibility/lock.
- Grid/guides, zoom/pan/rotate view, artboard resizing, slices and dimensions.
- `.openstrator` open/save/autosave recovery plus SVG/PNG/PDF export.
- Original icon/splash, first-run tutorial, appearance modes, editable shortcuts and animated shortcut help.

## Not yet claimed as exact Illustrator parity

These still need later dedicated milestones/engines:

- Full compound-path boolean topology for every self-intersection and Create-Outlines hole case.
- True gradient-mesh/freeform-gradient node topology.
- Complete Live Paint graph and symbol-definition/instance architectures.
- Full calligraphic/scatter/art/bristle/pattern brush engines and tablet pressure curves.
- Complete clipping/opacity mask and multi-fill/multi-stroke Appearance graph.
- Advanced script shaping/composer controls and Illustrator-identical line breaking/optical kerning.
- ICC/CMYK/spot/separation/prepress workflows.
- AI/EPS/PDF round-trip fidelity.
- Adobe-compatible plug-in/scripting APIs, cloud collaboration, and proprietary 3D/material rendering.

Openstrator implements original native equivalents; it does not contain Adobe code or proprietary effect algorithms.
