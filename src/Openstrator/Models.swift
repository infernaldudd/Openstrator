import SwiftUI
import CoreGraphics
import AppKit
import OpenstratorCore

struct RGBAColor: Codable, Equatable, Hashable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double = 1

    static let black = RGBAColor(r: 0.08, g: 0.09, b: 0.11)
    static let white = RGBAColor(r: 1, g: 1, b: 1)
    static let clear = RGBAColor(r: 0, g: 0, b: 0, a: 0)
    static let accent = RGBAColor(r: 0.15, g: 0.49, b: 0.98)

    var swiftUIColor: Color { Color(red: r, green: g, blue: b, opacity: a) }

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
        r = Double(ns.redComponent)
        g = Double(ns.greenComponent)
        b = Double(ns.blueComponent)
        a = Double(ns.alphaComponent)
    }
}

struct CodablePoint: Codable, Equatable, Hashable {
    var x: Double
    var y: Double
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }

    init(_ point: CGPoint) {
        x = point.x
        y = point.y
    }

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

enum ToolCategory: String, CaseIterable, Identifiable {
    case selection = "Selection"
    case drawing = "Drawing"
    case shapes = "Shapes"
    case type = "Type"
    case transform = "Transform"
    case color = "Color & Appearance"
    case construction = "Construction"
    case navigation = "Navigation"

    var id: String { rawValue }
}

enum ToolKind: String, CaseIterable, Identifiable {
    case select, directSelect, groupSelect, magicWand, lasso
    case pen, addAnchor, deleteAnchor, anchorPoint, curvature, pencil, paintbrush, blobBrush, smooth, pathEraser, scissors, knife, joinTool, shaper
    case rectangle, roundedRectangle, ellipse, polygon, star, line, arc, spiral, rectGrid, polarGrid, flare
    case text, areaText, typeOnPath, verticalText, verticalAreaText, verticalTypeOnPath, touchType
    case rotate, reflect, scale, shear, width, freeTransform, reshape, warp, twirl, pucker, bloat, scallop, crystallizeTool, wrinkle, puppetWarp
    case gradient, mesh, eyedropper, measure
    case blend, shapeBuilder, livePaintBucket, livePaintSelection
    case symbolSprayer, symbolShifter, symbolScruncher, symbolSizer, symbolSpinner, symbolStainer, symbolScreener, symbolStyler
    case graph, stackedColumnGraph, barGraph, stackedBarGraph, lineGraph, areaGraph, scatterGraph, pieGraph, radarGraph
    case perspectiveGrid, perspectiveSelection, artboard, slice, sliceSelection, dimension, objectsOnPath
    case eraser, hand, printTiling, rotateView, zoom

    var id: String { rawValue }

    var category: ToolCategory {
        switch self {
        case .select, .directSelect, .groupSelect, .magicWand, .lasso:
            return .selection
        case .pen, .addAnchor, .deleteAnchor, .anchorPoint, .curvature, .pencil, .paintbrush, .blobBrush,
             .smooth, .pathEraser, .scissors, .knife, .joinTool, .shaper, .eraser:
            return .drawing
        case .rectangle, .roundedRectangle, .ellipse, .polygon, .star, .line, .arc, .spiral, .rectGrid, .polarGrid, .flare:
            return .shapes
        case .text, .areaText, .typeOnPath, .verticalText, .verticalAreaText, .verticalTypeOnPath, .touchType:
            return .type
        case .rotate, .reflect, .scale, .shear, .width, .freeTransform, .reshape, .warp, .twirl, .pucker,
             .bloat, .scallop, .crystallizeTool, .wrinkle, .puppetWarp:
            return .transform
        case .gradient, .mesh, .eyedropper, .measure:
            return .color
        case .blend, .shapeBuilder, .livePaintBucket, .livePaintSelection,
             .symbolSprayer, .symbolShifter, .symbolScruncher, .symbolSizer, .symbolSpinner, .symbolStainer, .symbolScreener, .symbolStyler,
             .graph, .stackedColumnGraph, .barGraph, .stackedBarGraph, .lineGraph, .areaGraph, .scatterGraph, .pieGraph, .radarGraph,
             .perspectiveGrid, .perspectiveSelection, .artboard, .slice, .sliceSelection, .dimension, .objectsOnPath:
            return .construction
        case .hand, .printTiling, .rotateView, .zoom:
            return .navigation
        }
    }

