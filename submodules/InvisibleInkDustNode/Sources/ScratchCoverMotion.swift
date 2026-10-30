import CoreGraphics

/// Inertial, bounded motion shared by all six covers. No perspective or frame jitter.
struct ScratchCoverMotion {
    struct Body {
        let index: Int
        let home: CGPoint
        let size: CGFloat
        let depth: CGFloat
        let phase: CGFloat
        var position: CGPoint
        var velocity = CGPoint.zero
        var noise = CGPoint.zero
        var targetNoise = CGPoint.zero
        var nextNoise: CGFloat = 0
        var pulse: CGFloat = 0
    }
    let size: CGSize
    private(set) var bodies: [Body] = []
    private(set) var time: CGFloat = 0
    private var seed: UInt64
    private var touch: CGPoint?
    private var touchVelocity = CGPoint.zero
    private var lastTouchTime: CGFloat = 0

    init(size: CGSize, seed: UInt64) {
        self.size = size
        self.seed = seed
        let count = max(12, min(24, Int(size.width * size.height / 8500)))
        let unit = max(0.65, min(1.3, size.width / 360))
        let anchors: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(0.20,0.25,66,1), (0.77,0.62,62,0.95), (0.72,0.17,55,0.9), (0.29,0.81,49,0.8)]
        for index in 0 ..< count {
            let position: CGPoint
            let depth: CGFloat
            let bodySize: CGFloat
            if index < anchors.count {
                let a = anchors[index]
                position = CGPoint(x: a.0 * size.width, y: a.1 * size.height)
                bodySize = a.2 * unit
                depth = a.3
            } else {
                var best = CGPoint.zero
                var clearance: CGFloat = -1
                for _ in 0 ..< 24 {
                    let candidate = CGPoint(x: (0.03 + random() * 0.94) * size.width, y: (0.03 + random() * 0.94) * size.height)
                    let gap = bodies.map { hypot($0.home.x - candidate.x, $0.home.y - candidate.y) }.min() ?? 0
                    if gap > clearance { best = candidate; clearance = gap }
                }
                position = best
                depth = index < 12 ? 0.4 + random() * 0.24 : 0.17 + random() * 0.18
                bodySize = (18 + depth * 29) * unit
            }
            bodies.append(Body(index: index, home: position, size: bodySize, depth: depth, phase: random() * .pi * 2, position: position))
        }
        bodies.sort { $0.depth < $1.depth }
    }

    private mutating func random() -> CGFloat {
        seed = seed &* 1664525 &+ 1013904223
        return CGFloat(seed & 0xffffffff) / CGFloat(UInt32.max)
    }

    mutating func setTouch(_ point: CGPoint?) {
        if let point, let touch {
            let delta = max(1 / 120.0, time - lastTouchTime)
            touchVelocity = CGPoint(x: min(1400, max(-1400, (point.x - touch.x) / delta)), y: min(1400, max(-1400, (point.y - touch.y) / delta)))
        } else { touchVelocity = .zero }
        touch = point
        lastTouchTime = time
    }

    mutating func impulse(at point: CGPoint, strength: CGFloat = 1) {
        for index in bodies.indices {
            let dx = bodies[index].position.x - point.x, dy = bodies[index].position.y - point.y
            let distance = max(1, hypot(dx, dy))
            let force = max(0, 1 - distance / 210) * 75 * strength * bodies[index].depth
            bodies[index].velocity.x += dx / distance * force
            bodies[index].velocity.y += dy / distance * force
            bodies[index].pulse = max(bodies[index].pulse, max(0, 1 - distance / 160) * 0.12 * strength)
        }
    }

    mutating func advance(_ delta: CGFloat) {
        let dt = min(0.05, max(0, delta))
        time += dt
        for index in bodies.indices {
            if time > bodies[index].nextNoise {
                bodies[index].targetNoise = CGPoint(x: (random() - 0.5) * 7, y: (random() - 0.5) * 7)
                bodies[index].nextNoise = time + 0.45 + random() * 0.6
            }
            var body = bodies[index]
            body.noise.x += (body.targetNoise.x - body.noise.x) * dt * 1.6
            body.noise.y += (body.targetNoise.y - body.noise.y) * dt * 1.6
            let driftX = (sin(time * 0.31 + body.phase) * 9 + sin(time * 0.73 + body.phase * 0.6) * 3) * 0.7
            let driftY = (cos(time * 0.26 + body.phase * 0.6) * 10 + sin(time * 0.58 + body.phase) * 3) * 0.7
            var ax = (body.home.x + driftX - body.position.x) * 2.1 + body.noise.x * 0.7
            var ay = (body.home.y + driftY - body.position.y) * 2.1 + body.noise.y * 0.7
            if let touch {
                let dx = body.position.x - touch.x, dy = body.position.y - touch.y
                let distance = max(1, hypot(dx, dy))
                let falloff = pow(max(0, 1 - distance / 135), 2)
                let force = 1000 * falloff * body.depth
                ax += dx / distance * force + touchVelocity.x * 0.75 * falloff * body.depth
                ay += dy / distance * force + touchVelocity.y * 0.75 * falloff * body.depth
            }
            body.velocity.x = (body.velocity.x + ax * dt) * exp(-2.6 * dt)
            body.velocity.y = (body.velocity.y + ay * dt) * exp(-2.6 * dt)
            body.position.x = min(size.width - 3, max(3, body.position.x + body.velocity.x * dt))
            body.position.y = min(size.height - 3, max(3, body.position.y + body.velocity.y * dt))
            body.pulse *= exp(-5 * dt)
            bodies[index] = body
        }
        touchVelocity.x *= exp(-12 * dt)
        touchVelocity.y *= exp(-12 * dt)
    }
}
