import UIKit
import XCTest
import Display
@testable import InvisibleInkDustNode

/// Hosts the real session, film, mask and touch surface on a disposable test window.
/// Account routing, the chat history and the SpaceWarp renderer still need the full-app pass.
@MainActor
final class ScratchCardRenderingTests: XCTestCase {
    private func pause(_ seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func makeWindow() -> UIWindow {
        let window: UIWindow
        let scenes = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
        print("Scratch rendering scenes: \(scenes.map { "\($0.activationState.rawValue):\($0.coordinateSpace.bounds)" })")
        if let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first {
            window = UIWindow(windowScene: scene)
        } else { window = UIWindow(frame: UIScreen.main.bounds) }
        let controller = UIViewController()
        controller.view.backgroundColor = UIColor(white: 0.12, alpha: 1)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        return window
    }

    func testAsyncCoverRequestsShareTextureAndCannotReplaceLiveScene() async throws {
        let size = CGSize(width: 277, height: 509)
        let ready = expectation(description: "Two cells share a cold cover request")
        ready.expectedFulfillmentCount = 2
        var images: [UIImage] = []
        var returned = false
        for _ in 0 ..< 2 {
            ScratchCoverStillArtwork.requestImage(cover: .dislike, size: size) { image in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertTrue(returned, "A cold request must not rasterize inline on the caller")
                if let image { images.append(image) }
                ready.fulfill()
            }
        }
        returned = true
        let scene = ScratchCoverSceneView(frame: CGRect(x: 0, y: 0, width: 319, height: 477))
        scene.setCover(.party)
        scene.setCover(.like)
        scene.setMotionActive(true, allowed: true, interactive: true)
        await fulfillment(of: [ready], timeout: 5)
        try await pause(0.3)
        XCTAssertEqual(images.count, 2)
        if images.count == 2 { XCTAssertTrue(images[0] === images[1]) }
        XCTAssertNil(scene.layer.contents, "Late closed-cover jobs cannot overwrite interactive stickers")
        XCTAssertGreaterThan(scene.liveStickerCount, 0)
    }

    func testStickerHasTransparentPaperCorners() {
        let image = ScratchStickerArtwork.image(for: "❤️").cgImage!
        var pixel: [UInt8] = [0, 0, 0, 0]
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // This lies inside the glyph renderer's rectangular bounds but outside the heart.
        context.translateBy(x: -24, y: -24)
        context.draw(image, in: CGRect(x: 0, y: 0, width: 144, height: 144))
        XCTAssertEqual(pixel[3], 0, "The white paper border must follow the emoji silhouette")
    }

    func testClosedCoversStayFlatAndEffectsAreLazy() async throws {
        let window = makeWindow()
        defer { window.isHidden = true }
        let scroll = UIScrollView(frame: window.bounds)
        window.rootViewController!.view.addSubview(scroll)
        let side = (window.bounds.width - 48) / 2
        let silhouettePhoto = (makePhoto(CGSize(width: 280, height: 220)) as! UIImageView).image!
        scroll.contentSize = CGSize(width: window.bounds.width, height: 60 + 6 * 180)
        var requests = 0
        for index in 0 ..< 12 {
            let source = ScratchRevealView(frame: CGRect(x: 18 + CGFloat(index % 2) * (side + 12), y: 60 + CGFloat(index / 2) * 180, width: side, height: 164))
            source.particleEffectFactory = { _ in requests += 1; return nil }
            source.updateAppearance(arguments: nil, accentColor: .systemBlue, cover: ScratchCardCover.menuOrder[(index % 6) + 1])
            source.setPhoto(silhouettePhoto)
            source.layer.cornerRadius = 16
            scroll.addSubview(source)
            source.setMotionActive(true)
            source.layoutIfNeeded()
            func count(_ layer: CALayer) -> Int { 1 + (layer.sublayers ?? []).reduce(0) { $0 + count($1) } }
            XCTAssertLessThan(count(source.layer), 45, "Closed cards must not allocate per-sticker layers")
        }
        try await pause(0.6)
        UIView.animate(withDuration: 0.8) { scroll.contentOffset.y = max(0, scroll.contentSize.height - scroll.bounds.height) }
        try await pause(1.2)
        UIView.animate(withDuration: 0.8) { scroll.contentOffset.y = 0 }
        try await pause(1)
        XCTAssertEqual(requests, 0, "Scrolling past cards must not prepare particle effects")
        let first = ScratchCoverStillArtwork.image(cover: .like, size: CGSize(width: 280, height: 220))
        let second = ScratchCoverStillArtwork.image(cover: .like, size: CGSize(width: 280, height: 220))
        XCTAssertTrue(first === second, "Closed covers reuse the baked texture")
    }

    func testPhotoTextureIsOpaqueTintedAndSuppressesFineDetails() {
        func image(checker: Bool, split: Bool = false) -> UIImage {
            UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128)).image { renderer in
                UIColor(white: 0.5, alpha: 1).setFill()
                renderer.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
                if split {
                    UIColor.black.setFill(); renderer.fill(CGRect(x: 0, y: 0, width: 64, height: 128))
                    UIColor.white.setFill(); renderer.fill(CGRect(x: 64, y: 0, width: 64, height: 128))
                } else if checker {
                    for y in 0 ..< 128 { for x in 0 ..< 128 {
                        UIColor(white: (x + y) % 2 == 0 ? 0 : 1, alpha: 1).setFill()
                        renderer.fill(CGRect(x: x, y: y, width: 1, height: 1))
                    } }
                }
            }
        }
        func pixels(_ image: UIImage) -> [UInt8] {
            let cg = image.cgImage!
            var result = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
            result.withUnsafeMutableBytes { buffer in
                let context = CGContext(data: buffer.baseAddress, width: cg.width, height: cg.height, bitsPerComponent: 8,
                    bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            }
            return result
        }
        let flat = ScratchCoverPhotoArtwork.image(photo: image(checker: false), cover: .heart)!
        let detailed = ScratchCoverPhotoArtwork.image(photo: image(checker: true), cover: .heart)!
        let silhouette = ScratchCoverPhotoArtwork.image(photo: image(checker: false, split: true), cover: .heart)!
        XCTAssertEqual(flat.cgImage!.width, 64)
        let a = pixels(flat), b = pixels(detailed), c = pixels(silhouette)
        let meanError = zip(a, b).reduce(0.0) { $0 + Double(abs(Int($1.0) - Int($1.1))) } / Double(a.count)
        XCTAssertLessThan(meanError, 2, "Fine checker detail must disappear; isolated edge-resampling differences are not texture")
        for index in stride(from: 3, to: c.count, by: 4) { XCTAssertEqual(c[index], 255) }
        let left = (32 * 64 + 16) * 4, right = (32 * 64 + 48) * 4
        XCTAssertLessThan(c[left], a[left], "The large dark shape remains perceptible")
        XCTAssertGreaterThan(c[right + 1], a[right + 1], "The large light shape remains perceptible")
        XCTAssertGreaterThan(c[left], c[left + 1], "Heart keeps its warm pink tint")
    }

