import SwiftUI
import AppKit
import OpenstratorCore

struct RootEditorView: View {
    @EnvironmentObject var store: EditorStore
    @State private var showInspector = true
    @State private var showLayers = true
    @State private var fontSearch = ""

    var body: some View {
        VStack(spacing: 0) {
            titlebar
            Divider()

            HStack(spacing: 0) {
                toolRail
                Divider()

                EditorCanvasView()
                    .environmentObject(store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showInspector {
                    Divider()
                    inspector
                        .frame(width: 320)
                }
            }

            Divider()
            statusBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var titlebar: some View {
        HStack(spacing: 11) {
            Image("OpenstratorMark")
                .resizable()
                .scaledToFit()
                .frame(width: 27, height: 27)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                Text(store.document.name)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(store.architecture.kind.rawValue)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                toolbarButton("arrow.uturn.backward", help: "Undo") { store.undo() }
                toolbarButton("arrow.uturn.forward", help: "Redo") { store.redo() }

                Divider().frame(height: 18)

                Menu {
                    Button("Align Left") { store.alignSelection(.left) }
                    Button("Align Horizontal Centers") { store.alignSelection(.horizontalCenter) }
                    Button("Align Right") { store.alignSelection(.right) }
                    Divider()
                    Button("Align Top") { store.alignSelection(.top) }
                    Button("Align Vertical Centers") { store.alignSelection(.verticalCenter) }
                    Button("Align Bottom") { store.alignSelection(.bottom) }
                    Divider()
                    Button("Distribute Horizontally") { store.distributeSelection(horizontal: true) }
                    Button("Distribute Vertically") { store.distributeSelection(horizontal: false) }
                } label: {
                    Image(systemName: "align.horizontal.center")
                        .frame(width: 26, height: 24)
                }
                .menuStyle(.borderlessButton)
                .help("Align & Distribute")

                Menu {
                    Button("Bring to Front") { store.changeZOrder(.front) }
                    Button("Bring Forward") { store.changeZOrder(.forward) }
                    Button("Send Backward") { store.changeZOrder(.backward) }
                    Button("Send to Back") { store.changeZOrder(.back) }
                } label: {
                    Image(systemName: "square.3.layers.3d.top.filled")
                        .frame(width: 26, height: 24)
                }
                .menuStyle(.borderlessButton)
                .help("Arrange")

                Divider().frame(height: 18)

                toolbarButton(showLayers ? "square.3.layers.3d" : "square.3.layers.3d.slash", help: "Layers") {
                    showLayers.toggle()
                }
                toolbarButton(showInspector ? "sidebar.right" : "sidebar.trailing", help: "Inspector") {
                    showInspector.toggle()
                }
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 50)
        .background(.ultraThinMaterial)
    }

    private func toolbarButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 26)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var toolRail: some View {
        let primary: [ToolKind] = [.select, .directSelect, .pen, .paintbrush, .text, .rectangle, .star, .eraser, .gradient, .shapeBuilder, .hand, .zoom]
        return VStack(spacing: 5) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 5) {
                    ForEach(primary) { tool in
                        toolButton(tool)
                    }

                    Divider().padding(.vertical, 4)

                    Menu {
                        ForEach(ToolCategory.allCases) { category in
                            Menu(category.rawValue) {
                                ForEach(ToolKind.allCases.filter { $0.category == category }) { tool in
                                    Button {
                                        store.activeTool = tool
                                    } label: {
                                        Label(tool.title, systemImage: tool.symbol)
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 38, height: 36)
                    }
                    .menuStyle(.borderlessButton)
                    .help("All Tools")
                }
            }

            Divider()

            Button { store.zoom = min(8, store.zoom * 1.15) } label: {
                Image(systemName: "plus.magnifyingglass").frame(width: 36, height: 28)
            }
            .buttonStyle(.plain)
            .help("Zoom In")

            Button { store.zoom = max(0.10, store.zoom / 1.15) } label: {
                Image(systemName: "minus.magnifyingglass").frame(width: 36, height: 28)
            }
            .buttonStyle(.plain)
            .help("Zoom Out")
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 7)
        .frame(width: 58)
        .background(.thinMaterial)
    }

    private func toolButton(_ tool: ToolKind) -> some View {
        Button {
            store.activeTool = tool
        } label: {
            Image(systemName: tool.symbol)
                .font(.system(size: 15.5, weight: .medium))
                .frame(width: 38, height: 35)
                .foregroundStyle(store.activeTool == tool ? Color.accentColor : Color.primary.opacity(0.86))
                .background(
                    store.activeTool == tool ? Color.accentColor.opacity(0.14) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .help(tool.title)
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                inspectorHeader

                if store.selection.count > 1 {
                    multiSelectionControls
                } else if let object = store.primarySelectedObject {
                    objectControls(object)
                } else {
                    emptySelection
                }

                if showLayers {
                    Divider()
                    layersPanel
                }

                Divider()
                ResourceLibraryPanel()
                    .environmentObject(store)

                Divider()
                documentPanel
            }
            .padding(14)
        }
        .background(.regularMaterial)
    }

    private var inspectorHeader: some View {
        HStack {
            Text("Inspector")
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            if !store.selection.isEmpty {
                Text("\(store.selection.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptySelection: some View {
        VStack(spacing: 10) {
            Image(systemName: "cursorarrow.rays")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("No Selection").font(.headline)
            Text("Select an object to edit its transform, appearance, blend mode, typography, and effects.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 230)
        }
        .frame(maxWidth: .infinity, minHeight: 190)
    }

    private var multiSelectionControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Multiple Selection", symbol: "square.on.square")

            HStack(spacing: 8) {
                actionChip("Group", symbol: "square.3.layers.3d") { store.groupSelection() }
                actionChip("Ungroup", symbol: "square.2.layers.3d") { store.ungroupSelection() }
            }

            Text("Align")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                compactAction("align.horizontal.left") { store.alignSelection(.left) }
                compactAction("align.horizontal.center") { store.alignSelection(.horizontalCenter) }
                compactAction("align.horizontal.right") { store.alignSelection(.right) }
                compactAction("align.vertical.top") { store.alignSelection(.top) }
                compactAction("align.vertical.center") { store.alignSelection(.verticalCenter) }
                compactAction("align.vertical.bottom") { store.alignSelection(.bottom) }
            }

            HStack(spacing: 8) {
                actionChip("Distribute H", symbol: "distribute.horizontal.center") { store.distributeSelection(horizontal: true) }
                actionChip("Distribute V", symbol: "distribute.vertical.center") { store.distributeSelection(horizontal: false) }
            }
        }
    }

    @ViewBuilder
    private func objectControls(_ object: VectorObject) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            transformSection(object)
            AppearancePanel(object: object)
                .environmentObject(store)
            if object.kind == .image {
                RasterFilterPanel(object: object)
                    .environmentObject(store)
            }
            if object.kind == .text { typographySection(object) }
        }
    }

    private func transformSection(_ object: VectorObject) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Transform", symbol: "move.3d")

            TextField("Layer name", text: objectBinding(object, \.name))
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                numericField("X", objectBinding(object, \.x))
                numericField("Y", objectBinding(object, \.y))
            }
            HStack(spacing: 8) {
                numericField("W", objectBinding(object, \.width), min: 1)
                numericField("H", objectBinding(object, \.height), min: 1)
            }

