import AppKit
import CoreText
import Foundation
import OpenstratorCore

@MainActor
enum TextOutliner {
    static func paths(for object: VectorObject) -> [BezierPathV6] {
        let data = object.resolvedTypography
        guard !data.text.isEmpty else { return [] }
        let resolved = MacFontCatalog.shared.resolveFont(style: data.character)
        let ctFont = CTFontCreateWithName(resolved.font.fontName as CFString, CGFloat(data.character.fontSize), nil)
        let attributed = NSAttributedString(string: data.text, attributes: [kCTFontAttributeName as NSAttributedString.Key: ctFont])
        let line = CTLineCreateWithAttributedString(attributed)
        let runs = CTLineGetGlyphRuns(line) as NSArray
        var output: [BezierPathV6] = []
        for case let run as CTRun in runs {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            var glyphs = Array(repeating: CGGlyph(), count: count)
            var positions = Array(repeating: CGPoint.zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            // The attributed string above applies a single CTFont to the whole line,
            // so every CTRun uses this font. Avoid Swift 6's invalid conditional
            // downcast to the CoreFoundation CTFont type.
            let runFont = ctFont
            for index in 0..<count {
                guard let glyphPath = CTFontCreatePathForGlyph(runFont, glyphs[index], nil) else { continue }
                var transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1,
                                                  tx: object.x + positions[index].x,
                                                  ty: object.y + CGFloat(data.character.fontSize) + positions[index].y)
                guard let moved = glyphPath.copy(using: &transform) else { continue }
                output.append(contentsOf: bezierSubpaths(from: moved))
            }
        }
        return output
    }

    private static func bezierSubpaths(from path: CGPath) -> [BezierPathV6] {
        var completed: [BezierPathV6] = []
        var anchors: [PathAnchorV6] = []
        var isClosed = false

        func finish() {
            guard !anchors.isEmpty else { return }
            completed.append(BezierPathV6(anchors: anchors, isClosed: isClosed))
            anchors.removeAll(); isClosed = false
        }

        path.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                finish()
                anchors = [PathAnchorV6(point: element.points[0])]
            case .addLineToPoint:
                anchors.append(PathAnchorV6(point: element.points[0]))
            case .addCurveToPoint:
                guard !anchors.isEmpty else { return }
                anchors[anchors.count - 1].outHandle = element.points[0]
                anchors.append(PathAnchorV6(point: element.points[2], inHandle: element.points[1]))
            case .addQuadCurveToPoint:
                guard let previous = anchors.last else { return }
                let q = element.points[0], end = element.points[1]
                let c1 = CGPoint(x: previous.point.x + (q.x - previous.point.x) * 2 / 3,
                                 y: previous.point.y + (q.y - previous.point.y) * 2 / 3)
                let c2 = CGPoint(x: end.x + (q.x - end.x) * 2 / 3,
                                 y: end.y + (q.y - end.y) * 2 / 3)
                anchors[anchors.count - 1].outHandle = c1
                anchors.append(PathAnchorV6(point: end, inHandle: c2))
            case .closeSubpath:
                isClosed = true
                finish()
            @unknown default:
                break
            }
        }
        finish()
        return completed
    }
}
