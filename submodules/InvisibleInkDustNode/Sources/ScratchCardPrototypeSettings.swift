import Foundation
import LegacyComponents

/// Prototype transport: a standard media spoiler plus a versioned invisible caption suffix.
public enum ScratchCardMessage {
    private static var marker: String { TGMediaEditingContext.scratchCardMarker() ?? "" }

    private static func suffix(in text: String) -> (Range<String.Index>, ScratchCardCover)? {
        let marker = self.marker
        guard !marker.isEmpty else { return nil }
        if text.hasSuffix(marker) {
            let start = text.index(text.endIndex, offsetBy: -marker.count)
            return (start ..< text.endIndex, .like) // Original prototype messages.
        }
        guard let range = text.range(of: marker, options: .backwards) else { return nil }
        let code = text[range.upperBound...]
        for cover in ScratchCardCover.allCases {
            let expected = String(repeating: "\u{200b}", count: cover.rawValue + 1) + "\u{2064}"
            if code == expected { return (range.lowerBound ..< text.endIndex, cover) }
        }
        return nil
    }

    public static func visibleText(_ text: String) -> String {
        guard let (range, _) = suffix(in: text) else { return text }
        return String(text[..<range.lowerBound])
    }

    public static func cover(in text: String) -> ScratchCardCover? { suffix(in: text)?.1 }
    public static func hasMarker(_ text: String) -> Bool { cover(in: text) != nil }
}