            sliderRow("Rotation", value: objectBinding(object, \.rotation), range: -180...180, suffix: "°")
            sliderRow("Opacity", value: objectBinding(object, \.opacity), range: 0...1, suffix: "")

            DisclosureGroup("Advanced Transform") {
                VStack(spacing: 8) {
                    sliderRow("Scale X", value: optionalDoubleBinding(object.id, \.scaleX, fallback: 1), range: -2.5...2.5, suffix: "×")
                    sliderRow("Scale Y", value: optionalDoubleBinding(object.id, \.scaleY, fallback: 1), range: -2.5...2.5, suffix: "×")
                    sliderRow("Shear X", value: optionalDoubleBinding(object.id, \.shearX, fallback: 0), range: -1.5...1.5, suffix: "")
                    sliderRow("Shear Y", value: optionalDoubleBinding(object.id, \.shearY, fallback: 0), range: -1.5...1.5, suffix: "")
                }
                .padding(.top, 6)
            }
            .font(.caption)
        }
    }

    @MainActor
    private func typographySection(_ object: VectorObject) -> some View {
        let data = object.resolvedTypography
        let allFamilies = MacFontCatalog.shared.families
        let families = fontSearch.isEmpty ? allFamilies : MacFontCatalog.shared.search(fontSearch)
        let family = MacFontCatalog.shared.family(named: data.character.fontFamily)
        let faces = family?.faces ?? []
        let currentFace = faces.first(where: { $0.postScriptName == data.character.postScriptName })
            ?? faces.first(where: { $0.displayName == data.character.fontFace })
        let axes = currentFace?.variableAxes ?? []

        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Typography", symbol: "textformat")

            TextField("Text", text: objectBinding(object, \.text), axis: .vertical)
                .lineLimit(2...6)

            DisclosureGroup("Font") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Search fonts", text: $fontSearch)
                        .textFieldStyle(.roundedBorder)

                    Picker("Font Family", selection: Binding(
                        get: { object.resolvedTypography.character.fontFamily },
                        set: { store.setFontFamily($0, objectID: object.id) }
                    )) {
                        ForEach(families) { item in
                            Text(item.family).font(.custom(item.family, size: 12)).tag(item.family)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Font Face", selection: Binding(
                        get: { object.resolvedTypography.character.fontFace },
                        set: { store.setFontFace($0, objectID: object.id) }
                    )) {
                        if faces.isEmpty { Text("Regular").tag("Regular") }
                        ForEach(faces) { face in Text(face.displayName).tag(face.displayName) }
                    }
                    .pickerStyle(.menu)

                    if family == nil {
                        Label("Missing font — using system substitution", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2).foregroundStyle(.orange)
                    }

                    HStack(spacing: 8) {
                        numericField("Size", characterBinding(object.id, \.fontSize), min: 1)
                        numericField("Leading", characterBinding(object.id, \.leading), min: 0)
                    }

                    if !axes.isEmpty {
                        Text("Variable Font").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ForEach(axes) { axis in
                            HStack {
                                Text(axis.name).font(.caption2).frame(width: 76, alignment: .leading)
                                Slider(value: variableAxisBinding(object.id, axis: axis), in: axis.minimum...axis.maximum)
                                Text(variableAxisBinding(object.id, axis: axis).wrappedValue, format: .number.precision(.fractionLength(0...1)))
                                    .font(.system(size: 9.5, design: .monospaced)).frame(width: 44)
                            }
                        }
                    }
                }.padding(.top, 6)
            }

            DisclosureGroup("Character") {
                VStack(spacing: 8) {
                    sliderRow("Tracking", value: characterBinding(object.id, \.tracking), range: -100...300, suffix: "")
                    sliderRow("Kerning", value: characterBinding(object.id, \.kerning), range: -100...300, suffix: "")
                    sliderRow("Baseline", value: characterBinding(object.id, \.baselineShift), range: -100...100, suffix: "")
                    sliderRow("Horizontal Scale", value: characterBinding(object.id, \.horizontalScale), range: 0.25...3, suffix: "×")
                    sliderRow("Vertical Scale", value: characterBinding(object.id, \.verticalScale), range: 0.25...3, suffix: "×")
                    sliderRow("Glyph Rotate", value: characterBinding(object.id, \.rotationDegrees), range: -180...180, suffix: "°")
                    HStack {
                        Toggle("Underline", isOn: characterBinding(object.id, \.underline))
                        Toggle("Strikethrough", isOn: characterBinding(object.id, \.strikethrough))
                    }.font(.caption)
                    HStack {
                        Picker("Caps", selection: characterBinding(object.id, \.capitalization)) {
                            Text("Normal").tag(TextCapitalizationV6.normal)
                            Text("All Caps").tag(TextCapitalizationV6.allCaps)
                            Text("Small Caps").tag(TextCapitalizationV6.smallCaps)
                            Text("Title Case").tag(TextCapitalizationV6.titleCase)
                        }
                        Picker("Script", selection: characterBinding(object.id, \.scriptPosition)) {
                            Text("Normal").tag(TextScriptPositionV6.normal)
                            Text("Superscript").tag(TextScriptPositionV6.superscript)
                            Text("Subscript").tag(TextScriptPositionV6.subscript)
                        }
                    }.pickerStyle(.menu)
                    HStack {
                        Toggle("Ligatures", isOn: openTypeBinding(object.id, key: "liga"))
                        Toggle("OpenType Kerning", isOn: openTypeBinding(object.id, key: "kern"))
                    }.font(.caption2)
                }.padding(.top, 6)
            }

            DisclosureGroup("Paragraph") {
                VStack(spacing: 8) {
                    Picker("Alignment", selection: paragraphBinding(object.id, \.alignment)) {
                        Text("Left").tag(TextAlignmentV6.left)
                        Text("Center").tag(TextAlignmentV6.center)
                        Text("Right").tag(TextAlignmentV6.right)
                        Text("Justify").tag(TextAlignmentV6.justify)
                    }.pickerStyle(.segmented)
                    HStack(spacing: 8) {
                        numericField("Left Indent", paragraphBinding(object.id, \.leftIndent), min: 0)
                        numericField("Right Indent", paragraphBinding(object.id, \.rightIndent), min: 0)
                    }
                    HStack(spacing: 8) {
                        numericField("First Line", paragraphBinding(object.id, \.firstLineIndent))
                        numericField("Line Spacing", paragraphBinding(object.id, \.lineSpacing), min: 0)
                    }
                    HStack(spacing: 8) {
                        numericField("Before", paragraphBinding(object.id, \.spacingBefore), min: 0)
                        numericField("After", paragraphBinding(object.id, \.spacingAfter), min: 0)
                    }
                    Toggle("Hyphenation", isOn: paragraphBinding(object.id, \.hyphenation))
                    HStack {
                        Button("Bullets") { store.toggleBullets(id: object.id) }
                        Button("Numbering") { store.toggleNumbering(id: object.id) }
                    }.buttonStyle(.bordered).controlSize(.small)
                }.padding(.top, 6)
            }

            DisclosureGroup("Layout & Warp") {
                VStack(spacing: 8) {
                    Picker("Text Layout", selection: Binding(
                        get: { object.resolvedTypography.layoutMode },
                        set: { store.setTextLayout($0, objectID: object.id) }
                    )) {
                        Text("Point Type").tag(TextLayoutModeV6.point)
                        Text("Area Type").tag(TextLayoutModeV6.area)
                        Text("Type on Path").tag(TextLayoutModeV6.path)
                        Text("Vertical Type").tag(TextLayoutModeV6.verticalPoint)
                        Text("Vertical Area Type").tag(TextLayoutModeV6.verticalArea)
                        Text("Vertical Type on Path").tag(TextLayoutModeV6.verticalPath)
                    }.pickerStyle(.menu)

                    Picker("Warp", selection: Binding(
                        get: { object.resolvedTypography.warp?.style ?? .none },
                        set: { store.applyTextWarp(style: $0, bend: object.resolvedTypography.warp?.bend ?? 0.35) }
                    )) {
                        ForEach(TextWarpStyleV6.allCases, id: \.self) { style in
                            Text(style.rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized).tag(style)
                        }
                    }.pickerStyle(.menu)
                    if let warp = object.resolvedTypography.warp {
                        sliderRow("Warp Bend", value: Binding(
                            get: { warp.bend },
                            set: { store.applyTextWarp(style: warp.style, bend: $0, horizontalDistortion: warp.horizontalDistortion, verticalDistortion: warp.verticalDistortion) }
                        ), range: -1...1, suffix: "")
                    }
                }.padding(.top, 6)
            }

            HStack(spacing: 7) {
                actionChip("Create Outlines", symbol: "point.topleft.down.curvedto.point.bottomright.up") { store.createOutlines() }
                actionChip("Check Spelling", symbol: "text.badge.checkmark") { store.checkSpelling() }
            }
        }
    }

    private var layersPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                sectionTitle("Layers", symbol: "square.3.layers.3d")
                Spacer()
                Button { store.revealSelectionInLayers() } label: { Image(systemName: "scope") }
                    .buttonStyle(.plain)
                    .help("Locate selected artwork")
                Button { store.groupSelection() } label: { Image(systemName: "folder.badge.plus") }
                    .buttonStyle(.plain)
                    .help("Group Selection")
                Button { store.duplicateSelection() } label: { Image(systemName: "plus.square.on.square") }
                    .buttonStyle(.plain)
                    .help("Duplicate")
                Button(role: .destructive) { store.deleteSelection() } label: { Image(systemName: "trash") }
                    .buttonStyle(.plain)
                    .help("Delete")
            }

            if store.layerRows.isEmpty {
                Text("No layers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(store.layerRows) { entry in
                    LayerTreeRowView(entry: entry)
                        .environmentObject(store)
                }
            }
        }
    }

    private var documentPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Document", symbol: "doc")

            HStack(spacing: 7) {
                actionChip("Portrait", symbol: "rectangle.portrait") { store.setArtboardOrientation(.portrait) }
                actionChip("Landscape", symbol: "rectangle") { store.setArtboardOrientation(.landscape) }
            }

            HStack(spacing: 8) {
                numericField("Width", Binding(
                    get: { store.document.artboardWidth },
                    set: { value in
                        store.snapshot(); store.document.artboardWidth = max(64, value); store.commitMutation()
                    }
                ), min: 64)
                numericField("Height", Binding(
                    get: { store.document.artboardHeight },
                    set: { value in
                        store.snapshot(); store.document.artboardHeight = max(64, value); store.commitMutation()
                    }
                ), min: 64)
            }

            ColorPicker("Artboard", selection: Binding(
                get: { store.document.background.swiftUIColor },
                set: { value in
                    store.snapshot(); store.document.background = RGBAColor(value); store.commitMutation()
                }
            ))

            Toggle("Show Grid", isOn: Binding(
                get: { store.document.showGrid },
                set: { store.document.showGrid = $0; store.commitMutation() }
            ))
            Toggle("Snap to Grid", isOn: Binding(
                get: { store.document.snapToGrid },
                set: { store.document.snapToGrid = $0; store.commitMutation() }
            ))
            sliderRow("Grid", value: Binding(
                get: { store.document.gridSpacing },
                set: { store.document.gridSpacing = $0; store.commitMutation() }
            ), range: 4...100, suffix: " px")

            HStack(spacing: 7) {
                actionChip("Vertical Guide", symbol: "rectangle.split.1x2") { store.addGuide(axis: .vertical) }
                actionChip("Horizontal", symbol: "rectangle.split.2x1") { store.addGuide(axis: .horizontal) }
            }
            Button("Clear Guides") { store.clearGuides() }
                .buttonStyle(.borderless)
                .disabled(store.document.guides.isEmpty)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.green.opacity(0.82))
                .frame(width: 6, height: 6)
            Text(store.status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Text(store.activeTool.title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider().frame(height: 14)

            Text("\(Int(store.zoom * 100))%")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .trailing)

            Slider(value: $store.zoom, in: 0.10...4)
                .frame(width: 130)
        }
        .padding(.horizontal, 14)
        .frame(height: 31)
        .background(.bar)
    }

    private func sectionTitle(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func actionChip(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11.5, weight: .medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func compactAction(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: 24, height: 22)
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
    }

    private func numericField(_ label: String, _ value: Binding<Double>, min: Double? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            TextField(label, value: Binding(
                get: { value.wrappedValue },
                set: { newValue in value.wrappedValue = min.map { Swift.max($0, newValue) } ?? newValue }
            ), format: .number.precision(.fractionLength(0...1)))
            .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity)
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .leading)
            Slider(value: value, in: range)
            Text("\(value.wrappedValue, specifier: "%.0f")\(suffix)")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
    }

    private func objectBinding<Value>(_ object: VectorObject, _ keyPath: WritableKeyPath<VectorObject, Value>) -> Binding<Value> {
        let id = object.id
        let fallback = object[keyPath: keyPath]
        return Binding(
            get: {
                store.document.objects.first(where: { $0.id == id })?[keyPath: keyPath] ?? fallback
            },
            set: { newValue in
                store.updateObject(id: id) { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private func optionalDoubleBinding(_ id: UUID, _ keyPath: WritableKeyPath<VectorObject, Double?>, fallback: Double) -> Binding<Double> {
        Binding(
            get: { store.document.objects.first(where: { $0.id == id })?[keyPath: keyPath] ?? fallback },
            set: { value in store.updateObject(id: id) { $0[keyPath: keyPath] = value } }
        )
    }

    private func optionalStringBinding(_ id: UUID, _ keyPath: WritableKeyPath<VectorObject, String?>, fallback: String) -> Binding<String> {
        Binding(
            get: { store.document.objects.first(where: { $0.id == id })?[keyPath: keyPath] ?? fallback },
            set: { value in store.updateObject(id: id) { $0[keyPath: keyPath] = value } }
        )
    }

    private func characterBinding<Value>(_ id: UUID, _ keyPath: WritableKeyPath<CharacterStyleV6, Value>) -> Binding<Value> {
        Binding(
            get: { store.document.objects.first(where: { $0.id == id })?.resolvedTypography.character[keyPath: keyPath] ?? CharacterStyleV6.default[keyPath: keyPath] },
            set: { value in store.updateCharacterStyle(id: id) { $0[keyPath: keyPath] = value } }
        )
    }

    private func paragraphBinding<Value>(_ id: UUID, _ keyPath: WritableKeyPath<ParagraphStyleV6, Value>) -> Binding<Value> {
        Binding(
            get: { store.document.objects.first(where: { $0.id == id })?.resolvedTypography.paragraph[keyPath: keyPath] ?? ParagraphStyleV6.default[keyPath: keyPath] },
            set: { value in store.updateParagraphStyle(id: id) { $0[keyPath: keyPath] = value } }
        )
    }

    private func openTypeBinding(_ id: UUID, key: String) -> Binding<Bool> {
        Binding(
            get: { store.document.objects.first(where: { $0.id == id })?.resolvedTypography.character.openTypeFeatures[key] ?? false },
            set: { value in store.updateCharacterStyle(id: id) { $0.openTypeFeatures[key] = value } }
        )
    }

    private func variableAxisBinding(_ id: UUID, axis: VariableFontAxisRecord) -> Binding<Double> {
        let key = String(axis.id)
        return Binding(
            get: { store.document.objects.first(where: { $0.id == id })?.resolvedTypography.character.variableAxes[key] ?? axis.defaultValue },
            set: { value in store.updateCharacterStyle(id: id) { $0.variableAxes[key] = value } }
        )
    }

    private func symbol(for kind: VectorKind) -> String {
        switch kind {
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .polygon: return "hexagon"
        case .line: return "line.diagonal"
        case .text: return "textformat"
        case .path: return "scribble"
        case .image: return "photo"
        }
    }

    private func defaultAmount(_ kind: EffectKind) -> Double { kind.defaultAmount }

    private func effectRange(_ kind: EffectKind) -> ClosedRange<Double> { kind.amountRange }

}

private struct RasterFilterSheetID: Identifiable {
    let id: UUID
}

private struct RasterFilterPanel: View {
    @EnvironmentObject private var store: EditorStore
    let object: VectorObject
    @State private var editingFilter: RasterFilterSheetID?

    private var filters: [RasterFilterRecordV6] { object.rasterFilters ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Raster Filters", systemImage: "camera.filters")
                    .font(.caption.weight(.semibold))
                Spacer()
                Menu {
                    ForEach(RasterFilterIDV6.allCases, id: \.rawValue) { filterID in
                        Button(filterID.displayName) { store.addRasterFilter(filterID) }
                    }
                } label: { Image(systemName: "plus.circle") }
                .menuStyle(.borderlessButton)
            }

            if filters.isEmpty {
                Text("No raster filters")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filters, id: \.uuid) { filter in
                    HStack(spacing: 7) {
                        Toggle("", isOn: Binding(
                            get: { store.rasterFilter(objectID: object.id, filterUUID: filter.uuid)?.enabled ?? false },
                            set: { _ in store.toggleRasterFilter(objectID: object.id, filterUUID: filter.uuid) }
                        ))
                        .labelsHidden()
                        Button(filter.id.displayName) { editingFilter = RasterFilterSheetID(id: filter.uuid) }
                            .buttonStyle(.plain)
                        Spacer()
                        Button { store.removeRasterFilter(objectID: object.id, filterUUID: filter.uuid) } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.caption)
                }
                Button("Clear Raster Filters") { store.clearRasterFilters() }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
        }
        .sheet(item: $editingFilter) { item in
            RasterFilterEditorSheet(objectID: object.id, filterUUID: item.id)
                .environmentObject(store)
        }
    }
}

private struct RasterFilterEditorSheet: View {
    @EnvironmentObject private var store: EditorStore
    @Environment(\.dismiss) private var dismiss
    let objectID: UUID
    let filterUUID: UUID

    private var filter: RasterFilterRecordV6? { store.rasterFilter(objectID: objectID, filterUUID: filterUUID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(filter?.id.displayName ?? "Raster Filter").font(.title3.weight(.semibold))
            if let filter {
                ForEach(filter.parameterKeys, id: \.self) { key in
                    HStack {
                        Text(key.displayName).frame(width: 110, alignment: .leading)
                        Slider(value: parameterBinding(key), in: filter.id.range(for: key))
                        Text(parameterBinding(key).wrappedValue, format: .number.precision(.fractionLength(0...2)))
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 58, alignment: .trailing)
                    }
                }
            }
            Spacer()
            HStack {
                Button("Reset") { store.resetRasterFilterPreview(objectID: objectID) }
                Spacer()
                Button("Cancel") { store.cancelRasterFilterPreview(objectID: objectID); dismiss() }
                Button("Apply") { store.commitRasterFilterPreview(objectID: objectID); dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 430)
        .frame(minHeight: 240)
        .onAppear { store.beginRasterFilterPreview(objectID: objectID) }
        .onDisappear { store.cancelRasterFilterPreview(objectID: objectID) }
    }

    private func parameterBinding(_ key: String) -> Binding<Double> {
        Binding(
            get: { store.rasterFilter(objectID: objectID, filterUUID: filterUUID)?.parameters[key] ?? 0 },
            set: { store.updateRasterFilterPreview(objectID: objectID, filterUUID: filterUUID, parameter: key, value: $0) }
        )
    }
}

private extension RasterFilterIDV6 {
    var displayName: String {
        switch self {
        case .gaussianBlur: return "Gaussian Blur"
        case .motionBlur: return "Motion Blur"
        case .exposure: return "Exposure"
        case .brightnessContrast: return "Brightness / Contrast"
        case .saturation: return "Saturation"
        case .hue: return "Hue"
        case .sepia: return "Sepia"
        case .sharpen: return "Sharpen"
        case .noise: return "Noise"
        case .pixelate: return "Pixelate"
        case .crystallize: return "Crystallize"
        case .colorControls: return "Color Controls"
        }
    }

    func range(for key: String) -> ClosedRange<Double> {
        switch key {
        case "radius": return self == .gaussianBlur ? 0...200 : 1...250
        case "distance": return 0...500
        case "angle": return -360...360
        case "ev": return -10...10
        case "brightness": return -1...1
        case "contrast": return 0...4
        case "saturation": return 0...2
        case "intensity": return 0...1
        case "sharpness": return 0...2
        case "amount": return 0...1
        case "scale": return 1...250
        default: return 0...1
        }
    }
}

private extension RasterFilterRecordV6 {
    var parameterKeys: [String] { parameters.keys.sorted() }
}

private extension String {
    var displayName: String {
        replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
    }
}
