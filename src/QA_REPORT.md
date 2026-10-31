# Openstrator V6 M6 QA report

## Milestone

M6 implements the roadmap's Layer/Object Workflows milestone on top of the M5.1 raster/native-compiler-repair baseline.

## Portable verification completed

- `swift test --filter OpenstratorCoreTests`: **126 tests, 0 failures**.
- Framework-free `OpenstratorCoreSelfTest`: **87 checks passed** through `OpenstratorCoreSelfTest M6 final`.
- Historical M1 gate completed before the long aggregate runner reached M2; M2, M3 and M4 acceptance gates were then rerun independently to completion and passed.
- M5 full core/self-test stages passed; the aggregate wrapper hit the execution-time ceiling during its contract section, so every remaining M5 image/raster/filter/compiler/delete/parser/icon/manifest gate was run individually and passed.
- M6 model compatibility, layer UI bridge, clipping/mask, Embedded Object, linked asset, Symbol, resource/thumbnail, macOS compiler-risk and release contracts all pass.
- M4 selected-object delete lifecycle regression remains green.
- M5.1 native compiler regression remains green.
- All portable Swift source files pass `swiftc -frontend -parse`.
- Icon alpha and `Package.swift` manifest checks pass.

## M6 behavior covered

- `LayerTreeV6` provides cycle-safe hierarchical nesting, reorder/reparent, subtree deletion, object-order projection and validation.
- Existing M5.1 documents remain compatible because app-level hierarchy/resource fields are optional and bootstrapped only when needed.
- Layers UI supports nested expand/collapse, reorder/reparent, visibility, lock, rename, selection targeting, locate-selection and accents while retaining the legacy flat object renderer as a compatibility bridge.
- Clipping groups route content through a clipping path; opacity masks support normal/inverted compositing and release without losing the mask artwork.
- Embedded Objects preserve encoded editable child artwork and original bounds, render through a transformable proxy, support separate content editing, replace/expand, and guard recursive nesting.
- Linked images retain an embedded raster fallback, prefer the live source when available, expose linked/modified/missing state, and support Refresh, Relink and Embed.
- Symbols share one definition payload across instances; replacing a definition updates instances and Detach restores editable artwork. Symbol Sprayer can use M6 definitions.
- Graphic Styles persist full Appearance stacks. Resource libraries can import/export Embedded Objects, Links, Symbols and Graphic Styles as JSON.
- Layer thumbnails use a bounded `NSCache` and asynchronous generation after a UI yield; mutation/undo/redo invalidates stale thumbnails.
- Duplicate/copy/paste remap hierarchy relationships while sharing resource payloads by UUID rather than multiplying embedded data.

## Native macOS compiler-risk hardening

M6 adds `scripts/m6_mac_compiler_regression.py`, covering issues portable parsing cannot prove: explicit `OpenstratorCore` and AppKit imports, cross-file view visibility, main-actor isolation for thumbnail/resource views, explicit AppKit/CoreGraphics numeric bridges, and conditional style typing.

## Native macOS gate still required

This workspace is Linux and cannot semantically type-check/link/launch AppKit and SwiftUI as a macOS application. The authoritative final gate remains running `BUILD_OPENSTRATOR.command` on the matching Mac architecture. After a successful build, smoke-test launch, Layers nesting/reorder/visibility/lock, clipping groups, opacity masks, Embedded Object edit/expand, linked-asset refresh/relink/embed, Symbols, Graphic Styles/resources, thumbnails, save/reopen, Undo/Redo and Delete/Backspace.
