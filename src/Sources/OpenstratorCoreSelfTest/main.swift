import Foundation
import OpenstratorCore

private var checks = 0

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() {
        fatalError("OpenstratorCoreSelfTest FAILED: \(message)")
    }
}

private func nearlyEqual(_ lhs: Double, _ rhs: Double, tolerance: Double = 0.001) -> Bool {
    abs(lhs - rhs) <= tolerance
}

require(OpenstratorCoreInfo.documentFormatVersion == 6, "document format version must be 6")

for zoom in [0.25, 0.5, 1.0, 2.0, 4.0] {
    let transform = CanvasTransform(
        viewportSize: CGSize(width: 1440, height: 900),
        artboardSize: CGSize(width: 1200, height: 800),
        zoom: zoom,
        pan: CGSize(width: 137, height: -83),
        rotationDegrees: 13
    )
    let input = CGPoint(x: 387.25, y: 221.75)
    let output = transform.documentPoint(fromViewport: transform.viewportPoint(fromDocument: input))
    require(nearlyEqual(Double(output.x), Double(input.x)), "canvas X round-trip failed at zoom \(zoom)")
    require(nearlyEqual(Double(output.y), Double(input.y)), "canvas Y round-trip failed at zoom \(zoom)")
}

require(GridMetrics.make(baseSpacing: 24, zoom: 0.25, screenScale: 2).documentSpacing == 96, "zoomed-out grid spacing")
require(GridMetrics.make(baseSpacing: 24, zoom: 4, screenScale: 2).documentSpacing == 6, "zoomed-in grid spacing")
require(CanvasKeyRouting.shouldHandleDelete(keyCode: 51, hasSelection: true, textEditingActive: false), "Backspace must delete selected artwork")
require(!CanvasKeyRouting.shouldHandleDelete(keyCode: 51, hasSelection: true, textEditingActive: true), "Backspace must remain available while editing text")

let id = NodeID()
let move = MoveSession(startPointer: CGPoint(x: 10, y: 10), originals: [id: .identity])
let moved = move.transforms(currentPointer: CGPoint(x: 35, y: 10))
require(nearlyEqual(moved[id]?.translationX ?? .nan, 25), "move session must use original transform snapshot")

let resize = ResizeSession(
    originalBounds: CGRect(x: 100, y: 100, width: 200, height: 100),
    originals: [id: .identity],
    handle: .bottomRight,
    startPointer: CGPoint(x: 300, y: 200)
)
let proportional = resize.result(pointerDocumentPoint: CGPoint(x: 400, y: 260), modifiers: [.preserveAspect])
require(nearlyEqual(Double(proportional.bounds.width / proportional.bounds.height), 2), "Shift resize must preserve aspect ratio")
let centered = resize.result(pointerDocumentPoint: CGPoint(x: 400, y: 260), modifiers: [.fromCenter])
require(nearlyEqual(Double(centered.bounds.midX), 200) && nearlyEqual(Double(centered.bounds.midY), 150), "Option resize must scale from center")

var document = DocumentV6.empty(width: 800, height: 600)
var rect = DocumentNode.rectangle(name: "Self Test Rect", rect: CGRect(x: -50, y: -25, width: 100, height: 50))
rect.transform = NodeTransform(translationX: 300, translationY: 200, rotationDegrees: 45, scaleX: 1, scaleY: 1, shearX: 0, shearY: 0)
do {
    try document.insert(rect, parent: document.activeArtboardID, index: 0)
} catch {
    fatalError("OpenstratorCoreSelfTest FAILED: document insertion error: \(error)")
}
require(HitTester.hitTest(point: CGPoint(x: 300, y: 200), in: document)?.nodeID == rect.id, "transformed hit-testing must select visible geometry")
require(HitTester.hitTest(point: CGPoint(x: 350, y: 150), in: document) == nil, "hit-testing must reject empty AABB corners")

