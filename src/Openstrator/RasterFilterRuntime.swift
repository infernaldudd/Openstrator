import AppKit
import CoreImage
import Foundation
import OpenstratorCore

@MainActor
enum RasterRenderQualityV6 {
    case preview
    case final

    var maxDimension: CGFloat? {
        switch self {
        case .preview: return 2048
        case .final: return nil
        }
    }
}

@MainActor
enum RasterFilterRuntime {
    static let context = CIContext(options: [.cacheIntermediates: true])

    static func filteredImage(for object: VectorObject, document: OpenDocument, quality: RasterRenderQualityV6 = .preview) -> NSImage? {
        guard let assetID = object.rasterAssetID,
              let asset = document.rasterAssets?.first(where: { $0.id == assetID }),
              var image = CIImage(data: asset.embeddedData) else { return nil }

        let original = image.extent.integral
        if let maxDimension = quality.maxDimension, max(original.width, original.height) > maxDimension {
            let scale = maxDimension / max(original.width, original.height)
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        let baseExtent = image.extent.integral
        for raw in object.rasterFilters ?? [] where raw.enabled {
            var record = raw
            record.normalize()
            image = apply(record, to: image, extent: baseExtent).cropped(to: baseExtent)
        }
        guard baseExtent.width > 0, baseExtent.height > 0,
              let cg = context.createCGImage(image, from: baseExtent) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width), height: CGFloat(cg.height)))
    }

    private static func apply(_ record: RasterFilterRecordV6, to input: CIImage, extent: CGRect) -> CIImage {
        func n(_ key: String, _ fallback: Double) -> Double { record.parameters[key] ?? fallback }
        switch record.id {
        case .gaussianBlur:
            return filter("CIGaussianBlur", input: input, values: [kCIInputRadiusKey: n("radius", 8)]) ?? input
        case .motionBlur:
            return filter("CIMotionBlur", input: input, values: [kCIInputRadiusKey: n("distance", 20), kCIInputAngleKey: n("angle", 0) * .pi / 180]) ?? input
        case .exposure:
            return filter("CIExposureAdjust", input: input, values: [kCIInputEVKey: n("ev", 0)]) ?? input
        case .brightnessContrast:
            return filter("CIColorControls", input: input, values: [kCIInputBrightnessKey: n("brightness", 0), kCIInputContrastKey: n("contrast", 1)]) ?? input
        case .saturation:
            return filter("CIColorControls", input: input, values: [kCIInputSaturationKey: n("saturation", 1)]) ?? input
        case .hue:
            return filter("CIHueAdjust", input: input, values: [kCIInputAngleKey: n("angle", 0) * .pi / 180]) ?? input
        case .sepia:
            return filter("CISepiaTone", input: input, values: [kCIInputIntensityKey: n("intensity", 0.8)]) ?? input
        case .sharpen:
            return filter("CISharpenLuminance", input: input, values: [kCIInputSharpnessKey: n("sharpness", 0.4)]) ?? input
        case .noise:
            guard let noise = CIFilter(name: "CIRandomGenerator")?.outputImage,
                  let matrix = CIFilter(name: "CIColorMatrix") else { return input }
            let amount = n("amount", 0.08)
            matrix.setValue(noise.cropped(to: extent), forKey: kCIInputImageKey)
            matrix.setValue(CIVector(x: amount, y: amount, z: amount, w: amount), forKey: "inputAVector")
            guard let tinted = matrix.outputImage,
                  let composite = CIFilter(name: "CISourceOverCompositing") else { return input }
            composite.setValue(tinted, forKey: kCIInputImageKey)
            composite.setValue(input, forKey: kCIInputBackgroundImageKey)
            return composite.outputImage ?? input
        case .pixelate:
            return filter("CIPixellate", input: input, values: [kCIInputScaleKey: n("scale", 12)]) ?? input
        case .crystallize:
            return filter("CICrystallize", input: input, values: [kCIInputRadiusKey: n("radius", 18)]) ?? input
        case .colorControls:
            return filter("CIColorControls", input: input, values: [
                kCIInputBrightnessKey: n("brightness", 0),
                kCIInputContrastKey: n("contrast", 1),
                kCIInputSaturationKey: n("saturation", 1)
            ]) ?? input
        }
    }

    private static func filter(_ name: String, input: CIImage, values: [String: Any]) -> CIImage? {
        guard let filter = CIFilter(name: name) else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        for (key, value) in values { filter.setValue(value, forKey: key) }
        return filter.outputImage
    }
}
