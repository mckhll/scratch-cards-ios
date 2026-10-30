import CoreGraphics

/// Deterministic paper layout shared by the chat cover and its expanded copy.
/// Only the peel changes over time; stickers never float away from their printed positions.
struct ScratchStickerLayout {
    struct Sticker {
        var index: Int
        let home: CGPoint
        let size: CGFloat
        let angle: CGFloat
        var curl: CGFloat = 0
        var peelStart: CGFloat?
        var direction = CGPoint.zero
        var removed = false
    }

    let size: CGSize
    private(set) var stickers: [Sticker] = []
    private(set) var time: CGFloat = 0
    private var touch: CGPoint?
    private var seed: UInt64
    static let peelDuration: CGFloat = 0.42

    init(size: CGSize, seed: UInt64, objectCount: Int = 8, density: CGFloat = 0.87) {
        self.size = size
        self.seed = seed
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return }
        let unit = size.width / 360
        // Reduce density through spacing, never by punching random holes in a
        // finished pattern. Bounded jitter keeps every part of the cover filled.
        let density = density.isFinite ? min(1, max(0.25, density)) : 0.87
        let spacing = 1 / sqrt(density)
        let stepX = 86 * spacing
        let stepY = 77 * spacing
        let rows = min(36, Int(ceil(size.height / (stepY * unit))) + 1)
        let columns = Int(ceil(360 / stepX)) + 1
        let count = max(1, objectCount)
        var uses = [Int](repeating: 0, count: count)
        for row in 0 ..< rows {
            for column in 0 ..< columns {
                let point = CGPoint(x: (CGFloat(column) * stepX - 2 + (row % 2 == 0 ? 0 : stepX * 0.48) + (random() - 0.5) * 22) * unit, y: (CGFloat(row) * stepY - 4 + (random() - 0.5) * 24) * unit)
                let side = (86 + random() * 20) * unit
                let angle = (random() - 0.5) * 0.76
                guard CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side).intersects(CGRect(origin: .zero, size: size)) else { continue }
                // Compare physical neighbours, including the previous row. A
                // sequential repeat check misses vertical/diagonal emoji stripes.
                var object = 0
                var bestScore = CGFloat.greatestFiniteMagnitude
                for candidate in 0 ..< count {
                    if count > 1, let last = stickers.last, last.index == candidate,
                       hypot(point.x - last.home.x, point.y - last.home.y) < stepX * unit * 1.3 { continue }
                    var score = random() * 0.18 + CGFloat(uses[candidate]) * 0.025
                    let matching = stickers.filter { $0.index == candidate && hypot(point.x - $0.home.x, point.y - $0.home.y) < stepX * unit * 2.7 }
                    for neighbour in matching {
                        let distance = hypot(point.x - neighbour.home.x, point.y - neighbour.home.y) / (stepX * unit)
                        if distance < 2.2 { score += 8 * exp(-distance * distance * 1.8) }
                    }
                    // Break runs along diagonals as well as across a row. Two
                    // nearby equal objects must not recruit a third in line.
                    for (i, a) in matching.enumerated() {
                        for b in matching.dropFirst(i + 1) {
                            let dx = a.home.x - b.home.x, dy = a.home.y - b.home.y
                            let length = hypot(dx, dy)
                            guard length > stepX * unit * 0.6, length < stepX * unit * 2.7 else { continue }
                            let distance = abs(dx * (point.y - b.home.y) - dy * (point.x - b.home.x)) / length
                            if distance < stepX * unit * 0.22 { score += 12 }
                        }
                    }
                    if score < bestScore { object = candidate; bestScore = score }
                }
                uses[object] += 1
                stickers.append(Sticker(index: object, home: point, size: side, angle: angle))
            }
        }
    }

    private mutating func random() -> CGFloat {
        seed = seed &* 1664525 &+ 1013904223
        return CGFloat(seed & 0xffffffff) / CGFloat(UInt32.max)
    }

    var needsAnimation: Bool {
        touch != nil || stickers.contains { !$0.removed && ($0.peelStart != nil || $0.curl > 0.001) }
    }

    mutating func setTouch(_ point: CGPoint?) { touch = point }

    @discardableResult
    mutating func peel(from start: CGPoint, to end: CGPoint, animated: Bool) -> Bool {
        guard start.x.isFinite, start.y.isFinite, end.x.isFinite, end.y.isFinite else { return false }
        let dx = end.x - start.x, dy = end.y - start.y
        let square = dx * dx + dy * dy
        var changed = false
        for index in stickers.indices {
            guard stickers[index].peelStart == nil, !stickers[index].removed else { continue }
            let home = stickers[index].home
            let fraction = square > 0 ? min(1, max(0, ((home.x - start.x) * dx + (home.y - start.y) * dy) / square)) : 0
            let distance = hypot(home.x - start.x - dx * fraction, home.y - start.y - dy * fraction)
            guard distance < stickers[index].size * 0.42 else { continue }
            stickers[index].peelStart = time
            let length = max(1, hypot(dx, dy))
            stickers[index].direction = CGPoint(x: dx / length, y: dy / length)
            stickers[index].removed = !animated
            changed = true
        }
        return changed
    }

    mutating func finish(at point: CGPoint, animated: Bool) {
        touch = nil
        let diagonal = max(1, hypot(size.width, size.height))
        for index in stickers.indices where stickers[index].peelStart == nil {
            stickers[index].peelStart = time + hypot(stickers[index].home.x - point.x, stickers[index].home.y - point.y) / diagonal * 0.09
            stickers[index].direction = CGPoint(x: (stickers[index].home.x - point.x) / max(1, size.width), y: -1)
            stickers[index].removed = !animated
        }
    }

    mutating func advance(_ delta: CGFloat) {
        let dt = min(0.05, max(0, delta))
        time += dt
        for index in stickers.indices {
            if let start = stickers[index].peelStart {
                if time - start >= Self.peelDuration { stickers[index].removed = true }
            } else {
                let target: CGFloat
                if let touch {
                    let distance = hypot(touch.x - stickers[index].home.x, touch.y - stickers[index].home.y)
                    let reach = max(1, size.width * 0.23)
                    target = exp(-distance * distance / (reach * reach)) * 0.26
                } else { target = 0 }
                stickers[index].curl += (target - stickers[index].curl) * min(1, dt * 14)
            }
        }
    }
}