    var title: String {
        switch self {
        case .select: return "Selection"
        case .directSelect: return "Direct Selection"
        case .groupSelect: return "Group Selection"
        case .magicWand: return "Magic Wand"
        case .lasso: return "Lasso"
        case .pen: return "Pen"
        case .addAnchor: return "Add Anchor Point"
        case .deleteAnchor: return "Delete Anchor Point"
        case .anchorPoint: return "Anchor Point"
        case .curvature: return "Curvature"
        case .pencil: return "Pencil"
        case .paintbrush: return "Paintbrush"
        case .blobBrush: return "Blob Brush"
        case .smooth: return "Smooth"
        case .pathEraser: return "Path Eraser"
        case .scissors: return "Scissors"
        case .knife: return "Knife"
        case .joinTool: return "Join"
        case .shaper: return "Shaper"
        case .rectangle: return "Rectangle"
        case .roundedRectangle: return "Rounded Rectangle"
        case .ellipse: return "Ellipse"
        case .polygon: return "Polygon"
        case .star: return "Star"
        case .line: return "Line Segment"
        case .arc: return "Arc"
        case .spiral: return "Spiral"
        case .rectGrid: return "Rectangular Grid"
        case .polarGrid: return "Polar Grid"
        case .flare: return "Flare"
        case .text: return "Type"
        case .areaText: return "Area Type"
        case .typeOnPath: return "Type on Path"
        case .verticalText: return "Vertical Type"
        case .verticalAreaText: return "Vertical Area Type"
        case .verticalTypeOnPath: return "Vertical Type on Path"
        case .touchType: return "Touch Type"
        case .rotate: return "Rotate"
        case .reflect: return "Reflect"
        case .scale: return "Scale"
        case .shear: return "Shear"
        case .width: return "Width"
        case .freeTransform: return "Free Transform"
        case .reshape: return "Reshape"
        case .warp: return "Warp"
        case .twirl: return "Twirl"
        case .pucker: return "Pucker"
        case .bloat: return "Bloat"
        case .scallop: return "Scallop"
        case .crystallizeTool: return "Crystallize"
        case .wrinkle: return "Wrinkle"
        case .puppetWarp: return "Puppet Warp"
        case .gradient: return "Gradient"
        case .mesh: return "Gradient Mesh"
        case .eyedropper: return "Eyedropper"
        case .measure: return "Measure"
        case .blend: return "Blend"
        case .shapeBuilder: return "Shape Builder"
        case .livePaintBucket: return "Live Paint Bucket"
        case .livePaintSelection: return "Live Paint Selection"
        case .symbolSprayer: return "Symbol Sprayer"
        case .symbolShifter: return "Symbol Shifter"
        case .symbolScruncher: return "Symbol Scruncher"
        case .symbolSizer: return "Symbol Sizer"
        case .symbolSpinner: return "Symbol Spinner"
        case .symbolStainer: return "Symbol Stainer"
        case .symbolScreener: return "Symbol Screener"
        case .symbolStyler: return "Symbol Styler"
        case .graph: return "Column Graph"
        case .stackedColumnGraph: return "Stacked Column Graph"
        case .barGraph: return "Bar Graph"
        case .stackedBarGraph: return "Stacked Bar Graph"
        case .lineGraph: return "Line Graph"
        case .areaGraph: return "Area Graph"
        case .scatterGraph: return "Scatter Graph"
        case .pieGraph: return "Pie Graph"
        case .radarGraph: return "Radar Graph"
        case .perspectiveGrid: return "Perspective Grid"
        case .perspectiveSelection: return "Perspective Selection"
        case .artboard: return "Artboard"
        case .slice: return "Slice"
        case .sliceSelection: return "Slice Selection"
        case .dimension: return "Dimension"
        case .objectsOnPath: return "Objects on Path"
        case .eraser: return "Eraser"
        case .hand: return "Hand"
        case .printTiling: return "Print Tiling"
        case .rotateView: return "Rotate View"
        case .zoom: return "Zoom"
        }
    }

    var symbol: String {
        switch self {
        case .select: return "arrow.up.left"
        case .directSelect: return "cursorarrow.rays"
        case .groupSelect: return "square.3.layers.3d"
        case .magicWand: return "wand.and.stars"
        case .lasso: return "lasso"
        case .pen, .addAnchor, .deleteAnchor, .anchorPoint, .curvature: return "point.topleft.down.curvedto.point.bottomright.up"
        case .pencil, .smooth, .reshape, .shaper: return "pencil.tip"
        case .paintbrush, .blobBrush: return "paintbrush"
        case .pathEraser, .eraser: return "eraser"
        case .scissors: return "scissors"
        case .knife: return "triangle"
        case .joinTool: return "link"
        case .rectangle, .roundedRectangle: return "rectangle"
        case .ellipse: return "circle"
        case .polygon: return "hexagon"
        case .star: return "star"
        case .line, .arc: return "line.diagonal"
        case .spiral: return "hurricane"
        case .rectGrid, .polarGrid, .perspectiveGrid, .perspectiveSelection: return "grid"
        case .flare: return "sun.max"
        case .text, .areaText, .verticalText, .verticalAreaText, .typeOnPath, .verticalTypeOnPath, .touchType: return "textformat"
        case .rotate, .rotateView: return "arrow.triangle.2.circlepath"
        case .reflect: return "arrow.left.and.right"
        case .scale, .freeTransform, .puppetWarp: return "arrow.up.left.and.arrow.down.right"
        case .shear, .warp, .twirl, .pucker, .bloat, .scallop, .crystallizeTool, .wrinkle: return "skew"
        case .width: return "lineweight"
        case .gradient: return "circle.lefthalf.filled"
        case .mesh: return "circle.grid.cross"
        case .eyedropper: return "eyedropper"
        case .measure, .dimension: return "ruler"
        case .blend, .objectsOnPath: return "square.on.square"
        case .shapeBuilder, .livePaintBucket, .livePaintSelection: return "square.3.layers.3d.down.right"
        case .symbolSprayer, .symbolShifter, .symbolScruncher, .symbolSizer, .symbolSpinner, .symbolStainer, .symbolScreener, .symbolStyler: return "sparkles"
        case .graph, .stackedColumnGraph, .barGraph, .stackedBarGraph, .lineGraph, .areaGraph, .scatterGraph, .pieGraph, .radarGraph: return "chart.bar"
        case .artboard: return "rectangle.dashed"
        case .slice, .sliceSelection: return "crop"
        case .hand, .printTiling: return "hand.draw"
        case .zoom: return "magnifyingglass"
        }
    }
}

