import Foundation
@testable import OpenstratorCore

func makeDocumentWithOneRect() -> DocumentV6 {
    var document = DocumentV6.empty(width: 1200, height: 800)
    try! document.insert(.rectangle(name: "Rect", rect: CGRect(x: 0, y: 0, width: 100, height: 50)), parent: document.activeArtboardID, index: 0)
    return document
}
