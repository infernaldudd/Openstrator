import SwiftUI
import OpenstratorCore

struct AppearancePanel: View {
    @EnvironmentObject private var store: EditorStore
    let object: VectorObject
    @State private var editingEffectID: UUID?

    private var stack: AppearanceStackV6 { store.appearanceStack(objectID: object.id) ?? object.resolvedAppearanceStack }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Appearance", systemImage: "paintbrush.pointed")
                    .font(.caption.weight(.semibold))
                Spacer()
                Menu {
                    Button("Add Fill") { store.addAppearanceFill(objectID: object.id) }
                    Button("Add Stroke") { store.addAppearanceStroke(objectID: object.id) }
                    Divider()
                    ForEach(EffectRegistryV6.descriptors) { descriptor in
                        Button(descriptor.displayName) { store.addLiveEffect(descriptor.effectID, objectID: object.id) }
                    }
                    Divider()
                    Menu("All Effects") {
                        ForEach(EffectCategory.allCases) { category in
                            Menu(category.rawValue) {
                                ForEach(EffectKind.allCases.filter { $0.category == category }) { kind in
                                    Button(kind.title) { store.addEffect(kind) }
                                }
                            }
                        }
                    }
                } label: { Image(systemName: "plus.circle.fill") }
                .menuStyle(.borderlessButton)
            }

            HStack(spacing: 8) {
                Text("Opacity").font(.caption2).foregroundStyle(.secondary)
                Slider(value: stackRootNumberBinding(\.opacity), in: 0...1)
                Text(stack.opacity, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 9.5, design: .monospaced)).frame(width: 38)
            }

            Picker("Blend", selection: stackBlendBinding) {
                ForEach([BlendModeV6.normal,.multiply,.screen,.overlay,.darken,.lighten,.softLight,.hardLight,.difference,.exclusion], id: \.rawValue) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            .pickerStyle(.menu)

            if stack.entries.isEmpty {
                Text("Add fills, strokes, and live effects. Entries render in stack order and remain editable.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            ForEach(stack.entries, id: \.id) { entry in
                entryRow(entryID: entry.id)
            }

            Button("Expand Appearance") { store.expandAppearance() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .sheet(item: Binding(
            get: { editingEffectID.map(EffectSheetID.init) },
            set: { editingEffectID = $0?.id }
        )) { value in
            EffectEditorSheet(objectID: object.id, entryID: value.id)
                .environmentObject(store)
        }
    }

    @ViewBuilder
    private func entryRow(entryID: UUID) -> some View {
        if let entry = stack.entries.first(where: { $0.id == entryID }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Button { store.toggleAppearanceEntry(objectID: object.id, entryID: entryID) } label: {
                        Image(systemName: entry.enabled ? "eye" : "eye.slash")
                    }.buttonStyle(.plain)

                    Image(systemName: icon(for: entry)).foregroundStyle(.secondary)
                    Text(title(for: entry)).font(.caption).lineLimit(1)
                    Spacer()
                    Button { store.moveAppearanceEntry(objectID: object.id, entryID: entryID, offset: -1) } label: { Image(systemName: "chevron.up") }.buttonStyle(.plain)
                    Button { store.moveAppearanceEntry(objectID: object.id, entryID: entryID, offset: 1) } label: { Image(systemName: "chevron.down") }.buttonStyle(.plain)
                    Button { store.duplicateAppearanceEntry(objectID: object.id, entryID: entryID) } label: { Image(systemName: "plus.square.on.square") }.buttonStyle(.plain)
                    Button(role: .destructive) { store.removeAppearanceEntry(objectID: object.id, entryID: entryID) } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain)
                }

                switch entry {
                case .fill(let fill): fillControls(entryID: entryID, fill: fill)
                case .stroke(let stroke): strokeControls(entryID: entryID, stroke: stroke)
                case .effect:
                    Button("Edit Effect…") { editingEffectID = entryID }
                        .buttonStyle(.borderless).font(.caption2)
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func fillControls(entryID: UUID, fill: FillAppearanceV6) -> some View {
        VStack(spacing: 6) {
            paintControls(entryID: entryID, isStroke: false, paint: fill.paint)
            HStack {
                Text("Opacity").font(.caption2).foregroundStyle(.secondary)
                Slider(value: entryOpacityBinding(entryID: entryID), in: 0...1)
            }
        }
    }

    private func strokeControls(entryID: UUID, stroke: StrokeAppearanceV6) -> some View {
        VStack(spacing: 6) {
            paintControls(entryID: entryID, isStroke: true, paint: stroke.paint)
            HStack {
                Text("Width").font(.caption2).foregroundStyle(.secondary)
                Slider(value: strokeWidthBinding(entryID: entryID), in: 0...80)
                Text(stroke.width, format: .number.precision(.fractionLength(0...1))).font(.caption2.monospacedDigit()).frame(width: 34)
            }
        }
    }

    @ViewBuilder
    private func paintControls(entryID: UUID, isStroke: Bool, paint: AppearancePaintV6) -> some View {
        switch paint {
        case .color:
            HStack {
                ColorPicker(isStroke ? "Stroke Color" : "Fill Color", selection: paintColorBinding(entryID: entryID))
                Button("Gradient") { setGradient(entryID: entryID) }.buttonStyle(.borderless).font(.caption2)
            }
        case .linearGradient(let gradient):
            VStack(spacing: 5) {
                HStack {
                    Text("Linear Gradient").font(.caption2)
                    Spacer()
                    Button("Solid") { setSolid(entryID: entryID) }.buttonStyle(.borderless).font(.caption2)
                }
                if gradient.stops.count >= 2 {
                    HStack {
                        ColorPicker("Start", selection: gradientColorBinding(entryID: entryID, stop: 0))
                        ColorPicker("End", selection: gradientColorBinding(entryID: entryID, stop: gradient.stops.count - 1))
                    }
                }
                HStack {
                    Text("Angle").font(.caption2).foregroundStyle(.secondary)
                    Slider(value: gradientAngleBinding(entryID: entryID), in: 0...360)
                }
            }
        }
    }

    private var stackBlendBinding: Binding<BlendModeV6> {
        Binding(get: { stack.blendMode }, set: { value in
            store.updateAppearanceStack(objectID: object.id) { $0.blendMode = value }
        })
    }
    private func stackRootNumberBinding(_ keyPath: WritableKeyPath<AppearanceStackV6, Double>) -> Binding<Double> {
        Binding(get: { stack[keyPath: keyPath] }, set: { value in store.updateAppearanceStack(objectID: object.id) { $0[keyPath: keyPath] = value } })
    }
    private func entryOpacityBinding(entryID: UUID) -> Binding<Double> {
        Binding(get: {
            guard let entry = stack.entries.first(where: { $0.id == entryID }) else { return 1 }
            switch entry { case .fill(let v): return v.opacity; case .stroke(let v): return v.opacity; case .effect: return 1 }
        }, set: { value in
            store.updateAppearanceStack(objectID: object.id) { stack in
                guard let i = stack.entries.firstIndex(where: { $0.id == entryID }) else { return }
                switch stack.entries[i] {
                case .fill(var v): v.opacity = value; stack.entries[i] = .fill(v)
                case .stroke(var v): v.opacity = value; stack.entries[i] = .stroke(v)
                case .effect: break
                }
            }
        })
    }
    private func strokeWidthBinding(entryID: UUID) -> Binding<Double> {
        Binding(get: {
            guard let entry = stack.entries.first(where: { $0.id == entryID }), case .stroke(let value) = entry else { return 0 }
            return value.width
        }, set: { value in
            store.updateAppearanceStack(objectID: object.id) { stack in
                guard let i = stack.entries.firstIndex(where: { $0.id == entryID }), case .stroke(var stroke) = stack.entries[i] else { return }
                stroke.width = value; stack.entries[i] = .stroke(stroke)
            }
        })
    }
    private func paintColorBinding(entryID: UUID) -> Binding<Color> {
        Binding(get: {
            guard let entry = stack.entries.first(where: { $0.id == entryID }) else { return .clear }
            let paint: AppearancePaintV6
            switch entry { case .fill(let v): paint = v.paint; case .stroke(let v): paint = v.paint; case .effect: return .clear }
            if case .color(let c) = paint { return Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a) }
            return .clear
        }, set: { value in
            let c = RGBAColor(value); let core = RGBAColorV6(r: c.r, g: c.g, b: c.b, a: c.a)
            store.updateAppearanceStack(objectID: object.id) { stack in
                guard let i = stack.entries.firstIndex(where: { $0.id == entryID }) else { return }
                switch stack.entries[i] {
                case .fill(var v): v.paint = .color(core); stack.entries[i] = .fill(v)
                case .stroke(var v): v.paint = .color(core); stack.entries[i] = .stroke(v)
                case .effect: break
                }
            }
        })
    }
    private func gradientColorBinding(entryID: UUID, stop: Int) -> Binding<Color> {
        Binding(get: {
            guard let entry = stack.entries.first(where: { $0.id == entryID }) else { return .clear }
            let paint: AppearancePaintV6
            switch entry { case .fill(let v): paint = v.paint; case .stroke(let v): paint = v.paint; case .effect: return .clear }
            guard case .linearGradient(let g) = paint, g.stops.indices.contains(stop) else { return .clear }
            let c = g.stops[stop].color; return Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
        }, set: { color in
            let c = RGBAColor(color); let core = RGBAColorV6(r: c.r, g: c.g, b: c.b, a: c.a)
            mutateGradient(entryID: entryID) { g in if g.stops.indices.contains(stop) { g.stops[stop].color = core } }
        })
    }
    private func gradientAngleBinding(entryID: UUID) -> Binding<Double> {
        Binding(get: {
            guard let entry = stack.entries.first(where: { $0.id == entryID }) else { return 0 }
            switch entry { case .fill(let v): if case .linearGradient(let g) = v.paint { return g.angleDegrees }; case .stroke(let v): if case .linearGradient(let g) = v.paint { return g.angleDegrees }; case .effect: break }
            return 0
        }, set: { value in mutateGradient(entryID: entryID) { $0.angleDegrees = value } })
    }
    private func mutateGradient(entryID: UUID, _ mutation: @escaping (inout LinearGradientV6) -> Void) {
        store.updateAppearanceStack(objectID: object.id) { stack in
            guard let i = stack.entries.firstIndex(where: { $0.id == entryID }) else { return }
            switch stack.entries[i] {
            case .fill(var v): if case .linearGradient(var g) = v.paint { mutation(&g); v.paint = .linearGradient(g); stack.entries[i] = .fill(v) }
            case .stroke(var v): if case .linearGradient(var g) = v.paint { mutation(&g); v.paint = .linearGradient(g); stack.entries[i] = .stroke(v) }
            case .effect: break
            }
        }
    }
    private func setGradient(entryID: UUID) {
        let gradient = LinearGradientV6(angleDegrees: 0, stops: [.init(location: 0, color: .white), .init(location: 1, color: .black)])
        store.updateAppearanceStack(objectID: object.id) { stack in
            guard let i = stack.entries.firstIndex(where: { $0.id == entryID }) else { return }
            switch stack.entries[i] { case .fill(var v): v.paint = .linearGradient(gradient); stack.entries[i] = .fill(v); case .stroke(var v): v.paint = .linearGradient(gradient); stack.entries[i] = .stroke(v); case .effect: break }
        }
    }
    private func setSolid(entryID: UUID) {
        store.updateAppearanceStack(objectID: object.id) { stack in
            guard let i = stack.entries.firstIndex(where: { $0.id == entryID }) else { return }
            switch stack.entries[i] { case .fill(var v): v.paint = .color(.black); stack.entries[i] = .fill(v); case .stroke(var v): v.paint = .color(.black); stack.entries[i] = .stroke(v); case .effect: break }
        }
    }
    private func title(for entry: AppearanceEntryV6) -> String {
        switch entry { case .fill: return "Fill"; case .stroke: return "Stroke"; case .effect(let v): return EffectRegistryV6.descriptor(id: v.effectID)?.displayName ?? v.effectID }
    }
    private func icon(for entry: AppearanceEntryV6) -> String { switch entry { case .fill: return "paintbrush.fill"; case .stroke: return "pencil.line"; case .effect: return "wand.and.stars" } }
}

private struct EffectSheetID: Identifiable { let id: UUID }

private struct EffectEditorSheet: View {
    @EnvironmentObject private var store: EditorStore
    @Environment(\.dismiss) private var dismiss
    let objectID: UUID
    let entryID: UUID

    private var effect: LiveEffectV6? {
        guard let stack = store.appearanceStack(objectID: objectID), let entry = stack.entries.first(where: { $0.id == entryID }), case .effect(let effect) = entry else { return nil }
        return effect
    }
    private var descriptor: EffectDescriptorV6? { effect.flatMap { EffectRegistryV6.descriptor(id: $0.effectID) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(descriptor?.displayName ?? "Live Effect").font(.title3.weight(.semibold))
            if let descriptor {
                ForEach(descriptor.parameters.keys.sorted(), id: \.self) { key in
                    parameterRow(key: key, descriptor: descriptor.parameters[key]!)
                }
            }
            Spacer()
            HStack {
                Button("Reset") { store.resetAppearancePreview(objectID: objectID) }
                Spacer()
                Button("Cancel") { store.cancelAppearancePreview(objectID: objectID); dismiss() }
                Button("Apply") { store.commitAppearancePreview(objectID: objectID); dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 420).frame(minHeight: 260)
        .onAppear { store.beginAppearancePreview(objectID: objectID) }
        .onDisappear { store.cancelAppearancePreview(objectID: objectID) }
    }

    @ViewBuilder
    private func parameterRow(key: String, descriptor: EffectParameterDescriptorV6) -> some View {
        switch descriptor.kind {
        case .number:
            HStack { Text(descriptor.label).frame(width: 135, alignment: .leading); Slider(value: numberBinding(key: key, fallback: descriptor.defaultValue.numberValue ?? 0), in: (descriptor.minimum ?? -100)...(descriptor.maximum ?? 100)); Text(numberBinding(key: key, fallback: 0).wrappedValue, format: .number.precision(.fractionLength(0...2))).frame(width: 55) }
        case .integer:
            Stepper(descriptor.label + ": \(integerValue(key: key))", value: integerBinding(key: key), in: Int(descriptor.minimum ?? 0)...Int(descriptor.maximum ?? 100))
        case .boolean:
            Toggle(descriptor.label, isOn: boolBinding(key: key))
        case .choice:
            Picker(descriptor.label, selection: choiceBinding(key: key, fallback: descriptor.defaultValue.choiceValue ?? "")) { ForEach(descriptor.choices, id: \.self) { Text($0.capitalized).tag($0) } }.pickerStyle(.menu)
        case .color:
            ColorPicker(descriptor.label, selection: colorBinding(key: key))
        case .point:
            Text(descriptor.label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func mutateEffect(_ mutation: @escaping (inout LiveEffectV6) -> Void) {
        store.updateAppearancePreview(objectID: objectID) { stack in
            guard let i = stack.entries.firstIndex(where: { $0.id == entryID }), case .effect(var effect) = stack.entries[i] else { return }
            mutation(&effect)
            if let validated = try? EffectRegistryV6.validate(effect) { effect = validated }
            stack.entries[i] = .effect(effect)
        }
    }
    private func numberBinding(key: String, fallback: Double) -> Binding<Double> { Binding(get: { effect?.parameters[key]?.numberValue ?? fallback }, set: { v in mutateEffect { $0.parameters[key] = .number(v) } }) }
    private func integerValue(key: String) -> Int { effect?.parameters[key]?.integerValue ?? 0 }
    private func integerBinding(key: String) -> Binding<Int> { Binding(get: { integerValue(key: key) }, set: { v in mutateEffect { $0.parameters[key] = .integer(v) } }) }
    private func boolBinding(key: String) -> Binding<Bool> { Binding(get: { effect?.parameters[key]?.boolValue ?? false }, set: { v in mutateEffect { $0.parameters[key] = .boolean(v) } }) }
    private func choiceBinding(key: String, fallback: String) -> Binding<String> { Binding(get: { effect?.parameters[key]?.choiceValue ?? fallback }, set: { v in mutateEffect { $0.parameters[key] = .choice(v) } }) }
    private func colorBinding(key: String) -> Binding<Color> { Binding(get: { let c = effect?.parameters[key]?.colorValue ?? .black; return Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a) }, set: { value in let c = RGBAColor(value); mutateEffect { $0.parameters[key] = .color(.init(r: c.r,g: c.g,b: c.b,a: c.a)) } }) }
}
