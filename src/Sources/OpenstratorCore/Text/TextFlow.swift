import Foundation

public enum TextThreadError: Error, Equatable, Sendable {
    case cycle
}

public struct TextFrameFlowV6: Equatable, Sendable {
    public var visibleText: String
    public var capacity: Int
    public init(visibleText: String, capacity: Int) {
        self.visibleText = visibleText
        self.capacity = capacity
    }
}

public struct TextFlowResultV6: Equatable, Sendable {
    public var frames: [TextFrameFlowV6]
    public var overflow: String
    public init(frames: [TextFrameFlowV6], overflow: String) {
        self.frames = frames
        self.overflow = overflow
    }
}

public enum TextThreadEngine {
    public static func capacity(for data: TextDataV6) -> Int {
        switch data.layoutMode {
        case .point, .verticalPoint, .path, .verticalPath:
            return Int.max
        case .area:
            let size = max(1, data.character.fontSize)
            let line = data.character.leading > 0 ? data.character.leading : size * 1.2 + data.paragraph.lineSpacing
            let usableWidth = max(1, Double(data.frame.width) - data.paragraph.leftIndent - data.paragraph.rightIndent)
            let charsPerLine = max(1, Int(floor(usableWidth / max(1, size * 0.55 + data.character.trackingPoints + data.character.kerningPoints))))
            let lines = max(1, Int(floor(Double(data.frame.height) / max(1, line))))
            return max(1, charsPerLine * lines)
        case .verticalArea:
            let size = max(1, data.character.fontSize)
            let step = data.character.leading > 0 ? data.character.leading : size * 1.2 + data.paragraph.lineSpacing
            let rows = max(1, Int(floor(Double(data.frame.height) / max(1, step))))
            let columns = max(1, Int(floor(Double(data.frame.width) / max(1, size * 1.05))))
            return max(1, rows * columns)
        }
    }

    public static func flow(text: String, frames: [TextDataV6]) -> TextFlowResultV6 {
        var remaining = Array(text)
        var output: [TextFrameFlowV6] = []
        for frame in frames {
            let cap = capacity(for: frame)
            let take = cap == Int.max ? remaining.count : min(cap, remaining.count)
            let visible = String(remaining.prefix(take))
            if take > 0 { remaining.removeFirst(take) }
            output.append(TextFrameFlowV6(visibleText: visible, capacity: cap))
        }
        return TextFlowResultV6(frames: output, overflow: String(remaining))
    }

    public static func orderedChain(start: UUID, links: [UUID: TextThreadV6]) throws -> [UUID] {
        var result: [UUID] = []
        var seen: Set<UUID> = []
        var current: UUID? = start
        while let id = current, links[id] != nil {
            if seen.contains(id) { throw TextThreadError.cycle }
            seen.insert(id)
            result.append(id)
            guard let next = links[id]?.nextFrameID, links[next] != nil else { break }
            current = next
        }
        return result
    }
}