do {
    let encoded = try JSONEncoder().encode(document)
    let decoded = try JSONDecoder().decode(DocumentV6.self, from: encoded)
    require(decoded == document, "V6 document JSON round-trip")
} catch {
    fatalError("OpenstratorCoreSelfTest FAILED: document coding error: \(error)")
}

var history = CommandHistory(limit: 8)
do {
    let before = document.node(id: rect.id)!.transform
    let after = NodeTransform.translation(x: 20, y: 0)
    try history.execute(.setTransform(id: rect.id, from: before, to: after), on: &document)
    require(nearlyEqual(document.node(id: rect.id)?.transform.translationX ?? .nan, 20), "command execute")
    try history.undo(on: &document)
    require(document.node(id: rect.id)?.transform == before, "command undo")
    try history.redo(on: &document)
    require(nearlyEqual(document.node(id: rect.id)?.transform.translationX ?? .nan, 20), "command redo")
} catch {
    fatalError("OpenstratorCoreSelfTest FAILED: command-history error: \(error)")
}

print("OpenstratorCoreSelfTest: PASS (\(checks) checks)")

// V6 M2 vector-path release gates.
let cubic = CubicBezierSegmentV6(
    p0: CGPoint(x: 0, y: 0),
    p1: CGPoint(x: 0, y: 100),
    p2: CGPoint(x: 100, y: 100),
    p3: CGPoint(x: 100, y: 0)
)
let cubicMid = BezierGeometry.point(on: cubic, t: 0.5)
require(nearlyEqual(Double(cubicMid.x), 50) && nearlyEqual(Double(cubicMid.y), 75), "cubic midpoint must use true Bezier evaluation")

let directPath = BezierPathV6(anchors: [
    PathAnchorV6(point: CGPoint(x: 0, y: 0), outHandle: CGPoint(x: 30, y: 0), kind: .symmetric),
    PathAnchorV6(point: CGPoint(x: 100, y: 0), inHandle: CGPoint(x: 70, y: 0), kind: .symmetric)
])
let handleHit = DirectSelection.hitTest(path: directPath, point: CGPoint(x: 30, y: 0), tolerance: 2)
require(handleHit?.component == .outgoingHandle(0), "direct selection must hit outgoing handles")
let movedAnchor = DirectSelection.moveAnchor(path: directPath, index: 0, to: CGPoint(x: 10, y: 5))
require(movedAnchor.anchors[0].outHandle == CGPoint(x: 40, y: 5), "moving an anchor must move its handles")

var pen = PenPathBuilder(closeTolerance: 6)
_ = pen.add(point: CGPoint(x: 10, y: 10), dragTo: CGPoint(x: 30, y: 10))
_ = pen.add(point: CGPoint(x: 100, y: 10))
let penClose = pen.add(point: CGPoint(x: 12, y: 10))
require(penClose.closed && pen.path.isClosed, "Pen must close when clicking near the first anchor")
require(pen.path.anchors.first?.inHandle != nil && pen.path.anchors.first?.outHandle != nil, "Pen drag must create symmetric handles")

var curvature = CurvaturePathBuilder(closeTolerance: 6)
_ = curvature.add(point: CGPoint(x: 0, y: 0))
_ = curvature.add(point: CGPoint(x: 50, y: 40))
_ = curvature.add(point: CGPoint(x: 100, y: 0))
require(curvature.path.anchors[1].kind == .smooth && curvature.path.anchors[1].inHandle != nil && curvature.path.anchors[1].outHandle != nil, "Curvature must generate smooth internal handles")

let pencilSamples = (0...40).map { i in CGPoint(x: Double(i) * 4, y: sin(Double(i) * 0.3) * 0.35) }
let fittedPencil = PencilFitter.fit(samples: pencilSamples, tolerance: 1.0, smoothing: 0.85)
require(fittedPencil.anchors.count >= 2 && fittedPencil.anchors.count < pencilSamples.count, "Pencil fitting must simplify noisy samples without collapsing the stroke")
require(fittedPencil.anchors.first?.point == pencilSamples.first && fittedPencil.anchors.last?.point == pencilSamples.last, "Pencil fitting must preserve endpoints")