enum VectorKind: String, Codable, CaseIterable {
    case rectangle
    case ellipse
    case polygon
    case line
    case text
    case path
    case image
}

struct GradientStopModel: Codable, Equatable, Identifiable {
    var id = UUID()
    var location: Double
    var color: RGBAColor
}

struct LinearGradientModel: Codable, Equatable {
    var angleDegrees: Double = 0
    var stops: [GradientStopModel] = [
        GradientStopModel(location: 0, color: RGBAColor(r: 0.20, g: 0.55, b: 1.0)),
        GradientStopModel(location: 1, color: RGBAColor(r: 0.55, g: 0.25, b: 1.0))
    ]
}

enum BlendModeKind: String, Codable, CaseIterable, Identifiable {
    case normal
    case multiply
    case screen
    case overlay
    case darken
    case lighten
    case softLight
    case hardLight
    case difference
    case exclusion

    var id: String { rawValue }
    var title: String {
        switch self {
        case .softLight: return "Soft Light"
        case .hardLight: return "Hard Light"
        default: return rawValue.capitalized
        }
    }
}

enum EffectCategory: String, CaseIterable, Identifiable {
    case convertShape = "Convert to Shape"
    case stylize = "Stylize"
    case blur = "Blur"
    case color = "Color"
    case distortTransform = "Distort & Transform"
    case warp = "Warp"
    case path = "Path"
    case pathfinder = "Pathfinder"
    case threeD = "3D & Materials"
    case artistic = "Artistic"
    case brushStrokes = "Brush Strokes"
    case rasterDistort = "Distort (Raster)"
    case pixelate = "Pixelate"
    case sketch = "Sketch"
    case texture = "Texture"
    case video = "Video"
    case utility = "Rasterize & SVG"

    var id: String { rawValue }
}

enum EffectKind: String, Codable, CaseIterable, Identifiable, Hashable {
    // Convert to Shape
    case convertRectangle, convertRoundedRectangle, convertEllipse
    // Stylize
    case shadow, glow, innerShadow, innerGlow, feather, roundCorners, scribble, glowingEdges, neonEdge
    // Blur
    case blur, gaussianBlur, radialBlur, zoomBlur, smartBlur, motionBlur
    // Color
    case brightness, contrast, saturation, hueRotate, grayscale, sepia, invert, exposure, vibrance, temperature, posterize, threshold, colorBoost, fade
    // Distort & Transform
    case offset, transformScale, transformRotate, freeDistort, puckerBloat, roughen, tweak, twist, zigZag
    // Warp
    case warpArc, warpArch, warpBulge, warpFlag, warpFish, warpInflate, warpRise, warpShellLower, warpShellUpper, warpSqueeze, warpWave
    // Path
    case offsetPath, outlineObject, outlineStroke
    // Pathfinder
    case pathfinderAdd, pathfinderIntersect, pathfinderExclude, pathfinderSubtract, pathfinderMinusBack, pathfinderDivide, pathfinderTrim, pathfinderMerge, pathfinderCrop, pathfinderOutline
    // 3D & Materials
    case plane3D, extrude3D, revolve3D, inflate3D
    // Artistic
    case coloredPencil, cutout, dryBrush, filmGrain, fresco, neonGlow, paintDaubs, paletteKnife, plasticWrap, posterEdges, roughPastels, smudgeStick, sponge, underpainting, watercolor
    // Brush Strokes
    case accentedEdges, angledStrokes, crosshatch, darkStrokes, inkOutlines, spatter, sprayedStrokes, sumiE
    // Distort (Raster)
    case diffuseGlow, glass, oceanRipple
    // Pixelate
    case colorHalftone, crystallize, mezzotint, mosaic, pointillize
    // Sketch
    case basRelief, chalkCharcoal, charcoal, chrome, conteCrayon, graphicPen, halftonePattern, notePaper, photocopy, plaster, reticulation, stamp, tornEdges, waterPaper
    // Texture
    case craquelure, grain, mosaicTiles, patchwork, stainedGlass, texturizer
    // Video
    case deInterlace, ntscColors
    // Rasterize & SVG
    case rasterize, svgFilter

    var id: String { rawValue }

