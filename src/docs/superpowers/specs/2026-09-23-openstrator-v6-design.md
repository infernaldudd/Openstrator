# Openstrator V6 — Hybrid Vector + Raster Editor Design

Date: 2026-09-23
Status: Proposed for user review
Base: Openstrator Intel Pro V5.2 Terminal
Target platforms: macOS Intel x86_64 and Apple Silicon arm64

## 1. Product intent

Openstrator V6 is a native macOS professional graphics editor that combines a full vector workflow with a real raster layer engine. The capability target is functional breadth comparable to a modern Illustrator-class editor, while keeping Openstrator's branding, icons, source code, visual styling, and internal implementations original.

The user explicitly wants:

- every Illustrator-class tool represented by a working Openstrator equivalent;
- every Illustrator-class effect represented by a working Openstrator equivalent;
- comprehensive menus and submenus rather than a small demo menu set;
- professional typography, path, layers, masks, artboards, appearance, color, symbols, graphs, perspective, transforms, export, and raster workflows;
- a hybrid vector + raster document model;
- embedded/non-destructive object editing comparable in workflow to “smart object” behavior, but implemented and named independently;
- no fake controls: visible commands must either work or be clearly disabled with a reason;
- the existing reported interaction defects fixed at the engine level;
- separate Intel and Apple Silicon builds and a normal working-memory goal under 3 GB for typical documents.

## 2. Current V5.2 findings

The V5.2 source is ~4,849 Swift lines spread across seven main Swift files. Its editor model is centered on a flat `OpenDocument.objects: [VectorObject]` list. `VectorObject` combines geometry, text, fill/stroke, grouping, and effects into one structure. The current effect stack is `[VectorEffect]`, with many advanced effects approximated directly inside `CanvasView` using SwiftUI `GraphicsContext` filters.

This architecture is adequate for a prototype but is the root limitation behind the current interaction and feature depth issues:

- hit testing operates mostly on axis-aligned object bounds rather than transformed geometry;
- selection bounds do not fully represent rotation, path geometry, raster masks, or nested groups;
- text is stored as plain text plus size/weight rather than a true typography model;
- there is no first-class raster layer, mask, appearance target, linked asset, embedded document, symbol definition, graph model, or effect parameter schema;
- many effects are one-dimensional “amount” approximations;
- a large amount of behavior is concentrated in `EditorStore.swift` and `CanvasView.swift`;
- menus expose only a fraction of the available tools and document operations.

V6 therefore needs a core-model migration, not another pass of adding enum cases to V5.

## 3. Architecture choice

### 3.1 Preserve the app shell, replace the weak core

V6 keeps the working native SwiftUI macOS shell, onboarding, custom icon, keybind settings, basic file workflow, and architecture-specific build packaging. The document engine, rendering engine, selection/transform engine, command system, and layer tree are replaced incrementally behind stable UI-facing protocols.

This avoids a full rewrite while preventing V5's flat `VectorObject` design from constraining every new feature.

### 3.2 Module boundaries

The V6 codebase is split into focused modules:

- **OpenstratorApp** — SwiftUI app lifecycle, windows, commands, preferences.
- **DocumentCore** — document graph, node IDs, layer tree, resources, serialization, migration.
- **VectorCore** — paths, anchors, Bézier handles, live shapes, strokes, brushes, meshes, symbols, graphs, perspective.
- **RasterCore** — raster tiles, masks, pixel selections, painting, compositing, Core Image/vImage filters.
- **TextCore** — Core Text-backed typography, font enumeration, glyph layout, area text, path text, styles.
- **AppearanceCore** — fills, strokes, opacity, blend modes, live effects, graphic styles, effect expansion.
- **RenderCore** — vector/raster compositor, viewport tiles, cached previews, export rendering.
- **SelectionCore** — hit testing, selection hierarchy, snapping, guides, transform handles, modifier keys.
- **CommandCore** — undoable commands, transactions, clipboard, menu validation, command palette/keybinds.
- **ImportExport** — Openstrator format plus SVG/PDF/PNG/JPEG/TIFF and supported placed assets.
- **UIComponents** — toolbar, panels, inspectors, dialogs, context menus, tool options, status UI.

