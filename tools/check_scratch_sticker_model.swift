import Foundation
import CoreGraphics

@main
struct ScratchStickerChecks {
    static func main() {
        let size = CGSize(width: 360, height: 460)
        let seed: UInt64 = 271021
        let original = ScratchStickerLayout(size: size, seed: seed)
        let dense = ScratchStickerLayout(size: size, seed: seed, density: 1)
        precondition(original.stickers.count < dense.stickers.count)
        precondition(original.stickers.count > Int(CGFloat(dense.stickers.count) * 0.75))
        let expanded = ScratchStickerLayout(size: CGSize(width: 540, height: 690), seed: seed)
        precondition(!original.stickers.isEmpty)
        precondition(original.stickers.count == expanded.stickers.count)
        for (small, large) in zip(original.stickers, expanded.stickers) {
            precondition(small.index == large.index)
            precondition(abs(small.home.x * 1.5 - large.home.x) < 0.001)
            precondition(abs(small.home.y * 1.5 - large.home.y) < 0.001)
            precondition(abs(small.size * 1.5 - large.size) < 0.001)
            precondition(small.angle == large.angle)
        }
        // One fast event must hit the same sticker set as coalesced samples.
        var fast = original
        var sampled = original
        let start = CGPoint(x: 12, y: 100), end = CGPoint(x: 344, y: 100)
        fast.peel(from: start, to: end, animated: true)
        for i in 0 ..< 40 {
            let p = CGPoint(x: start.x + (end.x - start.x) * CGFloat(i) / 40, y: 100)
            let q = CGPoint(x: start.x + (end.x - start.x) * CGFloat(i + 1) / 40, y: 100)
            sampled.peel(from: p, to: q, animated: true)
        }
        precondition(fast.stickers.map { $0.peelStart != nil } == sampled.stickers.map { $0.peelStart != nil })
        precondition(fast.stickers.contains { $0.peelStart != nil })
        for _ in 0 ..< 60 { fast.advance(1 / 60) }
        precondition(fast.stickers.filter { $0.peelStart != nil }.allSatisfy { $0.removed })
        var finish = original
        finish.finish(at: CGPoint(x: 180, y: 230), animated: true)
        for _ in 0 ..< 40 { finish.advance(1 / 60) }
        precondition(finish.stickers.allSatisfy { $0.removed })
        precondition(!finish.needsAnimation)
        var quiet = original
        quiet.finish(at: CGPoint(x: 100, y: 100), animated: false)
        precondition(quiet.stickers.allSatisfy { $0.removed })
        var touch = original
        touch.setTouch(CGPoint(x: 140, y: 150))
        for _ in 0 ..< 20 { touch.advance(1 / 60) }
        precondition(touch.stickers.contains { $0.curl > 0.05 })
        touch.setTouch(nil)
        for _ in 0 ..< 90 { touch.advance(1 / 60) }
        precondition(!touch.needsAnimation)
        // Short emoji palettes must not collapse into one identical emoji per row.
        for count in [3, 4, 8] {
            let layout = ScratchStickerLayout(size: size, seed: seed, objectCount: count)
            precondition(Set(layout.stickers.map(\.index)).count == count)
            precondition(Set(layout.stickers.prefix(5).map { Int($0.home.y) }).count > 2)
        }
        // No randomly deleted cells: cover every region, including boundaries.
        // Verify the short palettes/seeds used by the actual seven covers.
        for palette in [3, 4, 8] {
            for cover in 0 ... 6 {
                for height: CGFloat in [240, 460, 620] {
                    let layout = ScratchStickerLayout(size: CGSize(width: 360, height: height), seed: seed + UInt64(cover) * 7919, objectCount: palette)
                    for y in stride(from: CGFloat(0), through: height, by: 12) {
                        for x in stride(from: CGFloat(0), through: 360, by: 12) {
                            let nearest = layout.stickers.map { hypot($0.home.x - x, $0.home.y - y) }.min()!
                            precondition(nearest < 82, "Unfilled patch at \(x),\(y): \(nearest)")
                        }
                    }
                    for (a, b) in zip(layout.stickers, layout.stickers.dropFirst()) {
                        if hypot(a.home.x - b.home.x, a.home.y - b.home.y) < 86 / sqrt(0.87) * 1.3 {
                            precondition(a.index != b.index, "Consecutive neighbours must not form repeated rows")
                        }
                    }
                    for (index, a) in layout.stickers.enumerated() {
                        for b in layout.stickers.dropFirst(index + 1) where a.index == b.index {
                            precondition(hypot(a.home.x - b.home.x, a.home.y - b.home.y) > 74, "Identical stickers form a neighbouring stripe")
                        }
                    }
                }
            }
        }
        for coverage: CGFloat in [0, 0.49, 0.49999] {
            precondition(!ScratchRevealPolicy.shouldReveal(coverage: coverage, released: true))
        }
        for coverage: CGFloat in [0.5, 0.6, 0.8, 0.80999] {
            precondition(!ScratchRevealPolicy.shouldReveal(coverage: coverage, released: false))
            precondition(ScratchRevealPolicy.shouldReveal(coverage: coverage, released: true))
        }
        precondition(ScratchRevealPolicy.shouldReveal(coverage: 0.81, released: false))
        // No pose can invert the clip or create a zero-area plane.
        for x in stride(from: -100.0, through: 460.0, by: 20) {
            for y in stride(from: -100.0, through: 560.0, by: 20) {
                let transform = ScratchCardParallax.transform(at: CGPoint(x: x, y: y), size: size, reduceMotion: false)
                precondition(transform.a * transform.d - transform.b * transform.c > 0.9)
            }
        }
        precondition(ScratchCardParallax.transform(at: .zero, size: .zero, reduceMotion: false) == .identity)
        precondition(ScratchCardParallax.transform(at: CGPoint(x: CGFloat.nan, y: 0), size: size, reduceMotion: false) == .identity)
        precondition(ScratchCardParallax.transform(at: CGPoint(x: 360, y: 460), size: size, reduceMotion: true) == .identity)
        print("PASS: proportional source/expanded layout; fast/coalesced hit equivalence; peel retirement; completion; reduced motion; touch settlement; non-inverting parallax")
    }
}