    var category: EffectCategory {
        switch self {
        case .convertRectangle, .convertRoundedRectangle, .convertEllipse: return .convertShape
        case .shadow, .glow, .innerShadow, .innerGlow, .feather, .roundCorners, .scribble, .glowingEdges, .neonEdge: return .stylize
        case .blur, .gaussianBlur, .radialBlur, .zoomBlur, .smartBlur, .motionBlur: return .blur
        case .brightness, .contrast, .saturation, .hueRotate, .grayscale, .sepia, .invert, .exposure, .vibrance, .temperature, .posterize, .threshold, .colorBoost, .fade: return .color
        case .offset, .transformScale, .transformRotate, .freeDistort, .puckerBloat, .roughen, .tweak, .twist, .zigZag: return .distortTransform
        case .warpArc, .warpArch, .warpBulge, .warpFlag, .warpFish, .warpInflate, .warpRise, .warpShellLower, .warpShellUpper, .warpSqueeze, .warpWave: return .warp
        case .offsetPath, .outlineObject, .outlineStroke: return .path
        case .pathfinderAdd, .pathfinderIntersect, .pathfinderExclude, .pathfinderSubtract, .pathfinderMinusBack, .pathfinderDivide, .pathfinderTrim, .pathfinderMerge, .pathfinderCrop, .pathfinderOutline: return .pathfinder
        case .plane3D, .extrude3D, .revolve3D, .inflate3D: return .threeD
        case .coloredPencil, .cutout, .dryBrush, .filmGrain, .fresco, .neonGlow, .paintDaubs, .paletteKnife, .plasticWrap, .posterEdges, .roughPastels, .smudgeStick, .sponge, .underpainting, .watercolor: return .artistic
        case .accentedEdges, .angledStrokes, .crosshatch, .darkStrokes, .inkOutlines, .spatter, .sprayedStrokes, .sumiE: return .brushStrokes
        case .diffuseGlow, .glass, .oceanRipple: return .rasterDistort
        case .colorHalftone, .crystallize, .mezzotint, .mosaic, .pointillize: return .pixelate
        case .basRelief, .chalkCharcoal, .charcoal, .chrome, .conteCrayon, .graphicPen, .halftonePattern, .notePaper, .photocopy, .plaster, .reticulation, .stamp, .tornEdges, .waterPaper: return .sketch
        case .craquelure, .grain, .mosaicTiles, .patchwork, .stainedGlass, .texturizer: return .texture
        case .deInterlace, .ntscColors: return .video
        case .rasterize, .svgFilter: return .utility
        }
    }

    var title: String {
        switch self {
        case .convertRectangle: return "Rectangle"
        case .convertRoundedRectangle: return "Rounded Rectangle"
        case .convertEllipse: return "Ellipse"
        case .shadow: return "Drop Shadow"
        case .glow: return "Outer Glow"
        case .innerShadow: return "Inner Shadow"
        case .innerGlow: return "Inner Glow"
        case .feather: return "Feather"
        case .roundCorners: return "Round Corners"
        case .scribble: return "Scribble"
        case .glowingEdges: return "Glowing Edges"
        case .neonEdge: return "Neon Edge"
        case .blur: return "Blur"
        case .gaussianBlur: return "Gaussian Blur"
        case .radialBlur: return "Radial Blur"
        case .zoomBlur: return "Zoom Blur"
        case .smartBlur: return "Smart Blur"
        case .motionBlur: return "Motion Blur"
        case .brightness: return "Brightness"
        case .contrast: return "Contrast"
        case .saturation: return "Saturation"
        case .hueRotate: return "Hue Rotation"
        case .grayscale: return "Grayscale"
        case .sepia: return "Sepia"
        case .invert: return "Invert"
        case .exposure: return "Exposure"
        case .vibrance: return "Vibrance"
        case .temperature: return "Temperature"
        case .posterize: return "Posterize"
        case .threshold: return "Threshold"
        case .colorBoost: return "Color Boost"
        case .fade: return "Fade"
        case .offset: return "Offset"
        case .transformScale: return "Transform Scale"
        case .transformRotate: return "Transform Rotate"
        case .freeDistort: return "Free Distort"
        case .puckerBloat: return "Pucker & Bloat"
        case .roughen: return "Roughen"
        case .tweak: return "Tweak"
        case .twist: return "Twist"
        case .zigZag: return "Zig Zag"
        case .warpArc: return "Arc"
        case .warpArch: return "Arch"
        case .warpBulge: return "Bulge"
        case .warpFlag: return "Flag"
        case .warpFish: return "Fish"
        case .warpInflate: return "Inflate"
        case .warpRise: return "Rise"
        case .warpShellLower: return "Shell Lower"
        case .warpShellUpper: return "Shell Upper"
        case .warpSqueeze: return "Squeeze"
        case .warpWave: return "Wave"
        case .offsetPath: return "Offset Path"
        case .outlineObject: return "Outline Object"
        case .outlineStroke: return "Outline Stroke"
        case .pathfinderAdd: return "Add / Unite"
        case .pathfinderIntersect: return "Intersect"
        case .pathfinderExclude: return "Exclude"
        case .pathfinderSubtract: return "Subtract / Minus Front"
        case .pathfinderMinusBack: return "Minus Back"
        case .pathfinderDivide: return "Divide"
        case .pathfinderTrim: return "Trim"
        case .pathfinderMerge: return "Merge"
        case .pathfinderCrop: return "Crop"
        case .pathfinderOutline: return "Outline"
        case .plane3D: return "Plane"
        case .extrude3D: return "Extrude & Bevel"
        case .revolve3D: return "Revolve"
        case .inflate3D: return "Inflate"
        case .coloredPencil: return "Colored Pencil"
        case .cutout: return "Cutout"
        case .dryBrush: return "Dry Brush"
        case .filmGrain: return "Film Grain"
        case .fresco: return "Fresco"
        case .neonGlow: return "Neon Glow"
        case .paintDaubs: return "Paint Daubs"
        case .paletteKnife: return "Palette Knife"
        case .plasticWrap: return "Plastic Wrap"
        case .posterEdges: return "Poster Edges"
        case .roughPastels: return "Rough Pastels"
        case .smudgeStick: return "Smudge Stick"
        case .sponge: return "Sponge"
        case .underpainting: return "Underpainting"
        case .watercolor: return "Watercolor"
        case .accentedEdges: return "Accented Edges"
        case .angledStrokes: return "Angled Strokes"
        case .crosshatch: return "Crosshatch"
        case .darkStrokes: return "Dark Strokes"
        case .inkOutlines: return "Ink Outlines"
        case .spatter: return "Spatter"
        case .sprayedStrokes: return "Sprayed Strokes"
        case .sumiE: return "Sumi-e"
        case .diffuseGlow: return "Diffuse Glow"
        case .glass: return "Glass"
        case .oceanRipple: return "Ocean Ripple"
        case .colorHalftone: return "Color Halftone"
        case .crystallize: return "Crystallize"
        case .mezzotint: return "Mezzotint"
        case .mosaic: return "Mosaic"
        case .pointillize: return "Pointillize"
        case .basRelief: return "Bas Relief"
        case .chalkCharcoal: return "Chalk & Charcoal"
        case .charcoal: return "Charcoal"
        case .chrome: return "Chrome"
        case .conteCrayon: return "Conté Crayon"
        case .graphicPen: return "Graphic Pen"
        case .halftonePattern: return "Halftone Pattern"
        case .notePaper: return "Note Paper"
        case .photocopy: return "Photocopy"
        case .plaster: return "Plaster"
        case .reticulation: return "Reticulation"
        case .stamp: return "Stamp"
        case .tornEdges: return "Torn Edges"
        case .waterPaper: return "Water Paper"
        case .craquelure: return "Craquelure"
        case .grain: return "Grain"
        case .mosaicTiles: return "Mosaic Tiles"
        case .patchwork: return "Patchwork"
        case .stainedGlass: return "Stained Glass"
        case .texturizer: return "Texturizer"
        case .deInterlace: return "De-Interlace"
        case .ntscColors: return "NTSC Colors"
        case .rasterize: return "Rasterize"
        case .svgFilter: return "SVG Filter"
        }
    }