Each module has public protocols so implementation details can be changed without rewriting consumers.

## 4. V6 document model

### 4.1 Node tree

Replace the flat `[VectorObject]` list with a hierarchical `DocumentNode` tree.

Required node kinds:

- `VectorLayerNode`
- `PathNode`
- `LiveShapeNode`
- `TextNode`
- `RasterLayerNode`
- `GroupNode`
- `ArtboardNode`
- `ClippingGroupNode`
- `OpacityMaskNode`
- `EmbeddedObjectNode`
- `LinkedAssetNode`
- `SymbolInstanceNode`
- `SymbolDefinitionNode`
- `GraphNode`
- `LivePaintGroupNode`
- `PerspectiveObjectNode`
- `GuideNode`
- `SliceNode`

All nodes share:

- UUID identity;
- name;
- visibility/lock state;
- local transform matrix;
- opacity;
- blend mode;
- appearance stack;
- optional clip/mask references;
- parent/children relationship where applicable;
- bounds API returning geometric, visual, and hit-test bounds separately.

### 4.2 Appearance model

An object can have multiple fills and strokes, not just one of each. Appearance entries are ordered and targetable.

`AppearanceStack` contains:

- zero or more fills;
- zero or more strokes;
- object opacity/blending;
- live effect entries;
- per-fill/per-stroke effects;
- masks;
- graphic style reference.

This is required for professional Illustrator-class appearance workflows.

### 4.3 Embedded Object system

Openstrator's original equivalent of Smart Object behavior is **Embedded Object**.

Capabilities:

- convert selected vector/raster/group/text artwork to Embedded Object;
- preserve original internal content and dimensions;
- transform non-destructively;
- apply live effects without altering source content;
- open embedded contents in a separate editor window/tab;
- replace contents;
- relink to an external file when appropriate;
- rasterize/expand explicitly when the user requests it;
- nested embedded objects supported with recursion guard.

## 5. Coordinate, selection, transform, and snapping engine

V6 has one canonical document coordinate system. Rendering, hit testing, pointer input, guides, transforms, brushes, effects, and selection handles all convert through the same matrix pipeline.

### 5.1 Required behavior

- Paintbrush/Pencil/Blob Brush points stay under the pointer at every zoom/pan level.
- Click and drag have a movement threshold so a normal click never becomes an accidental move.
- Hit testing is geometry-aware: fill hit, stroke hit, Bézier path distance, text glyph/area hit, raster alpha hit where enabled.
- Transforms use transformed visual bounds, not raw axis-aligned source bounds.
- Selection honors nesting and direct/group selection semantics.
- Shadow/effect hit testing is configurable and should not accidentally select obscured objects.
- Handles have visible size plus a larger invisible hit target.
- Backspace/Delete are intercepted and consumed when deleting selected artwork.
- Arrow nudging uses document-space values independent of zoom.
- Dragging uses a stable origin snapshot, preventing cumulative drift.

### 5.2 Modifier semantics

For corner resize:

- default: free width/height;
- Shift: preserve aspect ratio;
- Option: scale from center;
- Shift+Option: preserve aspect ratio from center.

For rotation:

- Shift snaps to configured angular increments;
- Option can duplicate on transform where applicable.

For drag/move:

- Shift axis-constrains after a threshold;
- snapping may target grid, guides, points, paths, artboards, glyphs, and smart guides.

## 6. Vector engine capability contract

### 6.1 Selection family

Working equivalents for:

- Selection
- Direct Selection
- Group Selection
- Magic Wand
- Lasso
- Artboard

Magic Wand criteria must include configurable fill, stroke, stroke weight, opacity, and blend similarity.

