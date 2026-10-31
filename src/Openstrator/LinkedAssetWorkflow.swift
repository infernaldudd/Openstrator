import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers
import OpenstratorCore

enum LinkedAssetState: Equatable {
    case linked
    case modified
    case missing

    var title: String {
        switch self {
        case .linked: return "Linked"
        case .modified: return "Modified"
        case .missing: return "Missing"
        }
    }

    var symbol: String {
        switch self {
        case .linked: return "link"
        case .modified: return "arrow.triangle.2.circlepath"
        case .missing: return "exclamationmark.triangle"
        }
    }
}

@MainActor
enum LinkedAssetRuntime {
    static func state(_ resource: LinkedAssetResourceV6) -> LinkedAssetState {
        guard let url = URL(string: resource.sourceURLString), url.isFileURL,
              FileManager.default.fileExists(atPath: url.path) else { return .missing }
        guard let saved = resource.modificationDate, let current = modificationDate(url) else { return .linked }
        return abs(current - saved) > 0.5 ? .modified : .linked
    }

    static func image(resourceID: UUID, document: OpenDocument, maxPixelDimension: Int) -> NSImage? {
        guard let resource = document.resourceLibrary?.linkedAssets.first(where: { $0.id == resourceID }) else { return nil }
        if let url = URL(string: resource.sourceURLString), url.isFileURL,
           let data = try? Data(contentsOf: url) {
            let stamp = modificationDate(url) ?? 0
            return RasterImageRuntime.image(data: data, cacheKey: "link-\(resource.id.uuidString)-\(stamp)", maxPixelDimension: maxPixelDimension)
        }
        if let fallback = resource.fallbackRasterAssetID {
            return RasterImageRuntime.image(assetID: fallback, document: document, maxPixelDimension: maxPixelDimension)
        }
        return nil
    }

    static func fingerprint(_ data: Data) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in data { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return String(format: "%016llx", hash)
    }

    static func modificationDate(_ url: URL) -> Double? {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate?.timeIntervalSince1970
    }
}

