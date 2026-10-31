import Foundation

public struct CommandHistory: Sendable {
    private var undoStack: [DocumentCommand] = []
    private var redoStack: [DocumentCommand] = []
    public let limit: Int
    public init(limit: Int) { self.limit = max(1, limit) }
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public mutating func execute(_ command: DocumentCommand, on document: inout DocumentV6) throws {
        for m in command.forward { try m.apply(to: &document) }
        undoStack.append(command)
        if undoStack.count > limit { undoStack.removeFirst(undoStack.count - limit) }
        redoStack.removeAll()
    }

    public mutating func coalesce(_ command: DocumentCommand, on document: inout DocumentV6) throws {
        guard let key = command.coalescingKey, let last = undoStack.last, last.coalescingKey == key else {
            try execute(command, on: &document); return
        }
        for m in command.forward { try m.apply(to: &document) }
        var merged = command
        merged.inverse = last.inverse
        undoStack[undoStack.count - 1] = merged
        redoStack.removeAll()
    }

    public mutating func undo(on document: inout DocumentV6) throws {
        guard let command = undoStack.popLast() else { return }
        for m in command.inverse { try m.apply(to: &document) }
        redoStack.append(command)
    }

    public mutating func redo(on document: inout DocumentV6) throws {
        guard let command = redoStack.popLast() else { return }
        for m in command.forward { try m.apply(to: &document) }
        undoStack.append(command)
    }
}
