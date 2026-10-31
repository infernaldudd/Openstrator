# Openstrator V6 Milestone 2 — Vector Path + Live Shape Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a runnable V6 M2 build with true cubic Bézier path data, direct anchor/handle selection, working Pen/Curvature/Pencil creation, path editing operations, guide/anchor/artboard snapping, and multi-artboard document operations while preserving M1.1 reliability.

**Architecture:** Extend `OpenstratorCore` rather than adding more geometry logic to `CanvasView.swift`. The app shell stores optional Bézier anchors on legacy `VectorObject` records as a compatibility bridge; all path math/editing comes from `OpenstratorCore`, and legacy point arrays are derived previews for existing render/export code until the renderer is fully V6-native.

**Tech Stack:** Swift 5.9+, SwiftUI/AppKit on macOS 13+, Foundation/CoreGraphics-compatible geometry in `OpenstratorCore`, SwiftPM, XCTest on full test environments, framework-free `OpenstratorCoreSelfTest` for Terminal builds.

**Spec:** `docs/superpowers/specs/2026-09-23-openstrator-v6-design.md`

## Global Constraints

- Intel x86_64 and Apple Silicon arm64 must share source behavior.
- Typical working memory remains under 3 GB.
- No fake tools: Pen, Curvature, Pencil, Direct Selection, anchor editing, guides/snapping and artboards must have real document behavior.
- Existing M1.1 selection/move/resize/delete/grid/icon regressions remain green.
- Existing `.openstrator` files decode when Bézier metadata is absent.
- Terminal build must not require XCTest; framework-free self-test remains the release preflight.
- V6 path data stores true cubic anchors with incoming/outgoing handles and corner/smooth/symmetric mode.

## Review Focus

1. Degenerate/zero-length Bézier segments must never emit NaN/inf and remain selectable/editable.
2. Closed-path seam operations must treat last→first as a real segment for hit testing, insertion, splitting, and flattening.
3. Direct-selection tolerance must be stable across zoom because UI converts viewport tolerance to document units.
4. Pencil fitting must reduce noisy samples while preserving first/last points and not collapse a real stroke to one anchor.
5. Multi-artboard add/duplicate/remove must preserve a valid active artboard and reject deletion of the final artboard.

---

### Task 1: True cubic Bézier model and evaluator

**Files:**
- Create: `Sources/OpenstratorCore/Vector/BezierPath.swift`
- Modify: `Sources/OpenstratorCore/Document/DocumentV6.swift`
- Modify: `Sources/OpenstratorCore/Geometry/AffineGeometry.swift`
- Test: `Tests/OpenstratorCoreTests/BezierPathTests.swift`

**Interfaces:**
- Produces `PathAnchorV6`, `AnchorKindV6`, `BezierPathV6`, `CubicBezierSegmentV6`, `BezierGeometry.point`, `derivative`, `split`, `flatten`, `bounds`, `distance`.
- `PathData` stores `[PathAnchorV6]` and remains backward-decodable from M1 `{point}` anchors.

- [ ] Write RED tests for cubic midpoint/derivative, closed seam, flatten endpoints, exact split continuity, curve bounds and backward JSON anchor decoding.
- [ ] Run `swift test --filter BezierPathTests`; expected failure because the M2 types do not exist.
- [ ] Implement the vector types and cubic evaluator with finite-value guards and recursive/step flattening tolerance.
- [ ] Update `GeometryResolver` and path hit testing to use Bézier bounds/distance instead of straight anchor chords.
- [ ] Run focused + full core suite; commit `feat: add cubic bezier path core`.

### Task 2: Direct selection and anchor/handle editing

**Files:**
- Create: `Sources/OpenstratorCore/Selection/DirectSelection.swift`
- Test: `Tests/OpenstratorCoreTests/DirectSelectionTests.swift`

**Interfaces:**
- Produces `PathComponentHit`, `PathComponent`, `DirectSelection.hitTest(path:point:tolerance:)`, `moveAnchor`, `moveHandle`, `convertAnchorKind`.

- [ ] Write RED tests for anchor priority over segment, handle hit, curved-segment hit, corner handle independence, smooth collinearity, symmetric mirrored handles, and closed seam hit.
- [ ] Run focused test and confirm RED.
- [ ] Implement direct hit testing and immutable path edit helpers.
- [ ] Run focused + full suite; commit `feat: add direct path selection`.

### Task 3: Pen/Curvature builders and path operations

**Files:**
- Create: `Sources/OpenstratorCore/Vector/PathEditing.swift`
- Create: `Sources/OpenstratorCore/Vector/PathBuilders.swift`
- Test: `Tests/OpenstratorCoreTests/PathEditingTests.swift`
- Test: `Tests/OpenstratorCoreTests/PathBuilderTests.swift`

**Interfaces:**
- Produces `PathEditor.insertAnchor(path:segmentIndex:t:)`, `deleteAnchor`, `reverse`, `join`, `split`, `close`, `open`.
- Produces `PenPathBuilder` and `CurvaturePathBuilder` state machines.

- [ ] RED tests: insertion stays on original curve; reverse swaps handles; join avoids duplicate coincident endpoint; split creates two valid open paths; pen drag makes mirrored handles; close-near-first closes; curvature creates smooth internal handles.
- [ ] Run focused tests and confirm RED.
- [ ] Implement exact de Casteljau insertion/splitting, endpoint join/reverse, Pen drag handle semantics, and Catmull-Rom-style curvature handle generation.
- [ ] Run focused + full suite; commit `feat: add pen curvature and path editing`.

