import XCTest
@testable import OpenstratorCore

final class TypographyModelTests: XCTestCase {
    private struct LegacyText: Codable {
        var text: String
        var frame: CGRect
        var fontSize: Double
        var fontWeight: Double
    }

    func testLegacyM2TextDecodesIntoM3Defaults() throws {
        let legacy = LegacyText(text: "Legacy text", frame: CGRect(x: 10, y: 20, width: 300, height: 80), fontSize: 42, fontWeight: 0.73)
        let data = try JSONEncoder().encode(legacy)
        let decoded = try JSONDecoder().decode(TextDataV6.self, from: data)

        XCTAssertEqual(decoded.text, "Legacy text")
        XCTAssertEqual(decoded.frame, legacy.frame)
        XCTAssertEqual(decoded.layoutMode, .point)
        XCTAssertEqual(decoded.character.fontSize, 42)
        XCTAssertEqual(decoded.character.legacyWeight, 0.73)
        XCTAssertEqual(decoded.character.fontFamily, CharacterStyleV6.default.fontFamily)
        XCTAssertEqual(decoded.paragraph.alignment, .left)
        XCTAssertTrue(decoded.runs.isEmpty)
        XCTAssertTrue(decoded.glyphTransforms.isEmpty)
    }

    func testRichTypographyRoundTripsAllPersistentFields() throws {
        let run = TextRunV6(range: TextRangeV6(location: 2, length: 5), style: CharacterStyleV6(
            fontFamily: "Avenir Next", fontFace: "Demi Bold", postScriptName: "AvenirNext-DemiBold",
            fontSize: 33, legacyWeight: 0.68, leading: 39, tracking: 1.5, kerning: -0.4,
            baselineShift: 2, horizontalScale: 0.95, verticalScale: 1.1, rotationDegrees: 4,
            underline: true, strikethrough: false, capitalization: .smallCaps, scriptPosition: .normal,
            openTypeFeatures: ["liga": true, "kern": true], variableAxes: ["wght": 635]
        ))
        let data = TextDataV6(
            text: "Openstrator typography",
            frame: CGRect(x: 5, y: 9, width: 420, height: 180),
            layoutMode: .area,
            character: .default,
            paragraph: ParagraphStyleV6(alignment: .justify, leftIndent: 12, rightIndent: 9, firstLineIndent: 18, spacingBefore: 3, spacingAfter: 7, lineSpacing: 2, tabs: [60, 120], listStyle: .numbered, hyphenation: true, direction: .leftToRight),
            runs: [run],
            glyphTransforms: [GlyphTransformV6(glyphIndex: 3, offsetX: 7, offsetY: -2, scaleX: 1.2, scaleY: 0.9, rotationDegrees: 11)],
            path: TextPathOptionsV6(pathReference: UUID(), startOffset: 12, endOffset: 5, baselineOffset: 3, flip: true),
            thread: TextThreadV6(previousFrameID: UUID(), nextFrameID: UUID()),
            warp: TextWarpV6(style: .arc, bend: 0.35, horizontalDistortion: 0.1, verticalDistortion: -0.2)
        )
        var rich = data
        rich.runs = [run]
        let encoded = try JSONEncoder().encode(rich)
        let decoded = try JSONDecoder().decode(TextDataV6.self, from: encoded)
        XCTAssertEqual(decoded, rich)
    }

    func testTypographyNormalizationClampsUnsafeValues() {
        var style = CharacterStyleV6.default
        style.fontSize = -50
        style.leading = -4
        style.horizontalScale = 0
        style.verticalScale = 9
        var data = TextDataV6(text: "X", frame: .zero, character: style)
        data.normalize()
        XCTAssertGreaterThanOrEqual(data.character.fontSize, 1)
        XCTAssertGreaterThanOrEqual(data.character.leading, 0)
        XCTAssertGreaterThanOrEqual(data.character.horizontalScale, 0.05)
        XCTAssertLessThanOrEqual(data.character.verticalScale, 8)
    }
}

extension TypographyModelTests {
    func testTrackingAndKerningConvertFromThousandthsOfEmToPoints() {
        let style = CharacterStyleV6(fontSize: 20, tracking: 100, kerning: -50)
        XCTAssertEqual(style.trackingPoints, 2, accuracy: 0.0001)
        XCTAssertEqual(style.kerningPoints, -1, accuracy: 0.0001)
    }
}
