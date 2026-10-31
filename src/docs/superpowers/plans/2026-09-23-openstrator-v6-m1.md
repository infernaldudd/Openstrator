# Openstrator V6 Milestone 1 — Core Reliability + Document Graph Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace V5.2's flat object/snapshot core with the first V6 document, command, coordinate, selection, and transform foundations while fixing the user's release-blocking interaction bugs.

**Architecture:** Keep the existing SwiftUI app shell and Terminal packaging, but add a pure `OpenstratorCore` SwiftPM library for document geometry and command logic. `EditorStore` becomes an adapter between SwiftUI and `OpenstratorCore`; `CanvasView` consumes one canonical `CanvasTransform` for both pointer mapping and rendering, so hit testing, drawing, selection, moving, resizing, and snapping share the same coordinate pipeline.

**Tech Stack:** Swift 5.9, macOS 13+, SwiftUI, AppKit, CoreGraphics, XCTest, Swift Package Manager, existing x86_64/arm64 Terminal packaging.

**Spec:** `docs/superpowers/specs/2026-09-23-openstrator-v6-design.md`

## Global Constraints

- Target platforms: macOS Intel x86_64 and Apple Silicon arm64.
- Keep the normal working-memory goal under 3 GB for typical documents.
- Preserve Openstrator branding, icons, source code, visual styling, and internal implementations as original work.
- No fake controls: visible commands must work or be disabled with a reason.
- V6 document format version is exactly `6`.
- Shift + corner resize preserves aspect ratio; Option + corner resize scales from center; Shift+Option combines both.
- Backspace and Forward Delete delete selected artwork and must not close the app/window.
- Paintbrush and Pencil must track the pointer at 25%, 50%, 100%, 200%, and 400% zoom with arbitrary pan.
- Feature behavior and document format must be identical between Intel and Apple Silicon builds.
- Preserve the current Terminal-first distribution workflow with separate Intel and Apple Silicon source packages.

## Review Focus

1. **Viewport transform edge cases:** 25%–400% zoom, arbitrary pan, and nonzero view rotation must round-trip viewport↔document coordinates within 0.001 pt; Task 5 owns these tests.
2. **Transformed hit testing:** rotated/scaled rectangles, ellipses, lines, and paths must select from visible geometry and reject nearby empty space; Task 6 owns these tests.
3. **Resize modifier combinations:** corner drags that cross an opposite edge or approach the minimum size must still preserve Shift/Option semantics without NaN/negative dimensions; Task 7 owns these tests.
4. **Legacy document fidelity:** V5.2 JSON must migrate object order, names, geometry, text, fill/stroke, gradient, effects, visibility, lock state, group relationships, grid/guides, and artboard size; Task 3 owns these tests.
5. **Keyboard focus safety:** Delete/Backspace must delete artwork only when canvas commands own the event and must pass through untouched while an `NSTextView` is first responder; Task 8 owns these tests.

---

## Execution Precondition

The distributed V5.2 ZIP has no Git metadata. Before Task 1, create a local baseline repository in the extracted working copy:

```bash
git init
git add .
git commit -m "chore: baseline Openstrator V5.2"
```

If `.git` already exists, skip initialization and confirm `git status --short` is clean before starting.

## File Structure Locked by This Milestone

### New core library

- `Sources/OpenstratorCore/Geometry/CanvasTransform.swift` — viewport/document matrix conversion and pixel-aligned grid metrics.
- `Sources/OpenstratorCore/Geometry/AffineGeometry.swift` — transformed bounds, inverse-point mapping, path distance helpers.
- `Sources/OpenstratorCore/Document/DocumentV6.swift` — V6 document, node IDs, node tree and current milestone payloads.
- `Sources/OpenstratorCore/Document/AppearanceV6.swift` — fill, stroke, gradient, blend and migrated live-effect records needed by M1.
- `Sources/OpenstratorCore/Document/LegacyV5.swift` — frozen V5.2 decoding structures; no UI dependencies.
- `Sources/OpenstratorCore/Document/V5Migrator.swift` — V5.2 → V6 conversion.
- `Sources/OpenstratorCore/Commands/DocumentCommand.swift` — forward/inverse document mutations and coalescing keys.
- `Sources/OpenstratorCore/Commands/CommandHistory.swift` — bounded delta undo/redo history.
- `Sources/OpenstratorCore/Selection/HitTesting.swift` — geometry-aware hit testing.
- `Sources/OpenstratorCore/Selection/TransformSession.swift` — drag/move/resize origin snapshots and modifier-constrained transforms.
- `Sources/OpenstratorCore/Selection/Snapping.swift` — grid snap and adaptive grid spacing.

### New tests

- `Tests/OpenstratorCoreTests/DocumentV6Tests.swift`
- `Tests/OpenstratorCoreTests/V5MigratorTests.swift`
- `Tests/OpenstratorCoreTests/CommandHistoryTests.swift`
- `Tests/OpenstratorCoreTests/CanvasTransformTests.swift`
- `Tests/OpenstratorCoreTests/HitTestingTests.swift`
- `Tests/OpenstratorCoreTests/TransformSessionTests.swift`
- `Tests/OpenstratorCoreTests/SnappingTests.swift`
- `Tests/OpenstratorAppTests/KeyboardRoutingTests.swift`
- `Tests/OpenstratorAppTests/EditorIntegrationTests.swift`

### Existing app files modified