    var defaultAmount: Double {
        switch self {
        case .contrast, .saturation, .vibrance, .colorBoost: return 1.15
        case .hueRotate, .transformRotate, .twist: return 24
        case .shadow, .glow, .innerShadow, .innerGlow, .blur, .gaussianBlur, .radialBlur, .zoomBlur, .smartBlur, .motionBlur, .feather: return 8
        case .transformScale: return 1.12
        case .offset, .offsetPath, .extrude3D: return 12
        case .roundCorners, .convertRoundedRectangle: return 16
        case .colorHalftone: return 12
        case .rasterize: return 144
        default: return 0.45
        }
    }

    var amountRange: ClosedRange<Double> {
        switch self {
        case .hueRotate: return 0...360
        case .transformRotate, .twist: return -180...180
        case .shadow, .glow, .innerShadow, .innerGlow, .blur, .gaussianBlur, .radialBlur, .zoomBlur, .smartBlur, .motionBlur, .feather, .roundCorners, .convertRoundedRectangle: return 0...40
        case .contrast, .saturation, .vibrance, .colorBoost, .transformScale: return 0...2.5
        case .offset, .offsetPath, .extrude3D: return -60...60
        case .brightness, .exposure, .temperature, .fade: return -1...1
        case .colorHalftone: return 4...64
        case .rasterize: return 72...600
        default: return 0...1
        }
    }
}

struct VectorEffect: Codable, Equatable, Identifiable {
    var id = UUID()
    var kind: EffectKind
    var amount: Double
    var enabled = true

    init(id: UUID = UUID(), kind: EffectKind, amount: Double, enabled: Bool = true) {
        self.id = id
        self.kind = kind
        self.amount = amount
        self.enabled = enabled
    }

    var liveEffectV6: LiveEffectV6? {
        guard let effectID = kind.m4EffectID, let descriptor = EffectRegistryV6.descriptor(id: effectID) else { return nil }
        var live = descriptor.makeDefaultEffect(id: id)
        live.enabled = enabled
        if let key = kind.m4PrimaryParameter { live.parameters[key] = .number(amount) }
        return try? EffectRegistryV6.validate(live)
    }

    init?(live: LiveEffectV6) {
        guard let kind = EffectKind(m4EffectID: live.effectID) else { return nil }
        self.id = live.id
        self.kind = kind
        self.enabled = live.enabled
        self.amount = kind.m4PrimaryParameter.flatMap { live.parameters[$0]?.numberValue } ?? 0
    }
}