@MainActor
extension EditorStore {
    func placeLinkedImages() {
        let panel = NSOpenPanel()
        panel.title = "Place Linked Images"
        panel.allowedContentTypes = [UTType.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        placeLinkedImages(at: panel.urls)
    }

    func placeLinkedImages(at urls: [URL]) {
        let imports = urls.compactMap { url -> (URL, RasterAssetRecord)? in
            guard let asset = try? RasterImageRuntime.metadataAndEmbeddedAsset(from: url) else { return nil }
            return (url, asset)
        }
        guard !imports.isEmpty else { status = "No supported linked images"; return }
        snapshot()
        var assets = document.rasterAssets ?? []
        var library = document.resourceLibrary ?? ResourceLibraryV6()
        var created: [UUID] = []
        let artW = CGFloat(document.artboardWidth), artH = CGFloat(document.artboardHeight)
        let maxW = max(CGFloat(1), artW * 0.60), maxH = max(CGFloat(1), artH * 0.60)
        let base = CGPoint(x: artW / 2, y: artH / 2)

        for (index, pair) in imports.enumerated() {
            let (url, fallback) = pair
            let resource = LinkedAssetResourceV6(
                displayName: url.lastPathComponent,
                sourceURLString: url.absoluteString,
                originalFilename: url.lastPathComponent,
                fallbackRasterAssetID: fallback.id,
                contentFingerprint: LinkedAssetRuntime.fingerprint(fallback.embeddedData),
                modificationDate: LinkedAssetRuntime.modificationDate(url)
            )
            let pixelW = CGFloat(fallback.metadata.pixelWidth), pixelH = CGFloat(fallback.metadata.pixelHeight)
            let scale = min(CGFloat(1), min(maxW / pixelW, maxH / pixelH))
            let size = CGSize(width: max(1, pixelW * scale), height: max(1, pixelH * scale))
            let stagger = CGFloat(index) * 24
            var object = VectorObject.image(assetID: fallback.id, at: CGPoint(x: base.x - size.width / 2 + stagger, y: base.y - size.height / 2 + stagger), size: size, name: url.deletingPathExtension().lastPathComponent)
            object.linkedAssetID = resource.id
            assets.append(fallback)
            library.linkedAssets.append(resource)
            document.objects.append(object)
            created.append(object.id)
        }
        document.rasterAssets = assets
        document.resourceLibrary = library
        selection = Set(created)
        commitMutation(status: imports.count == 1 ? "Linked image placed" : "\(imports.count) linked images placed")
    }

    func linkedAssetState(_ id: UUID) -> LinkedAssetState {
        guard let resource = document.resourceLibrary?.linkedAssets.first(where: { $0.id == id }) else { return .missing }
        return LinkedAssetRuntime.state(resource)
    }

    func refreshLinkedAsset(_ id: UUID) {
        guard var library = document.resourceLibrary,
              let linkIndex = library.linkedAssets.firstIndex(where: { $0.id == id }),
              let url = URL(string: library.linkedAssets[linkIndex].sourceURLString),
              let fresh = try? RasterImageRuntime.metadataAndEmbeddedAsset(from: url) else {
            status = "Linked source is unavailable"
            return
        }
        snapshot()
        var assets = document.rasterAssets ?? []
        assets.append(fresh)
        library.linkedAssets[linkIndex].fallbackRasterAssetID = fresh.id
        library.linkedAssets[linkIndex].contentFingerprint = LinkedAssetRuntime.fingerprint(fresh.embeddedData)
        library.linkedAssets[linkIndex].modificationDate = LinkedAssetRuntime.modificationDate(url)
        document.resourceLibrary = library
        document.rasterAssets = assets
        for index in document.objects.indices where document.objects[index].linkedAssetID == id {
            document.objects[index].rasterAssetID = fresh.id
        }
        RasterImageCache.shared.removeAll()
        commitMutation(status: "Linked asset refreshed")
    }

    func relinkLinkedAsset(_ id: UUID) {
        let panel = NSOpenPanel()
        panel.title = "Relink Asset"
        panel.allowedContentTypes = [UTType.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let fresh = try? RasterImageRuntime.metadataAndEmbeddedAsset(from: url),
              var library = document.resourceLibrary,
              let linkIndex = library.linkedAssets.firstIndex(where: { $0.id == id }) else { return }
        snapshot()
        var assets = document.rasterAssets ?? []
        assets.append(fresh)
        library.linkedAssets[linkIndex].displayName = url.lastPathComponent
        library.linkedAssets[linkIndex].originalFilename = url.lastPathComponent
        library.linkedAssets[linkIndex].sourceURLString = url.absoluteString
        library.linkedAssets[linkIndex].fallbackRasterAssetID = fresh.id
        library.linkedAssets[linkIndex].contentFingerprint = LinkedAssetRuntime.fingerprint(fresh.embeddedData)
        library.linkedAssets[linkIndex].modificationDate = LinkedAssetRuntime.modificationDate(url)
        document.resourceLibrary = library
        document.rasterAssets = assets
        for index in document.objects.indices where document.objects[index].linkedAssetID == id { document.objects[index].rasterAssetID = fresh.id }
        RasterImageCache.shared.removeAll()
        commitMutation(status: "Asset relinked")
    }

    func embedLinkedAsset(_ id: UUID) {
        guard var library = document.resourceLibrary,
              let linkIndex = library.linkedAssets.firstIndex(where: { $0.id == id }),
              let existingFallbackID = library.linkedAssets[linkIndex].fallbackRasterAssetID else { return }
        snapshot()
        var embeddedID = existingFallbackID
        if let url = URL(string: library.linkedAssets[linkIndex].sourceURLString),
           let fresh = try? RasterImageRuntime.metadataAndEmbeddedAsset(from: url) {
            var assets = document.rasterAssets ?? []
            assets.append(fresh)
            document.rasterAssets = assets
            embeddedID = fresh.id
        }
        for index in document.objects.indices where document.objects[index].linkedAssetID == id {
            document.objects[index].linkedAssetID = nil
            document.objects[index].rasterAssetID = embeddedID
        }
        library.linkedAssets.remove(at: linkIndex)
        document.resourceLibrary = library
        RasterImageCache.shared.removeAll()
        commitMutation(status: "Linked asset embedded")
    }
}