- `Package.swift` — add `OpenstratorCore`, `OpenstratorCoreTests`, and `OpenstratorAppTests` targets.
- `Openstrator/Models.swift` — retain UI/tool/keybind enums; remove document ownership after migration and add temporary typealiases only where required by the app shell.
- `Openstrator/EditorStore.swift` — own `DocumentV6`, route mutations through commands, expose selection adapter APIs.
- `Openstrator/CanvasView.swift` — remove private coordinate math and cumulative move/resize math; use `CanvasTransform` and `TransformSession`.
- `Openstrator/Exporters.swift` — adapt current SVG/PNG/PDF paths to consume current V6 vector/text nodes.
- `Openstrator/OpenstratorApp.swift` — route Delete/Backspace through one command validation path.
- `BUILD_OPENSTRATOR.command` — run tests before release build and preserve failure logs.
- `Resources/OpenstratorMark.png` — transparent corners.
- `Resources/Openstrator.icns` — regenerated from the alpha-correct source.

---

### Task 1: Create an importable core target and failing test harness

**Files:**
- Modify: `Package.swift`
- Create: `Sources/OpenstratorCore/OpenstratorCore.swift`
- Create: `Tests/OpenstratorCoreTests/CoreSmokeTests.swift`
- Create: `Tests/OpenstratorAppTests/AppSmokeTests.swift`

**Interfaces:**
- Consumes: existing SwiftPM package named `Openstrator`.
- Produces: importable module `OpenstratorCore`; app target `Openstrator` depends on it; test commands `swift test --filter OpenstratorCoreTests` and `swift test`.

- [ ] **Step 1: Write the failing core import test**

```swift
import XCTest
@testable import OpenstratorCore

final class CoreSmokeTests: XCTestCase {
    func testCoreExposesV6FormatVersion() {
        XCTAssertEqual(OpenstratorCoreInfo.documentFormatVersion, 6)
    }
}
```

- [ ] **Step 2: Run the test before the target exists**

Run: `swift test --filter CoreSmokeTests/testCoreExposesV6FormatVersion`

Expected: FAIL because `OpenstratorCore` cannot be imported.

- [ ] **Step 3: Add the package targets**

Replace the package target section with this exact shape while preserving the current architecture compile define on the executable target:

```swift
products: [
    .executable(name: "Openstrator", targets: ["Openstrator"]),
    .library(name: "OpenstratorCore", targets: ["OpenstratorCore"])
],
targets: [
    .target(
        name: "OpenstratorCore",
        path: "Sources/OpenstratorCore"
    ),
    .executableTarget(
        name: "Openstrator",
        dependencies: ["OpenstratorCore"],
        path: "Openstrator",
        exclude: ["Assets.xcassets", "Info.plist"],
        swiftSettings: [.define("OPENSTRATOR_INTEL")]
    ),
    .testTarget(
        name: "OpenstratorCoreTests",
        dependencies: ["OpenstratorCore"],
        path: "Tests/OpenstratorCoreTests"
    ),
    .testTarget(
        name: "OpenstratorAppTests",
        dependencies: ["Openstrator", "OpenstratorCore"],
        path: "Tests/OpenstratorAppTests"
    )
]
```

Create `Sources/OpenstratorCore/OpenstratorCore.swift`:

```swift
public enum OpenstratorCoreInfo {
    public static let documentFormatVersion = 6
}
```

- [ ] **Step 4: Run the focused test and full suite**

Run: `swift test --filter CoreSmokeTests/testCoreExposesV6FormatVersion && swift test`

Expected: PASS, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/OpenstratorCore Tests
 git commit -m "build: add OpenstratorCore test harness"
```

---

### Task 2: Introduce the V6 node tree and appearance records

**Files:**
- Create: `Sources/OpenstratorCore/Document/AppearanceV6.swift`
- Create: `Sources/OpenstratorCore/Document/DocumentV6.swift`
- Test: `Tests/OpenstratorCoreTests/DocumentV6Tests.swift`

**Interfaces:**
- Produces:
  - `public struct NodeID: Hashable, Codable, Sendable`
  - `public struct DocumentV6: Codable, Equatable, Sendable`
  - `public struct DocumentNode: Codable, Equatable, Identifiable, Sendable`
  - `public enum NodePayload: Codable, Equatable, Sendable`
  - `public struct NodeTransform: Codable, Equatable, Sendable`
  - `public struct AppearanceV6: Codable, Equatable, Sendable`
  - `DocumentV6.node(id:)`, `parent(of:)`, `insert(_:parent:index:)`, `removeSubtree(id:)`, `replaceNode(_:)`.

- [ ] **Step 1: Write failing tree and serialization tests**

```swift
import XCTest
@testable import OpenstratorCore

final class DocumentV6Tests: XCTestCase {
    func testInsertChildMaintainsParentAndOrder() throws {
        var document = DocumentV6.empty(width: 1200, height: 800)
        let group = DocumentNode.group(name: "Group")
        let rect = DocumentNode.rectangle(name: "Rect", rect: CGRect(x: 20, y: 30, width: 100, height: 60))
        try document.insert(group, parent: document.activeArtboardID, index: 0)
        try document.insert(rect, parent: group.id, index: 0)

        XCTAssertEqual(document.parent(of: rect.id), group.id)
        XCTAssertEqual(document.node(id: group.id)?.children, [rect.id])
    }

    func testDocumentRoundTripsAsFormatSix() throws {
        var document = DocumentV6.empty(width: 640, height: 480)
        let text = DocumentNode.text(name: "Title", text: "Openstrator", frame: CGRect(x: 12, y: 18, width: 300, height: 80))
        try document.insert(text, parent: document.activeArtboardID, index: 0)

        let data = try JSONEncoder().encode(document)
        let decoded = try JSONDecoder().decode(DocumentV6.self, from: data)

        XCTAssertEqual(decoded.formatVersion, 6)
        XCTAssertEqual(decoded, document)
    }
}
```

- [ ] **Step 2: Run the tests and confirm RED**

Run: `swift test --filter DocumentV6Tests`

Expected: FAIL because V6 document types do not exist.

- [ ] **Step 3: Implement the minimal V6 model**

Use UUID-backed IDs and these exact M1 records:

```swift
public struct NodeID: Hashable, Codable, Sendable {
    public var rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
}