var snapDocument = DocumentV6.empty(width: 600, height: 400)
let guideNode = DocumentNode(name: "Self Test Guide", payload: .guide(GuideData(axis: "vertical", position: 123)))
do {
    try snapDocument.insert(guideNode, parent: snapDocument.rootID, index: snapDocument.rootChildren.count)
} catch {
    fatalError("OpenstratorCoreSelfTest FAILED: snap guide insertion error: \(error)")
}
let snappedGuide = SnapEngine.snap(point: CGPoint(x: 120, y: 90), document: snapDocument, options: SnapOptionsV6(tolerance: 5, grid: false, guides: true, anchors: false, artboards: false))
require(nearlyEqual(Double(snappedGuide.point.x), 123), "smart snap must snap X to a vertical guide")

do {
    let second = try snapDocument.addArtboard(rect: CGRect(x: 650, y: 0, width: 600, height: 400), makeActive: true)
    require(snapDocument.artboardIDs.count == 2 && snapDocument.activeArtboardID == second, "adding an artboard must preserve a valid active artboard")
    let third = try snapDocument.duplicateArtboard(id: second, offset: CGSize(width: 30, height: 20), makeActive: true)
    require(snapDocument.artboardIDs.count == 3 && snapDocument.activeArtboardID == third, "duplicating an artboard must create a distinct active artboard")
    try snapDocument.removeArtboard(id: third)
    require(snapDocument.artboardIDs.count == 2 && snapDocument.artboardIDs.contains(snapDocument.activeArtboardID), "removing an active artboard must select a valid replacement")
} catch {
    fatalError("OpenstratorCoreSelfTest FAILED: artboard operations error: \(error)")
}

print("OpenstratorCoreSelfTest M2: PASS (\(checks) checks)")

do {
    let closedCutSource = BezierPathV6(anchors: [
        PathAnchorV6(point: CGPoint(x: 0, y: 0)),
        PathAnchorV6(point: CGPoint(x: 100, y: 0)),
        PathAnchorV6(point: CGPoint(x: 100, y: 100))
    ], isClosed: true)
    let cutParts = try PathEditor.cut(path: closedCutSource, segmentIndex: 2, t: 0.5)
    require(cutParts.count == 1 && cutParts[0].isClosed == false && cutParts[0].anchors.first?.point == cutParts[0].anchors.last?.point, "closed seam cut must open the path at the exact seam point")
} catch {
    fatalError("OpenstratorCoreSelfTest FAILED: closed seam cut error: \(error)")
}

print("OpenstratorCoreSelfTest M2 final: PASS (\(checks) checks)")

// V6 M3 professional typography release gates.
var m3Character = CharacterStyleV6(
    fontFamily: "Openstrator Test Sans",
    fontFace: "Semibold Italic",
    postScriptName: "OpenstratorTest-SemiboldItalic",
    fontSize: 36,
    legacyWeight: 0.65,
    leading: 44,
    tracking: 80,
    kerning: -20,
    baselineShift: 2,
    horizontalScale: 1.1,
    verticalScale: 0.95,
    rotationDegrees: 3,
    underline: true,
    strikethrough: false,
    capitalization: .smallCaps,
    scriptPosition: .normal,
    openTypeFeatures: ["liga": true],
    variableAxes: ["2003265652": 625]
)
var m3Paragraph = ParagraphStyleV6(alignment: .center, leftIndent: 8, rightIndent: 6, firstLineIndent: 12, spacingBefore: 4, spacingAfter: 5, lineSpacing: 3, tabs: [24, 72], listStyle: .bullets, hyphenation: true, direction: .leftToRight)
var m3Text = TextDataV6(
    text: "Openstrator typography",
    frame: CGRect(x: 20, y: 30, width: 180, height: 90),
    layoutMode: .area,
    character: m3Character,
    paragraph: m3Paragraph,
    glyphTransforms: [GlyphTransformV6(glyphIndex: 2, offsetX: 4, offsetY: -3, scaleX: 1.15, scaleY: 0.9, rotationDegrees: 12)],
    warp: TextWarpV6(style: .arc, bend: 0.4)
)
require(m3Text.character.fontFamily == "Openstrator Test Sans" && m3Text.layoutMode == .area, "M3 typography payload must preserve rich character and layout data")
do {
    let encoded = try JSONEncoder().encode(m3Text)
    let decoded = try JSONDecoder().decode(TextDataV6.self, from: encoded)
    require(decoded == m3Text, "M3 typography payload must round-trip through JSON")
} catch {
    fatalError("OpenstratorCoreSelfTest FAILED: M3 typography coding error: \(error)")
}

