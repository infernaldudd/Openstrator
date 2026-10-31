import Foundation

public enum TextLayoutModeV6: String, Codable, CaseIterable, Hashable, Sendable {
    case point, area, path, verticalPoint, verticalArea, verticalPath
}

public enum TextAlignmentV6: String, Codable, CaseIterable, Hashable, Sendable {
    case left, center, right, justify
}

public enum TextDirectionV6: String, Codable, CaseIterable, Hashable, Sendable {
    case natural, leftToRight, rightToLeft
}

public enum TextCapitalizationV6: String, Codable, CaseIterable, Hashable, Sendable {
    case normal, allCaps, smallCaps, titleCase
}

public enum TextScriptPositionV6: String, Codable, CaseIterable, Hashable, Sendable {
    case normal, superscript, `subscript`
}

public enum TextListStyleV6: String, Codable, CaseIterable, Hashable, Sendable {
    case none, bullets, numbered
}

public enum TextWarpStyleV6: String, Codable, CaseIterable, Hashable, Sendable {
    case none, arc, arch, bulge, flag, fish, inflate, rise, shellLower, shellUpper, squeeze, wave
}

public struct TextRangeV6: Codable, Equatable, Sendable {
    public var location: Int
    public var length: Int
    public init(location: Int, length: Int) {
        self.location = max(0, location)
        self.length = max(0, length)
    }
}

public struct CharacterStyleV6: Codable, Equatable, Sendable {
    public var fontFamily: String
    public var fontFace: String
    public var postScriptName: String?
    public var fontSize: Double
    public var legacyWeight: Double
    public var leading: Double
    public var tracking: Double
    public var kerning: Double
    public var baselineShift: Double
    public var horizontalScale: Double
    public var verticalScale: Double
    public var rotationDegrees: Double
    public var underline: Bool
    public var strikethrough: Bool
    public var capitalization: TextCapitalizationV6
    public var scriptPosition: TextScriptPositionV6
    public var openTypeFeatures: [String: Bool]
    public var variableAxes: [String: Double]

    public static let `default` = CharacterStyleV6()

    public init(
        fontFamily: String = "Helvetica Neue",
        fontFace: String = "Regular",
        postScriptName: String? = nil,
        fontSize: Double = 42,
        legacyWeight: Double = 0.4,
        leading: Double = 0,
        tracking: Double = 0,
        kerning: Double = 0,
        baselineShift: Double = 0,
        horizontalScale: Double = 1,
        verticalScale: Double = 1,
        rotationDegrees: Double = 0,
        underline: Bool = false,
        strikethrough: Bool = false,
        capitalization: TextCapitalizationV6 = .normal,
        scriptPosition: TextScriptPositionV6 = .normal,
        openTypeFeatures: [String: Bool] = [:],
        variableAxes: [String: Double] = [:]
    ) {
        self.fontFamily = fontFamily
        self.fontFace = fontFace
        self.postScriptName = postScriptName
        self.fontSize = fontSize
        self.legacyWeight = legacyWeight
        self.leading = leading
        self.tracking = tracking
        self.kerning = kerning
        self.baselineShift = baselineShift
        self.horizontalScale = horizontalScale
        self.verticalScale = verticalScale
        self.rotationDegrees = rotationDegrees
        self.underline = underline
        self.strikethrough = strikethrough
        self.capitalization = capitalization
        self.scriptPosition = scriptPosition
        self.openTypeFeatures = openTypeFeatures
        self.variableAxes = variableAxes
    }

    /// Illustrator-style tracking/kerning values are stored in thousandths of an em.
    public var trackingPoints: Double { tracking * fontSize / 1000 }
    public var kerningPoints: Double { kerning * fontSize / 1000 }

    public mutating func normalize() {
        if fontFamily.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fontFamily = Self.default.fontFamily }
        if fontFace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fontFace = Self.default.fontFace }
        fontSize = min(2048, max(1, fontSize.isFinite ? fontSize : 42))
        legacyWeight = min(1, max(0, legacyWeight.isFinite ? legacyWeight : 0.4))
        leading = min(4096, max(0, leading.isFinite ? leading : 0))
        tracking = min(1000, max(-1000, tracking.isFinite ? tracking : 0))
        kerning = min(1000, max(-1000, kerning.isFinite ? kerning : 0))
        baselineShift = min(4096, max(-4096, baselineShift.isFinite ? baselineShift : 0))
        horizontalScale = min(8, max(0.05, horizontalScale.isFinite ? horizontalScale : 1))
        verticalScale = min(8, max(0.05, verticalScale.isFinite ? verticalScale : 1))
        rotationDegrees = rotationDegrees.isFinite ? rotationDegrees : 0
        variableAxes = variableAxes.filter { $0.value.isFinite }
    }
}