public struct RGBAColorV6: Codable, Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double
}

public enum BlendModeV6: String, Codable, Equatable, Sendable {
    case normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn
    case softLight, hardLight, difference, exclusion, hue, saturation, color, luminosity
}

public struct GradientStopV6: Codable, Equatable, Sendable {
    public var location: Double
    public var color: RGBAColorV6
}

public struct LinearGradientV6: Codable, Equatable, Sendable {
    public var angleDegrees: Double
    public var stops: [GradientStopV6]
}

public struct StrokeV6: Codable, Equatable, Sendable {
    public var color: RGBAColorV6
    public var width: Double
    public var dash: [Double]
    public var cap: String
    public var join: String
}

public struct LegacyEffectV6: Codable, Equatable, Sendable {
    public var kind: String
    public var amount: Double
    public var enabled: Bool
    public var boundsInflation: Double
}

public struct AppearanceV6: Codable, Equatable, Sendable {
    public var fill: RGBAColorV6
    public var gradient: LinearGradientV6?
    public var stroke: StrokeV6
    public var effects: [LegacyEffectV6]
}

public struct NodeTransform: Codable, Equatable, Sendable {
    public var translationX: Double
    public var translationY: Double
    public var rotationDegrees: Double
    public var scaleX: Double
    public var scaleY: Double
    public var shearX: Double
    public var shearY: Double
    public static let identity = NodeTransform(translationX: 0, translationY: 0, rotationDegrees: 0, scaleX: 1, scaleY: 1, shearX: 0, shearY: 0)
    public static func translation(x: Double, y: Double) -> NodeTransform {
        NodeTransform(translationX: x, translationY: y, rotationDegrees: 0, scaleX: 1, scaleY: 1, shearX: 0, shearY: 0)
    }
}

public struct ArtboardData: Codable, Equatable, Sendable { public var rect: CGRect; public var background: RGBAColorV6 }
public struct LiveRectData: Codable, Equatable, Sendable { public var rect: CGRect; public var cornerRadius: Double }
public struct LiveEllipseData: Codable, Equatable, Sendable { public var rect: CGRect }
public struct LivePolygonData: Codable, Equatable, Sendable { public var rect: CGRect; public var sides: Int }
public struct PathAnchorM1: Codable, Equatable, Sendable { public var point: CGPoint }
public struct PathData: Codable, Equatable, Sendable { public var anchors: [PathAnchorM1]; public var isClosed: Bool }
public struct TextDataM1: Codable, Equatable, Sendable { public var text: String; public var frame: CGRect; public var fontSize: Double; public var fontWeight: Double }
public struct GuideData: Codable, Equatable, Sendable { public var axis: String; public var position: Double }
public struct GridSettingsV6: Codable, Equatable, Sendable { public var spacing: Double; public var isVisible: Bool; public var snapEnabled: Bool }

public enum NodePayload: Codable, Equatable, Sendable {
    case root
    case group
    case artboard(ArtboardData)
    case rectangle(LiveRectData)
    case ellipse(LiveEllipseData)
    case polygon(LivePolygonData)
    case line(PathData)
    case path(PathData)
    case text(TextDataM1)
    case guide(GuideData)
}
```

Every `DocumentNode` must contain exactly these common fields:

```swift
public var id: NodeID
public var name: String
public var isVisible: Bool
public var isLocked: Bool
public var transform: NodeTransform
public var opacity: Double
public var blendMode: BlendModeV6
public var appearance: AppearanceV6
public var payload: NodePayload
public var children: [NodeID]
public var legacyGroupKey: UUID?
```

`DocumentV6.empty(width:height:)` creates a root node and one artboard child and sets `activeArtboardID`. `DocumentV6` stores `nodes: [NodeID: DocumentNode]`, `rootID`, `activeArtboardID`, `grid`, and document metadata. It exposes `rootChildren`, `artworkChildren` (children of `activeArtboardID`), `node(id:)`, `parent(of:)`, `insert(_:parent:index:)`, `removeSubtree(id:)`, and `replaceNode(_:)`. Factories `DocumentNode.group(name:)`, `.rectangle(name:rect:)`, `.ellipse(name:rect:)`, and `.text(name:text:frame:)` produce valid defaults. Tree mutation validates missing parents, duplicate IDs and parent cycles using thrown `DocumentTreeError` cases.

- [ ] **Step 4: Run focused tests and full suite**

Run: `swift test --filter DocumentV6Tests && swift test`

Expected: PASS, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Sources/OpenstratorCore/Document Tests/OpenstratorCoreTests/DocumentV6Tests.swift
 git commit -m "feat: add V6 document node tree"
```

---

### Task 3: Freeze V5.2 decoding and migrate legacy documents to V6

**Files:**
- Create: `Sources/OpenstratorCore/Document/LegacyV5.swift`
- Create: `Sources/OpenstratorCore/Document/V5Migrator.swift`
- Test: `Tests/OpenstratorCoreTests/V5MigratorTests.swift`

**Interfaces:**
- Consumes: V5.2 JSON shape currently represented by `OpenDocument` / `VectorObject` in `Openstrator/Models.swift:527-700`.
- Produces: `public enum V5Migrator { public static func migrate(_ legacy: LegacyDocumentV5) throws -> DocumentV6 }` and `public static func decodeAndMigrate(_ data: Data) throws -> DocumentV6`.

- [ ] **Step 1: Write a legacy fidelity fixture and failing migration test**

Create a JSON fixture in the test file containing two grouped objects: a gradient rectangle with a shadow and rotated/scaled text, plus one guide and nondefault grid settings. Assert every legacy field represented in V5.2 survives in the corresponding V6 node/appearance values.

