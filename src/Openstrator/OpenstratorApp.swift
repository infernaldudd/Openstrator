import SwiftUI
import OpenstratorCore

@main
struct OpenstratorApp: App {
    @StateObject private var store = EditorStore()
    @AppStorage("hasCompletedOnboarding.v2") private var hasCompletedOnboarding = false
    @AppStorage("appearanceMode") private var appearanceMode = "System"

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootEditorView()
                    .environmentObject(store)
                    .preferredColorScheme(preferredColorScheme)

                if !store.didFinishSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(50)
                } else if !hasCompletedOnboarding {
                    TutorialView(isPresented: Binding(
                        get: { !hasCompletedOnboarding },
                        set: { if !$0 { hasCompletedOnboarding = true } }
                    ))
                    .environmentObject(store)
                    .zIndex(40)
                }
            }
            .frame(minWidth: 1080, minHeight: 700)
            .task {
                store.installKeyboardMonitor()
                try? await Task.sleep(nanoseconds: 650_000_000)
                withAnimation(.easeOut(duration: 0.24)) {
                    store.didFinishSplash = true
                }
            }
            .onOpenURL { url in
                store.openDocument(at: url)
            }
        }
        .defaultSize(width: 1420, height: 900)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Document") { store.newDocument() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Open…") { store.openDocument() }
                    .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button("Place Images…") { store.placeImages() }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                Button("Place Linked Images…") { store.placeLinkedImages() }
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") { store.saveDocument() }
                    .keyboardShortcut("s", modifiers: .command)
                Button("Save As…") { store.saveDocument(saveAs: true) }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Divider()
                Menu("Export") {
                    Button("SVG…") { store.exportSVG() }
                    Button("PNG…") { store.exportPNG() }
                    Button("PDF…") { store.exportPDF() }
                }
            }

            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { store.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                Button("Redo") { store.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .pasteboard) {
                Button("Cut") { store.cutSelection() }
                    .keyboardShortcut("x", modifiers: .command)
                Button("Copy") { store.copySelection() }
                    .keyboardShortcut("c", modifiers: .command)
                Button("Paste") { store.paste() }
                    .keyboardShortcut("v", modifiers: .command)
                Divider()
                Button("Select All") { store.selectAll() }
                    .keyboardShortcut("a", modifiers: .command)
                Button("Deselect All") { store.deselectAll() }
                    .keyboardShortcut("a", modifiers: [.command, .shift])
            }

            CommandMenu("Insert") {
                Button("Images…") { store.placeImages() }
                Button("Linked Images…") { store.placeLinkedImages() }
                Divider()
                Button("Rectangle") { store.addRectangle() }
                Button("Ellipse") { store.addEllipse() }
                Button("Polygon") { store.addPolygon() }
                Button("Text") { store.addText() }
            }

            CommandMenu("Object") {
                Button("Duplicate") { store.duplicateSelection() }
                Button("Delete") { store.deleteSelection() }
                    .keyboardShortcut(.delete, modifiers: [])
                Divider()
                Button("Group") { store.groupSelection() }
                    .keyboardShortcut("g", modifiers: .command)
                Button("Ungroup") { store.ungroupSelection() }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Divider()
                Menu("Arrange") {
                    Button("Bring to Front") { store.changeZOrder(.front) }
                    Button("Bring Forward") { store.changeZOrder(.forward) }
                    Button("Send Backward") { store.changeZOrder(.backward) }
                    Button("Send to Back") { store.changeZOrder(.back) }
                }
                Menu("Align") {
                    Button("Left") { store.alignSelection(.left) }
                    Button("Horizontal Centers") { store.alignSelection(.horizontalCenter) }
                    Button("Right") { store.alignSelection(.right) }
                    Button("Top") { store.alignSelection(.top) }
                    Button("Vertical Centers") { store.alignSelection(.verticalCenter) }
                    Button("Bottom") { store.alignSelection(.bottom) }
                    Divider()
                    Button("Distribute Horizontally") { store.distributeSelection(horizontal: true) }
                    Button("Distribute Vertically") { store.distributeSelection(horizontal: false) }
                }
                Divider()
                Button("Expand Appearance") { store.expandAppearance() }
                Divider()
                Menu("Clipping") {
                    Button("Make Clipping Group") { store.makeClippingGroup() }
                    Button("Release Clipping Group") { store.releaseClippingGroup() }
                }
                Menu("Opacity Mask") {
                    Button("Make Opacity Mask") { store.makeOpacityMask() }
                    Button("Invert Opacity Mask") { store.toggleOpacityMaskInversion() }
                    Button("Release Opacity Mask") { store.releaseOpacityMask() }
                }
                Menu("Embedded Object") {
                    Button("Convert Selection") { store.convertSelectionToEmbeddedObject() }
                    Button("Edit Contents…") { store.openSelectedEmbeddedObject() }
                    Button("Replace Contents from Selection") { store.replaceEmbeddedContentsFromSelection() }
                    Button("Expand Contents") { store.expandSelectedEmbeddedObjects() }
                }
                Menu("Symbols") {
                    Button("Create Symbol from Selection") { store.createSymbolFromSelection() }
                    Button("Replace Definition from Selection") { store.replaceSymbolDefinitionFromSelection() }
                    Button("Detach Symbol Instance") { store.detachSelectedSymbolInstances() }
                }
            }

            CommandMenu("Type") {
                Menu("Font") {
                    ForEach(MacFontCatalog.shared.families) { family in
                        Menu(family.family) {
                            ForEach(family.faces) { face in
                                Button(face.displayName) {
                                    store.setFontFamily(family.family)
                                    store.setFontFace(face.displayName)
                                }
                            }
                        }
                    }
                }

                Menu("Recent Fonts") {
                    if store.recentFontFamilies.isEmpty {
                        Button("No Recent Fonts") { }
                            .disabled(true)
                    } else {
                        ForEach(store.recentFontFamilies, id: \.self) { family in
                            Button(family) { store.setFontFamily(family) }
                        }
                    }
                }

                Menu("Size") {
                    ForEach([8, 9, 10, 11, 12, 14, 18, 24, 36, 48, 72, 96, 144], id: \.self) { size in
                        Button("\(size) pt") {
                            store.updateCharacterStyle { $0.fontSize = Double(size) }
                        }
                    }
                }

                Menu("Leading") {
                    Button("Auto") { store.updateCharacterStyle { $0.leading = 0 } }
                    Divider()
                    ForEach([8, 10, 12, 14, 18, 24, 30, 36, 48, 72], id: \.self) { value in
                        Button("\(value) pt") {
                            store.updateCharacterStyle { $0.leading = Double(value) }
                        }
                    }
                }

                Menu("Tracking") {
                    ForEach([-200, -100, -50, 0, 25, 50, 100, 200, 400], id: \.self) { value in
                        Button("\(value)") {
                            store.updateCharacterStyle { $0.tracking = Double(value) }
                        }
                    }
                }

                Menu("Kerning") {
                    ForEach([-200, -100, -50, 0, 25, 50, 100, 200], id: \.self) { value in
                        Button("\(value)") {
                            store.updateCharacterStyle { $0.kerning = Double(value) }
                        }
                    }
                }

                Divider()

                Button("Create Outlines") { store.createOutlines() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])

                Menu("Spelling") {
                    Button("Check Spelling") { store.checkSpelling() }
                    Divider()
                    Button("Insert Typographic Apostrophe") { store.insertSpecialCharacter("’") }
                    Button("Insert Typographic Quotation Mark") { store.insertSpecialCharacter("“") }
                }

                Menu("Bullets & Numbering") {
                    Button("Bullets") { store.toggleBullets() }
                    Button("Numbering") { store.toggleNumbering() }
                }

                Menu("Text Orientation") {
                    Button("Horizontal") { store.setTextOrientation(vertical: false) }
                    Button("Vertical") { store.setTextOrientation(vertical: true) }
                }

                Menu("Text Alignment") {
                    Button("Left") { store.setParagraphAlignment(.left) }
                    Button("Center") { store.setParagraphAlignment(.center) }
                    Button("Right") { store.setParagraphAlignment(.right) }
                    Button("Justify") { store.setParagraphAlignment(.justify) }
                }

                Button("Convert Point/Area Type") { store.convertPointAreaText() }
                Button("Thread Selected Text Frames") { store.threadSelectedTextFrames() }
                Button("Unthread Text Frame") { store.unthreadSelectedTextFrame() }

                Menu("Warp Text") {
                    ForEach(TextWarpStyleV6.allCases.filter { $0 != .none }, id: \.self) { style in
                        Button(style.rawValue.capitalized) {
                            store.applyTextWarp(style: style, bend: 0.35)
                        }
                    }
                    Divider()
                    Button("Remove Warp") { store.applyTextWarp(style: .none) }
                }

                Menu("Insert Special Character") {
                    Button("Bullet •") { store.insertSpecialCharacter("•") }
                    Button("Em Dash —") { store.insertSpecialCharacter("—") }
                    Button("En Dash –") { store.insertSpecialCharacter("–") }
                    Button("Ellipsis …") { store.insertSpecialCharacter("…") }
                    Button("Copyright ©") { store.insertSpecialCharacter("©") }
                    Button("Registered ®") { store.insertSpecialCharacter("®") }
                    Button("Trademark ™") { store.insertSpecialCharacter("™") }
                }

                Button("Fill with Placeholder Text") { store.fillPlaceholderText() }
            }

            OpenstratorM5Commands(store: store)
        }

        Settings {
            SettingsView()
                .environmentObject(store)
                .frame(width: 790, height: 600)
                .preferredColorScheme(preferredColorScheme)
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }
}

