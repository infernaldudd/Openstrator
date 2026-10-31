import SwiftUI
import AppKit
import OpenstratorCore

private struct RenderGlyphV6 {
    var text: String
    var style: CharacterStyleV6
    var point: CGPoint
    var angle: Double
    var scaleX: Double
    var scaleY: Double
    var sourceIndex: Int
}

enum TypographyRenderer {
    @MainActor
    static func draw(
        object: VectorObject,
        pathLookup: (UUID) -> BezierPathV6?,
        context: inout GraphicsContext
    ) {
        let data = object.resolvedTypography
        let glyphs = makeGlyphs(data: data, pathLookup: pathLookup)
        for glyph in glyphs {
            var style = glyph.style
            let raw = glyph.text
            let display: String
            switch style.capitalization {
            case .allCaps: display = raw.uppercased()
            case .titleCase: display = raw.capitalized
            case .smallCaps:
                display = raw.uppercased()
                if raw != raw.uppercased() { style.fontSize *= 0.80 }
            case .normal: display = raw
            }
            switch style.scriptPosition {
            case .superscript:
                style.fontSize *= 0.72
                style.baselineShift += glyph.style.fontSize * 0.35
            case .subscript:
                style.fontSize *= 0.72
                style.baselineShift -= glyph.style.fontSize * 0.20
            case .normal: break
            }
            let resolved = MacFontCatalog.shared.resolveFont(style: style)
            let text = Text(verbatim: display)
                .font(.custom(resolved.font.fontName, size: style.fontSize))
                .foregroundColor(object.fill.swiftUIColor)
                .tracking(style.trackingPoints)
                .kerning(style.kerningPoints)
                .baselineOffset(style.baselineShift)
                .underline(style.underline)
                .strikethrough(style.strikethrough)
            let resolvedText = context.resolve(text)
            context.drawLayer { layer in
                var transform = CGAffineTransform(translationX: glyph.point.x, y: glyph.point.y)
                transform = transform.rotated(by: CGFloat((glyph.angle + style.rotationDegrees) * Double.pi / 180))
                transform = transform.scaledBy(x: CGFloat(glyph.scaleX * style.horizontalScale), y: CGFloat(glyph.scaleY * style.verticalScale))
                layer.concatenate(transform)
                layer.draw(resolvedText, at: CGPoint(x: 0, y: 0), anchor: .topLeading)
            }
        }
    }

    @MainActor
    private static func makeGlyphs(data: TextDataV6, pathLookup: (UUID) -> BezierPathV6?) -> [RenderGlyphV6] {
        let characters = Array(processedText(data))
        guard !characters.isEmpty else { return [] }
        let styles = characters.indices.map { style(forGlyph: $0, data: data) }
        let advances = styles.enumerated().map { index, style in
            glyphAdvance(String(characters[index]), style: style)
        }
        var placements: [TextGlyphPlacementV6] = []

        switch data.layoutMode {
        case .path, .verticalPath:
            guard let id = data.path?.pathReference, let path = pathLookup(id) else { return [] }
            placements = TextPathLayout.placements(
                advances: advances,
                path: path,
                startOffset: data.path?.startOffset ?? 0,
                endOffset: data.path?.endOffset ?? 0,
                baselineOffset: data.path?.baselineOffset ?? 0,
                flip: data.path?.flip ?? false
            )
            if data.layoutMode == .verticalPath {
                for i in placements.indices { placements[i].angleDegrees += 90 }
            }
        case .verticalPoint, .verticalArea:
            placements = verticalPlacements(characters: characters, styles: styles, frame: data.frame, wrapping: data.layoutMode == .verticalArea)
        case .point, .area:
            placements = horizontalPlacements(characters: characters, styles: styles, frame: data.frame, paragraph: data.paragraph, wrapping: data.layoutMode == .area)
        }

        let transformMap = Dictionary(uniqueKeysWithValues: data.glyphTransforms.map { ($0.glyphIndex, $0) })
        return placements.compactMap { base in
            guard characters.indices.contains(base.glyphIndex) else { return nil }
            var placement = base
            if let glyphTransform = transformMap[base.glyphIndex] {
                placement = TextPathLayout.applying(glyphTransform, to: placement)
            }
            if let warp = data.warp, warp.style != .none {
                let nx = Double((placement.point.x - data.frame.minX) / max(1, data.frame.width))
                let ny = Double((placement.point.y - data.frame.minY) / max(1, data.frame.height))
                let w = TextWarpEngine.offset(normalizedX: nx, normalizedY: ny, warp: warp, frame: data.frame.size)
                placement.point = CGPoint(x: Double(placement.point.x) + w.dx, y: Double(placement.point.y) + w.dy)
                placement.angleDegrees += w.rotationDegrees
                placement.scaleX *= w.scaleX
                placement.scaleY *= w.scaleY
            }
            return RenderGlyphV6(
                text: String(characters[placement.glyphIndex]),
                style: styles[placement.glyphIndex],
                point: placement.point,
                angle: placement.angleDegrees,
                scaleX: placement.scaleX,
                scaleY: placement.scaleY,
                sourceIndex: placement.glyphIndex
            )
        }
    }