### 6.2 Drawing and path family

Working equivalents for:

- Pen
- Add Anchor Point
- Delete Anchor Point
- Anchor Point conversion
- Curvature
- Pencil
- Paintbrush
- Blob Brush
- Smooth
- Path Eraser
- Scissors
- Knife
- Join
- Shaper
- Line Segment
- Arc
- Spiral
- Rectangular Grid
- Polar Grid
- Rectangle
- Rounded Rectangle
- Ellipse
- Polygon
- Star
- Flare

Path data must store true cubic Bézier anchors and handles. Existing V5 point arrays migrate to corner-anchor paths.

### 6.3 Modify family

Working equivalents for:

- Rotate
- Reflect
- Scale
- Shear
- Width
- Free Transform
- Reshape
- Warp
- Twirl
- Pucker
- Bloat
- Scallop
- Crystallize
- Wrinkle
- Puppet Warp
- Eraser
- Scissors
- Shape Builder
- Pathfinder operations
- envelope/warp operations
- live corners
- offset path
- simplify path
- outline/expand operations

### 6.4 Paint and construction family

Working equivalents for:

- Gradient
- Freeform/linear/radial gradient modes
- Gradient Mesh
- Eyedropper
- Measure
- Blend
- Shape Builder
- Live Paint Bucket
- Live Paint Selection
- perspective grid and perspective selection
- symbols and all symbol manipulation tools
- graph families
- slices and slice selection
- dimension tool
- objects-on-path workflow

## 7. Typography engine

Text must stop being a simple string with size and weight.

### 7.1 Fonts

Use Core Text / `CTFontManager` / AppKit font APIs to enumerate installed fonts and styles dynamically.

Font UI includes:

- family search;
- family preview;
- style/face;
- favorites/recent fonts;
- missing font indicator and substitution;
- variable-font axes when available.

### 7.2 Character formatting

Support:

- font family/style/size;
- leading;
- tracking;
- kerning;
- baseline shift;
- horizontal/vertical scale;
- rotation;
- underline/strikethrough;
- capitalization controls;
- superscript/subscript;
- OpenType feature toggles supported by Core Text;
- fill/stroke/appearance on text.

### 7.3 Paragraph formatting

Support:

- left/center/right/justify;
- indents;
- first-line indent;
- paragraph spacing;
- tabs;
- bullets and numbering;
- hyphenation where platform APIs permit;
- text direction and vertical text support where platform APIs permit.

### 7.4 Type object workflows

Support:

- point type;
- area type;
- type on path;
- vertical type;
- vertical area type;
- vertical type on path;
- touch-type-style per-glyph transforms;
- convert point/area text;
- create outlines;
- warp text;
- threading between text frames;
- overset indicator;
- spell checking through macOS text services.

## 8. Raster engine

### 8.1 Raster layers

A `RasterLayerNode` stores pixel data in a tiled backing store instead of one huge bitmap. Tiles are decoded/rendered lazily and evicted using an LRU cache.

Required raster features:

- place/import bitmap images;
- paint/erase on raster layers;
- rectangular/elliptical/freehand pixel selections;
- move/copy/cut/paste pixel regions;
- crop;
- resize/resample;
- layer masks;
- clipping;
- alpha-aware transforms;
- rasterize vector/text/group/embedded artwork;
- convert raster selection to path through tracing workflow later in the roadmap;
- non-destructive raster live filters when stored in the appearance stack.

### 8.2 Filter backend

Use Core Image first, Accelerate/vImage for operations better suited to CPU/vector math, and Metal kernels only where a real quality/performance benefit exists. Intel gets the same feature surface with Metal-optional/CPU fallback.

Raster filters render at preview resolution while dragging controls, then refine after interaction ends.

## 9. Effects system

V5's `VectorEffect(kind, amount)` is replaced by `LiveEffect` with typed parameter schemas.

Each effect defines:

- identifier;
- category;
- display name;
- supported node targets;
- parameter descriptors;
- defaults and valid ranges;
- preview renderer;
- full-resolution renderer;
- expansion/rasterization behavior;
- bounds inflation calculation;
- serialization version.

### 9.1 Vector/live effect families

Coverage target includes working equivalents for the complete current Illustrator-style effect families:

- 3D & Materials / compatible classic 3D workflows where practical;
- Convert to Shape;
- Distort & Transform;
- Path;
- Pathfinder;
- Rasterize;
- Stylize;
- SVG-filter import/application where supported;
- Warp presets.

### 9.2 Raster effect families

Coverage target includes:

- Artistic;
- Blur;
- Brush Strokes;
- Distort;
- Pixelate;
- Sketch;
- Stylize;
- Texture;
- Video/legacy compatibility effects where meaningful.

The V5 inventory already includes many of these names, but V6 requires real multi-parameter implementations instead of a single “amount” slider.

### 9.3 Required professional controls

Examples:

- Gaussian Blur: radius;
- Motion Blur: distance + angle;
- Radial/Zoom Blur: center + amount + mode;
- Drop Shadow: x/y, blur, opacity, color, blend mode;
- Inner/Outer Glow: color, opacity, blur, blend mode;
- Roughen: size, detail, relative/absolute, smooth/corner;
- Zig Zag: size, ridges, smooth/corner;
- Pucker/Bloat: signed amount;
- transform effect: move, scale, rotate, copies, transform origin;
- 3D: rotation/orientation, depth/revolve, perspective, lighting/material parameters appropriate to Openstrator's renderer;
- texture effects: scaling, relief, lighting and texture choice when relevant.

Every dialog/panel must support live preview, reset, cancel, and OK/apply. Effects remain editable in the Appearance panel until expanded/rasterized.

## 10. Menus and context menus

V6 exposes a comprehensive professional command structure. It should feel familiar to experienced vector-editor users without cloning Adobe's exact menu ordering, icons, wording where proprietary, or trade dress.

### 10.1 Main macOS menu groups

- Openstrator
- File
- Edit
- Object
- Type
- Select
- Effect
- Raster
- View
- Window
- Help

Optional `Layer` can be present if it improves the hybrid workflow, but layer operations must also be available through the Layers panel context menu.

### 10.2 File

New, Open, Open Recent, Close, Save, Save As, Revert, Place/Import, Package/Collect Assets equivalent, Document Setup, Export, Export Selection, Export for Screens, print/PDF workflows, document info.

### 10.3 Edit

Undo/Redo, Cut/Copy/Paste, Paste in Front/Back/Place, preferences/settings, keyboard shortcuts, color/preset management, spelling, find/replace text, perspective-grid presets where applicable.

### 10.4 Object

Transform, Arrange, Align/Distribute, Group/Ungroup, Lock/Unlock, Hide/Show, Expand/Expand Appearance, Rasterize, Flatten Transparency equivalent, Path, Shape, Blend, Envelope/Warp, Perspective, Live Paint, Clipping Mask, Compound Path, Artboards, Graph, Slice, Intertwine-style ordering workflow if implemented, Embedded Object conversion.

### 10.5 Type

Font, Recent Fonts, Size, glyph/special character insertion, area/point conversion, type on path, threading, orientation, alignment, outlines, paragraph/character commands, tabs, bullets/numbering, case controls, spell checking, warp text, find/replace font.

### 10.6 Select

All, Deselect, Reselect, Inverse, Next/Previous Object, Same-by-attribute, Object categories, save/edit selection, isolate selected object/group.

### 10.7 Effect

All live vector and raster effect categories, Appearance access, document raster-effect settings, last-effect repeat/edit-last-effect commands.

### 10.8 Raster

Hybrid-specific raster operations: image adjustments, crop, resample, pixel selection operations, raster masks, rasterize, destructive apply, channels where supported, and filter gallery/browser.