let areaA = TextDataV6(text: "", frame: CGRect(x: 0, y: 0, width: 90, height: 48), layoutMode: .area, character: CharacterStyleV6(fontSize: 12, leading: 14))
let areaB = TextDataV6(text: "", frame: CGRect(x: 100, y: 0, width: 90, height: 48), layoutMode: .area, character: CharacterStyleV6(fontSize: 12, leading: 14))
let threadedSource = String(repeating: "A", count: 100)
let threaded = TextThreadEngine.flow(text: threadedSource, frames: [areaA, areaB])
require(threaded.frames.map(\.visibleText).joined() + threaded.overflow == threadedSource, "threaded area text must preserve every character including overflow")

let verticalArea = TextDataV6(text: "", frame: CGRect(x: 0, y: 0, width: 48, height: 90), layoutMode: .verticalArea, character: CharacterStyleV6(fontSize: 12, leading: 14))
require(TextThreadEngine.capacity(for: verticalArea) > 10, "vertical area text must calculate rows and columns")

let chainA = UUID(), chainB = UUID()
var rejectedCycle = false
do {
    _ = try TextThreadEngine.orderedChain(start: chainA, links: [
        chainA: TextThreadV6(previousFrameID: chainB, nextFrameID: chainB),
        chainB: TextThreadV6(previousFrameID: chainA, nextFrameID: chainA)
    ])
} catch TextThreadError.cycle {
    rejectedCycle = true
} catch {
    rejectedCycle = false
}
require(rejectedCycle, "text threading must reject cycles")

let typePath = BezierPathV6(anchors: [
    PathAnchorV6(point: CGPoint(x: 0, y: 0)),
    PathAnchorV6(point: CGPoint(x: 100, y: 0)),
    PathAnchorV6(point: CGPoint(x: 100, y: 100))
])
let typePlacements = TextPathLayout.placements(advances: [20, 20, 20, 20, 20, 20], path: typePath, startOffset: 0, endOffset: 0, baselineOffset: 0, flip: false)
require(typePlacements.count == 6, "type-on-path must place glyph advances until path capacity is exhausted")
require(nearlyEqual(typePlacements.first?.angleDegrees ?? .nan, 0, tolerance: 2) && abs(typePlacements.last?.angleDegrees ?? 0) > 80, "type-on-path must follow segment tangents")

let transformedGlyph = TextPathLayout.applying(GlyphTransformV6(glyphIndex: 0, offsetX: 3, offsetY: -4, scaleX: 1.2, scaleY: 0.8, rotationDegrees: 15), to: TextGlyphPlacementV6(glyphIndex: 0, point: CGPoint(x: 10, y: 20), angleDegrees: 5))
require(transformedGlyph.point == CGPoint(x: 13, y: 16) && nearlyEqual(transformedGlyph.angleDegrees, 20), "Touch Type glyph transforms must persist offset and rotation")

let arcWarp = TextWarpEngine.offset(normalizedX: 0.5, normalizedY: 0.5, warp: TextWarpV6(style: .arc, bend: 0.8), frame: CGSize(width: 200, height: 80))
let arcEdge = TextWarpEngine.offset(normalizedX: 0, normalizedY: 0.5, warp: TextWarpV6(style: .arc, bend: 0.8), frame: CGSize(width: 200, height: 80))
require(abs(arcWarp.dy) > abs(arcEdge.dy), "arc text warp must bend the center more than the edge")