private extension RGBAColor {
    var coreColorV6: RGBAColorV6 { .init(r: r, g: g, b: b, a: a) }
    init(core: RGBAColorV6) { self.init(r: core.r, g: core.g, b: core.b, a: core.a) }
}

extension LinearGradientModel {
    var coreGradientV6: LinearGradientV6 {
        .init(angleDegrees: angleDegrees, stops: stops.map { .init(location: $0.location, color: $0.color.coreColorV6) })
    }
    init(core: LinearGradientV6) {
        self.init(angleDegrees: core.angleDegrees, stops: core.stops.map { GradientStopModel(location: $0.location, color: RGBAColor(core: $0.color)) })
    }
}

private extension BlendModeKind {
    var coreBlendModeV6: BlendModeV6 { BlendModeV6(rawValue: rawValue) ?? .normal }
    init(core: BlendModeV6) { self = BlendModeKind(rawValue: core.rawValue) ?? .normal }
}

extension EffectKind {
    var m4EffectID: String? {
        switch self {
        case .blur, .gaussianBlur: return "gaussianBlur"
        case .motionBlur: return "motionBlur"
        case .shadow: return "dropShadow"
        case .glow: return "outerGlow"
        case .innerShadow: return "innerShadow"
        case .innerGlow: return "innerGlow"
        case .roughen: return "roughen"
        case .zigZag: return "zigZag"
        case .puckerBloat: return "puckerBloat"
        case .offsetPath: return "offsetPath"
        case .roundCorners: return "roundCorners"
        case .convertRectangle: return "convertRectangle"
        case .convertRoundedRectangle: return "convertRoundedRectangle"
        case .convertEllipse: return "convertEllipse"
        case .warpArc, .warpArch, .warpBulge, .warpFlag, .warpFish, .warpInflate, .warpRise, .warpSqueeze, .warpWave: return "warp"
        default: return nil
        }
    }
    var m4PrimaryParameter: String? {
        switch m4EffectID {
        case "gaussianBlur": return "radius"
        case "motionBlur": return "distance"
        case "dropShadow", "outerGlow", "innerShadow", "innerGlow": return "blur"
        case "roughen", "zigZag": return "size"
        case "puckerBloat": return "amount"
        case "offsetPath": return "offset"
        case "roundCorners", "convertRoundedRectangle": return "radius"
        case "warp": return "bend"
        default: return nil
        }
    }
    init?(m4EffectID: String) {
        switch m4EffectID {
        case "gaussianBlur": self = .gaussianBlur
        case "motionBlur": self = .motionBlur
        case "dropShadow": self = .shadow
        case "outerGlow": self = .glow
        case "innerShadow": self = .innerShadow
        case "innerGlow": self = .innerGlow
        case "roughen": self = .roughen
        case "zigZag": self = .zigZag
        case "puckerBloat": self = .puckerBloat
        case "offsetPath": self = .offsetPath
        case "roundCorners": self = .roundCorners
        case "convertRectangle": self = .convertRectangle
        case "convertRoundedRectangle": self = .convertRoundedRectangle
        case "convertEllipse": self = .convertEllipse
        case "warp": self = .warpArc
        default: return nil
        }
    }
}