    private static func processedText(_ data: TextDataV6) -> String {
        let paragraphs = data.text.components(separatedBy: "\n")
        switch data.paragraph.listStyle {
        case .none: return data.text
        case .bullets: return paragraphs.map { "• " + $0 }.joined(separator: "\n")
        case .numbered: return paragraphs.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        }
    }

    private static func style(forGlyph index: Int, data: TextDataV6) -> CharacterStyleV6 {
        for run in data.runs where index >= run.range.location && index < run.range.location + run.range.length {
            return run.style
        }
        return data.character
    }

    @MainActor
    private static func glyphAdvance(_ text: String, style: CharacterStyleV6) -> Double {
        if text == "\n" { return 0 }
        let resolved = MacFontCatalog.shared.resolveFont(style: style)
        let width = (text as NSString).size(withAttributes: [.font: resolved.font]).width
        return max(1, Double(width) + style.trackingPoints + style.kerningPoints)
    }

    @MainActor
    private static func horizontalPlacements(characters: [Character], styles: [CharacterStyleV6], frame: CGRect, paragraph: ParagraphStyleV6, wrapping: Bool) -> [TextGlyphPlacementV6] {
        struct Line { var items: [(Int, Double)]; var width: Double }
        let maxWidth = max(1, Double(frame.width) - paragraph.leftIndent - paragraph.rightIndent)
        var lines: [Line] = [Line(items: [], width: 0)]
        for index in characters.indices {
            if characters[index] == "\n" {
                lines.append(Line(items: [], width: 0)); continue
            }
            let advance = glyphAdvance(String(characters[index]), style: styles[index])
            if wrapping, !lines.last!.items.isEmpty, lines.last!.width + advance > maxWidth {
                lines.append(Line(items: [], width: 0))
            }
            lines[lines.count - 1].items.append((index, advance))
            lines[lines.count - 1].width += advance
        }
        var output: [TextGlyphPlacementV6] = []
        var y = Double(frame.minY) + paragraph.spacingBefore
        for (lineIndex, line) in lines.enumerated() {
            let firstStyle = line.items.first.map { styles[$0.0] } ?? .default
            let lineHeight = firstStyle.leading > 0 ? firstStyle.leading : firstStyle.fontSize * 1.2 + paragraph.lineSpacing
            let firstIndent = lineIndex == 0 ? paragraph.firstLineIndent : 0
            let available = max(0, maxWidth - firstIndent)
            let startOffset: Double
            switch paragraph.alignment {
            case .left, .justify: startOffset = 0
            case .center: startOffset = max(0, (available - line.width) / 2)
            case .right: startOffset = max(0, available - line.width)
            }
            var x = Double(frame.minX) + paragraph.leftIndent + firstIndent + startOffset
            for (index, advance) in line.items {
                output.append(TextGlyphPlacementV6(glyphIndex: index, point: CGPoint(x: x, y: y)))
                x += advance
            }
            y += lineHeight
            if wrapping, y > Double(frame.maxY) { break }
        }
        return output
    }

    @MainActor
    private static func verticalPlacements(characters: [Character], styles: [CharacterStyleV6], frame: CGRect, wrapping: Bool) -> [TextGlyphPlacementV6] {
        var output: [TextGlyphPlacementV6] = []
        var x = Double(frame.minX)
        var y = Double(frame.minY)
        var columnWidth = 0.0
        for index in characters.indices {
            if characters[index] == "\n" {
                x += max(columnWidth, styles[index].fontSize * 1.1); y = Double(frame.minY); columnWidth = 0; continue
            }
            let style = styles[index]
            let advance = style.leading > 0 ? style.leading : style.fontSize * 1.15
            if wrapping, y + advance > Double(frame.maxY), y > Double(frame.minY) {
                x += max(columnWidth, style.fontSize * 1.1); y = Double(frame.minY); columnWidth = 0
            }
            if wrapping, x > Double(frame.maxX) { break }
            output.append(TextGlyphPlacementV6(glyphIndex: index, point: CGPoint(x: x, y: y), angleDegrees: 0))
            y += advance
            columnWidth = max(columnWidth, style.fontSize)
        }
        return output
    }
}