m3Character.fontSize = -50
m3Character.horizontalScale = 0
m3Character.normalize()
require(m3Character.fontSize >= 1 && m3Character.horizontalScale >= 0.05, "typography normalization must clamp unsafe font metrics")

m3Text.character = m3Character
m3Paragraph.alignment = .justify
m3Text.paragraph = m3Paragraph
require(m3Text.paragraph.alignment == .justify && m3Text.paragraph.listStyle == .bullets, "paragraph formatting must preserve alignment and list style")

let unitStyle = CharacterStyleV6(fontSize: 20, tracking: 100, kerning: -50)
require(nearlyEqual(unitStyle.trackingPoints, 2) && nearlyEqual(unitStyle.kerningPoints, -1), "tracking and kerning must convert from thousandths of an em to points")

print("OpenstratorCoreSelfTest M3 final: PASS (\(checks) checks)")

// V6 M4 ordered appearance + typed live effects release gates.
let m4FillA = FillAppearanceV6(id: UUID(), paint: .color(.white))
let m4StrokeA = StrokeAppearanceV6(id: UUID(), paint: .color(.black), width: 4, dash: [8, 4], cap: "round", join: "bevel")
let m4FillB = FillAppearanceV6(id: UUID(), opacity: 0.6, blendMode: .screen, paint: .color(.black))
var m4Stack = AppearanceStackV6(entries: [.fill(m4FillA), .stroke(m4StrokeA), .fill(m4FillB)], opacity: 0.8, blendMode: .multiply)
require(m4Stack.entries.map(\.id) == [m4FillA.id, m4StrokeA.id, m4FillB.id], "M4 appearance stack must preserve ordered stable entry IDs")
do {
    let encoded = try JSONEncoder().encode(m4Stack)
    let decoded = try JSONDecoder().decode(AppearanceStackV6.self, from: encoded)
    require(decoded == m4Stack, "M4 appearance stack must round-trip through JSON")
} catch {
    fatalError("OpenstratorCoreSelfTest FAILED: M4 appearance coding error: \(error)")
}
require(EffectRegistryV6.descriptor(id: "dropShadow")?.parameters["blur"] != nil && EffectRegistryV6.descriptor(id: "transform") != nil, "M4 typed effect registry must expose required descriptors")
var m4Blur = EffectRegistryV6.descriptor(id: "gaussianBlur")!.makeDefaultEffect()
m4Blur.parameters["radius"] = .number(10_000)
let m4ValidatedBlur = try! EffectRegistryV6.validate(m4Blur)
require(m4ValidatedBlur.parameters["radius"] == .number(250), "M4 effect registry must clamp unsafe parameter ranges")
let m4Legacy = AppearanceV6(fill: .white, stroke: StrokeV6(color: .black, width: 3), effects: [LegacyEffectV6(kind: "shadow", amount: 9)])
let m4Migrated = AppearanceMigrationV6.stack(from: m4Legacy)
require(m4Migrated.entries.count == 3, "M4 legacy appearance migration must retain fill, stroke, and supported live effects")
let m4Rect = CGRect(x: 10, y: 20, width: 100, height: 60)
let m4BlurBounds = EffectBoundsV6.visualBounds(geometricBounds: m4Rect, appearance: .init(entries: [.effect(m4ValidatedBlur)]))
require(m4BlurBounds.width > m4Rect.width && m4BlurBounds.height > m4Rect.height, "M4 blur must expand visual bounds without changing geometry")
var m4Shadow = EffectRegistryV6.descriptor(id: "dropShadow")!.makeDefaultEffect()
m4Shadow.parameters["x"] = .number(-12); m4Shadow.parameters["y"] = .number(8); m4Shadow.parameters["blur"] = .number(5)
require(EffectBoundsV6.visualBounds(geometricBounds: m4Rect, appearance: .init(entries: [.effect(m4Shadow)])).minX < m4Rect.minX, "M4 signed drop shadow offsets must expand the correct visual side")
var m4Transform = EffectRegistryV6.descriptor(id: "transform")!.makeDefaultEffect()
m4Transform.parameters["x"] = .number(20); m4Transform.parameters["copies"] = .integer(2)
let m4TransformBounds = EffectBoundsV6.visualBounds(geometricBounds: m4Rect, appearance: .init(entries: [.effect(m4Transform)]))
require(m4TransformBounds.maxX >= m4Rect.maxX + 40, "M4 transform copies must union successive visual bounds")
let m4Expanded = ExpandAppearanceV6.expand(appearance: .init(entries: [.fill(m4FillA), .stroke(m4StrokeA), .fill(m4FillB)]))
require(m4Expanded.pieces.map(\.sourceEntryID) == [m4FillA.id, m4StrokeA.id, m4FillB.id], "M4 vector expansion must preserve paint stack ordering")
let m4ExpandedCopies = ExpandAppearanceV6.expand(appearance: .init(entries: [.fill(m4FillA), .effect(m4Transform)]))
require(m4ExpandedCopies.pieces.map(\.copyIndex) == [0,1,2], "M4 Transform effect must expand editable copies")
let m4RasterBlock = ExpandAppearanceV6.expand(appearance: .init(entries: [.fill(m4FillA), .effect(m4ValidatedBlur)]))
require(m4RasterBlock.requiresRasterExpansion && m4RasterBlock.blockingEffectIDs == ["gaussianBlur"], "M4 must explicitly defer raster-dependent expansion to M5")
var m4DisabledGlow = EffectRegistryV6.descriptor(id: "outerGlow")!.makeDefaultEffect(); m4DisabledGlow.enabled = false
require(EffectBoundsV6.visualBounds(geometricBounds: m4Rect, appearance: .init(entries: [.effect(m4DisabledGlow)])) == m4Rect, "disabled M4 effects must not inflate visual bounds")

