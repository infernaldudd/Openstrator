public enum CanvasKeyRouting {
    public static func shouldHandleDelete(keyCode: UInt16, hasSelection: Bool, textEditingActive: Bool) -> Bool {
        guard !textEditingActive, hasSelection else { return false }
        return keyCode == 51 || keyCode == 117
    }
}
