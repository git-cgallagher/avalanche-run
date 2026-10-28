import AppKit
import SpriteKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var skView: SKView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMenu()

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

        if let dir = ProcessInfo.processInfo.environment["AVALANCHE_SNAPSHOT_DIR"] {
            runSnapshotScript(into: URL(fileURLWithPath: dir))
        }
    }

    /// Dev aid: starts a run, holds tuck and weaves, and snapshots along the way.
    private func runSnapshotScript(into dir: URL) {
        func key(_ code: UInt16, down: Bool) {
            guard let scene = skView.scene, let event = NSEvent.keyEvent(
                with: down ? .keyDown : .keyUp, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil, characters: "", charactersIgnoringModifiers: "",
                isARepeat: false, keyCode: code) else { return }
            down ? scene.keyDown(with: event) : scene.keyUp(with: event)
        }
        func at(_ t: Double, _ action: @escaping @MainActor () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { MainActor.assumeIsolated { action() } }
        }
        func shot(_ name: String) { (skView.scene as? GameScene)?.snapshot(to: dir.appendingPathComponent("\(name).png")) }

        at(1.5) { shot("1-title") }
        at(2.0) { key(49, down: true); key(49, down: false); key(125, down: true) }
        at(3.5) { key(124, down: true) }
        at(3.8) { key(124, down: false) }
        at(4.5) { shot("2-running") }
        at(5.0) { key(123, down: true) }
        at(5.6) { key(123, down: false) }
        at(7.0) { shot("3-later") }
        at(10.0) { shot("4-later") }
        at(16.0) { shot("5-end") }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // Key-up events are lost while another app has focus, so drop held keys and pause.
    func windowDidResignKey(_ notification: Notification) {
        (skView.scene as? GameScene)?.focusLost()
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