### 10.9 View

Preview modes, outline mode, pixel preview, overprint-style preview when supported, proofing later, zoom/fitting, rulers, grid, guides, smart guides, snapping modes, perspective grid, transparency grid, hide/show edges/artboards/selection adornments.

### 10.10 Window

Panels/workspaces, toolbar modes, contextual task bar, document windows, appearance, layers, properties, transform, align, pathfinder, character, paragraph, glyphs, swatches, color, gradient, stroke, brushes, symbols, graphic styles, links/assets, info, navigator, history.

### 10.11 Context menus

Right-click menus are contextual and generated from command availability rather than hard-coded duplicates. Examples include:

- transform;
- arrange;
- group/ungroup;
- isolate;
- lock/hide;
- clipping/mask;
- create outlines for text;
- convert to Embedded Object;
- rasterize;
- expand appearance;
- path operations;
- export selection;
- text/font operations;
- linked/embedded asset actions.

## 11. Panels and dialogs

Required dockable/floating panel equivalents:

- Layers
- Properties
- Appearance
- Transform
- Align
- Pathfinder
- Character
- Paragraph
- Glyphs
- Color
- Swatches
- Gradient
- Stroke
- Brushes
- Symbols
- Graphic Styles
- Links/Assets
- Artboards
- Info
- Navigator
- History
- Effects browser

Panels share a common SwiftUI panel framework with detachable/floating support where feasible on macOS.

## 12. Brushes, strokes, gradients, patterns, and color

### Brushes

Support basic brush definitions required for a professional vector editor:

- calligraphic;
- scatter;
- art;
- pattern;
- bristle-style approximation;
- pressure/tilt input where macOS input APIs provide it.

### Stroke

Support:

- width;
- cap;
- join;
- miter limit;
- dash/gap sequence;
- arrowheads/markers;
- align inside/center/outside where geometry permits;
- variable-width profiles;
- Width-tool control points.

### Gradients

Support linear, radial, freeform-style and mesh workflows; multiple color stops; midpoint; opacity stop; transform/origin controls; gradient-on-stroke modes where practical.

### Patterns

Pattern resource model with editable tile bounds, spacing, transform, and swatch reuse.

### Color

RGB/HSL/HSB/CMYK-style document controls, swatches, spot/global-style colors where supported, gradients/pattern swatches, color groups. Initial V6 export color-management scope is sRGB plus tagged PDF workflows; broader prepress/ICC work is a separate milestone.

## 13. Layers and masks

Layers panel must support:

- nested groups/layers;
- drag reorder and reparent;
- visibility/lock;
- rename;
- duplicate/delete;
- selection targeting;
- locate selected object;
- clipping groups;
- opacity masks;
- merge/flatten commands appropriate to node types;
- layer color/selection accent;
- expand/collapse tree;
- artboards in hierarchy where appropriate;
- thumbnails generated asynchronously.

## 14. Rendering pipeline

### 14.1 Scene evaluation

1. Evaluate document node tree.
2. Resolve transforms and clipping/masks.
3. Resolve vector geometry and text glyph runs.
4. Evaluate appearance stack and live effects.
5. Rasterize only the regions/effects that require pixels.
6. Composite into viewport tiles.
7. Cache reusable intermediate results using content hashes/version counters.

### 14.2 Preview vs final quality

Interactive transforms/effect sliders may use lower-resolution raster previews. Mouse-up/idle triggers high-quality refinement. Export always uses final-quality rendering.

### 14.3 Bounds

Every effect declares visual bounds expansion. Selection bounds can show geometric or visual bounds depending on tool/preferences. This avoids clipping glows/shadows and improves hit testing.

## 15. Performance and memory

Target: normal working set below 3 GB for typical school/prosumer documents, not a guarantee for arbitrarily huge multi-gigapixel files.

Strategies:

- tiled raster storage;
- lazy image decode;
- viewport-only rendering;
- LRU tile/effect caches with explicit byte budgets;
- immutable/shared resources for symbols, brushes, patterns and embedded data;
- command-delta undo instead of full-document snapshots;
- preview-resolution live filters;
- release-only diagnostics for cache/memory pressure;
- automatic cache purge on macOS memory-pressure notification.

Architecture profiles:

- Intel: smaller caches, lower preview tile concurrency, CPU/vector fallbacks, conservative history budget.
- Apple Silicon: larger but capped cache, more concurrent tile work, Metal acceleration where available.

Feature behavior and document format remain identical between architectures.

## 16. Undo/redo and commands

V5 copies entire documents into history. V6 replaces this with undoable commands/transactions.

Examples:

- `MoveNodesCommand`
- `TransformNodesCommand`
- `SetAppearancePropertyCommand`
- `InsertNodeCommand`
- `DeleteNodesCommand`
- `EditPathAnchorsCommand`
- `RasterStrokeCommand`
- `ApplyLiveEffectCommand`
- `SetTextAttributesCommand`

Continuous drags/sliders coalesce into one undo item.

All menu items, toolbar actions, context-menu actions and shortcuts dispatch the same commands. This prevents features working from one entry point but not another.

## 17. File format and migration

New `.openstrator` format version: V6 format version 6.

The file is a package or structured archive containing:

- document JSON/plist-like manifest;
- embedded raster assets;
- embedded object subdocuments;
- resource library (brushes/patterns/symbols/styles);
- optional thumbnails/previews.

A migrator reads V2/V5 documents and converts every legacy `VectorObject` to the appropriate V6 node. Legacy effects are mapped to V6 live effects with best-effort parameter translation.

Saving never overwrites an older-format original without explicit confirmation; first save of a migrated file creates V6 format.

## 18. Import/export scope

Core V6:

- Openstrator V6;
- SVG import/export;
- PDF export and practical vector PDF import subset;
- PNG;
- JPEG;
- TIFF where platform APIs support it;
- placed/linked common bitmap formats;
- text import where practical.

AI/EPS compatibility is not claimed as native Adobe-format fidelity unless an independent legal/open parser is implemented and verified. The product must never claim perfect proprietary-format compatibility without evidence.

## 19. UI/UX direction

The app remains distinctly macOS and Openstrator-branded:

- native menu bar and keyboard semantics;
- original toolbar icons/SF Symbols where appropriate;
- original panel styling;
- dark/light/system appearance;
- contextual tool options;
- first-run tutorial;
- hoverable animated help previews in shortcut settings;
- command search/palette for locating tools and commands;
- editable shortcuts with conflict detection.

Tool flyouts and panel placement can follow conventional graphics-editor interaction patterns, but the app must not copy Adobe artwork, icons, exact panel graphics, splash screens, or proprietary visual assets.

## 20. V5.2 regression repairs that V6 must pass

The following are release-blocking acceptance tests:

1. Paintbrush and Pencil draw directly under the pointer at 25%, 50%, 100%, 200%, and 400% zoom with arbitrary pan.
2. Backspace and Forward Delete delete the selection and do not close the app/window.
3. Clicking visible fill selects that object; clicking a visible stroke selects it; empty canvas deselects unless modifiers request otherwise.
4. Rotated/scaled objects are selectable using their transformed geometry.
5. Object drag does not jump on mouse-down and does not accumulate positional error.
6. Grid remains visually stable while zooming/panning and uses adaptive spacing/pixel alignment.
7. Resize handles remain clickable at all zoom levels.
8. Shift + corner drag preserves aspect ratio.
9. Option + corner drag scales from center.
10. Shift + Option combines both behaviors.
11. Effects render inside correct expanded bounds without duplicate-looking strokes or clipped shadows/glows.
12. App icon has transparent outer background with no white square.

## 21. Quality gates

No feature is counted “implemented” because an enum/menu item exists.