### Task 4: Pencil fitting and live shape path generators

**Files:**
- Create: `Sources/OpenstratorCore/Vector/PencilFitter.swift`
- Create: `Sources/OpenstratorCore/Vector/LiveShapeGeometry.swift`
- Test: `Tests/OpenstratorCoreTests/PencilFitterTests.swift`
- Test: `Tests/OpenstratorCoreTests/LiveShapeGeometryTests.swift`

**Interfaces:**
- Produces `PencilFitter.fit(samples:tolerance:smoothing:)`.
- Produces `LiveShapeGeometry.rectangle`, `roundedRectangle`, `ellipse`, `polygon`, `star`, `arc`, `spiral`, `rectangularGrid`, `polarGrid`.

- [ ] RED tests for noisy-line simplification, endpoint preservation, smooth handles, 4-cubic ellipse, rounded rectangle corner clamp, polygon/star vertex counts, arc endpoints and finite spiral/grid output.
- [ ] Run focused tests and confirm RED.
- [ ] Implement RDP simplification + smooth handle fitting and deterministic live-shape generators.
- [ ] Run focused + full suite; commit `feat: add pencil fitting and live shapes`.

### Task 5: Smart snapping, guides, and multi-artboard operations

**Files:**
- Create: `Sources/OpenstratorCore/Selection/SnapEngine.swift`
- Create: `Sources/OpenstratorCore/Document/ArtboardOperations.swift`
- Modify: `Sources/OpenstratorCore/Document/DocumentV6.swift`
- Test: `Tests/OpenstratorCoreTests/SnapEngineTests.swift`
- Test: `Tests/OpenstratorCoreTests/ArtboardOperationsTests.swift`

**Interfaces:**
- Produces `SnapCandidate`, `SnapResultV6`, `SnapEngine.snap(point:document:options:)` supporting grid, guides, path anchors and artboard edges/centers.
- Produces `DocumentV6.addArtboard`, `duplicateArtboard`, `removeArtboard`, `setActiveArtboard`, `artboardIDs`.

- [ ] RED tests for nearest candidate priority, guide snap, anchor snap, artboard edge/center snap, disabled sources, duplicate artboard offset and final-artboard deletion rejection.
- [ ] Run focused tests and confirm RED.
- [ ] Implement the snap candidate engine and artboard tree operations.
- [ ] Run focused + full suite; commit `feat: add smart snapping and artboards`.

### Task 6: App compatibility bridge and interactive M2 tools

**Files:**
- Modify: `Openstrator/Models.swift`
- Modify: `Openstrator/EditorStore.swift`
- Modify: `Openstrator/CanvasView.swift`
- Modify: `Openstrator/Exporters.swift`
- Test: `Tests/OpenstratorCoreTests/M2BridgeContractTests.swift`

**Interfaces:**
- `VectorObject.bezierAnchors: [PathAnchorV6]?` is optional and backward compatible.
- `EditorStore.bezierPath(for:)`, `replaceBezierPath(objectID:path:)`, `penClick`, `finishPenPath`, `cancelDraftPath`, `directComponentHit`, `moveDirectComponent`.
- Existing `points` remains a flattened derivative cache for current renderer/exporters.

- [ ] RED contract tests for optional metadata decoding and flatten consistency.
- [ ] Implement the optional bridge field and conversion helpers.
- [ ] Change Pencil to call `PencilFitter`; Pen/Curvature maintain a persistent draft path between clicks; clicking near the first anchor closes; Escape cancels and Return commits.
- [ ] Direct Selection draws anchor/handle overlays and dragging an anchor/handle updates the selected path rather than moving the whole object.
- [ ] Existing renderer/exporter consume flattened points so visible results remain compatible.
- [ ] Run parser checks and full Linux core suite; commit `feat: wire M2 vector tools into editor`.

### Task 7: Framework-free M2 release gate and packaging

**Files:**
- Modify: `Sources/OpenstratorCoreSelfTest/main.swift`
- Create: `scripts/m2_acceptance.sh`
- Modify: `BUILD_OPENSTRATOR.command`
- Modify: `README.md`, `FEATURES.md`, `QA_REPORT.md`

**Interfaces:**
- Self-test checks cubic geometry, direct selection, Pen/Curvature/Pencil, snapping, artboards in addition to M1 checks.
- Terminal builder runs framework-free self-test before compiling the app and never requires XCTest.

- [ ] Add self-test checks first and confirm they fail against pre-M2 core where applicable.
- [ ] Implement final release checks; run `swift test --filter OpenstratorCoreTests`, `swift run -c release OpenstratorCoreSelfTest`, parser/static checks, and ZIP integrity.
- [ ] Create Intel and Apple Silicon packages from one source tree, changing only architecture configuration/build profile.
- [ ] Commit `release: package Openstrator V6 M2`.

## Completion Contract

M2 ships only when all M1 tests stay green, all M2 core tests pass, the framework-free self-test passes, app Swift sources parse, both architecture ZIPs have matching source hashes excluding architecture config/profile, and the Terminal builder contains no mandatory XCTest invocation.