```swift
func testMigratesLegacyGeometryAppearanceGroupingAndCanvasSettings() throws {
    let legacy = try JSONDecoder().decode(LegacyDocumentV5.self, from: Self.legacyFixture)
    let v6 = try V5Migrator.migrate(legacy)

    XCTAssertEqual(v6.artboardSize.width, 1440)
    XCTAssertEqual(v6.grid.spacing, 32)
    XCTAssertTrue(v6.grid.snapEnabled)
    XCTAssertEqual(v6.guides.count, 1)

    let topLevel = v6.artworkChildren.compactMap(v6.node(id:))
    XCTAssertEqual(topLevel.count, 1)
    guard case .group = topLevel[0].payload else { return XCTFail("legacy group must migrate to GroupNode") }
    let children = topLevel[0].children.compactMap(v6.node(id:))
    XCTAssertEqual(children.map(\.name), ["Gradient Card", "Headline"])
    XCTAssertEqual(children[0].appearance.effects.first?.kind, "shadow")
    XCTAssertEqual(children[1].transform.rotationDegrees, 17)
}
```

- [ ] **Step 2: Run and confirm RED**

Run: `swift test --filter V5MigratorTests`

Expected: FAIL because legacy decoder/migrator types do not exist.

- [ ] **Step 3: Implement frozen legacy types and mapping**

Copy the V5.2 serialized field names exactly into `LegacyV5.swift`; do not import SwiftUI. Translate:

- `rectangle`, `ellipse`, `polygon` → matching live-shape payload;
- `line`, `path` → `PathData` with corner anchors from legacy points;
- `text` → `TextDataM1` preserving text, size and weight;
- x/y/width/height → payload local bounds with node translation;
- rotation/scale/shear → `NodeTransform`;
- fill/gradient/stroke/strokeWidth/dash/cap/join → `AppearanceV6`;
- V5 effects → `LegacyEffectV6` records with original kind and amount;
- each legacy `groupID` → one `GroupNode` inserted at the first grouped object's z-order position, with grouped objects moved under it in original order; also retain the source UUID in `legacyGroupKey` for migration diagnostics;
- guides/grid/artboard/background → V6 canvas metadata.

- [ ] **Step 4: Verify migration and serialization round-trip**

Run: `swift test --filter V5MigratorTests && swift test`

Expected: PASS, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Sources/OpenstratorCore/Document/LegacyV5.swift Sources/OpenstratorCore/Document/V5Migrator.swift Tests/OpenstratorCoreTests/V5MigratorTests.swift
 git commit -m "feat: migrate V5 documents to V6 graph"
```

---

### Task 4: Replace full-document snapshots with delta command history

**Files:**
- Create: `Sources/OpenstratorCore/Commands/DocumentCommand.swift`
- Create: `Sources/OpenstratorCore/Commands/CommandHistory.swift`
- Test: `Tests/OpenstratorCoreTests/CommandHistoryTests.swift`

**Interfaces:**
- Produces:
  - `public enum DocumentMutation: Equatable, Sendable`
  - `public struct DocumentCommand: Equatable, Sendable`
  - `public struct CommandHistory`
  - `mutating func execute(_ command: DocumentCommand, on document: inout DocumentV6) throws`
  - `mutating func undo(on document: inout DocumentV6) throws`
  - `mutating func redo(on document: inout DocumentV6) throws`
  - `mutating func coalesce(_ command: DocumentCommand, on document: inout DocumentV6) throws`

- [ ] **Step 1: Write failing insert/delete/move/coalescing tests**

```swift
func testMoveCommandsCoalesceIntoOneUndoStep() throws {
    var document = makeDocumentWithOneRect()
    let id = document.artworkChildren[0]
    var history = CommandHistory(limit: 36)

    try history.execute(.setTransform(id: id, from: .identity, to: .translation(x: 10, y: 0), coalescingKey: "drag:\(id)"), on: &document)
    try history.coalesce(.setTransform(id: id, from: .translation(x: 10, y: 0), to: .translation(x: 25, y: 0), coalescingKey: "drag:\(id)"), on: &document)
    try history.undo(on: &document)

    XCTAssertEqual(document.node(id: id)?.transform, .identity)
    XCTAssertFalse(history.canUndo)
}
```

Also test insert→undo→redo and delete subtree→undo restoring original index and children.

- [ ] **Step 2: Run and confirm RED**

Run: `swift test --filter CommandHistoryTests`

Expected: FAIL because command history does not exist.

- [ ] **Step 3: Implement document mutations and bounded history**

Define the command support records explicitly:

```swift
public struct NodeSubtree: Equatable, Sendable {
    public var rootID: NodeID
    public var nodes: [NodeID: DocumentNode]
}

public struct CanvasSettingsV6: Codable, Equatable, Sendable {
    public var grid: GridSettingsV6
}

public enum DocumentMutation: Equatable, Sendable {
    case insert(parent: NodeID, index: Int, subtree: NodeSubtree)
    case remove(parent: NodeID, index: Int, subtree: NodeSubtree)
    case replaceNode(before: DocumentNode, after: DocumentNode)
    case setTransform(id: NodeID, before: NodeTransform, after: NodeTransform)
    case replaceCanvas(before: CanvasSettingsV6, after: CanvasSettingsV6)
}
```

`DocumentCommand` stores `label`, `forward: [DocumentMutation]`, `inverse: [DocumentMutation]`, and optional `coalescingKey`. Add factory `DocumentCommand.setTransform(id:from:to:coalescingKey:)` that creates forward `.setTransform(id:before:after:)` and inverse `.setTransform(id:before:after:)` with the values reversed. `CommandHistory` stores commands only; it must never retain whole `DocumentV6` snapshots. Test helpers `makeDocumentWithOneRect()` and `nodeTransform(_:,in:)` live only under `Tests/OpenstratorCoreTests/TestFixtures.swift`; `makeDocumentWithOneRect()` inserts one rectangle under `activeArtboardID`.

- [ ] **Step 4: Run focused and full tests**

Run: `swift test --filter CommandHistoryTests && swift test`

Expected: PASS, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Sources/OpenstratorCore/Commands Tests/OpenstratorCoreTests/CommandHistoryTests.swift
 git commit -m "feat: add delta command undo history"
```

