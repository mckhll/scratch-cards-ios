import CoreGraphics

enum ScratchRevealPolicy {
    static func shouldReveal(coverage: CGFloat, released: Bool) -> Bool {
        coverage >= (released ? 0.5 : 0.81)
    }
}