print("OpenstratorCoreSelfTest M4 final: PASS (\(checks) checks)")

// V6 M5 raster engine + artboard orientation release gates.
do {
    var artboardDoc = DocumentV6.empty(width: 900, height: 600)
    let artboardID = artboardDoc.activeArtboardID
    guard let beforeNode = artboardDoc.node(id: artboardID), case let .artboard(beforeArtboard) = beforeNode.payload else {
        fatalError("OpenstratorCoreSelfTest FAILED: missing M5 artboard")
    }
    try artboardDoc.setArtboardOrientation(.portrait, id: artboardID)
    guard let portraitNode = artboardDoc.node(id: artboardID), case let .artboard(portraitArtboard) = portraitNode.payload else {
        fatalError("OpenstratorCoreSelfTest FAILED: missing portrait artboard")
    }
    require(portraitArtboard.rect.height >= portraitArtboard.rect.width, "M5 portrait orientation")
    require(nearlyEqual(Double(portraitArtboard.rect.midX), Double(beforeArtboard.rect.midX)) && nearlyEqual(Double(portraitArtboard.rect.midY), Double(beforeArtboard.rect.midY)), "M5 orientation must preserve artboard center")
    let portraitRect = portraitArtboard.rect
    try artboardDoc.setArtboardOrientation(.portrait, id: artboardID)
    guard let repeatedNode = artboardDoc.node(id: artboardID), case let .artboard(repeatedArtboard) = repeatedNode.payload else {
        fatalError("OpenstratorCoreSelfTest FAILED: missing repeated artboard")
    }
    require(repeatedArtboard.rect == portraitRect, "M5 orientation must be idempotent")
    try artboardDoc.setArtboardOrientation(.landscape, id: artboardID)
    require(artboardDoc.artboardSize.width >= artboardDoc.artboardSize.height, "M5 landscape orientation")
} catch {
    fatalError("OpenstratorCoreSelfTest FAILED: M5 artboard orientation error: \(error)")
}