---

### Task 5: Add one canonical viewport/document coordinate transform and adaptive grid math

**Files:**
- Create: `Sources/OpenstratorCore/Geometry/CanvasTransform.swift`
- Create: `Sources/OpenstratorCore/Selection/Snapping.swift`
- Test: `Tests/OpenstratorCoreTests/CanvasTransformTests.swift`
- Test: `Tests/OpenstratorCoreTests/SnappingTests.swift`

**Interfaces:**
- Produces:
  - `public struct CanvasTransform`
  - `func documentPoint(fromViewport:) -> CGPoint`
  - `func viewportPoint(fromDocument:) -> CGPoint`
  - `func documentDelta(fromViewportDelta:) -> CGVector`
  - `public struct GridMetrics`
  - `GridMetrics.make(baseSpacing:zoom:screenScale:)`
  - `snap(point:spacing:)`.

- [ ] **Step 1: Write failing coordinate round-trip tests for every required zoom**

```swift
func testViewportDocumentRoundTripAcrossZoomPanAndRotation() {
    for zoom in [0.25, 0.5, 1.0, 2.0, 4.0] {
        let transform = CanvasTransform(
            viewportSize: CGSize(width: 1440, height: 900),
            artboardSize: CGSize(width: 1200, height: 800),
            zoom: zoom,
            pan: CGSize(width: 137, height: -83),
            rotationDegrees: 13
        )
        let input = CGPoint(x: 387.25, y: 221.75)
        let viewport = transform.viewportPoint(fromDocument: input)
        let output = transform.documentPoint(fromViewport: viewport)
        XCTAssertEqual(output.x, input.x, accuracy: 0.001)
        XCTAssertEqual(output.y, input.y, accuracy: 0.001)
    }
}
```

Add a second test proving a 100-pixel viewport drag becomes `100 / zoom` document points when rotation is zero.

- [ ] **Step 2: Write failing adaptive grid test**

```swift
func testAdaptiveGridKeepsScreenSpacingReadable() {
    XCTAssertEqual(GridMetrics.make(baseSpacing: 24, zoom: 0.25, screenScale: 2).documentSpacing, 96)
    XCTAssertEqual(GridMetrics.make(baseSpacing: 24, zoom: 1.0, screenScale: 2).documentSpacing, 24)
    XCTAssertEqual(GridMetrics.make(baseSpacing: 24, zoom: 4.0, screenScale: 2).documentSpacing, 6)
}
```

- [ ] **Step 3: Run and confirm RED**

Run: `swift test --filter CanvasTransformTests && swift test --filter SnappingTests`

Expected: FAIL because transform/grid APIs do not exist.

- [ ] **Step 4: Implement matrix-based coordinate conversion**

Build the document→viewport `CGAffineTransform` in this order: translate document center to origin, rotate by `rotationDegrees`, scale by `zoom`, translate to viewport center + pan. `documentPoint` uses `transform.inverted()`; never duplicate this math in SwiftUI views.

Adaptive grid spacing must choose powers of two around the base spacing so projected minor lines stay between 12 and 48 physical pixels; return a pixel-aligned viewport offset using `screenScale`.

- [ ] **Step 5: Run focused and full tests**

Run: `swift test --filter CanvasTransformTests && swift test --filter SnappingTests && swift test`

Expected: PASS, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add Sources/OpenstratorCore/Geometry/CanvasTransform.swift Sources/OpenstratorCore/Selection/Snapping.swift Tests/OpenstratorCoreTests/CanvasTransformTests.swift Tests/OpenstratorCoreTests/SnappingTests.swift
 git commit -m "feat: unify canvas coordinates and grid math"
```

---

### Task 6: Implement transformed geometry hit testing

**Files:**
- Create: `Sources/OpenstratorCore/Geometry/AffineGeometry.swift`
- Create: `Sources/OpenstratorCore/Selection/HitTesting.swift`
- Test: `Tests/OpenstratorCoreTests/HitTestingTests.swift`

**Interfaces:**
- Consumes: `DocumentV6`, `DocumentNode`, `NodeTransform` from Task 2.
- Produces:
  - `public struct HitTestOptions`
  - `public struct HitResult`
  - `public enum HitTester { static func hitTest(point:in:options:) -> HitResult? }`
  - `public enum GeometryResolver { static func geometricBounds(nodeID:in:) -> CGRect?; static func transformedCorners(nodeID:in:) -> [CGPoint] }`.

- [ ] **Step 1: Write failing rectangle/ellipse/line/path transform tests**

```swift
func testRotatedRectangleHitsVisibleGeometryButNotAABBCorner() throws {
    var document = DocumentV6.empty(width: 800, height: 600)
    var rect = DocumentNode.rectangle(name: "Rotated", rect: CGRect(x: -50, y: -25, width: 100, height: 50))
    rect.transform = NodeTransform(translationX: 300, translationY: 200, rotationDegrees: 45, scaleX: 1, scaleY: 1, shearX: 0, shearY: 0)
    try document.insert(rect, parent: document.rootID, index: 0)

    XCTAssertNotNil(HitTester.hitTest(point: CGPoint(x: 300, y: 200), in: document))
    XCTAssertNil(HitTester.hitTest(point: CGPoint(x: 350, y: 150), in: document))
}
```

Add tests for ellipse fill, a 2 pt line hit with an 8 pt screen-independent tolerance, open path segment distance, hidden node rejection, and locked node rejection by default.

- [ ] **Step 2: Run and confirm RED**

Run: `swift test --filter HitTestingTests`

Expected: FAIL because `HitTester` does not exist.

- [ ] **Step 3: Implement local-space hit testing**

For each candidate in reverse paint order:

1. compose ancestor + local transform;
2. inverse-transform the document point into node-local coordinates;
3. rectangle/polygon: fill containment plus stroke expansion;
4. ellipse: normalized ellipse equation for fill, ring distance for stroke;
5. line/path: minimum distance to each line/cubic segment using flattened tolerance bounded to 0.5 document points;
6. text in M1: local text frame containment;
7. ignore hidden nodes and locked nodes unless `HitTestOptions.includeLocked == true`.

Return `HitResult(nodeID:part:distance:)` and sort equal-depth candidates by distance before z-order fallback. `GeometryResolver.transformedCorners` returns the four transformed local bounds corners for live shapes/text and path bounds corners for paths; `geometricBounds` returns their document-space union.

- [ ] **Step 4: Run focused and full tests**

Run: `swift test --filter HitTestingTests && swift test`

Expected: PASS, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Sources/OpenstratorCore/Geometry/AffineGeometry.swift Sources/OpenstratorCore/Selection/HitTesting.swift Tests/OpenstratorCoreTests/HitTestingTests.swift
 git commit -m "feat: add transformed geometry hit testing"
```