public struct ParagraphStyleV6: Codable, Equatable, Sendable {
    public var alignment: TextAlignmentV6
    public var leftIndent: Double
    public var rightIndent: Double
    public var firstLineIndent: Double
    public var spacingBefore: Double
    public var spacingAfter: Double
    public var lineSpacing: Double
    public var tabs: [Double]
    public var listStyle: TextListStyleV6
    public var hyphenation: Bool
    public var direction: TextDirectionV6

    public static let `default` = ParagraphStyleV6()

    public init(
        alignment: TextAlignmentV6 = .left,
        leftIndent: Double = 0,
        rightIndent: Double = 0,
        firstLineIndent: Double = 0,
        spacingBefore: Double = 0,
        spacingAfter: Double = 0,
        lineSpacing: Double = 0,
        tabs: [Double] = [],
        listStyle: TextListStyleV6 = .none,
        hyphenation: Bool = false,
        direction: TextDirectionV6 = .natural
    ) {
        self.alignment = alignment
        self.leftIndent = leftIndent
        self.rightIndent = rightIndent
        self.firstLineIndent = firstLineIndent
        self.spacingBefore = spacingBefore
        self.spacingAfter = spacingAfter
        self.lineSpacing = lineSpacing
        self.tabs = tabs
        self.listStyle = listStyle
        self.hyphenation = hyphenation
        self.direction = direction
    }

    public mutating func normalize() {
        leftIndent = max(0, leftIndent.isFinite ? leftIndent : 0)
        rightIndent = max(0, rightIndent.isFinite ? rightIndent : 0)
        firstLineIndent = firstLineIndent.isFinite ? firstLineIndent : 0
        spacingBefore = max(0, spacingBefore.isFinite ? spacingBefore : 0)
        spacingAfter = max(0, spacingAfter.isFinite ? spacingAfter : 0)
        lineSpacing = max(0, lineSpacing.isFinite ? lineSpacing : 0)
        tabs = tabs.filter { $0.isFinite && $0 >= 0 }.sorted()
    }
}

public struct TextRunV6: Codable, Equatable, Sendable {
    public var range: TextRangeV6
    public var style: CharacterStyleV6
    public init(range: TextRangeV6, style: CharacterStyleV6) {
        self.range = range
        self.style = style
    }
}

public struct GlyphTransformV6: Codable, Equatable, Sendable {
    public var glyphIndex: Int
    public var offsetX: Double
    public var offsetY: Double
    public var scaleX: Double
    public var scaleY: Double
    public var rotationDegrees: Double
    public init(glyphIndex: Int, offsetX: Double = 0, offsetY: Double = 0, scaleX: Double = 1, scaleY: Double = 1, rotationDegrees: Double = 0) {
        self.glyphIndex = max(0, glyphIndex)
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.rotationDegrees = rotationDegrees
    }
}

public struct TextPathOptionsV6: Codable, Equatable, Sendable {
    public var pathReference: UUID?
    public var startOffset: Double
    public var endOffset: Double
    public var baselineOffset: Double
    public var flip: Bool
    public init(pathReference: UUID? = nil, startOffset: Double = 0, endOffset: Double = 0, baselineOffset: Double = 0, flip: Bool = false) {
        self.pathReference = pathReference
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.baselineOffset = baselineOffset
        self.flip = flip
    }
}

public struct TextThreadV6: Codable, Equatable, Sendable {
    public var previousFrameID: UUID?
    public var nextFrameID: UUID?
    public init(previousFrameID: UUID? = nil, nextFrameID: UUID? = nil) {
        self.previousFrameID = previousFrameID
        self.nextFrameID = nextFrameID
    }
}

public struct TextWarpV6: Codable, Equatable, Sendable {
    public var style: TextWarpStyleV6
    public var bend: Double
    public var horizontalDistortion: Double
    public var verticalDistortion: Double
    public init(style: TextWarpStyleV6 = .none, bend: Double = 0, horizontalDistortion: Double = 0, verticalDistortion: Double = 0) {
        self.style = style
        self.bend = bend
        self.horizontalDistortion = horizontalDistortion
        self.verticalDistortion = verticalDistortion
    }

