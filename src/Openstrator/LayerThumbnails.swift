import SwiftUI
import AppKit
import OpenstratorCore

@MainActor
final class LayerThumbnailCache: ObservableObject {
    static let shared = LayerThumbnailCache()
    private let cache = NSCache<NSString, NSImage>()
    private var pending = Set<String>()

    private init() {
        cache.countLimit = 96
        cache.totalCostLimit = 24 * 1024 * 1024
    }

    func image(for object: VectorObject, document: OpenDocument) -> NSImage? {
        let key = object.id.uuidString
        if let cached = cache.object(forKey: key as NSString) { return cached }
        guard pending.insert(key).inserted else { return nil }
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            let image = self.render(object: object, document: document)
            self.pending.remove(key)
            if let image {
                self.cache.setObject(image, forKey: key as NSString, cost: Int(image.size.width * image.size.height * 4))
            }
            self.objectWillChange.send()
        }
        return nil
    }

    func removeAll() {
        cache.removeAllObjects()
        pending.removeAll()
        objectWillChange.send()
    }

    private func render(object: VectorObject, document: OpenDocument) -> NSImage? {
        let canvas = NSSize(width: 38, height: 30)
        if object.kind == .image, object.embeddedObjectID == nil, object.symbolDefinitionID == nil {
            let source: NSImage?
            if let linkID = object.linkedAssetID {
                source = LinkedAssetRuntime.image(resourceID: linkID, document: document, maxPixelDimension: 96)
            } else if let assetID = object.rasterAssetID {
                source = RasterImageRuntime.image(assetID: assetID, document: document, maxPixelDimension: 96)
            } else { source = nil }
            if let source { return fitted(source, size: canvas) }
        }

        let image = NSImage(size: canvas)
        image.lockFocus()
        defer { image.unlockFocus() }
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: canvas)).fill()

        let rect = NSRect(x: 5, y: 4, width: 28, height: 22)
        if object.embeddedObjectID != nil || object.symbolDefinitionID != nil {
            NSColor.controlAccentColor.withAlphaComponent(0.16).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
            let letter = object.embeddedObjectID != nil ? "E" : "S"
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: NSColor.controlAccentColor]
            let size = letter.size(withAttributes: attrs)
            letter.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2), withAttributes: attrs)
            return image
        }

        let fill = NSColor(red: CGFloat(object.fill.r), green: CGFloat(object.fill.g), blue: CGFloat(object.fill.b), alpha: CGFloat(max(0.18, object.fill.a)))
        let stroke = NSColor(red: CGFloat(object.stroke.r), green: CGFloat(object.stroke.g), blue: CGFloat(object.stroke.b), alpha: CGFloat(max(0.25, object.stroke.a)))
        switch object.kind {
        case .rectangle:
            fill.setFill(); NSBezierPath(roundedRect: rect, xRadius: CGFloat(min(6, object.cornerRadius * 0.1)), yRadius: CGFloat(min(6, object.cornerRadius * 0.1))).fill()
        case .ellipse:
            fill.setFill(); NSBezierPath(ovalIn: rect).fill()
        case .polygon:
            let p = NSBezierPath()
            for i in 0..<6 {
                let a = -Double.pi / 2 + Double(i) * 2 * Double.pi / 6
                let point = NSPoint(x: rect.midX + CGFloat(cos(a)) * rect.width / 2, y: rect.midY + CGFloat(sin(a)) * rect.height / 2)
                i == 0 ? p.move(to: point) : p.line(to: point)
            }
            p.close(); fill.setFill(); p.fill()
        case .line, .path:
            let p = NSBezierPath(); p.move(to: NSPoint(x: rect.minX, y: rect.minY + 4)); p.curve(to: NSPoint(x: rect.maxX, y: rect.maxY - 4), controlPoint1: NSPoint(x: rect.midX, y: rect.maxY), controlPoint2: NSPoint(x: rect.midX, y: rect.minY)); stroke.setStroke(); p.lineWidth = 2; p.stroke()
        case .text:
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 18, weight: .medium), .foregroundColor: fill]
            "T".draw(at: NSPoint(x: rect.midX - 5, y: rect.midY - 10), withAttributes: attrs)
        case .image:
            NSColor.secondaryLabelColor.setStroke(); let p = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3); p.lineWidth = 1; p.stroke()
        }
        return image
    }

    private func fitted(_ source: NSImage, size: NSSize) -> NSImage {
        let output = NSImage(size: size)
        output.lockFocus()
        defer { output.unlockFocus() }
        let sourceSize = source.size
        let scale = min(size.width / max(1, sourceSize.width), size.height / max(1, sourceSize.height))
        let drawSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let rect = NSRect(x: (size.width - drawSize.width) / 2, y: (size.height - drawSize.height) / 2, width: drawSize.width, height: drawSize.height)
        source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        return output
    }
}

@MainActor
struct LayerThumbnailView: View {
    @EnvironmentObject var store: EditorStore
    let node: LayerNodeV6
    @ObservedObject private var cache = LayerThumbnailCache.shared

    var body: some View {
        Group {
            if let objectID = node.objectID,
               let object = store.document.objects.first(where: { $0.id == objectID }),
               let image = cache.image(for: object, document: store.document) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: fallbackSymbol).foregroundStyle(.secondary)
            }
        }
        .frame(width: 32, height: 24)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 4))
    }

    private var fallbackSymbol: String {
        switch node.kind {
        case .artboard: return "rectangle.on.rectangle"
        case .layer: return "square.3.layers.3d"
        case .group: return "folder"
        case .object: return "square"
        case .clippingGroup: return "crop"
        case .embeddedObject: return "shippingbox"
        case .symbolInstance: return "seal"
        }
    }
}