struct VectorObject: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var kind: VectorKind
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var rotation: Double = 0
    var opacity: Double = 1
    var fill: RGBAColor = .white
    var gradient: LinearGradientModel? = nil
    var stroke: RGBAColor = .black
    var strokeWidth: Double = 1
    var cornerRadius: Double = 0
    var blendMode: BlendModeKind = .normal
    var text: String = "Text"
    var fontSize: Double = 42
    var fontWeight: Double = 0.4
    var points: [CodablePoint] = []
    // V6 M2 true cubic data. Optional so every V5/M1 document still decodes.
    var bezierAnchors: [PathAnchorV6]? = nil
    var effects: [VectorEffect] = []
    var isVisible = true
    var isLocked = false
    var groupID: UUID? = nil
    // Optional so older .openstrator files remain decodable.
    var isClosed: Bool? = nil
    var scaleX: Double? = nil
    var scaleY: Double? = nil
    var shearX: Double? = nil
    var shearY: Double? = nil
    var strokeDash: [Double]? = nil
    var lineCap: String? = nil
    var lineJoin: String? = nil
    // V6 M3 rich typography. Optional so every V5/M1/M2 document still decodes.
    var typography: TextDataV6? = nil
    // V6 M4 canonical ordered appearance. Optional so every M3.1 document still decodes.
    var appearanceStack: AppearanceStackV6? = nil
    // V6 M5 raster references. Optional so M4.1 and older documents decode unchanged.
    var rasterAssetID: UUID? = nil
    var rasterFilters: [RasterFilterRecordV6]? = nil
    var rasterMask: RasterMaskV6? = nil
    // V6 M6 layer/object workflow references. Optional so M5.1 and older files decode unchanged.
    var layerNodeID: UUID? = nil
    var clippingGroupID: UUID? = nil
    var clippingRole: ClippingRoleV6? = nil
    var opacityMaskObjectID: UUID? = nil
    var opacityMaskInverted: Bool? = nil
    var embeddedObjectID: UUID? = nil
    var symbolDefinitionID: UUID? = nil
    var graphicStyleID: UUID? = nil
    var linkedAssetID: UUID? = nil

    var resolvedAppearanceStack: AppearanceStackV6 {
        if var appearanceStack {
            appearanceStack.normalize()
            return appearanceStack
        }
        var entries: [AppearanceEntryV6] = []
        if let gradient {
            entries.append(.fill(FillAppearanceV6(paint: .linearGradient(gradient.coreGradientV6))))
        } else {
            entries.append(.fill(FillAppearanceV6(paint: .color(fill.coreColorV6))))
        }
        if strokeWidth > 0 || stroke.a > 0 {
            entries.append(.stroke(StrokeAppearanceV6(
                paint: .color(stroke.coreColorV6),
                width: strokeWidth,
                dash: strokeDash ?? [],
                cap: lineCap ?? "butt",
                join: lineJoin ?? "miter"
            )))
        }
        entries.append(contentsOf: effects.compactMap { $0.liveEffectV6 }.map(AppearanceEntryV6.effect))
        return AppearanceStackV6(entries: entries, opacity: opacity, blendMode: blendMode.coreBlendModeV6)
    }

    mutating func applyAppearanceStack(_ stack: AppearanceStackV6) {
        let legacyUnmapped = effects.filter { $0.liveEffectV6 == nil }
        var normalized = stack
        normalized.normalize()
        appearanceStack = normalized
        opacity = normalized.opacity
        blendMode = BlendModeKind(core: normalized.blendMode)

        if let fillEntry = normalized.entries.compactMap({ entry -> FillAppearanceV6? in
            if case .fill(let value) = entry, value.enabled { return value }
            return nil
        }).first {
            switch fillEntry.paint {
            case .color(let color):
                fill = RGBAColor(core: color)
                gradient = nil
            case .linearGradient(let value):
                gradient = LinearGradientModel(core: value)
                fill = .clear
            }
        } else {
            fill = .clear
            gradient = nil
        }

        if let strokeEntry = normalized.entries.compactMap({ entry -> StrokeAppearanceV6? in
            if case .stroke(let value) = entry, value.enabled { return value }
            return nil
        }).first {
            if case .color(let color) = strokeEntry.paint { stroke = RGBAColor(core: color) }
            strokeWidth = strokeEntry.width
            strokeDash = strokeEntry.dash
            lineCap = strokeEntry.cap
            lineJoin = strokeEntry.join
        } else {
            stroke = .clear
            strokeWidth = 0
            strokeDash = []
        }
        effects = normalized.entries.compactMap { entry in
            guard case .effect(let effect) = entry else { return nil }
            return VectorEffect(live: effect)
        } + legacyUnmapped
    }

    var resolvedTypography: TextDataV6 {
        var data: TextDataV6
        if let typography {
            data = typography
        } else {
            var style = CharacterStyleV6.default
            style.fontSize = fontSize
            style.legacyWeight = fontWeight
            data = TextDataV6(text: text, frame: bounds, character: style)
        }
        // Geometry and text content remain mirrored for compatibility with older files/tools.
        data.text = text
        data.frame = bounds
        if typography == nil {
            data.character.fontSize = fontSize
            data.character.legacyWeight = fontWeight
        }
        data.normalize()
        return data
    }

    mutating func applyTypography(_ data: TextDataV6) {
        var normalized = data
        normalized.normalize()
        typography = normalized
        text = normalized.text
        fontSize = normalized.character.fontSize
        fontWeight = normalized.character.legacyWeight
        x = normalized.frame.origin.x
        y = normalized.frame.origin.y
        width = max(1, normalized.frame.width)
        height = max(1, normalized.frame.height)
    }

    mutating func ensureTypography(layoutMode: TextLayoutModeV6? = nil) {
        var data = resolvedTypography
        if let layoutMode { data.layoutMode = layoutMode }
        applyTypography(data)
    }

    var bounds: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    static func rectangle(at p: CGPoint, size: CGSize = CGSize(width: 180, height: 120)) -> VectorObject {
        .init(
            name: "Rectangle",
            kind: .rectangle,
            x: p.x,
            y: p.y,
            width: size.width,
            height: size.height,
            fill: RGBAColor(r: 0.15, g: 0.48, b: 0.96),
            stroke: .clear,
            strokeWidth: 0,
            cornerRadius: 10
        )
    }

    static func ellipse(at p: CGPoint, size: CGSize = CGSize(width: 140, height: 140)) -> VectorObject {
        .init(
            name: "Ellipse",
            kind: .ellipse,
            x: p.x,
            y: p.y,
            width: size.width,
            height: size.height,
            fill: RGBAColor(r: 0.98, g: 0.33, b: 0.35),
            stroke: .clear,
            strokeWidth: 0
        )
    }

    static func polygon(at p: CGPoint, size: CGSize = CGSize(width: 160, height: 150)) -> VectorObject {
        .init(
            name: "Polygon",
            kind: .polygon,
            x: p.x,
            y: p.y,
            width: size.width,
            height: size.height,
            fill: RGBAColor(r: 0.35, g: 0.73, b: 0.51),
            stroke: .clear,
            strokeWidth: 0
        )
    }

    static func line(from start: CGPoint, to end: CGPoint) -> VectorObject {
        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxX = max(start.x, end.x)
        let maxY = max(start.y, end.y)
        return .init(
            name: "Line",
            kind: .line,
            x: minX,
            y: minY,
            width: max(1, maxX - minX),
            height: max(1, maxY - minY),
            fill: .clear,
            stroke: .black,
            strokeWidth: 2,
            points: [CodablePoint(start), CodablePoint(end)],
            bezierAnchors: [PathAnchorV6(point: start), PathAnchorV6(point: end)]
        )
    }

    static func text(at p: CGPoint) -> VectorObject {
        .init(
            name: "Text",
            kind: .text,
            x: p.x,
            y: p.y,
            width: 300,
            height: 80,
            fill: RGBAColor(r: 0.08, g: 0.09, b: 0.11),
            stroke: .clear,
            strokeWidth: 0,
            text: "Type something",
            fontSize: 42
        )
    }

    static func image(assetID: UUID, at p: CGPoint, size: CGSize, name: String = "Image") -> VectorObject {
        .init(
            name: name, kind: .image, x: p.x, y: p.y,
            width: max(1, size.width), height: max(1, size.height),
            fill: .clear, stroke: .clear, strokeWidth: 0,
            rasterAssetID: assetID
        )
    }

    static func path(points: [CGPoint], name: String = "Path", closed: Bool = false) -> VectorObject {
        let minX = points.map(\.x).min() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxX = points.map(\.x).max() ?? minX + 1
        let maxY = points.map(\.y).max() ?? minY + 1
        return .init(
            name: name,
            kind: .path,
            x: minX,
            y: minY,
            width: max(1, maxX - minX),
            height: max(1, maxY - minY),
            fill: .clear,
            stroke: .black,
            strokeWidth: 2,
            points: points.map(CodablePoint.init),
            bezierAnchors: points.map { PathAnchorV6(point: $0) },
            isClosed: closed
        )
    }
}