    func testPhotoTextureReuseAndStaleRequestCancellation() async throws {
        let photo = (makePhoto(CGSize(width: 280, height: 220)) as! UIImageView).image!
        let film = ScratchFilmView()
        film.setCover(.heart)
        film.setPhoto(photo)
        try await pause(0.3)
        XCTAssertNotNil(film.preparedPhotoImage)
        let expanded = ScratchFilmView()
        expanded.setCover(.heart)
        expanded.copyPhoto(from: film)
        XCTAssertTrue(expanded.preparedPhotoImage === film.preparedPhotoImage)
        film.setCover(.fire)
        film.setPhoto(nil)
        try await pause(0.3)
        XCTAssertNil(film.preparedPhotoImage, "A cancelled old request must not restore another photo's silhouette")
        var temporary: UIImage? = UIImage(cgImage: photo.cgImage!)
        film.setPhoto(temporary)
        temporary = nil
        try await pause(0.3)
        XCTAssertNotNil(film.preparedPhotoImage)
        film.setPhoto(nil)
        XCTAssertNil(film.preparedPhotoImage, "Clearing must also work after the weak original photo has been released")
    }

    func testIdleHintAndRevealOnRelease() async throws {
        let window = makeWindow()
        defer { window.isHidden = true }
        let (source, session, underlay) = try await makeSession(window: window, cover: .heart)
        var completions: [Bool] = []
        session.finished = { revealed in
            completions.append(revealed)
            if revealed { source.isHidden = true }
            underlay.alpha = 1
        }
        try await pause(0.85)
        XCTAssertFalse(session.isGestureHintVisible)
        try await pause(1.8)
        XCTAssertTrue(session.isGestureHintVisible)
        print("Scratch guide visible before first interaction")
        let size = session.expandedRect.size
        session.rub([CGPoint(x: size.width * 0.1, y: size.height * 0.1)], began: true)
        XCTAssertFalse(session.isGestureHintVisible)
        session.endRub()
        try await pause(0.4)
        XCTAssertTrue(completions.isEmpty, "A small scratch must not reveal on release")
        try await pause(0.8)
        XCTAssertTrue(session.isGestureHintVisible, "Idle coaching returns after an incomplete gesture")
        try await pause(1.2)
        for row in 0 ..< 20 {
            let y = (0.035 + CGFloat(row) * 0.048) * size.height
            session.rub([CGPoint(x: size.width * (row % 2 == 0 ? 0.04 : 0.96), y: y), CGPoint(x: size.width * (row % 2 == 0 ? 0.96 : 0.04), y: y)], began: row == 0)
            try await pause(0.08)
            if session.coverageFraction >= 0.55 { break }
        }
        XCTAssertGreaterThanOrEqual(session.coverageFraction, 0.5)
        XCTAssertLessThan(session.coverageFraction, 0.81)
        print("Scratch held coverage: \(session.coverageFraction)")
        try await pause(0.3)
        XCTAssertTrue(completions.isEmpty, "Holding after 50% must preserve the interaction")
        session.endRub(cancelled: true)
        try await pause(0.2)
        XCTAssertTrue(completions.isEmpty, "System cancellation is not a deliberate release")
        session.rub([CGPoint(x: size.width * 0.5, y: size.height * 0.3)], began: true)
        session.endRub()
        try await pause(1.3)
        XCTAssertEqual(completions, [true])
        source.removeFromSuperview()
        underlay.removeFromSuperview()
    }

