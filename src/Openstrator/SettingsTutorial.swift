import SwiftUI

struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image("OpenstratorMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 108, height: 108)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
                    .scaleEffect(appeared ? 1 : 0.92)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: 5) {
                    Text("Openstrator")
                        .font(.system(size: 31, weight: .semibold, design: .rounded))
                    Text("Vector design, made for macOS.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .offset(y: appeared ? 0 : 7)
                .opacity(appeared ? 1 : 0)

                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 7)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.56, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }
}

struct TutorialView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var store: EditorStore
    @State private var page = 0

    private let steps: [(title: String, body: String, symbol: String)] = [
        (
            "Welcome to Openstrator",
            "A native macOS vector workspace with an original interface and familiar professional editing concepts.",
            "sparkles.rectangle.stack"
        ),
        (
            "Draw directly on the artboard",
            "The compact rail holds everyday tools. Open ••• All Tools for the complete selection, drawing, type, transform, symbol, graph, perspective, artboard, slice, measurement, and navigation toolkit.",
            "pencil.and.outline"
        ),
        (
            "Style without flattening",
            "Use fills, gradients, strokes, blend modes, opacity, typography, and a reorderable non-destructive effect stack with vector, raster-style, warp, 3D, artistic, texture, and Pathfinder equivalents.",
            "slider.horizontal.3"
        ),
        (
            "Organize precisely",
            "Shift-select multiple objects, group them, align or distribute them, reorder layers, and use grid snapping and guides.",
            "square.3.layers.3d"
        ),
        (
            "Shortcuts that explain themselves",
            "In Settings → Shortcuts, change any key combination. Hover the info button to watch a small preview of that action.",
            "command"
        ),
        (
            "Built for your Mac",
            "This build uses a native SwiftUI renderer and architecture-specific release settings for \(ArchitectureProfile.current.kind.rawValue).",
            "memorychip"
        )
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.24).ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.10))
                        .frame(width: 112, height: 112)
                    Image(systemName: steps[page].symbol)
                        .font(.system(size: 50, weight: .regular))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                }

                VStack(spacing: 9) {
                    Text(steps[page].title)
                        .font(.system(size: 26, weight: .semibold))
                    Text(steps[page].body)
                        .font(.system(size: 14.5))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 470)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 7) {
                    ForEach(steps.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Color.accentColor : Color.secondary.opacity(0.20))
                            .frame(width: index == page ? 25 : 7, height: 7)
                    }
                }

                HStack {
                    Button("Skip") { isPresented = false }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if page > 0 {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.22)) { page -= 1 }
                        }
                    }

                    Button(page == steps.count - 1 ? "Start Designing" : "Continue") {
                        if page == steps.count - 1 {
                            isPresented = false
                        } else {
                            withAnimation(.easeInOut(duration: 0.22)) { page += 1 }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(36)
            .frame(width: 620)
            .frame(minHeight: 500)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 27, style: .continuous).stroke(.white.opacity(0.14)))
            .shadow(color: .black.opacity(0.22), radius: 42, y: 20)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: EditorStore
    @AppStorage("appearanceMode") private var appearanceMode = "System"
    @AppStorage("autosaveEnabled") private var autosave = true
    @AppStorage("memoryBudgetMB") private var memoryBudget = Double(ArchitectureProfile.current.targetWorkingSetMB)

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            shortcutsTab
                .tabItem { Label("Shortcuts", systemImage: "command") }

            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(10)
    }

    private var generalTab: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: $appearanceMode) {
                    Text("System").tag("System")
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                }
                .pickerStyle(.segmented)
            }

            Section("Documents") {
                Toggle("Autosave recovery snapshot", isOn: $autosave)
                if store.hasRecoverySnapshot {
                    Button("Restore Latest Recovery Snapshot") { store.restoreRecoverySnapshot() }
                }
            }

            Section("Performance") {
                LabeledContent("Build") {
                    Text(store.architecture.kind.rawValue)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Undo history") {
                    Text("\(store.architecture.undoLimit) snapshots")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Working memory target") {
                    HStack {
                        Slider(value: $memoryBudget, in: 1200...2800, step: 100)
                            .frame(width: 220)
                        Text("\(Int(memoryBudget)) MB")
                            .monospacedDigit()
                            .frame(width: 70, alignment: .trailing)
                    }
                }
                Text("The memory setting is a cache/recovery budget, not a hard macOS process limit. Openstrator avoids a browser runtime and stores ordinary artwork as compact vector data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(6)
    }

    private var shortcutsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Keyboard Shortcuts")
                            .font(.title2.bold())
                        Text("Edit keys and modifiers live. Hover the info button to preview the action.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Restore Defaults") { store.resetKeybinds() }
                }

                ForEach($store.keybinds) { $binding in
                    ShortcutRow(binding: $binding)
                    Divider()
                }
            }
            .padding(18)
        }
    }

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 18) {
                Image("OpenstratorMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 14, y: 7)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Openstrator")
                        .font(.system(size: 28, weight: .bold))
                    Text("Native vector editor for macOS")
                        .foregroundStyle(.secondary)
                    Text("Version 0.5 Pro Toolkit")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Divider()

            Text("Openstrator uses original code, branding, iconography, and interface design. It implements general vector-editing concepts without shipping third-party logos, artwork, proprietary fonts, or copied interface assets.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GroupBox("Current build") {
                VStack(alignment: .leading, spacing: 8) {
                    Label(store.architecture.kind.rawValue, systemImage: "cpu")
                    Label("macOS 13+", systemImage: "macwindow")
                    Label("SwiftUI + Core Graphics rendering", systemImage: "swift")
                    Label("SVG, PNG and PDF export", systemImage: "square.and.arrow.up")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            Spacer()
        }
        .padding(28)
    }
}

