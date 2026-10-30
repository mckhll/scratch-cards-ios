import AppKit
import WebKit
import Foundation

@MainActor final class Harness: NSObject, WKNavigationDelegate {
    let web: WKWebView
    let out = URL(fileURLWithPath: CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "/tmp/party-cover-qa", isDirectory: true)
    var didRun = false
    override init() {
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(WKUserScript(source: """
        window.__clock=0;window.__raf=[];window.requestAnimationFrame=cb=>{window.__raf.push(cb);return window.__raf.length};
        Object.defineProperty(document,'hidden',{get:()=>false});
        Object.defineProperty(performance,'now',{value:()=>window.__clock});
        window.__advance=n=>{for(let i=0;i<n;i++){window.__clock+=1000/60;const q=window.__raf.splice(0);q.forEach(cb=>cb(window.__clock));}};
        HTMLCanvasElement.prototype.setPointerCapture=function(){};
        HTMLCanvasElement.prototype.hasPointerCapture=function(){return false};
        """, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        web = WKWebView(frame: CGRect(x: 0, y: 0, width: 1100, height: 1000), configuration: config)
        super.init()
        web.navigationDelegate = self
    }
    func js(_ script: String) async throws -> Any? {
        try await web.evaluateJavaScript(script)
    }
    func snapshot(_ name: String) async throws {
        guard let dataURL = try await js("document.getElementById('scene').toDataURL('image/png')") as? String,
              let data = Data(base64Encoded: String(dataURL.split(separator: ",", maxSplits: 1)[1])) else { throw NSError(domain: "Screenshot", code: 1) }
        try data.write(to: out.appendingPathComponent(name + ".png"))
    }
    func state() async throws -> [String:Any] { try await js("window.partyCoverLab.snapshot()") as! [String:Any] }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !didRun else { return }; didRun = true
        Task { @MainActor in
            do {
                try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
                for _ in 0 ..< 80 {
                    if (try? await self.js("!!window.partyCoverLab?.snapshot().ready")) as? Bool == true { break }
                    try await Task.sleep(nanoseconds: 50_000_000)
                }
                guard (try await state())["ready"] as? Bool == true else { throw NSError(domain: "NotReady", code: 2) }
                _ = try await js("document.getElementById('reduced').checked=false;document.getElementById('reduced').dispatchEvent(new Event('change'));__advance(60)")
                try await snapshot("idle")
                let desktopConfig = WKSnapshotConfiguration()
                desktopConfig.rect = CGRect(x: 0, y: 0, width: 1100, height: 900)
                if let image = try? await web.takeSnapshot(configuration: desktopConfig), let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
                    try png.write(to: out.appendingPathComponent("desktop-page.png"))
                }

                var metrics = [[String:Any]]()
                _ = try await js("document.getElementById('demo').click()")
                for index in 0 ... 32 {
                    if index > 0 { _ = try await js("__advance(15)") }
                    let data = try await state()
                    guard data["finite"] as? Bool == true else { throw NSError(domain: "NonFinitePhysics", code: 3) }
                    metrics.append(["index":index,"time":Double(index)*0.25,"state":data])
                    try await snapshot(String(format: "motion-%02d",index))
                }
                _ = try await js("document.getElementById('mode-erase').click();__advance(1)")
                // Synthetic input belongs only to this isolated local fixture.
                let gesture = """
                (()=>{const c=document.getElementById('scene');let down=false;
                function point(x,y){let r=c.getBoundingClientRect();return {clientX:r.left+x/400*r.width,clientY:r.top+y/520*r.height,pointerId:1,bubbles:true,pointerType:'touch'}}
                for(let row=0;row<10;row++){let y=32+row*49;
                  for(let i=0;i<=30;i++){const x=row%2?380-i*12:20+i*12;
                    c.dispatchEvent(new PointerEvent(down?'pointermove':'pointerdown',point(x,y)));down=true;__advance(1);}}
                c.dispatchEvent(new PointerEvent('pointerup',point(380,490)));__advance(60);return window.partyCoverLab.snapshot();})()
                """
                let revealed = try await js(gesture) as! [String:Any]
                guard revealed["revealed"] as? Bool == true else { throw NSError(domain: "ScratchNotRevealed", code: 4) }
                try await snapshot("revealed")
                _ = try await js("document.getElementById('mode-cover').click();__advance(60);document.getElementById('pause').click();__advance(60)")
                let a = try await js("document.getElementById('scene').toDataURL()") as! String
                _ = try await js("__advance(60)")
                let b = try await js("document.getElementById('scene').toDataURL()") as! String
                guard a == b else { throw NSError(domain: "PauseMoves", code: 5) }
                _ = try await js("document.getElementById('pause').click();document.getElementById('theme').click();__advance(60)")
                try await snapshot("light")
                web.frame = CGRect(x: 0, y: 0, width: 390, height: 900)
                try await Task.sleep(nanoseconds: 100_000_000)
                _ = try await js("__advance(2)")
                let fits = try await js("document.documentElement.scrollWidth<=window.innerWidth") as? Bool
                guard fits == true else { throw NSError(domain: "MobileOverflow", code: 6) }
                let finalError = try await js("document.querySelector('.error')?.textContent || ''") as? String ?? ""
                guard finalError.isEmpty else { throw NSError(domain: finalError, code: 7) }
                try JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted,.sortedKeys]).write(to: out.appendingPathComponent("motion.json"))
                let config = WKSnapshotConfiguration()
                config.rect = CGRect(x: 0, y: 0, width: 390, height: 900)
                if let image = try? await web.takeSnapshot(configuration: config), let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) {
                    try png.write(to: out.appendingPathComponent("mobile-page.png"))
                }
                print("PASS: 33 rendered motion frames, finite physics, scratch reveal at 60%, pause pixels identical, light theme, 390px layout, no runtime errors")
                fflush(stdout)
                NSApplication.shared.terminate(nil)
            } catch {
                print("FAIL: \(error)")
                if let text = try? await self.js("document.body.innerText") { print(text) }
                fflush(stdout)
                exit(1)
            }
        }
    }
}
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    let harness = Harness()
    let window = NSWindow(contentRect: CGRect(x: -2400, y: 0, width: 1100, height: 1000), styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = harness.web
    window.orderFront(nil)
    DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
        print("TIMEOUT: url=\(harness.web.url?.absoluteString ?? "nil") loading=\(harness.web.isLoading)")
        fflush(stdout)
        exit(2)
    }
    harness.web.loadFileURL(URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath + "/index.html"), allowingReadAccessTo: URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath + "/index.html").deletingLastPathComponent())
    withExtendedLifetime((harness, window)) { app.run() }
}