A tool/effect/menu command reaches parity status only when:

- it has a real document/renderer behavior;
- it has undo/redo coverage;
- serialization round-trip passes;
- its UI control is enabled only when valid;
- shortcut/menu/context-menu routing is tested;
- Intel and Apple Silicon source behavior is the same;
- representative visual or numerical tests pass;
- no known crash occurs under invalid selection states.

## 22. Testing strategy

### Unit tests

- geometry transforms;
- Bézier hit testing;
- snapping;
- modifier-constrained resizing;
- layer tree mutation;
- command undo/redo;
- effect parameter serialization;
- typography attributes;
- document migration;
- tile cache eviction;
- file round-trips.

### Rendering tests

Golden-image tests for deterministic vector/raster rendering at fixed scale and color space, with tolerances for GPU/CPU differences.

### Interaction tests

macOS UI tests for selection, drag, resize, typing, menu dispatch, context menus, panels, delete/backspace, effect dialogs and export flows.

### Build matrix

- Intel x86_64 release build on macOS runner;
- Apple Silicon arm64 release build on macOS runner;
- clean build from ZIP/source package;
- launch smoke test;
- sample document open/save/export.

## 23. Delivery phases

V6 is too large to safely implement as one giant patch. It is decomposed into milestones that all use the same final architecture:

1. **Core reliability + document graph** — canonical coordinates, node tree, command undo, selection/transform engine, V5 migration, current bug fixes.
2. **Vector path/live-shape core** — anchors, Bézier editing, shape tools, path operations, snapping, guides, artboards.
3. **Typography** — real fonts, styles, text frames/path text, character/paragraph panels, outlines.
4. **Appearance/effects** — multi-fill/stroke appearance stack, true parameterized vector effects, Appearance panel.
5. **Raster engine** — tiled raster layers, masks, painting, pixel selections, Core Image/vImage filters.
6. **Layer/object workflows** — clipping/opacity masks, Embedded Objects, links, symbols, styles, resources.
7. **Advanced vector systems** — brushes, gradient mesh, Live Paint, perspective, graph, symbols, Puppet Warp, advanced distortion.
8. **Menus/panels completeness** — full command registry, contextual menus, window panels, command search, shortcut coverage.
9. **Import/export + performance** — SVG/PDF fidelity improvements, batch/export selection, cache tuning, architecture-specific optimization.
10. **Parity audit** — compare the official current Illustrator tool/effect/menu capability inventory against Openstrator's registry; no unexplained missing item ships as “complete.”

Each milestone must leave the app runnable and must not depend on placeholder menu items from later milestones.

## 24. Definition of V6 “maxed out”

V6 may be called feature-complete against this spec only when the parity audit reports every targeted tool/effect/menu item in one of these states:

- **Implemented** — working Openstrator equivalent with tests;
- **Platform-inapplicable** — feature has no meaningful macOS/Openstrator equivalent, with documented reason;
- **Legally/proprietarily unavailable** — exact proprietary behavior/file format cannot be reproduced safely, but an original alternative is provided where practical.

There must be no silent placeholders and no “button exists, behavior missing” state in the release build.

## 25. Reference baseline

Capability inventory should be checked against current official Adobe Illustrator documentation at implementation/audit time because Adobe changes Illustrator over time. As of this spec, official Adobe documentation describes an Advanced toolbar with all tools, six main tool categories, editable Appearance effects, raster and vector effect families, and a current desktop release line updated through August 2026.

Reference pages used for the initial V6 inventory:

- https://helpx.adobe.com/illustrator/using/tools-in-illustrator.html
- https://helpx.adobe.com/illustrator/using/tools.html
- https://helpx.adobe.com/illustrator/using/effects.html
- https://helpx.adobe.com/illustrator/using/summary-effects.html
- https://helpx.adobe.com/illustrator/desktop/get-started/learn-the-basics/workspace-overview.html