var m5Metadata = RasterAssetMetadataV6(pixelWidth: -1, pixelHeight: 0, dpi: -2, mimeType: "")
m5Metadata.normalize()
require(m5Metadata.pixelWidth == 1 && m5Metadata.pixelHeight == 1 && nearlyEqual(m5Metadata.dpi, 72), "M5 raster metadata normalization")

do {
    let rasterAsset = RasterImageDataV6(assetID: UUID(), metadata: .init(pixelWidth: 2, pixelHeight: 2, mimeType: "image/png"), embeddedData: Data([1,2,3]))
    let encoded = try JSONEncoder().encode(rasterAsset)
    let decoded = try JSONDecoder().decode(RasterImageDataV6.self, from: encoded)
    require(decoded == rasterAsset, "M5 embedded raster asset JSON round-trip")
} catch {
    fatalError("OpenstratorCoreSelfTest FAILED: M5 raster coding error: \(error)")
}

do {
    var tiles = try RasterTileStoreV6(width: 300, height: 270)
    try tiles.setPixel(.init(r: 12, g: 34, b: 56, a: 78), x: 256, y: 256)
    require(tiles.pixel(x: 256, y: 256) == .init(r: 12, g: 34, b: 56, a: 78) && tiles.allocatedTileCount == 1, "M5 tile addressing")

    let cropped = try RasterOperationsV6.crop(tiles, x: 255, y: 255, width: 2, height: 2)
    require(cropped.pixel(x: 1, y: 1).a == 78, "M5 crop preserves pixels")

    let resized = try RasterOperationsV6.resampleBilinear(cropped, width: 4, height: 4)
    require(resized.width == 4 && resized.height == 4, "M5 bilinear resample dimensions")

    var bottom = try RasterTileStoreV6(width: 1, height: 1)
    var top = try RasterTileStoreV6(width: 1, height: 1)
    try bottom.setPixel(.init(r:0,g:0,b:255,a:255),x:0,y:0)
    try top.setPixel(.init(r:255,g:0,b:0,a:128),x:0,y:0)
    let composite = try RasterOperationsV6.composite(source: top, over: bottom, offsetX: 0, offsetY: 0)
    require(composite.pixel(x:0,y:0).a == 255 && composite.pixel(x:0,y:0).r > 100, "M5 source-over compositing")

    let selection = RasterSelectionV6.rectangle(canvasWidth: 5, canvasHeight: 5, x: 1, y: 1, width: 3, height: 3)
    require(selection.value(x: 2, y: 2) == 255 && selection.value(x: 0, y: 0) == 0, "M5 pixel selection mask")

    var paint = try RasterTileStoreV6(width: 5, height: 5)
    try RasterBrushV6.paint(&paint, centerX: 2, centerY: 2, radius: 2, color: .init(r: 255, g: 0, b: 0, a: 255), opacity: 1, selection: selection)
    require(paint.pixel(x:2,y:2).a == 255 && paint.pixel(x:0,y:0).a == 0, "M5 selection-clipped paint")
    try RasterBrushV6.erase(&paint, centerX: 2, centerY: 2, radius: 1, opacity: 0.5)
    require(paint.pixel(x:2,y:2).a < 255, "M5 erase-to-alpha")
} catch {
    fatalError("OpenstratorCoreSelfTest FAILED: M5 raster operations error: \(error)")
}

var m5Filter = RasterFilterRecordV6(id: .gaussianBlur, parameters: ["radius": 9999])
m5Filter.normalize()
require(m5Filter.parameters["radius"] == 200, "M5 raster filter parameter clamp")

print("OpenstratorCoreSelfTest M5 final: PASS (\(checks) checks)")