private struct ShortcutRow: View {
    @Binding var binding: KeybindDefinition
    @State private var showingHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(binding.title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(binding.display)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 155, alignment: .leading)

                modifierToggle("⌘", value: "command")
                modifierToggle("⇧", value: "shift")
                modifierToggle("⌥", value: "option")
                modifierToggle("⌃", value: "control")

                TextField("Key", text: $binding.key)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 55)
                    .onChange(of: binding.key) { newValue in
                        let cleaned = String(newValue.lowercased().filter { !$0.isWhitespace }.prefix(1))
                        if cleaned != binding.key { binding.key = cleaned }
                    }

                Spacer()

                Image(systemName: "info.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(showingHelp ? Color.accentColor : Color.secondary)
                    .padding(5)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        showingHelp = hovering
                    }
                    .popover(isPresented: $showingHelp, arrowEdge: .trailing) {
                        ShortcutHelpPreview(binding: binding)
                            .padding(16)
                            .frame(width: 285, height: 215)
                    }
            }

            Text(binding.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 3)
    }

    private func modifierToggle(_ glyph: String, value: String) -> some View {
        let active = binding.modifiers.contains(value)
        return Button {
            if active {
                binding.modifiers.removeAll { $0 == value }
            } else {
                binding.modifiers.append(value)
            }
        } label: {
            Text(glyph)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 25)
                .background(active ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

private struct ShortcutHelpPreview: View {
    let binding: KeybindDefinition
    @State private var animate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(binding.title).font(.headline)
                Spacer()
                Text(binding.display)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.primary.opacity(0.045))

                preview
                    .padding(18)
            }
            .frame(height: 112)

            Text(binding.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch binding.preview {
        case .select:
            ZStack {
                RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 2).frame(width: 86, height: 52)
                    .offset(x: animate ? 22 : -12)
                Image(systemName: "arrow.up.left").font(.title2).offset(x: animate ? -34 : -50, y: 25)
            }

        case .text:
            Text("Aa")
                .font(.system(size: animate ? 44 : 30, weight: .semibold, design: .rounded))
                .foregroundStyle(.tint)

        case .rectangle:
            RoundedRectangle(cornerRadius: animate ? 18 : 4)
                .fill(Color.accentColor.opacity(0.74))
                .frame(width: animate ? 120 : 72, height: animate ? 64 : 46)

        case .ellipse:
            Ellipse()
                .fill(Color.accentColor.opacity(0.72))
                .frame(width: animate ? 104 : 68, height: animate ? 68 : 50)

        case .polygon:
            Image(systemName: "hexagon.fill")
                .font(.system(size: animate ? 76 : 54))
                .foregroundStyle(.tint)

        case .duplicate:
            ZStack {
                RoundedRectangle(cornerRadius: 9).fill(Color.accentColor.opacity(0.55)).frame(width: 76, height: 56).offset(x: -18, y: -10)
                RoundedRectangle(cornerRadius: 9).fill(Color.accentColor.opacity(0.82)).frame(width: 76, height: 56).offset(x: animate ? 28 : 6, y: animate ? 16 : 2)
            }

        case .zoom:
            Image(systemName: "magnifyingglass")
                .font(.system(size: animate ? 68 : 42, weight: .light))
                .foregroundStyle(.tint)

        case .pen:
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 12, y: 72))
                    path.addCurve(to: CGPoint(x: 180, y: 28), control1: CGPoint(x: 68, y: animate ? 6 : 46), control2: CGPoint(x: 118, y: animate ? 88 : 40))
                }
                .stroke(Color.accentColor, lineWidth: 3)
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .foregroundStyle(.secondary)
            }

        case .align:
            HStack(alignment: .center, spacing: 10) {
                Rectangle().fill(Color.accentColor.opacity(0.5)).frame(width: 35, height: 40)
                Rectangle().fill(Color.accentColor.opacity(0.7)).frame(width: 35, height: animate ? 72 : 48)
                Rectangle().fill(Color.accentColor.opacity(0.9)).frame(width: 35, height: 56)
            }
            .offset(y: animate ? 0 : 8)

        case .export:
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 55))
                .foregroundStyle(.tint)
                .offset(y: animate ? -5 : 7)
        }
    }
}
