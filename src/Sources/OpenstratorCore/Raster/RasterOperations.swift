import Foundation

public enum RasterOperationsV6 {
    public static func crop(_ source: RasterTileStoreV6, x: Int, y: Int, width: Int, height: Int) throws -> RasterTileStoreV6 {
        guard width > 0, height > 0 else { throw RasterBufferError.invalidDimensions }
        var output = try RasterTileStoreV6(width: width, height: height, tileSize: source.tileSize)
        for outputY in 0..<height {
            for outputX in 0..<width {
                let sourceX = x + outputX
                let sourceY = y + outputY
                if sourceX >= 0, sourceY >= 0, sourceX < source.width, sourceY < source.height {
                    let pixel = source.pixel(x: sourceX, y: sourceY)
                    if pixel != .clear { try output.setPixel(pixel, x: outputX, y: outputY) }
                }
            }
        }
        return output
    }

    public static func resampleBilinear(_ source: RasterTileStoreV6, width: Int, height: Int) throws -> RasterTileStoreV6 {
        guard width > 0, height > 0 else { throw RasterBufferError.invalidDimensions }
        var output = try RasterTileStoreV6(width: width, height: height, tileSize: source.tileSize)
        let xScale = Double(source.width) / Double(width)
        let yScale = Double(source.height) / Double(height)

        for y in 0..<height {
            for x in 0..<width {
                let fx = (Double(x) + 0.5) * xScale - 0.5
                let fy = (Double(y) + 0.5) * yScale - 0.5
                let x0 = max(0, min(source.width - 1, Int(floor(fx))))
                let y0 = max(0, min(source.height - 1, Int(floor(fy))))
                let x1 = min(source.width - 1, x0 + 1)
                let y1 = min(source.height - 1, y0 + 1)
                let tx = max(0, min(1, fx - Double(x0)))
                let ty = max(0, min(1, fy - Double(y0)))
                let p00 = source.pixel(x: x0, y: y0)
                let p10 = source.pixel(x: x1, y: y0)
                let p01 = source.pixel(x: x0, y: y1)
                let p11 = source.pixel(x: x1, y: y1)

                func channel(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8) -> UInt8 {
                    let top = Double(a) * (1 - tx) + Double(b) * tx
                    let bottom = Double(c) * (1 - tx) + Double(d) * tx
                    return UInt8(max(0, min(255, Int((top * (1 - ty) + bottom * ty).rounded()))))
                }

                let pixel = RasterPixelV6(
                    r: channel(p00.r, p10.r, p01.r, p11.r),
                    g: channel(p00.g, p10.g, p01.g, p11.g),
                    b: channel(p00.b, p10.b, p01.b, p11.b),
                    a: channel(p00.a, p10.a, p01.a, p11.a)
                )
                if pixel != .clear { try output.setPixel(pixel, x: x, y: y) }
            }
        }
        return output
    }

    public static func composite(source: RasterTileStoreV6, over destination: RasterTileStoreV6, offsetX: Int, offsetY: Int) throws -> RasterTileStoreV6 {
        var output = destination
        for sourceY in 0..<source.height {
            for sourceX in 0..<source.width {
                let destinationX = sourceX + offsetX
                let destinationY = sourceY + offsetY
                guard destinationX >= 0, destinationY >= 0, destinationX < output.width, destinationY < output.height else { continue }

                let sourcePixel = source.pixel(x: sourceX, y: sourceY)
                if sourcePixel.a == 0 { continue }
                let destinationPixel = output.pixel(x: destinationX, y: destinationY)
                let sourceAlpha = Double(sourcePixel.a) / 255
                let destinationAlpha = Double(destinationPixel.a) / 255
                let outputAlpha = sourceAlpha + destinationAlpha * (1 - sourceAlpha)
                if outputAlpha <= 0 {
                    try output.setPixel(.clear, x: destinationX, y: destinationY)
                    continue
                }

                func blend(_ sourceChannel: UInt8, _ destinationChannel: UInt8) -> UInt8 {
                    let value = (Double(sourceChannel) / 255 * sourceAlpha + Double(destinationChannel) / 255 * destinationAlpha * (1 - sourceAlpha)) / outputAlpha
                    return UInt8(max(0, min(255, Int((value * 255).rounded()))))
                }

                let alpha = UInt8(max(0, min(255, Int((outputAlpha * 255).rounded()))))
                try output.setPixel(
                    .init(
                        r: blend(sourcePixel.r, destinationPixel.r),
                        g: blend(sourcePixel.g, destinationPixel.g),
                        b: blend(sourcePixel.b, destinationPixel.b),
                        a: alpha
                    ),
                    x: destinationX,
                    y: destinationY
                )
            }
        }
        return output
    }
}
