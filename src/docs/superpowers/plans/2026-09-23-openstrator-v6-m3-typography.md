# Openstrator V6 M3 Typography Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the prototype string/size/weight text model with a persistent professional typography system covering installed fonts, character/paragraph formatting, point/area/path/vertical text, threading, per-glyph transforms, outlines, warp, spelling, menus, rendering, export, and release gates.

**Architecture:** Portable typography data and deterministic layout helpers live in `OpenstratorCore` so persistence, commands, threading, path placement, and release self-tests stay cross-platform. macOS-only font enumeration, Core Text metrics/outlines, and spell checking live in the app target. `VectorObject` keeps legacy fields for file compatibility but gains optional `TextDataV6`; every M3 mutation synchronizes the compatibility fields.

**Tech Stack:** Swift 5.9+, SwiftUI, Foundation, OpenstratorCore, AppKit, CoreText, NSSpellChecker, SwiftPM/XCTest, framework-free release self-test.

**Spec:** `docs/superpowers/specs/2026-09-23-openstrator-v6-design.md`

## Global Constraints

- macOS 13+.
- Intel x86_64 and Apple Silicon arm64 feature parity.
- Typical working-set target remains under 3 GB.
- Existing `.openstrator` documents from V5/M1/M2 must continue decoding.
- Visible typography commands must work or be disabled by validation; no fake success messages.
- Openstrator keeps original branding, menu wording where practical, icons, source, and implementation.
- Terminal build may not require XCTest; release self-test remains framework-free.

## Review Focus

1. Legacy text objects with no `typography` payload render and edit with the same text/size/weight after M3 decoding.
2. Missing fonts fall back deterministically without corrupting the saved requested family/face.
3. Empty strings, emoji, combining marks, and multiline text never crash path/vertical/threading layout helpers.
4. Thread chains reject cycles and preserve overflow rather than dropping text.
5. Type-on-path and touch-type transforms remain stable when the referenced path or glyph index becomes invalid.

---

### Task 1: Portable typography model and backward compatibility

**Files:**
- Create: `Sources/OpenstratorCore/Text/TypographyModels.swift`
- Modify: `Sources/OpenstratorCore/Document/DocumentV6.swift`
- Create: `Tests/OpenstratorCoreTests/TypographyModelTests.swift`

**Interfaces:**
- Produces `CharacterStyleV6`, `ParagraphStyleV6`, `TextLayoutV6`, `TextRunV6`, `GlyphTransformV6`, `TextWarpV6`, `TextDataV6`.
- `TextDataV6` custom decoding supplies M2-compatible defaults when only `text/frame/fontSize/fontWeight` are present.

- [ ] Write tests that decode old M2 text JSON into M3 defaults and round-trip all M3 fields.
- [ ] Run `swift test --filter TypographyModelTests` and verify RED because the new types do not exist.
- [ ] Implement the model with custom Codable compatibility and validated ranges.
- [ ] Re-run focused tests, then `swift test --filter OpenstratorCoreTests`.
- [ ] Commit `feat(m3): add portable typography model`.

### Task 2: Text threading, layout modes, warp, and per-glyph transform core

**Files:**
- Create: `Sources/OpenstratorCore/Text/TextFlow.swift`
- Create: `Sources/OpenstratorCore/Text/TextPathLayout.swift`
- Create: `Tests/OpenstratorCoreTests/TextFlowTests.swift`
- Create: `Tests/OpenstratorCoreTests/TextPathLayoutTests.swift`

**Interfaces:**
- Produces `TextThreadEngine.flow(text:frames:)`, `TextPathLayout.placements(...)`, `TextWarpEngine.apply(...)`.
- Consumes `BezierPathV6`, `TextDataV6`.

- [ ] Write tests for point/area/vertical modes, overflow preservation, cycle rejection, path placement/tangent rotation, empty/emoji strings, and warp bounds.
- [ ] Run focused tests and verify RED for missing engines.
- [ ] Implement deterministic cross-platform geometry helpers.
- [ ] Re-run focused and full core suites.
- [ ] Commit `feat(m3): add text flow and path layout core`.

### Task 3: macOS installed-font catalog, variable axes, substitution, and spelling

**Files:**
- Create: `Openstrator/TypographyRuntime.swift`
- Modify: `Openstrator/EditorStore.swift`
- Create: `Tests/OpenstratorAppTests/TypographyRuntimeContractTests.swift`

**Interfaces:**
- Produces `MacFontCatalog.shared`, `FontFamilyRecord`, `FontFaceRecord`, `VariableFontAxisRecord`, `TypographyRuntime.resolveFont`, `TypographyRuntime.misspellings`.
- Font discovery uses `NSFontManager`; variable axes use Core Text when available; fallback is `.AppleSystemUIFont`.

- [ ] Add source-contract tests requiring dynamic family enumeration, style lookup, variable-axis API, deterministic fallback, and `NSSpellChecker` integration.
- [ ] Verify contract RED.
- [ ] Implement runtime and EditorStore font/recent/favorite state.
- [ ] Parser-check app sources and run core suite.
- [ ] Commit `feat(m3): add macOS font catalog and spelling`.

### Task 4: Persisted M3 text objects and editing commands