enum GuideAxis: String, Codable {
    case horizontal
    case vertical
}

struct CanvasGuide: Codable, Equatable, Identifiable {
    var id = UUID()
    var axis: GuideAxis
    var position: Double
}

struct RasterAssetRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var metadata: RasterAssetMetadataV6
    var embeddedData: Data
}

struct OpenDocument: Codable, Equatable {
    var formatVersion: Int = 2
    var name: String = "Untitled"
    var artboardWidth: Double = 1200
    var artboardHeight: Double = 800
    var background: RGBAColor = .white
    var objects: [VectorObject] = []
    var guides: [CanvasGuide] = []
    var gridSpacing: Double = 24
    var showGrid: Bool = true
    var snapToGrid: Bool = false
    var showGuides: Bool = true
    // Optional for backward compatibility with M4.1 and older files.
    var rasterAssets: [RasterAssetRecord]? = nil
    // V6 M6 hierarchy/resources remain optional for M5.1 and older files.
    var layerTree: LayerTreeV6? = nil
    var resourceLibrary: ResourceLibraryV6? = nil
}

struct KeybindDefinition: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var key: String
    var modifiers: [String]
    var explanation: String
    var preview: PreviewKind

    enum PreviewKind: String, Codable {
        case select
        case text
        case rectangle
        case ellipse
        case polygon
        case duplicate
        case zoom
        case pen
        case align
        case export
    }

    var display: String {
        let glyphs = modifiers.map { modifier -> String in
            switch modifier {
            case "command": return "⌘"
            case "shift": return "⇧"
            case "option": return "⌥"
            case "control": return "⌃"
            default: return modifier
            }
        }.joined()
        return glyphs + key.uppercased()
    }
}

struct ArchitectureProfile {
    enum Kind: String {
        case appleSilicon = "Apple Silicon"
        case intel = "Intel"
        case unknown = "Universal / Unknown"
    }

    let kind: Kind
    let undoLimit: Int
    let liveEffectsEnabledByDefault: Bool
    let targetWorkingSetMB: Int
    let hardWarningMB: Int

    static var current: ArchitectureProfile {
        #if OPENSTRATOR_APPLE_SILICON
        return ArchitectureProfile(kind: .appleSilicon, undoLimit: 64, liveEffectsEnabledByDefault: true, targetWorkingSetMB: 2200, hardWarningMB: 2800)
        #elseif OPENSTRATOR_INTEL
        return ArchitectureProfile(kind: .intel, undoLimit: 36, liveEffectsEnabledByDefault: true, targetWorkingSetMB: 1950, hardWarningMB: 2700)
        #else
        #if arch(arm64)
        return ArchitectureProfile(kind: .appleSilicon, undoLimit: 64, liveEffectsEnabledByDefault: true, targetWorkingSetMB: 2200, hardWarningMB: 2800)
        #elseif arch(x86_64)
        return ArchitectureProfile(kind: .intel, undoLimit: 36, liveEffectsEnabledByDefault: true, targetWorkingSetMB: 1950, hardWarningMB: 2700)
        #else
        return ArchitectureProfile(kind: .unknown, undoLimit: 32, liveEffectsEnabledByDefault: true, targetWorkingSetMB: 1900, hardWarningMB: 2600)
        #endif
        #endif
    }
}