---

### Task 7: Add stable drag and modifier-aware resize transform sessions

**Files:**
- Create: `Sources/OpenstratorCore/Selection/TransformSession.swift`
- Test: `Tests/OpenstratorCoreTests/TransformSessionTests.swift`

**Interfaces:**
- Consumes: selected node IDs and starting transforms/bounds.
- Produces:
  - `public enum ResizeHandleV6`
  - `public struct TransformModifiers: OptionSet`
  - `public struct MoveSession`
  - `public struct ResizeSession`
  - `MoveSession.transforms(currentPointer:)`
  - `ResizeSession.result(pointerDocumentPoint:modifiers:)`.

- [ ] **Step 1: Write failing move-origin test**

```swift
func testMoveUsesOriginalSnapshotInsteadOfAccumulatingDeltas() {
    let session = MoveSession(startPointer: CGPoint(x: 10, y: 10), originals: [id: .identity])
    let a = session.transforms(currentPointer: CGPoint(x: 20, y: 10))
    let b = session.transforms(currentPointer: CGPoint(x: 35, y: 10))
    XCTAssertEqual(a[id]?.translationX, 10)
    XCTAssertEqual(b[id]?.translationX, 25)
}
```

- [ ] **Step 2: Write failing Shift/Option resize tests**

For a starting rect `(100,100,200,100)` and bottom-right handle:

- default pointer `(400,260)` → width 300, height 160;
- Shift → preserve 2:1 ratio → width 300, height 150;
- Option → center remains `(200,150)`;
- Shift+Option → center remains `(200,150)` and ratio remains 2:1;
- crossing the opposite corner produces a normalized rectangle at least 4×4 without NaN values.

- [ ] **Step 3: Run and confirm RED**

Run: `swift test --filter TransformSessionTests`

Expected: FAIL because transform sessions do not exist.

- [ ] **Step 4: Implement transform sessions from immutable origin state**

Define modifier flags exactly:

```swift
public struct TransformModifiers: OptionSet, Sendable {
    public let rawValue: Int
    public static let preserveAspect = TransformModifiers(rawValue: 1 << 0)
    public static let fromCenter = TransformModifiers(rawValue: 1 << 1)
    public static let axisConstraint = TransformModifiers(rawValue: 1 << 2)
}
```

`ResizeSession` stores the original selection bounds, original node transforms, active handle and start pointer. Corner constraint uses the original `aspectRatio = width / height`; Option maps to `.fromCenter` and mirrors the moved edge around the original center; Shift maps to `.preserveAspect` and chooses the dominant pointer axis before applying the ratio; minimum size is exactly 4 document points. For a singly selected rotated node, the session converts the pointer through the inverse node transform, resizes in local coordinates, then reapplies the original rotation; for multiple nodes, it operates on the document-space union bounds.

- [ ] **Step 5: Run focused and full tests**

Run: `swift test --filter TransformSessionTests && swift test`

Expected: PASS, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add Sources/OpenstratorCore/Selection/TransformSession.swift Tests/OpenstratorCoreTests/TransformSessionTests.swift
 git commit -m "feat: add stable move and resize sessions"
```

---

### Task 8: Integrate V6 core into EditorStore and CanvasView, fixing the reported interactions

**Files:**
- Modify: `Openstrator/EditorStore.swift:1-1548`
- Modify: `Openstrator/CanvasView.swift:1-934`
- Modify: `Openstrator/Models.swift:527-700`
- Modify: `Openstrator/OpenstratorApp.swift`
- Modify: `Openstrator/Exporters.swift`
- Test: `Tests/OpenstratorAppTests/KeyboardRoutingTests.swift`
- Test: `Tests/OpenstratorAppTests/EditorIntegrationTests.swift`

**Interfaces:**
- Consumes: Tasks 2–7.
- Produces UI adapter methods:
  - `EditorStore.canvasTransform(viewportSize:screenScale:)`
  - `EditorStore.beginMove(pointer:)`, `updateMove(pointer:)`, `endMove()`
  - `EditorStore.beginResize(handle:pointer:)`, `updateResize(pointer:modifiers:)`, `endResize()`
  - `EditorStore.select(at:additive:)`
  - `EditorStore.handleCanvasKeyCode(_:textEditingActive:) -> Bool`
  - `EditorStore.handleCanvasKeyDown(_:) -> Bool` (thin `NSEvent` adapter around `handleCanvasKeyCode`)
  - `EditorStore.appendFreehandPoint(_:)`
  - `EditorStore.makeForTests(document:)` under `#if DEBUG` for deterministic app-target tests.

- [ ] **Step 1: Write failing Delete/Backspace routing tests**