    public mutating func normalize() {
        bend = min(1, max(-1, bend.isFinite ? bend : 0))
        horizontalDistortion = min(1, max(-1, horizontalDistortion.isFinite ? horizontalDistortion : 0))
        verticalDistortion = min(1, max(-1, verticalDistortion.isFinite ? verticalDistortion : 0))
    }
}

public struct TextDataV6: Codable, Equatable, Sendable {
    public var text: String
    public var frame: CGRect
    public var layoutMode: TextLayoutModeV6
    public var character: CharacterStyleV6
    public var paragraph: ParagraphStyleV6
    public var runs: [TextRunV6]
    public var glyphTransforms: [GlyphTransformV6]
    public var path: TextPathOptionsV6?
    public var thread: TextThreadV6
    public var warp: TextWarpV6?

    public init(
        text: String,
        frame: CGRect,
        layoutMode: TextLayoutModeV6 = .point,
        character: CharacterStyleV6 = .default,
        paragraph: ParagraphStyleV6 = .default,
        runs: [TextRunV6] = [],
        glyphTransforms: [GlyphTransformV6] = [],
        path: TextPathOptionsV6? = nil,
        thread: TextThreadV6 = TextThreadV6(),
        warp: TextWarpV6? = nil
    ) {
        self.text = text
        self.frame = frame
        self.layoutMode = layoutMode
        self.character = character
        self.paragraph = paragraph
        self.runs = runs
        self.glyphTransforms = glyphTransforms
        self.path = path
        self.thread = thread
        self.warp = warp
        normalize()
    }

    /// Compatibility initializer used by M1/M2 migrators and old payload construction.
    public init(text: String, frame: CGRect, fontSize: Double = 42, fontWeight: Double = 0.4) {
        var style = CharacterStyleV6.default
        style.fontSize = fontSize
        style.legacyWeight = fontWeight
        self.init(text: text, frame: frame, layoutMode: .point, character: style)
    }

    public mutating func normalize() {
        character.normalize()
        paragraph.normalize()
        if var warp { warp.normalize(); self.warp = warp }
        runs = runs.filter { $0.range.location >= 0 && $0.range.length >= 0 }
        glyphTransforms = glyphTransforms.filter { $0.glyphIndex >= 0 }
    }

    private enum CodingKeys: String, CodingKey {
        case text, frame, layoutMode, character, paragraph, runs, glyphTransforms, path, thread, warp
        case fontSize, fontWeight
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        frame = try c.decodeIfPresent(CGRect.self, forKey: .frame) ?? .zero
        layoutMode = try c.decodeIfPresent(TextLayoutModeV6.self, forKey: .layoutMode) ?? .point
        if let rich = try c.decodeIfPresent(CharacterStyleV6.self, forKey: .character) {
            character = rich
        } else {
            var legacy = CharacterStyleV6.default
            legacy.fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? 42
            legacy.legacyWeight = try c.decodeIfPresent(Double.self, forKey: .fontWeight) ?? 0.4
            character = legacy
        }
        paragraph = try c.decodeIfPresent(ParagraphStyleV6.self, forKey: .paragraph) ?? .default
        runs = try c.decodeIfPresent([TextRunV6].self, forKey: .runs) ?? []
        glyphTransforms = try c.decodeIfPresent([GlyphTransformV6].self, forKey: .glyphTransforms) ?? []
        path = try c.decodeIfPresent(TextPathOptionsV6.self, forKey: .path)
        thread = try c.decodeIfPresent(TextThreadV6.self, forKey: .thread) ?? TextThreadV6()
        warp = try c.decodeIfPresent(TextWarpV6.self, forKey: .warp)
        normalize()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(text, forKey: .text)
        try c.encode(frame, forKey: .frame)
        try c.encode(layoutMode, forKey: .layoutMode)
        try c.encode(character, forKey: .character)
        try c.encode(paragraph, forKey: .paragraph)
        try c.encode(runs, forKey: .runs)
        try c.encode(glyphTransforms, forKey: .glyphTransforms)
        try c.encodeIfPresent(path, forKey: .path)
        try c.encode(thread, forKey: .thread)
        try c.encodeIfPresent(warp, forKey: .warp)
        // Keep legacy readers useful even if they ignore the M3 fields.
        try c.encode(character.fontSize, forKey: .fontSize)
        try c.encode(character.legacyWeight, forKey: .fontWeight)
    }
}

public typealias TextDataM1 = TextDataV6