    private func makePhoto(_ size: CGSize) -> UIView {
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(red: 0.46, green: 0.69, blue: 0.77, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.94, green: 0.86, blue: 0.69, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: size.width * 0.63, y: size.height * 0.14, width: 56, height: 56))
            UIColor(red: 0.21, green: 0.38, blue: 0.46, alpha: 1).setFill()
            let mountain = UIBezierPath()
            mountain.move(to: CGPoint(x: 0, y: size.height))
            mountain.addLine(to: CGPoint(x: size.width * 0.3, y: size.height * 0.39))
            mountain.addLine(to: CGPoint(x: size.width * 0.62, y: size.height * 0.72))
            mountain.addLine(to: CGPoint(x: size.width * 0.81, y: size.height * 0.54))
            mountain.addLine(to: CGPoint(x: size.width, y: size.height))
            mountain.close()
            mountain.fill()
        }
        return UIImageView(image: image)
    }

    private func makeSession(window: UIWindow, cover: ScratchCardCover, language: String = "en") async throws -> (ScratchRevealView, ScratchCardSession, UIView) {
        let root = window.rootViewController!.view!
        let source = ScratchRevealView(frame: CGRect(x: root.bounds.width * 0.23, y: root.bounds.height * 0.31, width: root.bounds.width * 0.69, height: root.bounds.width * 0.8))
        source.strings = ScratchCardStrings(languageCode: language)
        let corners: ImageCorners
        if cover == .party {
            corners = ImageCorners(topLeft: .Corner(0), topRight: .Corner(0), bottomLeft: .Corner(16), bottomRight: .Corner(16))
        } else if cover == .poop {
            corners = ImageCorners(topLeft: .Corner(16), topRight: .Corner(16), bottomLeft: .Corner(16), bottomRight: .Corner(4))
        } else { corners = ImageCorners(radius: 16) }
        source.updateAppearance(arguments: TransformImageArguments(corners: corners, imageSize: source.bounds.size, boundingSize: source.bounds.size, intrinsicInsets: .zero), accentColor: .systemBlue, cover: cover)
        let underlay = makePhoto(source.bounds.size)
        source.setPhoto((underlay as! UIImageView).image)
        underlay.frame = source.frame
        underlay.alpha = 0
        root.addSubview(underlay)
        root.addSubview(source)
        root.viewWithTag(3001)?.removeFromSuperview()
        let label = UILabel(frame: CGRect(x: 20, y: window.safeAreaInsets.top + 10, width: root.bounds.width - 40, height: 30))
        label.tag = 3001
        label.text = source.strings.title(for: cover)
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        root.addSubview(label)
        root.layoutIfNeeded()
        try await pause(0.35) // Commit the source and its asynchronous artwork before capture.
        let landingCover = source.makeLandingCover()
        source.alpha = 0 // The real presenter hides its source before freezing the chat.
        let session = ScratchCardSession(source: source, photo: makePhoto(source.bounds.size), backdrop: nil, window: window, landingCover: landingCover)
        root.addSubview(session)
        session.present()
        return (source, session, underlay)
    }

    func testNativeStickerSessions() async throws {
        let window = makeWindow()
        defer { window.isHidden = true }
        try await pause(1)
        for (index, cover) in ScratchCardCover.menuOrder.enumerated() {
            window.overrideUserInterfaceStyle = index % 2 == 0 ? .dark : .light
            let (source, session, underlay) = try await makeSession(window: window, cover: cover, language: index % 2 == 0 ? "ru" : "en")
            var completions: [Bool] = []
            var rippleCount = 0
            session.finished = { revealed in
                completions.append(revealed)
                if revealed { source.isHidden = true }
                underlay.alpha = 1
            }
            session.rippleRequested = { _ in rippleCount += 1 }
            try await pause(0.5)
            let size = session.expandedRect.size
            XCTAssertGreaterThan(size.width, 0)
            let hit = window.hitTest(CGPoint(x: session.expandedRect.midX, y: session.expandedRect.midY), with: nil)
            XCTAssertTrue(hit?.isDescendant(of: session) == true)
            // Continuous coalesced samples across a shallow arc; leave it on camera.
            for step in 0 ... 25 {
                let u = CGFloat(step) / 25
                session.rub([CGPoint(x: (0.08 + u * 0.84) * size.width, y: (0.19 + sin(u * .pi) * 0.08) * size.height)], began: step == 0)
                try await pause(1 / 60)
            }
            XCTAssertTrue(completions.isEmpty)
            try await pause(0.25)
            // Keep rubbing without releasing: automatic reveal requires 81%.
            for row in 0 ..< 18 {
                for step in 0 ... 17 {
                    let u = CGFloat(step) / 17
                    session.rub([CGPoint(x: (0.04 + (row % 2 == 0 ? u : 1 - u) * 0.92) * size.width, y: (0.035 + CGFloat(row) * 0.055) * size.height)], began: step == 0)
                    try await pause(1 / 90)
                }
            }
            XCTAssertGreaterThanOrEqual(session.coverageFraction, 0.81)
            try await pause(1.3)
            XCTAssertEqual(completions, [true])
            XCTAssertEqual(rippleCount, cover.hasThemedEffects && !UIAccessibility.isReduceMotionEnabled ? 1 : 0)
            session.cancel()
            XCTAssertEqual(completions, [true], "Completion must be delivered exactly once")
            source.removeFromSuperview()
            underlay.removeFromSuperview()
        }
    }

    func testReturnMatchesSourceAfterOffsetAndPartialScratch() async throws {
        let window = makeWindow()
        defer { window.isHidden = true }
        let root = window.rootViewController!.view!
        // A modal need not share the window's origin. The real presentation host
        // adds its own container, while the source lives in a scrolling history.
        root.frame.origin.y = 19
        for (index, cover) in [ScratchCardCover.dislike, .poop, .party, .heart].enumerated() {
            let (source, session, underlay) = try await makeSession(window: window, cover: cover)
            var completions: [Bool] = []
            session.finished = { revealed in
                let expected = source.convert(source.bounds, to: session)
                let landed = session.presentedCardFrame
                XCTAssertEqual(landed.minX, expected.minX, accuracy: 0.1)
                XCTAssertEqual(landed.minY, expected.minY, accuracy: 0.1)
                XCTAssertEqual(landed.width, expected.width, accuracy: 0.1)
                XCTAssertEqual(landed.height, expected.height, accuracy: 0.1)
                completions.append(revealed)
            }
            try await pause(0.65)
            if index % 2 == 1 {
                session.rub([CGPoint(x: 65, y: 95), CGPoint(x: 150, y: 125)], began: true)
                try await pause(0.25)
            }
            print("Scratch return begins: \(cover), partial=\(index % 2 == 1)")
            session.perform(NSSelectorFromString("backgroundTapped"))
            try await pause(0.85)
            XCTAssertEqual(completions, [false])
            XCTAssertEqual(source.alpha, 1)
            XCTAssertNil(session.superview)
            try await pause(0.35)
            source.removeFromSuperview()
            underlay.removeFromSuperview()
        }
    }

    func testCloseAndRotationCancellation() async throws {
        let window = makeWindow()
        defer { window.isHidden = true }
        for rotate in [false, true] {
            let (source, session, underlay) = try await makeSession(window: window, cover: .heart)
            var completions: [Bool] = []
            session.finished = { revealed in
                completions.append(revealed)
                if revealed { source.isHidden = true }
                underlay.alpha = 1
            }
            try await pause(0.45)
            session.rub([CGPoint(x: 65, y: 95), CGPoint(x: 140, y: 105)], began: true)
            if rotate {
                session.frame = CGRect(x: 0, y: 0, width: window.bounds.height, height: window.bounds.width)
                session.setNeedsLayout()
                session.layoutIfNeeded()
            } else { session.perform(NSSelectorFromString("backgroundTapped")) }
            try await pause(0.65)
            XCTAssertEqual(completions, [false])
            session.cancel()
            XCTAssertEqual(completions, [false])
            source.removeFromSuperview()
            underlay.removeFromSuperview()
        }
    }
}