```swift
func testBackspaceReturnsHandledWhenSelectionWasDeleted() throws {
    let store = EditorStore.makeForTests(document: makeOneRectangleDocument())
    store.selection = [store.document.artworkChildren[0]]
    let handled = store.handleCanvasKeyCode(51, textEditingActive: false)
    XCTAssertTrue(handled)
    XCTAssertTrue(store.selection.isEmpty)
    XCTAssertTrue(store.document.artworkChildren.isEmpty)
}

func testBackspacePassesThroughDuringTextEditing() throws {
    let store = EditorStore.makeForTests(document: makeOneRectangleDocument())
    store.selection = [store.document.artworkChildren[0]]
    XCTAssertFalse(store.handleCanvasKeyCode(51, textEditingActive: true))
    XCTAssertEqual(store.document.artworkChildren.count, 1)
}
```

This specifically prevents V5.2's current `deleteSelection(); return !selection.isEmpty` bug, which returns false after clearing the selection.

- [ ] **Step 2: Write failing brush and drag integration tests**

Use the pure `CanvasTransform` to simulate viewport samples at zooms `[0.25, 0.5, 1, 2, 4]`; append the converted points through `appendFreehandPoint` and assert the stored path anchors equal the intended document points within 0.001. Add a drag test that sends pointer positions `(100,100) → (110,100) → (130,100)` and asserts the selected node ends exactly 30 document points from its original position, not 40.

- [ ] **Step 3: Run and confirm RED**

Run: `swift test --filter KeyboardRoutingTests && swift test --filter EditorIntegrationTests`

Expected: FAIL because `EditorStore` still owns V5 `OpenDocument` and uses cumulative gestures.

- [ ] **Step 4: Change EditorStore ownership to V6**

Replace:

```swift
@Published var document = OpenDocument()
private var undoStack: [OpenDocument] = []
private var redoStack: [OpenDocument] = []
```

with:

```swift
@Published var document: DocumentV6
@Published var selection: Set<NodeID> = []
private var history: CommandHistory
private var moveSession: MoveSession?
private var resizeSession: ResizeSession?
```

Initialize history limit from the existing architecture profile (`36` Intel, `64` Apple Silicon). File open first attempts V6 decode, then `V5Migrator.decodeAndMigrate`. Save encodes V6 format 6.

- [ ] **Step 5: Replace selection and movement routing**

- `select(at:)` calls `HitTester.hitTest`.
- A normal click does not begin movement until document-space movement exceeds `3 / zoom` screen-equivalent points.
- Movement and resize update node transforms from `MoveSession` / `ResizeSession` originals.
- One coalesced `DocumentCommand` is committed on mouse-up.
- Freehand tools use raw document-space points from `CanvasTransform`; grid snapping is not applied to every brush sample.
- Grid snapping is applied to shape creation and object move endpoints when enabled.

- [ ] **Step 6: Replace CanvasView coordinate and grid code**

Delete `CanvasView.toDocument(_:in:)`. Create one `CanvasTransform` per gesture/render pass from store zoom/pan/viewRotation/artboard/viewport. Use its conversion for all tool pointers and deltas. Remove the grid from the scaled artboard `DocumentArtworkView`; render it in a viewport-space `Canvas` clipped to the transformed artboard polygon. Generate document-space grid lines with `GridMetrics`, map each endpoint through `CanvasTransform`, and stroke at exactly `1 / screenScale` viewport points with half-pixel alignment. This prevents line-width scaling and shimmer during zoom/pan.

For a single selection, draw the selection polygon through `GeometryResolver.transformedCorners` rather than raw `object.bounds`; place corner handles at those transformed corners. For multiple selection, use the union of `GeometryResolver.geometricBounds`. Selection handles keep a 9×9 visible square but add a transparent 24×24 `contentShape(Rectangle())` hit target. Corner handle updates pass current `NSEvent.modifierFlags` mapped to `TransformModifiers`; rotated single-object resize is delegated to `ResizeSession` local-coordinate logic.

- [ ] **Step 7: Adapt current render/export paths to M1 V6 nodes**

Render/export exactly the node payloads available in Task 2: rectangle, ellipse, polygon, line/path, text, group and artboard. Preserve V5 appearance fields represented by `AppearanceV6`. Apply each migrated legacy effect once to one offscreen layer, expand that layer's allocation by `LegacyEffectV6.boundsInflation`, then composite once; do not stroke the base geometry again inside the effect loop. This is the M1 guard against duplicate-looking strokes and clipped shadow/glow bounds. Unsupported future node kinds do not exist in M1's `NodePayload`, so no enabled UI can create them.

- [ ] **Step 8: Run focused integration tests and full suite**

Run: `swift test --filter KeyboardRoutingTests && swift test --filter EditorIntegrationTests && swift test`

Expected: PASS, 0 failures.

- [ ] **Step 9: Commit**

```bash
git add Openstrator Sources/OpenstratorCore Tests/OpenstratorAppTests
 git commit -m "refactor: route editor interactions through V6 core"
```

---

### Task 9: Correct icon alpha and harden the Terminal builder

**Files:**
- Modify: `Resources/OpenstratorMark.png`
- Modify: `Resources/Openstrator.icns`
- Modify: `BUILD_OPENSTRATOR.command`
- Create: `scripts/verify_icon_alpha.swift`
- Create: `scripts/rebuild_icns.sh`

**Interfaces:**
- Produces: source mark with transparent outer corners; `.icns` generated from that mark; builder that runs tests before release compile and exits with the real failing status.

- [ ] **Step 1: Write the failing icon-alpha verifier**

Create `scripts/verify_icon_alpha.swift`:

```swift
import AppKit
import Foundation

let url = URL(fileURLWithPath: "Resources/OpenstratorMark.png")
guard let data = try? Data(contentsOf: url),
      let image = NSImage(data: data),
      let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff) else {
    fatalError("unable to decode icon")
}
let corners = [(0, 0), (rep.pixelsWide - 1, 0), (0, rep.pixelsHigh - 1), (rep.pixelsWide - 1, rep.pixelsHigh - 1)]
for (x, y) in corners {
    guard let color = rep.colorAt(x: x, y: y), color.alphaComponent == 0 else {
        fatalError("icon corner at \(x),\(y) is not transparent")
    }
}
print("icon alpha OK")
```

Run on macOS: `swift scripts/verify_icon_alpha.swift`

Expected: FAIL on the current white-corner asset.

- [ ] **Step 2: Remove only the external white matte**

Create an alpha mask connected to the image border for near-white pixels (`R,G,B >= 245`) and feather the matte boundary by one pixel. Do not remove white/silver elements enclosed inside the icon mark. Save the result back to `Resources/OpenstratorMark.png`.

- [ ] **Step 3: Rebuild the macOS icon resource**

`scripts/rebuild_icns.sh` must generate 16, 32, 128, 256, 512 and 1024 logical sizes plus `@2x` variants into a temporary `.iconset`, then run `iconutil -c icns` on macOS and replace `Resources/Openstrator.icns`.

- [ ] **Step 4: Make the Terminal builder test-first**

Before release compile, run:

```zsh
swift test 2>&1 | tee -a "$LOG"
build_status=${pipestatus[1]}
(( build_status == 0 )) || exit 11
```

Use a writable variable named `build_status`, never zsh's read-only `status`. Do not create `Build Output` until the executable exists and architecture verification passes.

- [ ] **Step 5: Run local non-macOS checks**

Run on macOS: `swift scripts/verify_icon_alpha.swift && bash -n scripts/rebuild_icns.sh`; after creating each delivery ZIP run `unzip -t Openstrator-Intel-V6-M1-Terminal.zip` and `unzip -t Openstrator-AppleSilicon-V6-M1-Terminal.zip`.

Expected: alpha verifier PASS, shell syntax PASS, ZIP CRC PASS. `iconutil` remains a macOS-only verification in Task 10.

- [ ] **Step 6: Commit**

```bash
git add Resources BUILD_OPENSTRATOR.command scripts/verify_icon_alpha.swift scripts/rebuild_icns.sh
 git commit -m "fix: remove icon matte and harden terminal build"
```

---

### Task 10: M1 acceptance suite and architecture build matrix

**Files:**
- Create: `Tests/OpenstratorCoreTests/M1AcceptanceTests.swift`
- Create: `scripts/m1_acceptance.sh`
- Modify: `QA_REPORT.md`
- Modify: `BUILD_FIX_NOTES.md`

**Interfaces:**
- Consumes: every M1 interface.
- Produces: one command for source-level acceptance and one macOS build command per architecture.

- [ ] **Step 1: Add the consolidated release-blocking acceptance tests**

`M1AcceptanceTests.swift` must include these exact behaviors:

1. viewport/document coordinate round-trip at 25/50/100/200/400%;
2. transformed geometry selection;
3. stable non-cumulative move;
4. Shift resize ratio;
5. Option center resize;
6. Shift+Option combined resize;
7. V5 fixture migration and V6 serialization round-trip;
8. grid adaptive spacing at extreme zooms;
9. undo/redo after move/delete;
10. effect visual-bounds inflation record survives migration;
11. transformed corner coordinates used by selection handles match rotated geometry.

- [ ] **Step 2: Run the full source test suite**

Run: `swift test`

Expected: PASS, 0 failures.

- [ ] **Step 3: Run the M1 acceptance script**

`scripts/m1_acceptance.sh` must run, in order:

```bash
swift test
swift scripts/verify_icon_alpha.swift
swiftc -frontend -parse Openstrator/*.swift Sources/OpenstratorCore/**/*.swift
```

Expected: exit 0.

- [ ] **Step 4: On an Intel Mac, build and smoke launch**

Run: `./BUILD_OPENSTRATOR.command`

Expected:
- `swift test` exits 0;
- release compile exits 0;
- `file "Build Output/Openstrator.app/Contents/MacOS/Openstrator"` reports `x86_64`;
- `open "Build Output/Openstrator.app"` launches without immediate termination;
- Backspace/Delete, selection, brush tracking, move, Shift-resize and grid behavior pass a manual smoke checklist recorded in `QA_REPORT.md`.

- [ ] **Step 5: On an Apple Silicon Mac runner, build and smoke launch**

Use the Apple Silicon package/config with the same source revision.

Expected:
- tests exit 0;
- binary reports `arm64`;
- app launches;
- same manual smoke checklist passes.

- [ ] **Step 6: Update QA documentation with evidence only**

Record command, macOS version, Swift version, architecture, exit code and failure count. Do not write “verified” for an architecture that was not actually built and launched.

- [ ] **Step 7: Commit**

```bash
git add Tests/OpenstratorCoreTests/M1AcceptanceTests.swift scripts/m1_acceptance.sh QA_REPORT.md BUILD_FIX_NOTES.md
 git commit -m "test: gate Openstrator V6 milestone one"
```

---

## Milestone 1 Completion Contract

Milestone 1 is complete only when all of the following are evidenced:

- `swift test` reports 0 failures;
- V5.2 fixture migration and V6 serialization pass;
- undo/redo uses command deltas rather than `[OpenDocument]` snapshots;
- pointer→document conversion is shared by rendering and interaction;
- Paintbrush/Pencil pointer tests pass at all five required zoom levels;
- transformed hit testing tests pass;
- move and resize modifier tests pass;
- Delete/Backspace routing tests pass including text-edit focus;
- adaptive grid tests pass;
- icon corner alpha verifier passes;
- Intel package is built and launched on Intel macOS;
- Apple Silicon package is built and launched on arm64 macOS;
- no enabled M1 UI command points at missing behavior.

The next implementation plan starts only after this milestone's evidence is captured.
