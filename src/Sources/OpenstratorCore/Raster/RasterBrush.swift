import Foundation

public enum RasterBrushV6 {
    public static func paint(
        _ store: inout RasterTileStoreV6,
        centerX: Int,
        centerY: Int,
        radius: Double,
        color: RasterPixelV6,
        opacity: Double,
        selection: RasterSelectionV6? = nil,
        mask: RasterMaskV6? = nil
    ) throws {
        let radius = max(0.5, radius)
        let opacity = max(0, min(1, opacity))
        let minX = max(0, Int(floor(Double(centerX) - radius)))
        let maxX = min(store.width - 1, Int(ceil(Double(centerX) + radius)))
        let minY = max(0, Int(floor(Double(centerY) - radius)))
        let maxY = min(store.height - 1, Int(ceil(Double(centerY) + radius)))
        guard minX <= maxX, minY <= maxY else { return }

        for y in minY...maxY {
            for x in minX...maxX {
                let dx = Double(x - centerX)
                let dy = Double(y - centerY)
                guard dx * dx + dy * dy <= radius * radius else { continue }
                let selectionCoverage = Double(selection?.value(x: x, y: y) ?? 255) / 255
                let maskCoverage = Double(mask?.value(x: x, y: y) ?? 255) / 255
                let coverage = opacity * selectionCoverage * maskCoverage
                guard coverage > 0 else { continue }

                let destination = store.pixel(x: x, y: y)
                let sourceAlpha = (Double(color.a) / 255) * coverage
                let destinationAlpha = Double(destination.a) / 255
                let outputAlpha = sourceAlpha + destinationAlpha * (1 - sourceAlpha)
                guard outputAlpha > 0 else {
                    try store.setPixel(.clear, x: x, y: y)
                    continue
                }

                func blend(_ source: UInt8, _ destination: UInt8) -> UInt8 {
                    let value = (Double(source) / 255 * sourceAlpha + Double(destination) / 255 * destinationAlpha * (1 - sourceAlpha)) / outputAlpha
                    return UInt8(max(0, min(255, Int((value * 255).rounded()))))
                }

                try store.setPixel(
                    .init(
                        r: blend(color.r, destination.r),
                        g: blend(color.g, destination.g),
                        b: blend(color.b, destination.b),
                        a: UInt8(max(0, min(255, Int((outputAlpha * 255).rounded()))))
                    ),
                    x: x,
                    y: y
                )
            }
        }
    }

    public static func erase(
        _ store: inout RasterTileStoreV6,
        centerX: Int,
        centerY: Int,
        radius: Double,
        opacity: Double,
        selection: RasterSelectionV6? = nil,
        mask: RasterMaskV6? = nil
    ) throws {
        let radius = max(0.5, radius)
        let opacity = max(0, min(1, opacity))
        let minX = max(0, Int(floor(Double(centerX) - radius)))
        let maxX = min(store.width - 1, Int(ceil(Double(centerX) + radius)))
        let minY = max(0, Int(floor(Double(centerY) - radius)))
        let maxY = min(store.height - 1, Int(ceil(Double(centerY) + radius)))
        guard minX <= maxX, minY <= maxY else { return }

        for y in minY...maxY {
            for x in minX...maxX {
                let dx = Double(x - centerX)
                let dy = Double(y - centerY)
                guard dx * dx + dy * dy <= radius * radius else { continue }
                let selectionCoverage = Double(selection?.value(x: x, y: y) ?? 255) / 255
                let maskCoverage = Double(mask?.value(x: x, y: y) ?? 255) / 255
                let coverage = opacity * selectionCoverage * maskCoverage
                guard coverage > 0 else { continue }
                var pixel = store.pixel(x: x, y: y)
                pixel.a = UInt8(max(0, min(255, Int((Double(pixel.a) * (1 - coverage)).rounded()))))
                try store.setPixel(pixel, x: x, y: y)
            }
        }
    }
}