@MainActor
private struct OpenstratorM5Commands: Commands {
    let store: EditorStore

    var body: some Commands {
        CommandMenu("Artboard") {
            Button("Portrait") { store.setArtboardOrientation(.portrait) }
            Button("Landscape") { store.setArtboardOrientation(.landscape) }
        }

        CommandMenu("Raster") {
            Menu("Filters") {
                Button("Gaussian Blur") { store.addRasterFilter(.gaussianBlur) }
                Button("Motion Blur") { store.addRasterFilter(.motionBlur) }
                Button("Exposure") { store.addRasterFilter(.exposure) }
                Button("Brightness / Contrast") { store.addRasterFilter(.brightnessContrast) }
                Button("Saturation") { store.addRasterFilter(.saturation) }
                Button("Hue") { store.addRasterFilter(.hue) }
                Button("Sepia") { store.addRasterFilter(.sepia) }
                Button("Sharpen") { store.addRasterFilter(.sharpen) }
                Button("Noise") { store.addRasterFilter(.noise) }
                Button("Pixelate") { store.addRasterFilter(.pixelate) }
                Button("Crystallize") { store.addRasterFilter(.crystallize) }
                Button("Color Controls") { store.addRasterFilter(.colorControls) }
            }
            Divider()
            Button("Clear Raster Filters") { store.clearRasterFilters() }
        }

        CommandMenu("View") {
            Button("Zoom In") { store.zoom = min(8, store.zoom * 1.15) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Zoom Out") { store.zoom = max(0.10, store.zoom / 1.15) }
                .keyboardShortcut("-", modifiers: .command)
            Button("Actual Size") { store.zoom = 1; store.pan = .zero }
                .keyboardShortcut("0", modifiers: .command)
            Divider()
            Toggle("Show Grid", isOn: Binding(
                get: { store.document.showGrid },
                set: { store.document.showGrid = $0; store.commitMutation() }
            ))
            Toggle("Snap to Grid", isOn: Binding(
                get: { store.document.snapToGrid },
                set: { store.document.snapToGrid = $0; store.commitMutation() }
            ))
            Toggle("Show Guides", isOn: Binding(
                get: { store.document.showGuides },
                set: { store.document.showGuides = $0; store.commitMutation() }
            ))
        }
    }
}

