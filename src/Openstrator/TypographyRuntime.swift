import AppKit
import CoreText
import Foundation
import OpenstratorCore

struct VariableFontAxisRecord: Identifiable, Hashable {
    var id: Int
    var name: String
    var minimum: Double
    var maximum: Double
    var defaultValue: Double
}

struct FontFaceRecord: Identifiable, Hashable {
    var id: String { postScriptName }
    var postScriptName: String
    var displayName: String
    var weight: Int
    var traitsRawValue: UInt
    var variableAxes: [VariableFontAxisRecord]
}

struct FontFamilyRecord: Identifiable, Hashable {
    var id: String { family }
    var family: String
    var faces: [FontFaceRecord]
}

struct ResolvedFontRecord {
    var font: NSFont
    var requestedFamily: String
    var requestedFace: String
    var substituted: Bool
}

@MainActor
final class MacFontCatalog {
    static let shared = MacFontCatalog()

    private(set) var families: [FontFamilyRecord] = []
    private var postScriptIndex: [String: FontFaceRecord] = [:]
    private var familyIndex: [String: FontFamilyRecord] = [:]

    private init() {
        reload()
    }

    func reload() {
        let manager = NSFontManager.shared
        let names = NSFontManager.shared.availableFontFamilies.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        var built: [FontFamilyRecord] = []
        var psIndex: [String: FontFaceRecord] = [:]
        for family in names {
            let members = manager.availableMembers(ofFontFamily: family) ?? []
            var faces: [FontFaceRecord] = []
            for member in members {
                guard member.count >= 2,
                      let postScript = member[0] as? String,
                      let display = member[1] as? String else { continue }
                let weight = (member.count > 2 ? member[2] as? Int : nil) ?? 5
                let traits = (member.count > 3 ? member[3] as? UInt : nil) ?? 0
                let face = FontFaceRecord(
                    postScriptName: postScript,
                    displayName: display,
                    weight: weight,
                    traitsRawValue: traits,
                    variableAxes: Self.variableAxes(forPostScriptName: postScript)
                )
                faces.append(face)
                psIndex[postScript] = face
            }
            if faces.isEmpty, let font = NSFont(name: family, size: 12) {
                let postScript = font.fontName
                let face = FontFaceRecord(
                    postScriptName: postScript,
                    displayName: "Regular",
                    weight: 5,
                    traitsRawValue: 0,
                    variableAxes: Self.variableAxes(forPostScriptName: postScript)
                )
                faces = [face]
                psIndex[postScript] = face
            }
            built.append(FontFamilyRecord(family: family, faces: faces))
        }
        families = built
        postScriptIndex = psIndex
        familyIndex = Dictionary(uniqueKeysWithValues: built.map { ($0.family, $0) })
    }

    func family(named name: String) -> FontFamilyRecord? {
        familyIndex[name]
    }

    func search(_ query: String) -> [FontFamilyRecord] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return families }
        return families.filter { family in
            family.family.localizedCaseInsensitiveContains(q) ||
            family.faces.contains { $0.displayName.localizedCaseInsensitiveContains(q) || $0.postScriptName.localizedCaseInsensitiveContains(q) }
        }
    }

    func resolveFont(style: CharacterStyleV6) -> ResolvedFontRecord {
        let size = CGFloat(max(1, style.fontSize))
        if let postScript = style.postScriptName, let font = Self.makeFont(postScriptName: postScript, size: size, style: style) {
            return ResolvedFontRecord(font: font, requestedFamily: style.fontFamily, requestedFace: style.fontFace, substituted: false)
        }
        if let family = familyIndex[style.fontFamily] {
            let preferred = family.faces.first { $0.displayName.caseInsensitiveCompare(style.fontFace) == .orderedSame }
                ?? family.faces.min(by: { abs($0.weight - Int((style.legacyWeight * 14).rounded())) < abs($1.weight - Int((style.legacyWeight * 14).rounded())) })
            if let preferred, let font = Self.makeFont(postScriptName: preferred.postScriptName, size: size, style: style) {
                return ResolvedFontRecord(font: font, requestedFamily: style.fontFamily, requestedFace: style.fontFace, substituted: false)
            }
        }
        let font = NSFont.systemFont(ofSize: size, weight: Self.systemWeight(from: style.legacyWeight))
        return ResolvedFontRecord(font: font, requestedFamily: style.fontFamily, requestedFace: style.fontFace, substituted: true)
    }

    private static func makeFont(postScriptName: String, size: CGFloat, style: CharacterStyleV6) -> NSFont? {
        guard !style.variableAxes.isEmpty else { return NSFont(name: postScriptName, size: size) }
        let variations: [NSNumber: NSNumber] = Dictionary(uniqueKeysWithValues: style.variableAxes.compactMap { key, value in
            guard let identifier = Int(key), value.isFinite else { return nil }
            return (NSNumber(value: identifier), NSNumber(value: value))
        })
        guard !variations.isEmpty else { return NSFont(name: postScriptName, size: size) }
        let attributes: [NSFontDescriptor.AttributeName: Any] = [
            .name: postScriptName,
            NSFontDescriptor.AttributeName.variation: variations
        ]
        return NSFont(descriptor: NSFontDescriptor(fontAttributes: attributes), size: size)
            ?? NSFont(name: postScriptName, size: size)
    }

    static func variableAxes(forPostScriptName name: String) -> [VariableFontAxisRecord] {
        let font = CTFontCreateWithName(name as CFString, 12, nil)
        guard let raw = CTFontCopyVariationAxes(font) as? [[CFString: Any]] else { return [] }
        return raw.compactMap { axis in
            let identifier = (axis[kCTFontVariationAxisIdentifierKey] as? NSNumber)?.intValue
            let name = axis[kCTFontVariationAxisNameKey] as? String
            let min = (axis[kCTFontVariationAxisMinimumValueKey] as? NSNumber)?.doubleValue
            let max = (axis[kCTFontVariationAxisMaximumValueKey] as? NSNumber)?.doubleValue
            let def = (axis[kCTFontVariationAxisDefaultValueKey] as? NSNumber)?.doubleValue
            guard let identifier, let name, let min, let max, let def else { return nil }
            return VariableFontAxisRecord(id: identifier, name: name, minimum: min, maximum: max, defaultValue: def)
        }
    }

    private static func systemWeight(from legacy: Double) -> NSFont.Weight {
        switch legacy {
        case ..<0.15: return .ultraLight
        case ..<0.28: return .light
        case ..<0.42: return .regular
        case ..<0.56: return .medium
        case ..<0.70: return .semibold
        case ..<0.84: return .bold
        default: return .heavy
        }
    }
}

enum TypographyRuntime {
    @MainActor
    static func resolveFont(style: CharacterStyleV6) -> ResolvedFontRecord {
        MacFontCatalog.shared.resolveFont(style: style)
    }

    static func misspellings(in text: String) -> [NSRange] {
        guard !text.isEmpty else { return [] }
        let checker = NSSpellChecker.shared
        var output: [NSRange] = []
        var location = 0
        let utf16Length = (text as NSString).length
        while location < utf16Length {
            let range = checker.checkSpelling(of: text, startingAt: location)
            if range.location == NSNotFound || range.length == 0 { break }
            output.append(range)
            location = max(location + 1, NSMaxRange(range))
        }
        return output
    }
}
