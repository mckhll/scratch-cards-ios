import AppKit
import WebKit
import Foundation

@MainActor final class Harness: NSObject, WKNavigationDelegate {
    let web: WKWebView
    let out = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    var ran = false
    override init() {
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(WKUserScript(source: """
        document.addEventListener('DOMContentLoaded',()=>{const s=document.createElement('style');s.textContent='*{transition:none!important}';document.head.appendChild(s)});
        window.__clock=0;window.__raf=[];window.requestAnimationFrame=cb=>{__raf.push(cb);return __raf.length};
        Object.defineProperty(document,'hidden',{get:()=>false});Object.defineProperty(performance,'now',{value:()=>__clock});
        window.__advance=n=>{for(let i=0;i<n;i++){__clock+=1000/60;const q=__raf.splice(0);q.forEach(cb=>cb(__clock));}};
        HTMLCanvasElement.prototype.setPointerCapture=function(){};HTMLCanvasElement.prototype.hasPointerCapture=function(){return false};
        """, injectionTime:.atDocumentStart,forMainFrameOnly:true))
        web=WKWebView(frame:CGRect(x:0,y:0,width:1230,height:1000),configuration:config)
        super.init();web.navigationDelegate=self
    }
    func js(_ value:String) async throws -> Any? {try await web.evaluateJavaScript(value)}
    func check(_ condition:Bool,_ message:String) throws {if !condition {throw NSError(domain:message,code:1)}}
    func image(_ id:String,_ name:String) async throws {
        let dataURL=try await js("coverCollection.render();coverCollection.image('\(id)')") as! String
        try Data(base64Encoded:String(dataURL.split(separator:",",maxSplits:1)[1]))!.write(to:out.appendingPathComponent(name+".png"))
    }
    func page(_ name:String) async throws {
        let config=WKSnapshotConfiguration();config.rect=web.bounds
        let image=try await web.takeSnapshot(configuration:config)
        let bitmap=NSBitmapImageRep(data:image.tiffRepresentation!)!
        try bitmap.representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent(name+".png"))
    }
    func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!) {
        guard !ran else{return};ran=true
        Task { @MainActor in
            do {
                try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
                try await Task.sleep(nanoseconds:200_000_000)
                try check((try await js("!!window.coverCollection")) as? Bool == true,"API missing")
                _=try await js("coverCollection.setVisible();coverCollection.setReduced(false);__advance(90);coverCollection.render()")
                try await page("gallery-desktop")
                let ids=["emoji","stickers","dust"]
                for id in ids {
                    _=try await js("if(coverCollection.select)coverCollection.select('\(id)');coverCollection.setVisible()")
                    try await image(id,"\(id)-idle")
                    _=try await js("coverCollection.setPlay(true)")
                    _=try await js("(()=>{const c=document.querySelector('[data-style=\"\(id)\"] canvas'),r=c.getBoundingClientRect();c.dispatchEvent(new PointerEvent('pointerdown',{clientX:r.left+r.width*.45,clientY:r.top+r.height*.35,pointerId:3,bubbles:true}));__advance(25);c.dispatchEvent(new PointerEvent('pointerup',{pointerId:3,bubbles:true}));})()")
                    try check((try await js("coverCollection.snapshot().find(c=>c.id==='\(id)').progress")) as? Double == 0,"Play mode erases \(id)")
                    try await image(id,"\(id)-touch")
                    _=try await js("coverCollection.setPlay(false);coverCollection.reset('\(id)')")
                    let gesture="""
                    (()=>{coverCollection.setVisible();const c=document.querySelector('[data-style=\"\(id)\"] canvas');
                    function event(type,x,y){const r=c.getBoundingClientRect();c.dispatchEvent(new PointerEvent(type,{clientX:r.left+x/360*r.width,clientY:r.top+y/460*r.height,pointerId:1,pointerType:'touch',bubbles:true}));}
                    event('pointerdown',25,75);for(let i=0;i<=24;i++){event('pointermove',25+i*12,75+Math.sin(i/24*Math.PI)*60);__advance(1)}event('pointerup',313,75);__advance(8);return coverCollection.snapshot().find(c=>c.id==='\(id)');})()
                    """
                    let partial=try await js(gesture) as! [String:Any]
                    try check((partial["progress"] as! Double)>0 && !(partial["complete"] as! Bool),"Partial scratch \(id)")
                    try await image(id,"\(id)-partial")
                    _=try await js("coverCollection.reset('\(id)');coverCollection.demo('\(id)')")
                    for index in 0...16 {
                        if index>0 {_=try await js("__advance(24)")}
                        let states=try await js("coverCollection.snapshot()") as! [[String:Any]]
                        try check(states.allSatisfy{$0["finite"] as? Bool == true},"Non-finite physics")
                        try await image(id,String(format:"\(id)-motion-%02d",index))
                    }
                    let final=(try await js("coverCollection.snapshot().find(c=>c.id==='\(id)')")) as! [String:Any]
                    try check(final["complete"] as? Bool == true,"Demo did not finish \(id)")
                    try await image(id,"\(id)-revealed")
                    _=try await js("coverCollection.reset('\(id)')")
                }
                _=try await js("coverCollection.setPaused(true);__advance(90);coverCollection.render()")
                let a=try await js("coverCollection.image('dust')") as! String
                _=try await js("__advance(60);coverCollection.render()")
                let b=try await js("coverCollection.image('dust')") as! String
                try check(a==b,"Ambient pause changes pixels")
                _=try await js("coverCollection.setPaused(false);coverCollection.setReduced(true);coverCollection.demo('emoji');__advance(390);coverCollection.render()")
                try check((try await js("coverCollection.snapshot().find(c=>c.id==='emoji').complete")) as? Bool == true,"Reduced motion reveal")
                _=try await js("coverCollection.reset('emoji');coverCollection.setReduced(false)")
                if (try await js("!!coverCollection.select")) as? Bool == true {
                    _=try await js("coverCollection.select('emoji');document.getElementById('appearance').click();document.getElementById('caption').click();coverCollection.render()")
                    try await Task.sleep(nanoseconds:250_000_000)
                    try await page("chat-light-caption")
                    _=try await js("document.getElementById('appearance').click();document.getElementById('caption').click();coverCollection.render()")
                    try await Task.sleep(nanoseconds:250_000_000)
                    try await page("chat-dark")
                }
                web.frame=CGRect(x:0,y:0,width:390,height:1100)
                try await Task.sleep(nanoseconds:150_000_000)
                _=try await js("coverCollection.setVisible();__advance(3);coverCollection.render()")
                try check((try await js("document.documentElement.scrollWidth<=window.innerWidth")) as? Bool == true,"Mobile overflow")
                try await page("gallery-mobile")
                _=try await js("""
                (()=>{const c=document.createElement('canvas');c.width=c.height=8;const x=c.getContext('2d');x.fillStyle='#1267cc';x.fillRect(0,0,8,8);const bytes=Uint8Array.from(atob(c.toDataURL().split(',')[1]),v=>v.charCodeAt(0));const dt=new DataTransfer();dt.items.add(new File([bytes],'local-test.png',{type:'image/png'}));const input=document.getElementById('photo');input.files=dt.files;input.dispatchEvent(new Event('change'));})()
                """)
                try await Task.sleep(nanoseconds:200_000_000)
                try check((try await js("coverCollection.hasPhoto()")) as? Bool == true,"Local photo input")
                _=try await js("coverCollection.setVisible();coverCollection.demo('emoji');__advance(390);coverCollection.render()")
                let pixel=try await js("Array.from(document.querySelector('[data-style=emoji] canvas').getContext('2d').getImageData(10,10,1,1).data)") as! [Int]
                try check(pixel == [18,103,204,255],"Local photo not rendered")
                try check((try await js("document.querySelector('.error')?.textContent||''")) as? String == "","Browser runtime error")
                print("PASS: three directions; touch without erasing; real pointer strokes; partial masks; 51 motion frames; all 60% completions; reset; ambient pause; Reduce Motion; mobile layout; local photo input")
                fflush(stdout);NSApplication.shared.terminate(nil)
            } catch {print("FAIL: \(error)");fflush(stdout);exit(1)}
        }
    }
}
MainActor.assumeIsolated {
    let app=NSApplication.shared;app.setActivationPolicy(.prohibited)
    let harness=Harness(),window=NSWindow(contentRect:CGRect(x:-2800,y:0,width:1230,height:1000),styleMask:[.borderless],backing:.buffered,defer:false)
    window.contentView=harness.web;window.orderFront(nil)
    let file=URL(fileURLWithPath:CommandLine.arguments[1])
    harness.web.loadFileURL(file,allowingReadAccessTo:file.deletingLastPathComponent())
    DispatchQueue.main.asyncAfter(deadline:.now()+55){print("TIMEOUT");fflush(stdout);exit(2)}
    withExtendedLifetime((harness,window)){app.run()}
}