// V6 M6 layer/object workflow + shared resource release gates.
do {
    var tree = LayerTreeV6()
    let artboard = LayerNodeV6(name: "Artboard 1", kind: .artboard)
    let group = LayerNodeV6(name: "Group", kind: .group)
    let nested = LayerNodeV6(name: "Nested", kind: .group)
    let artworkID = UUID()
    let object = LayerNodeV6(name: "Artwork", kind: .object, objectID: artworkID)

    try tree.insert(artboard, parent: nil, index: 0)
    try tree.insert(group, parent: artboard.id, index: 0)
    try tree.insert(nested, parent: group.id, index: 0)
    try tree.insert(object, parent: group.id, index: 1)
    let treeIsValid = try tree.validate()
    require(treeIsValid, "M6 nested layer tree must validate")

    try tree.move(object.id, toParent: nested.id, index: 0)
    require(tree.node(object.id)?.parentID == nested.id && tree.objectOrder() == [artworkID], "M6 layer reparent must preserve object identity/order")

    var cycleRejected = false
    do { try tree.move(group.id, toParent: nested.id, index: 0) }
    catch LayerTreeErrorV6.cycle { cycleRejected = true }
    catch { cycleRejected = false }
    require(cycleRejected, "M6 layer hierarchy must reject parent cycles")

    let encoded = try JSONEncoder().encode(tree)
    let decoded = try JSONDecoder().decode(LayerTreeV6.self, from: encoded)
    require(decoded == tree, "M6 layer tree must round-trip through JSON")

    let removed = try tree.removeSubtree(nested.id)
    require(removed[object.id] != nil && tree.node(object.id) == nil, "M6 subtree removal must remove descendant artwork nodes")
} catch {
    fatalError("OpenstratorCoreSelfTest FAILED: M6 layer workflow error: \(error)")
}

do {
    let sharedID = UUID()
    let embedded = EmbeddedObjectResourceV6(
        name: "Embedded Card",
        originalBounds: CGRect(x: 5, y: 8, width: 120, height: 80),
        payloadData: Data([10, 20, 30]),
        nestedEmbeddedResourceIDs: [sharedID]
    )
    let linked = LinkedAssetResourceV6(
        displayName: "Linked Photo",
        sourceURLString: "file:///tmp/photo.png",
        originalFilename: "photo.png",
        fallbackRasterAssetID: sharedID,
        contentFingerprint: "abc123",
        modificationDate: 42
    )
    let symbol = SymbolDefinitionV6(name: "Badge", originalBounds: CGRect(x: 0, y: 0, width: 64, height: 64), payloadData: Data([1, 2, 3, 4]))
    let style = GraphicStyleV6(name: "Card Style", appearance: m4Stack)
    let library = ResourceLibraryV6(embeddedObjects: [embedded], linkedAssets: [linked], symbols: [symbol], graphicStyles: [style])

    require(library.hasUniqueResourceIDs, "M6 resource library IDs must be unique")
    require(library.embeddedObjects[0].payloadData == Data([10, 20, 30]) && library.embeddedObjects[0].nestedEmbeddedResourceIDs == [sharedID], "M6 Embedded Object resources must preserve editable payload and nesting references")
    require(library.linkedAssets[0].fallbackRasterAssetID == sharedID && library.linkedAssets[0].contentFingerprint == "abc123", "M6 linked assets must preserve embedded fallback and fingerprint metadata")
    require(library.symbols[0].payloadData == Data([1, 2, 3, 4]), "M6 symbol definitions must preserve shared definition payload")
    require(library.graphicStyles[0].appearance == m4Stack, "M6 Graphic Styles must preserve complete appearance stacks")

    let encoded = try JSONEncoder().encode(library)
    let decoded = try JSONDecoder().decode(ResourceLibraryV6.self, from: encoded)
    require(decoded == library, "M6 resource library must round-trip through JSON")

    let duplicateID = embedded.id
    let bad = ResourceLibraryV6(
        embeddedObjects: [embedded],
        linkedAssets: [LinkedAssetResourceV6(id: duplicateID, displayName: "Duplicate", sourceURLString: "file:///tmp/dup.png", originalFilename: "dup.png")]
    )
    require(!bad.hasUniqueResourceIDs, "M6 resource library must reject duplicate IDs across resource kinds")
} catch {
    fatalError("OpenstratorCoreSelfTest FAILED: M6 resource coding error: \(error)")
}

print("OpenstratorCoreSelfTest M6 final: PASS (\(checks) checks)")
