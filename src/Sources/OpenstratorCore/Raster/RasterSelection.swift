import Foundation

public struct RasterSelectionV6: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var bytes: [UInt8]

    public init(width: Int, height: Int, bytes: [UInt8]) {
        let normalizedWidth = max(1, width)
        let normalizedHeight = max(1, height)
        let (count, overflow) = normalizedWidth.multipliedReportingOverflow(by: normalizedHeight)
        if overflow || count <= 0 {
            self.width = 1
            self.height = 1
            self.bytes = [0]
            return
        }
        self.width = normalizedWidth
        self.height = normalizedHeight
        if bytes.count == count { self.bytes = bytes }
        else if bytes.count > count { self.bytes = Array(bytes.prefix(count)) }
        else { self.bytes = bytes + Array(repeating: 0, count: count - bytes.count) }
    }

    public func value(x: Int, y: Int) -> UInt8 {
        guard x >= 0, y >= 0, x < width, y < height else { return 0 }
        return bytes[y * width + x]
    }

    public static func rectangle(canvasWidth: Int, canvasHeight: Int, x: Int, y: Int, width: Int, height: Int) -> RasterSelectionV6 {
        let canvas = normalizedCanvas(width: canvasWidth, height: canvasHeight)
        var bytes = Array(repeating: UInt8(0), count: canvas.width * canvas.height)
        guard width > 0, height > 0 else { return .init(width: canvas.width, height: canvas.height, bytes: bytes) }
        let minX = max(0, x)
        let minY = max(0, y)
        let maxX = min(canvas.width, x + width)
        let maxY = min(canvas.height, y + height)
        if minX < maxX && minY < maxY {
            for py in minY..<maxY {
                for px in minX..<maxX { bytes[py * canvas.width + px] = 255 }
            }
        }
        return .init(width: canvas.width, height: canvas.height, bytes: bytes)
    }

    public static func ellipse(canvasWidth: Int, canvasHeight: Int, x: Int, y: Int, width: Int, height: Int) -> RasterSelectionV6 {
        let canvas = normalizedCanvas(width: canvasWidth, height: canvasHeight)
        var bytes = Array(repeating: UInt8(0), count: canvas.width * canvas.height)
        guard width > 0, height > 0 else { return .init(width: canvas.width, height: canvas.height, bytes: bytes) }
        let rx = Double(width) / 2
        let ry = Double(height) / 2
        let cx = Double(x) + rx
        let cy = Double(y) + ry
        let startY = max(0, y)
        let endY = min(canvas.height, y + height)
        let startX = max(0, x)
        let endX = min(canvas.width, x + width)
        guard startX < endX, startY < endY else { return .init(width: canvas.width, height: canvas.height, bytes: bytes) }
        for py in startY..<endY {
            for px in startX..<endX {
                let dx = (Double(px) + 0.5 - cx) / rx
                let dy = (Double(py) + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1 { bytes[py * canvas.width + px] = 255 }
            }
        }
        return .init(width: canvas.width, height: canvas.height, bytes: bytes)
    }

    private static func normalizedCanvas(width: Int, height: Int) -> (width: Int, height: Int) {
        let w = max(1, width)
        let h = max(1, height)
        let (_, overflow) = w.multipliedReportingOverflow(by: h)
        return overflow ? (1, 1) : (w, h)
    }
}

public extension RasterMaskV6 {
    func value(x: Int, y: Int) -> UInt8 {
        guard x >= 0, y >= 0, x < width, y < height else { return 0 }
        return bytes[y * width + x]
    }
}
