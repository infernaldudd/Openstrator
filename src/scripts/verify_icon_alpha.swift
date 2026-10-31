#if canImport(AppKit)
import AppKit
import Foundation
let url = URL(fileURLWithPath: "Resources/OpenstratorMark.png")
guard let data = try? Data(contentsOf: url), let image = NSImage(data: data), let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { fatalError("unable to decode icon") }
let corners = [(0,0),(rep.pixelsWide-1,0),(0,rep.pixelsHigh-1),(rep.pixelsWide-1,rep.pixelsHigh-1)]
for (x,y) in corners { guard let color=rep.colorAt(x:x,y:y), color.alphaComponent < 0.01 else { fatalError("icon corner at \(x),\(y) is not transparent") } }
print("icon alpha OK")
#else
import Foundation
print("icon alpha verification requires macOS AppKit")
#endif
