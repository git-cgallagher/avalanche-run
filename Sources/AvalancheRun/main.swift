import AppKit
import SpriteKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    private var window: NSWindow!
    private var skView: SKView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMenu()
        let snapshotDir = ProcessInfo.processInfo.environment["AVALANCHE_SNAPSHOT_DIR"]
        if snapshotDir != nil {
            let suite = "net.cgallagher.avalancherun.snapshot"
            UserDefaults().removePersistentDomain(forName: suite)
            Store.defaults = UserDefaults(suiteName: suite) ?? .standard
        }
        _ = Sound.shared  // synthesize audio before the first frame
        if snapshotDir != nil { Sound.shared.silenceOutput() }

        let size = CGSize(width: 1024, height: 768)
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Avalanche Run"
        window.contentAspectRatio = size
        window.delegate = self

        skView = SKView(frame: NSRect(origin: .zero, size: size))
        skView.ignoresSiblingOrder = true
        window.contentView = skView

        let scene = GameScene(size: size)
        scene.scaleMode = .aspectFit
        skView.presentScene(scene)

        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(skView)
        NSApp.activate()

        if let snapshotDir {
            print("audio engine running: \(Sound.shared.isRunning)")
            runSnapshotScript(into: URL(fileURLWithPath: snapshotDir))
        }
    }

    /// Dev aid: starts a run, holds tuck, weaves and jumps, then types a high-score name,
    /// snapshotting along the way, at Turbo speed. Add AVALANCHE_DEBUG_CREATURES=1 to meet every creature early,
    /// and AVALANCHE_DEBUG_PRIZES=1 for frequent prize boxes in the skier's line.
    private func runSnapshotScript(into dir: URL) {
        func key(_ code: UInt16, _ chars: String = "", down: Bool = true) {
            guard let scene = skView.scene, let event = NSEvent.keyEvent(
                with: down ? .keyDown : .keyUp, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, characters: chars, charactersIgnoringModifiers: chars,
                isARepeat: false, keyCode: code) else { return }
            down ? scene.keyDown(with: event) : scene.keyUp(with: event)
        }
        func at(_ t: Double, _ action: @escaping @MainActor () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { MainActor.assumeIsolated { action() } }
        }
        func shot(_ name: String) { (skView.scene as? GameScene)?.snapshot(to: dir.appendingPathComponent("\(name).png")) }

        at(1.0) { key(5); key(5) }  // G twice: Normal → Fast → Turbo
        at(1.5) { shot("00-title") }
        at(2.0) { key(49); key(49, down: false); key(125) }
        for i in 1...26 {
            let t = 2.0 + Double(i) * 0.7
            at(t) { shot(String(format: "%02d-run", i)) }
            // Weave and hop so there's something to see.
            if i % 3 == 0 { at(t + 0.1) { key(i % 2 == 0 ? 123 : 124) } }
            if i % 3 == 0 { at(t + 0.4) { key(i % 2 == 0 ? 123 : 124, down: false) } }
            if i % 4 == 0 { at(t + 0.2) { key(49); key(49, down: false) } }
        }
        // Once buried, wait for the name prompt, sign the board, and quit.
        func waitForNaming(_ tries: Int) {
            guard let scene = skView.scene as? GameScene, tries < 200 else { NSApp.terminate(nil); return }
            guard scene.state == .naming else { at(0.25) { waitForNaming(tries + 1) }; return }
            for ch in "CLAUDE" { key(0, String(ch)) }
            at(0.3) { shot("90-name") }
            at(0.6) { key(36) }
            at(1.0) { shot("91-board") }
            at(1.4) { NSApp.terminate(nil) }
        }
        at(20.5) { key(125, down: false) }  // stop tucking so the avalanche catches up
        at(21.0) { key(126) }
        at(21.0) { waitForNaming(0) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // Key-up events are lost while another app has focus, so drop held keys and pause.
    func windowDidResignKey(_ notification: Notification) {
        (skView.scene as? GameScene)?.focusLost()
    }

    @objc private func setSpeed(_ sender: NSMenuItem) {
        Settings.speedIndex = sender.tag
        (skView.scene as? GameScene)?.speedChanged()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(setSpeed(_:)) { menuItem.state = menuItem.tag == Settings.speedIndex ? .on : .off }
        return true
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Avalanche Run", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Avalanche Run", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit Avalanche Run", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)

        let gameItem = NSMenuItem()
        let gameMenu = NSMenu(title: "Game")
        for (i, speed) in Settings.speeds.enumerated() {
            let item = NSMenuItem(title: "Speed: \(speed.label)", action: #selector(setSpeed(_:)), keyEquivalent: "\(i + 1)")
            item.tag = i
            item.target = self
            gameMenu.addItem(item)
        }
        gameItem.submenu = gameMenu
        menu.addItem(gameItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        let fullScreen = NSMenuItem(title: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullScreen.keyEquivalentModifierMask = [.command, .control]
        windowMenu.addItem(fullScreen)
        windowItem.submenu = windowMenu
        menu.addItem(windowItem)

        return menu
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