**Files:**
- Modify: `Openstrator/Models.swift`
- Modify: `Openstrator/EditorStore.swift`
- Create: `Tests/OpenstratorCoreTests/M3BridgeContractTests.swift`

**Interfaces:**
- `VectorObject.typography: TextDataV6?` is optional.
- `resolvedTypography` maps legacy fields to M3 defaults.
- Store commands: `updateCharacterStyle`, `updateParagraphStyle`, `setTextLayout`, `toggleBullets`, `toggleNumbering`, `threadSelectedTextFrames`, `unthreadSelectedTextFrame`, `applyTextWarp`, `setGlyphTransform`.

- [ ] Write bridge-contract tests for compatibility synchronization and threading IDs.
- [ ] Verify RED.
- [ ] Add optional M3 payload and commands while keeping old documents decodable.
- [ ] Re-run bridge/full tests and parser checks.
- [ ] Commit `feat(m3): bridge rich typography into editor objects`.

### Task 5: Point, area, vertical, path, and Touch Type tool behavior

**Files:**
- Modify: `Openstrator/CanvasView.swift`
- Modify: `Openstrator/EditorStore.swift`
- Modify: `Openstrator/Models.swift`

**Interfaces:**
- Type tools create distinct `TextLayoutModeV6` values.
- Type-on-path references an existing path UUID and preserves text as a separate object.
- Touch Type records per-glyph offsets/scale/rotation in `GlyphTransformV6`.

- [ ] Add source-contract tests for every type tool case and store entry point.
- [ ] Verify RED for vertical-area/path/touch-type gaps.
- [ ] Implement tool gestures and validation/status behavior.
- [ ] Parser-check app and run core suite.
- [ ] Commit `feat(m3): implement professional type tool modes`.

### Task 6: Typography rendering and create-outlines

**Files:**
- Create: `Openstrator/TypographyRenderer.swift`
- Create: `Openstrator/TextOutliner.swift`
- Modify: `Openstrator/CanvasView.swift`
- Modify: `Openstrator/EditorStore.swift`

**Interfaces:**
- `TypographyRenderer.draw(object:pathLookup:context:)` supports point/area/vertical/path text and glyph transforms.
- `TextOutliner.paths(for:) -> [BezierPathV6]` converts Core Text glyph outlines into document-space cubic paths.
- `EditorStore.createOutlines()` replaces selected text with path objects as one undoable snapshot.

- [ ] Add source-contract tests for Core Text usage, path/vertical render branches, and outline conversion.
- [ ] Verify RED.
- [ ] Implement renderer and CGPath→Bezier conversion including quadratic-to-cubic conversion.
- [ ] Wire Canvas renderer and Create Outlines.
- [ ] Parser-check all app Swift and run full core suite.
- [ ] Commit `feat(m3): render rich type and create outlines`.

### Task 7: Inspector, Type menu, bullets/numbering, warp, threading, spell actions

**Files:**
- Modify: `Openstrator/Panels.swift`
- Modify: `Openstrator/OpenstratorApp.swift`
- Modify: `Openstrator/EditorStore.swift`

**Interfaces:**
- Inspector exposes family/face/size/leading/tracking/kerning/baseline/scale/rotation/underline/strike/caps/script/paragraph alignment/indents/spacing/bullets/numbering/layout/warp.
- Type menu contains Font, Recent Fonts, Size, Leading, Tracking, Kerning, Create Outlines, Spelling, Bullets & Numbering, Orientation, Alignment, Convert Point/Area Type, Thread/Unthread, Warp Text, Fill Placeholder Text.

- [ ] Add source-contract tests requiring every major menu family and inspector control binding.
- [ ] Verify RED.
- [ ] Implement inspector and menu actions with disabled validation through store predicates.
- [ ] Parser-check and run full core suite.
- [ ] Commit `feat(m3): add Type menus and typography inspector`.

### Task 8: SVG/export persistence, M3 self-test, acceptance, docs, architecture packaging

**Files:**
- Modify: `Openstrator/Exporters.swift`
- Modify: `Sources/OpenstratorCoreSelfTest/main.swift`
- Create: `scripts/m3_acceptance.sh`
- Modify: `BUILD_OPENSTRATOR.command`
- Modify: `README.md`, `FEATURES.md`, `QA_REPORT.md`, `BUILD_FIX_NOTES.md`

**Interfaces:**
- SVG writes requested font family/style/size/tracking and text layout metadata; path text uses `<textPath>` when referenced path is exportable.
- Framework-free M3 self-test covers model compatibility, threading, path placement, warp, vertical layout, and glyph transforms.
- Builder explicitly packages M3 without invoking XCTest.

- [ ] Add M3 self-test checks first and prove the old M2 source cannot satisfy the new acceptance markers.
- [ ] Implement exporter and release self-test updates.
- [ ] Run full XCTest suite, framework-free self-test, parser checks, builder contract, icon-alpha check, and source contract checks.
- [ ] Update docs with exact verified counts.
- [ ] Create Intel and Apple Silicon packages differing only in architecture flags/configuration.
- [ ] Verify ZIP integrity, executable builder permission, source parity, and architecture configuration.
- [ ] Commit `release: package Openstrator V6 M3 typography`.
