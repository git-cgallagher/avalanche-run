import AppKit
import SpriteKit

enum Key {
    static let left: Set<UInt16> = [123, 0]     // ←, A
    static let right: Set<UInt16> = [124, 2]    // →, D
    static let tuck: Set<UInt16> = [125, 1]     // ↓, S
    static let brake: Set<UInt16> = [126, 13]   // ↑, W
    static let jump: UInt16 = 49                // Space
    static let pause: Set<UInt16> = [35, 53]    // P, Esc
    static let confirm: Set<UInt16> = [36, 76]  // Return, keypad Enter
    static let restart: UInt16 = 15             // R
    static let sound: UInt16 = 46               // M
    static let scores: UInt16 = 4               // H
    static let delete: UInt16 = 51              // Backspace
    static let speed: UInt16 = 5                // G
}

/// Gameplay tuning. Distances are scene points; 10 points = 1 meter.
enum Tune {
    static let halfWidth: CGFloat = 1100      // the run is 2,200 pt wide
    static let maxHeading: CGFloat = 1.35     // ~77° from straight downhill
    static let steerRate: CGFloat = 2.8       // rad/s
    static let gravity: CGFloat = 400
    static let drag: CGFloat = 0.42
    static let tuckBoost: CGFloat = 1.4
    static let brake: CGFloat = 560
    static let maxSpeed: CGFloat = 1250
    static let jumpAir: CGFloat = 0.5         // seconds aloft from a Space jump
    static let spinRate: CGFloat = 12         // rad/s while airborne
    static let landingSlop: CGFloat = 0.8     // radians off straight that still lands clean
    static let grabTime: CGFloat = 0.25       // seconds of ↓ in the air that count as a grab
    static let grabMinAir: CGFloat = 0.8      // grabs only count on ramp-sized air, so hops can't farm them
    static let comboWindow: CGFloat = 3       // seconds to chain the next trick
    static let maxMultiplier = 8
    static let pointsPerMeter: CGFloat = 10
    static let lookAhead: CGFloat = 200       // skier sits this far above screen center
    static let maxGap: CGFloat = 1200         // avalanche never falls further behind than this
    static let rowSpacing: CGFloat = 80
    static let creaturesFrom = 200            // meters before the locals start showing up
    static let prizeSpacing: ClosedRange<CGFloat> = 1200...2200  // points between prize boxes (120–220 m)
    static let prizePush: CGFloat = 500       // a distance prize shoves the avalanche back 50 m
    static let prizeFreeze: CGFloat = 4       // a time prize stops the avalanche for this many seconds
}

final class GameScene: SKScene {
    enum State { case title, scores, playing, paused, buried, naming, over }

    final class Obstacle {
        enum Kind { case tree, rock, mogul, ramp, gate, prize, decor }
        let kind: Kind
        let node: SKNode
        let radius: CGFloat
        var used = false

        init(_ kind: Kind, _ node: SKNode, radius: CGFloat) {
            self.kind = kind
            self.node = node
            self.radius = radius
        }
    }

    /// Set on a restarted scene so it skips the title card.
    var autostart = false
    /// Dev aid: creatures from the first second, cycling through every kind.
    let debugCreatures = ProcessInfo.processInfo.environment["AVALANCHE_DEBUG_CREATURES"] != nil
    /// Dev aid: a prize box dropped straight ahead of the skier every 2 s.
    private let debugPrizes = ProcessInfo.processInfo.environment["AVALANCHE_DEBUG_PRIZES"] != nil

    var state = State.title
    let world = SKNode()
    let cam = SKCameraNode()
    var camBase = CGPoint.zero
    private let skier = SKNode()
    private let skierArt = Art.skier()
    private let skierShadow = Art.ellipse(26, 10, fill: Palette.shade)
    private let avalanche = SKNode()
    private let overlay = SKNode()
    private let distanceLabel = GameScene.label("", size: 28)
    private let scoreLabel = GameScene.label("", size: 28)
    private let bestLabel = GameScene.label("", size: 15, bold: false)
    private let comboLabel = GameScene.label("", size: 20)
    private let comboBar = SKSpriteNode(color: Palette.gate, size: CGSize(width: 120, height: 5))
    private let meterFill = SKSpriteNode(color: Palette.gate, size: CGSize(width: 236, height: 8))
    private let meterTitle = GameScene.label("AVALANCHE GAP", size: 13)
    private let speedTag = GameScene.label("", size: 15)
    private var nameLabel: SKLabelNode?
    private var textures: [String: (SKTexture, CGPoint)] = [:]
    private static let trackFade = SKAction.sequence([.wait(forDuration: 1.5), .fadeOut(withDuration: 1.0), .removeFromParent()])

    var pos = CGPoint.zero
    var heading: CGFloat = 0
    var vel: CGFloat = 0
    var airLeft: CGFloat = 0
    private var airTotal: CGFloat = 0
    var canSpin = false  // true for real jumps; mogul bumps can't be spun or count as clears
    private var spin: CGFloat = 0
    private var grabTime: CGFloat = 0
    var stun: CGFloat = 0
    private var avY: CGFloat = 540
    private var spawnedTo: CGFloat = 0
    private var obstacles: [Obstacle] = []
    private var keys = Set<UInt16>()
    private var lastTime: TimeInterval = 0
    private var points = 0
    private var comboChain = 0
    private var comboTimer: CGFloat = 0
    var shake: CGFloat = 0
    private var overTimer: CGFloat = 0
    private var popupSlot = 0
    private var playerName = ""
    private var nextPrizeY: CGFloat = -900
    private var frozenTime: CGFloat = 0
    private var debugPrizeTimer: CGFloat = 2
    private var slowestSpeed = 1.0  // the leaderboard records the slowest speed used in a run

    var creatures: [Creature] = []
    var snowballs: [Snowball] = []
    var nextAttack: CGFloat = .random(in: 3...7)
    var lastCreature: Creature.Kind?
    var attackCount = 0

    var meters: Int { Int(max(0, -pos.y) / Tune.pointsPerMeter) }
    private var score: Int { meters + points }
    private var multiplier: Int { min(1 + comboChain, Tune.maxMultiplier) }

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = Palette.snow
        bakeTextures(in: view)
        addChild(world)
        camera = cam
        addChild(cam)

        skierShadow.zPosition = 9
        world.addChild(skierShadow)
        skier.addChild(skierArt)
        world.addChild(skier)

        buildAvalanche()
        buildHUD()
        buildSnowfall()
        spawnRows()
        updateSkierVisuals()
        updateCamera(dt: 0, snap: true)
        updateHUD()
        if debugCreatures { nextAttack = 1.2 }
        Sound.shared.startMusic()

        if autostart { start() } else { showTitle() }
    }

    private func bakeTextures(in view: SKView) {
        let art: [String: SKNode] = [
            "tree": Art.tree(), "rock": Art.rock(), "mogul": Art.mogul(), "ramp": Art.ramp(),
            "poleL": Art.gatePole(flagRight: true), "poleR": Art.gatePole(flagRight: false),
            "post": Art.post(), "dimple": Art.dimple(),
            "penguin": Art.penguin(), "bear": Art.polarBear(), "yeti": Art.yeti(), "narwhal": Art.narwhal(),
            "snowball": Art.snowball(), "prize": Art.prizeBox(),
        ]
        for (name, node) in art {
            let frame = node.calculateAccumulatedFrame()
            guard let texture = view.texture(from: node) else { continue }
            let anchor = CGPoint(x: -frame.minX / frame.width, y: -frame.minY / frame.height)
            textures[name] = (texture, anchor)
        }
    }

    func sprite(_ name: String) -> SKSpriteNode {
        guard let (texture, anchor) = textures[name] else { return SKSpriteNode() }
        let sprite = SKSpriteNode(texture: texture)
        sprite.anchorPoint = anchor
        return sprite
    }

    private func buildAvalanche() {
        func front(depth: CGFloat, seed: Int) -> CGPath {
            var rng = SeededRandom(seed: UInt64(seed))
            let w: CGFloat = 1800
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -w, y: 1800))
            path.addLine(to: CGPoint(x: -w, y: 0))
            var x = -w
            while x < w {
                let step = CGFloat.random(in: 50...110, using: &rng)
                let bulge = CGFloat.random(in: 0.5...1.0, using: &rng) * depth
                path.addQuadCurve(to: CGPoint(x: x + step, y: 0), control: CGPoint(x: x + step / 2, y: -bulge * 2))
                x += step
            }
            path.addLine(to: CGPoint(x: x, y: 1800))
            path.closeSubpath()
            return path
        }

        let back = Art.shape(front(depth: 30, seed: 7), fill: Palette.shade)
        back.position = CGPoint(x: 0, y: -14)
        back.run(.repeatForever(.sequence([
            .moveBy(x: 24, y: -6, duration: 0.7), .moveBy(x: -24, y: 6, duration: 0.7),
        ])))
        avalanche.addChild(back)
        avalanche.addChild(Art.shape(front(depth: 24, seed: 3), fill: .white, stroke: Palette.shade, width: 2))

        let puffs = SKEmitterNode()
        puffs.particleTexture = Art.dotTexture(radius: 10)
        puffs.particleBirthRate = 160
        puffs.particleLifetime = 0.9
        puffs.particlePositionRange = CGVector(dx: 2400, dy: 10)
        puffs.position = CGPoint(x: 0, y: -18)
        puffs.emissionAngle = -.pi / 2
        puffs.emissionAngleRange = 0.8
        puffs.particleSpeed = 110
        puffs.particleSpeedRange = 60
        puffs.particleScale = 0.9
        puffs.particleScaleRange = 0.6
        puffs.particleAlpha = 0.9
        puffs.particleAlphaSpeed = -1.0
        puffs.particleColor = .white
        puffs.particleColorBlendFactor = 1
        puffs.zPosition = -1
        avalanche.addChild(puffs)

        avalanche.zPosition = 60
        addChild(avalanche)
    }

    private func buildHUD() {
        distanceLabel.horizontalAlignmentMode = .left
        distanceLabel.position = CGPoint(x: -490, y: 350)
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.position = CGPoint(x: 490, y: 350)
        bestLabel.horizontalAlignmentMode = .right
        bestLabel.position = CGPoint(x: 490, y: 322)
        bestLabel.fontColor = Palette.ink.withAlphaComponent(0.6)

        let meterBack = SKShapeNode(rectOf: CGSize(width: 244, height: 16), cornerRadius: 8)
        meterBack.fillColor = SKColor(white: 1, alpha: 0.85)
        meterBack.strokeColor = Palette.shade
        meterBack.lineWidth = 2
        meterBack.position = CGPoint(x: 0, y: 354)
        meterFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        meterFill.position = CGPoint(x: -118, y: 0)
        meterBack.addChild(meterFill)
        meterTitle.fontColor = Palette.ink.withAlphaComponent(0.6)
        meterTitle.position = CGPoint(x: 0, y: 330)

        speedTag.horizontalAlignmentMode = .left
        speedTag.position = CGPoint(x: -490, y: 322)
        speedTag.fontColor = Palette.amber

        comboLabel.fontColor = Palette.gate
        comboLabel.horizontalAlignmentMode = .right
        comboLabel.position = CGPoint(x: 490, y: 294)
        comboBar.anchorPoint = CGPoint(x: 1, y: 0.5)
        comboBar.position = CGPoint(x: 490, y: 277)

        for node in [distanceLabel, scoreLabel, bestLabel, meterBack, meterTitle, speedTag, comboLabel, comboBar] as [SKNode] {
            node.zPosition = 100
            cam.addChild(node)
        }
        overlay.zPosition = 120
        overlay.isHidden = true
        cam.addChild(overlay)
    }

    private func buildSnowfall() {
        let snow = SKEmitterNode()
        snow.particleTexture = Art.dotTexture(radius: 6)
        snow.particleBirthRate = 50
        snow.particleLifetime = 10
        snow.particlePositionRange = CGVector(dx: 1300, dy: 0)
        snow.position = CGPoint(x: 0, y: 420)
        snow.emissionAngle = -.pi / 2 - 0.25
        snow.emissionAngleRange = 0.4
        snow.particleSpeed = 70
        snow.particleSpeedRange = 30
        snow.particleScale = 0.35
        snow.particleScaleRange = 0.25
        snow.particleAlpha = 0.9
        snow.particleColor = .white
        snow.particleColorBlendFactor = 1
        snow.zPosition = 80
        snow.advanceSimulationTime(10)
        cam.addChild(snow)
    }

    // MARK: - Course generation

    func depth(_ y: CGFloat) -> CGFloat { 10 + -y / 100_000 }

    @discardableResult
    private func place(_ name: String, _ kind: Obstacle.Kind, at p: CGPoint, radius: CGFloat = 0, scale: CGFloat = 1) -> Obstacle {
        let node = sprite(name)
        node.position = p
        node.setScale(scale)
        node.zPosition = kind == .decor && name == "dimple" ? 1 : depth(p.y)
        world.addChild(node)
        let obstacle = Obstacle(kind, node, radius: radius * scale)
        obstacles.append(obstacle)
        return obstacle
    }

    private func placeGate(at p: CGPoint) {
        let gate = SKNode()
        gate.position = p
        gate.zPosition = depth(p.y)
        let left = sprite("poleL")
        left.position = CGPoint(x: -70, y: 0)
        let right = sprite("poleR")
        right.position = CGPoint(x: 70, y: 0)
        gate.addChild(left)
        gate.addChild(right)
        world.addChild(gate)
        obstacles.append(Obstacle(.gate, gate, radius: 70))
    }

    private func spawnRows() {
        let w = Tune.halfWidth
        while spawnedTo > pos.y - 1000 {
            spawnedTo -= Tune.rowSpacing
            let y = spawnedTo
            let row = Int((-y / Tune.rowSpacing).rounded())

            // Run boundary: posts on the edge, forest beyond it.
            for side: CGFloat in [-1, 1] {
                if row % 2 == 0 { place("post", .decor, at: CGPoint(x: side * (w + 8), y: y)) }
                for _ in 0..<2 {
                    let p = CGPoint(x: side * (w + .random(in: 50...300)), y: y + .random(in: -40...40))
                    place("tree", .decor, at: p, scale: .random(in: 0.9...1.5))
                }
            }
            for _ in 0..<2 {
                place("dimple", .decor, at: CGPoint(x: .random(in: -w...w), y: y + .random(in: -40...40)))
            }

            if y < nextPrizeY {
                placePrize(at: CGPoint(x: CGFloat.random(in: (-w + 80)...(w - 80)), y: y))
                nextPrizeY -= CGFloat.random(in: Tune.prizeSpacing)
                continue
            }

            guard y < -450 else { continue }  // keep the start area clear
            let density = min(1.4 + -y / 9000, 5.0)
            var count = Int(density)
            if CGFloat.random(in: 0..<1) < density - CGFloat(count) { count += 1 }
            for _ in 0..<count {
                let p = CGPoint(x: .random(in: (-w + 40)...(w - 40)), y: y + .random(in: -30...30))
                switch Int.random(in: 0..<100) {
                case 0..<46: place("tree", .tree, at: p, radius: 13, scale: .random(in: 0.85...1.3))
                case 46..<62: place("rock", .rock, at: p, radius: 15, scale: .random(in: 0.8...1.2))
                case 62..<80: place("mogul", .mogul, at: p, radius: 24)
                case 80..<91: place("ramp", .ramp, at: p)
                default: placeGate(at: p)
                }
            }
        }
    }

    private func placePrize(at p: CGPoint) {
        let prize = place("prize", .prize, at: p, radius: 22)
        prize.node.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.45), .scale(to: 1, duration: 0.45)])))
    }

    private func cleanup() {
        let top = camBase.y + size.height / 2 + 120
        obstacles.removeAll { obstacle in
            guard obstacle.node.position.y > top else { return false }
            obstacle.node.removeFromParent()
            return true
        }
    }

    // MARK: - Input

    override func keyDown(with event: NSEvent) {
        let code = event.keyCode
        if state == .naming {
            typeName(event)
            return
        }
        keys.insert(code)
        guard !event.isARepeat else { return }
        if code == Key.sound {
            cycleSound()
            return
        }
        if code == Key.speed && (state == .title || state == .scores || state == .paused) {
            Settings.cycleSpeed()
            speedChanged()
            return
        }
        switch state {
        case .title:
            if code == Key.jump || Key.confirm.contains(code) { start() }
            if code == Key.scores { showScores() }
        case .scores:
            if code == Key.jump || Key.confirm.contains(code) { start() }
            if code == Key.scores || Key.pause.contains(code) { showTitle() }
        case .playing:
            if code == Key.jump { jump() }
            if Key.pause.contains(code) { setPaused(true) }
        case .paused:
            if Key.pause.contains(code) || code == Key.jump { setPaused(false) }
        case .over:
            if Key.confirm.contains(code) || code == Key.restart { restart() }
        case .buried, .naming:
            break
        }
    }

    override func keyUp(with event: NSEvent) {
        keys.remove(event.keyCode)
    }

    func focusLost() {
        keys.removeAll()
        if state == .playing { setPaused(true) }
    }

    private func held(_ set: Set<UInt16>) -> Bool { !keys.isDisjoint(with: set) }

    private func cycleSound() {
        let sound = Sound.shared
        sound.mode = Sound.Mode(rawValue: (sound.mode.rawValue + 1) % 3) ?? .all
        popup(sound.mode.label, color: Palette.ink)
        Sound.shared.play(.blip)
    }

    /// Called after the speed setting changes, from the G key or the Game menu.
    func speedChanged() {
        popup("Speed: \(Settings.speed.label)", color: Palette.ink)
        Sound.shared.play(.blip)
        if state == .title { showTitle() }
        if state == .paused { showPause() }
    }

    // MARK: - Game flow

    private func start() {
        slowestSpeed = Settings.speed.multiplier
        state = .playing
        overlay.isHidden = true
    }

    private func setPaused(_ paused: Bool) {
        if paused {
            state = .paused
            showPause()
        } else {
            state = .playing
            overlay.isHidden = true
        }
        Sound.shared.pauseMusic(paused)
    }

    private func restart() {
        guard let view else { return }
        let next = GameScene(size: size)
        next.scaleMode = scaleMode
        next.autostart = true
        view.presentScene(next, transition: .crossFade(withDuration: 0.35))
    }

    private func bury() {
        state = .buried
        overTimer = 0
        vel = 0
        keys.removeAll()
        comboChain = 0
        skier.run(.fadeOut(withDuration: 0.4))
        skierShadow.run(.fadeOut(withDuration: 0.4))
        Sound.shared.stopMusic()
        Sound.shared.play(.buried)
    }

    private func finishRun() {
        if Leaderboard.qualifies(score) {
            state = .naming
            playerName = Leaderboard.lastName
            showNameEntry()
            Sound.shared.play(.highScore)
        } else {
            state = .over
            showLeaderboard(title: "BURIED!", subtitle: "\(meters.formatted()) m  ·  score \(score.formatted())\(speedNote)",
                            highlight: nil, footer: "Press Return to ski again")
        }
    }

    private func typeName(_ event: NSEvent) {
        let code = event.keyCode
        if Key.confirm.contains(code) {
            commitName()
            return
        }
        if code == Key.delete {
            guard !playerName.isEmpty else { return }
            playerName.removeLast()
        } else if let ch = event.charactersIgnoringModifiers?.uppercased().first, playerName.count < 12,
                  ch.isLetter || ch.isNumber || " -.'".contains(ch) {
            playerName.append(ch)
        } else {
            return
        }
        Sound.shared.play(.blip, volume: 0.6)
        nameLabel?.text = playerName + "_"
    }

    private func commitName() {
        var name = playerName.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { name = "SKIER" }
        Leaderboard.lastName = name
        let rank = Leaderboard.record(ScoreEntry(name: name, score: score, meters: meters, date: Date(), speed: slowestSpeed))
        state = .over
        Sound.shared.play(.trick)
        showLeaderboard(title: "HIGH SCORES", subtitle: "\(name) takes #\(rank + 1)",
                        highlight: rank, footer: "Press Return to ski again")
    }

    // MARK: - Overlays

    private func showTitle() {
        state = .title
        showPanel(title: "AVALANCHE RUN", lines: [
            "Outrun the avalanche. Ski as far as you can.",
            "← →  steer     ↓  tuck     ↑  brake     Space  jump",
            "In the air: hold ← → to spin, ↓ to grab. Chain tricks for combos.",
            "Watch out for the locals. Jump them for big points.",
            "",
            "Space  start     H  high scores     M  sound",
            "G  game speed: \(Settings.speed.label)",
        ])
    }

    private func showPause() {
        showPanel(title: "PAUSED", lines: ["Press P to keep skiing", "G  game speed: \(Settings.speed.label)"])
    }

    /// " · Turbo" when the run wasn't at normal speed.
    private var speedNote: String {
        slowestSpeed == 1 ? "" : "  ·  \(Settings.name(forMultiplier: slowestSpeed))"
    }

    private func showScores() {
        state = .scores
        showLeaderboard(title: "HIGH SCORES", subtitle: nil, highlight: nil, footer: "Space  start     H  back")
    }

    private func showNameEntry() {
        let rank = Leaderboard.rank(for: score)
        presentPanel { y, content in
            addLine("NEW HIGH SCORE!", size: 44, to: content, y: &y)
            addLine("#\(rank + 1)  ·  \(score.formatted()) points  ·  \(meters.formatted()) m\(speedNote)", size: 19, bold: false, to: content, y: &y)
            y -= 8
            nameLabel = addLine(playerName + "_", size: 34, font: "Menlo-Bold", color: Palette.gate, to: content, y: &y)
            y -= 8
            addLine("Type your name, then press Return", size: 17, bold: false, to: content, y: &y)
        }
    }

    private func showPanel(title: String, lines: [String]) {
        presentPanel { y, content in
            addLine(title, size: 48, to: content, y: &y)
            y -= 6
            for line in lines { addLine(line, size: 19, bold: false, to: content, y: &y) }
        }
    }

    private func showLeaderboard(title: String, subtitle: String?, highlight: Int?, footer: String) {
        let entries = Leaderboard.entries
        presentPanel { y, content in
            addLine(title, size: 44, to: content, y: &y)
            if let subtitle { addLine(subtitle, size: 19, bold: false, to: content, y: &y) }
            y -= 10
            if entries.isEmpty {
                addLine("No scores yet. Go set one!", size: 17, bold: false, to: content, y: &y)
            }
            for (i, entry) in entries.enumerated() {
                y -= 14
                let color = i == highlight ? Palette.gate : Palette.ink
                let columns: [(String, CGFloat, SKLabelHorizontalAlignmentMode)] = [
                    ("\(i + 1).", -200, .right), (entry.name, -185, .left),
                    (entry.speed.map { $0 == 1 ? "" : Settings.name(forMultiplier: $0) } ?? "", 40, .right),
                    ("\(entry.meters.formatted()) m", 130, .right), (entry.score.formatted(), 260, .right),
                ]
                for (text, x, alignment) in columns {
                    let cell = GameScene.label(text, size: 18, font: "Menlo-Bold")
                    cell.fontColor = color
                    cell.horizontalAlignmentMode = alignment
                    cell.position = CGPoint(x: x, y: y)
                    content.addChild(cell)
                }
                y -= 14
            }
            y -= 12
            addLine(footer, size: 17, bold: false, to: content, y: &y)
        }
    }

    /// Lays lines out top-down with `build`, then sizes a rounded panel to fit and centers it.
    private func presentPanel(_ build: (inout CGFloat, SKNode) -> Void) {
        overlay.removeAllChildren()
        nameLabel = nil
        let content = SKNode()
        var y: CGFloat = 0
        build(&y, content)
        let height = -y + 64
        let panel = SKShapeNode(rectOf: CGSize(width: 680, height: height), cornerRadius: 20)
        panel.fillColor = SKColor(white: 1, alpha: 0.92)
        panel.strokeColor = Palette.shade
        panel.lineWidth = 2
        overlay.addChild(panel)
        content.position = CGPoint(x: 0, y: height / 2 - 32)
        overlay.addChild(content)
        overlay.isHidden = false
    }

    @discardableResult
    private func addLine(_ text: String, size: CGFloat, bold: Bool = true, font: String? = nil,
                         color: SKColor = Palette.ink, to content: SKNode, y: inout CGFloat) -> SKLabelNode {
        let label = GameScene.label(text, size: size, bold: bold, font: font)
        label.fontColor = color
        y -= size * 0.75
        label.position = CGPoint(x: 0, y: y)
        y -= size * 0.75
        content.addChild(label)
        return label
    }

    // MARK: - Simulation

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 1.0 / 60 : CGFloat(min(currentTime - lastTime, 1.0 / 30))
        lastTime = currentTime
        let rate = CGFloat(Settings.speed.multiplier)
        speed = rate  // SKAction animations follow the game speed too
        let simDt = dt * rate
        switch state {
        case .playing:
            // Substep at 60 Hz or finer so fast speeds can't tunnel through trees.
            let steps = max(1, Int((simDt * 60 - 0.01).rounded(.up)))
            for _ in 0..<steps where state == .playing { step(simDt / CGFloat(steps)) }
        case .buried: stepBuried(simDt)
        default: Sound.shared.setRumble(0)
        }
        updateCamera(dt: dt)
        updateHUD()
    }

    private func step(_ dt: CGFloat) {
        let prevY = pos.y
        slowestSpeed = min(slowestSpeed, Settings.speed.multiplier)

        if stun > 0 {
            stun -= dt
            if stun <= 0 {
                skierArt.removeAllActions()
                skierArt.zRotation = 0
            }
        } else if airLeft > 0 {
            let grabbing = canSpin && held(Key.tuck)
            if canSpin {
                if held(Key.left) { spin -= Tune.spinRate * dt }
                if held(Key.right) { spin += Tune.spinRate * dt }
                if grabbing { grabTime += dt }
            }
            skierArt.yScale = grabbing ? 0.8 : 1
            airLeft -= dt
            if airLeft <= 0 { land() }
        } else {
            if held(Key.left) { heading -= Tune.steerRate * dt }
            if held(Key.right) { heading += Tune.steerRate * dt }
            heading = max(-Tune.maxHeading, min(Tune.maxHeading, heading))
            var accel = Tune.gravity * cos(heading) * (held(Key.tuck) ? Tune.tuckBoost : 1) - Tune.drag * vel
            if held(Key.brake) { accel -= Tune.brake }
            vel = max(0, min(Tune.maxSpeed, vel + accel * dt))
        }

        pos.x += vel * sin(heading) * dt
        pos.y -= vel * cos(heading) * dt

        let limit = Tune.halfWidth - 24
        if abs(pos.x) > limit {
            pos.x = pos.x > 0 ? limit : -limit
            heading = (pos.x > 0 ? -1 : 1) * abs(heading) * 0.5
            vel *= 0.85
        }

        // The combo clock only runs while you're on the ground.
        if comboChain > 0 && airLeft <= 0 {
            comboTimer -= dt
            if comboTimer <= 0 { comboChain = 0 }
        }

        if debugPrizes {
            debugPrizeTimer -= dt
            if debugPrizeTimer <= 0 {
                debugPrizeTimer = 2
                placePrize(at: CGPoint(x: pos.x + sin(heading) * 300, y: pos.y - cos(heading) * 300))
            }
        }
        collide(prevY: prevY)
        updateCreatures(dt)
        layTracks(dt)
        updateSkierVisuals()

        if frozenTime > 0 { frozenTime = max(0, frozenTime - dt) }
        let avalancheSpeed: CGFloat = frozenTime > 0 ? 0 : min(320 + -pos.y * 0.014, 860)
        avY = min(avY - avalancheSpeed * dt, pos.y + Tune.maxGap)
        avalanche.alpha = frozenTime > 0 ? 0.75 : 1
        let gap = avY - pos.y
        if gap < 420 && frozenTime <= 0 { shake = max(shake, (420 - gap) / 420 * 6) }
        let rumble = Float(max(0, min(1, (800 - gap) / 800)))
        Sound.shared.setRumble(frozenTime > 0 ? rumble * 0.25 : rumble)
        if gap <= 6 { bury() }

        spawnRows()
        cleanup()
    }

    private func stepBuried(_ dt: CGFloat) {
        overTimer += dt
        Sound.shared.setRumble(Float(max(0, 1 - overTimer / 1.2)))
        if overTimer < 1.2 { avY -= 380 * dt }
        if overTimer > 1.2 && overlay.isHidden { finishRun() }
    }

    private func collide(prevY: CGFloat) {
        let grounded = airLeft <= 0 && stun <= 0
        for obstacle in obstacles where !obstacle.used && obstacle.kind != .decor {
            let p = obstacle.node.position
            let dy = pos.y - p.y
            guard abs(dy) < 90 else { continue }
            let dx = pos.x - p.x
            switch obstacle.kind {
            case .tree, .rock:
                guard hypot(dx, dy) < obstacle.radius + 8 else { continue }
                if airLeft > 0 {
                    guard canSpin else { continue }
                    obstacle.used = true
                    award("Clear", 50, sound: .clear)
                } else if stun <= 0 {
                    obstacle.used = true
                    crash(obstacle.kind == .tree ? "Timber!" : "Rocked!")
                }
            case .mogul:
                guard grounded, abs(dx) < obstacle.radius, abs(dy) < 12 else { continue }
                obstacle.used = true
                vel *= 0.65
                launch(0.18, spinnable: false)
            case .ramp:
                guard grounded, abs(dx) < 28, abs(dy) < 16 else { continue }
                obstacle.used = true
                launch(0.5 + vel / 1400, spinnable: true)
                Sound.shared.play(.jump)
            case .gate:
                guard prevY > p.y, pos.y <= p.y else { continue }
                obstacle.used = true
                if abs(dx) < obstacle.radius - 4 {
                    vel = min(Tune.maxSpeed, vel + 110)
                    award("Gate", 100, sound: .gate)
                }
            case .prize:
                guard hypot(dx, dy) < obstacle.radius + 12 else { continue }
                obstacle.used = true
                obstacle.node.removeAllActions()
                obstacle.node.run(.sequence([.group([.scale(to: 1.8, duration: 0.25), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
                collectPrize(at: p)
            case .decor:
                break
            }
        }
    }

    /// Prize boxes buy time (freeze the avalanche) or distance (shove it back).
    /// A distance prize would be wasted when the avalanche is already far back, so that rolls time instead.
    private func collectPrize(at p: CGPoint) {
        let gap = avY - pos.y
        if gap > Tune.maxGap - Tune.prizePush / 2 || Bool.random() {
            frozenTime += Tune.prizeFreeze
            popup("Avalanche frozen +\(Int(Tune.prizeFreeze))s", color: Palette.frozen)
        } else {
            avY = min(avY + Tune.prizePush, pos.y + Tune.maxGap)
            popup("Avalanche pushed back +\(Int(Tune.prizePush / Tune.pointsPerMeter)) m", color: Palette.frozen)
        }
        award("Prize", 50, sound: nil)
        Sound.shared.play(.prize)

        let sparkle = SKEmitterNode()
        sparkle.particleTexture = Art.dotTexture(radius: 5)
        sparkle.numParticlesToEmit = 40
        sparkle.particleBirthRate = 400
        sparkle.particleLifetime = 0.7
        sparkle.emissionAngleRange = 2 * .pi
        sparkle.particleSpeed = 180
        sparkle.particleSpeedRange = 90
        sparkle.particleScale = 0.5
        sparkle.particleScaleRange = 0.3
        sparkle.particleAlphaSpeed = -1.4
        sparkle.particleColor = Palette.ribbon
        sparkle.particleColorBlendFactor = 1
        sparkle.position = p
        sparkle.zPosition = 57
        world.addChild(sparkle)
        sparkle.run(.sequence([.wait(forDuration: 1.0), .removeFromParent()]))
    }

    private func jump() {
        guard airLeft <= 0, stun <= 0, vel > 80 else { return }
        launch(Tune.jumpAir, spinnable: true)
        Sound.shared.play(.jump)
    }

    private func launch(_ time: CGFloat, spinnable: Bool) {
        airLeft = time
        airTotal = time
        canSpin = spinnable
        spin = 0
        grabTime = 0
    }

    private func land() {
        airLeft = 0
        skierArt.yScale = 1
        let turn = CGFloat.pi * 2
        let turns = (spin / turn).rounded()
        let miss = abs(spin - turns * turn)
        spin = 0
        guard miss < Tune.landingSlop else {
            crash("Wipeout!")
            return
        }
        Sound.shared.play(.land, volume: 0.7)
        guard canSpin else { return }

        var tricks: [String] = []
        var base = 0
        let spins = Int(abs(turns))
        if spins > 0 {
            tricks.append("\(spins * 360)")
            base += spins * 250
        }
        if airTotal >= Tune.grabMinAir && grabTime >= Tune.grabTime {
            tricks.append("Grab")
            base += 100
        }
        if airTotal >= 1.0 {
            tricks.append("Big air")
            base += 100
        }
        grabTime = 0
        if base > 0 { award(tricks.joined(separator: " + "), base, sound: .trick) }
    }

    /// Scores a trick at the current combo multiplier and extends the chain.
    func award(_ trick: String, _ base: Int, sound: Sound.Effect?) {
        let multiplier = self.multiplier
        let gained = base * multiplier
        points += gained
        comboChain += 1
        comboTimer = Tune.comboWindow
        popup(multiplier > 1 ? "\(trick) +\(gained)  ×\(multiplier)" : "\(trick) +\(gained)", color: Palette.gate)
        if let sound { Sound.shared.play(sound) }
        if multiplier > 1 { Sound.shared.play(.comboUp, volume: 0.5) }
    }

    func crash(_ message: String) {
        stun = 1.1
        vel = 0
        airLeft = 0
        spin = 0
        grabTime = 0
        shake = 10
        skierArt.yScale = 1
        skierArt.run(.rotate(byAngle: .pi * 4, duration: 0.7))
        popup(message, color: Palette.danger)
        Sound.shared.play(.crash)
        if comboChain >= 2 {
            popup("Combo lost", color: Palette.danger)
            Sound.shared.play(.comboLost, volume: 0.6)
        }
        comboChain = 0
    }

    private func layTracks(_ dt: CGFloat) {
        guard airLeft <= 0, stun <= 0, vel > 10 else { return }
        let length = vel * dt + 1.5
        let dir = CGVector(dx: sin(heading), dy: -cos(heading))
        let perp = CGVector(dx: cos(heading), dy: sin(heading))
        for side: CGFloat in [-5, 5] {
            let track = SKSpriteNode(color: Palette.track, size: CGSize(width: 2.2, height: length))
            track.position = CGPoint(x: pos.x + perp.dx * side - dir.dx * length / 2,
                                     y: pos.y + perp.dy * side - dir.dy * length / 2)
            track.zRotation = heading
            track.zPosition = 2
            world.addChild(track)
            track.run(GameScene.trackFade)
        }
    }

    private func updateSkierVisuals() {
        let hop = airLeft > 0 ? sin(.pi * (1 - airLeft / airTotal)) * min(70, airTotal * 95) : 0
        skier.position = CGPoint(x: pos.x, y: pos.y + hop)
        skier.zRotation = heading + spin
        skier.setScale(1 + hop / 140)
        skier.zPosition = airLeft > 0 ? 55 : depth(pos.y) + 0.0002
        skierShadow.position = pos
        skierShadow.setScale(1 - hop / 160)
    }

    private func updateCamera(dt: CGFloat, snap: Bool = false) {
        let limit = Tune.halfWidth + 140 - size.width / 2
        let targetX = max(-limit, min(limit, pos.x))
        camBase.x = snap ? targetX : camBase.x + (targetX - camBase.x) * min(1, dt * 6)
        camBase.y = pos.y - Tune.lookAhead
        shake = max(0, shake - dt * 20)
        cam.position = CGPoint(x: camBase.x + .random(in: -1...1) * shake,
                               y: camBase.y + .random(in: -1...1) * shake)
        avalanche.position = CGPoint(x: camBase.x, y: avY)
    }

    private func updateHUD() {
        distanceLabel.text = "\(meters.formatted()) m"
        scoreLabel.text = score.formatted()
        bestLabel.text = "best \(max(Leaderboard.best, score).formatted())"
        let fraction = max(0, min(1, (avY - pos.y) / Tune.maxGap))
        meterFill.xScale = max(0.02, fraction)
        if frozenTime > 0 {
            meterFill.color = Palette.frozen
            meterTitle.text = "FROZEN \(String(format: "%.1f", frozenTime))s"
        } else {
            meterFill.color = fraction < 0.3 ? Palette.danger : fraction < 0.6 ? Palette.amber : Palette.gate
            meterTitle.text = "AVALANCHE GAP"
        }
        speedTag.isHidden = Settings.speed.multiplier == 1
        speedTag.text = "\(Settings.speed.name.uppercased()) \(Settings.speed.multiplier.formatted())×"

        let showCombo = comboChain > 0 && (state == .playing || state == .paused)
        comboLabel.isHidden = !showCombo
        comboBar.isHidden = !showCombo
        if showCombo {
            comboLabel.text = "COMBO ×\(multiplier)"
            comboBar.xScale = max(0.01, comboTimer / Tune.comboWindow)
        }
    }

    func popup(_ text: String, color: SKColor) {
        let label = GameScene.label(text, size: 24)
        label.fontColor = color
        popupSlot = (popupSlot + 1) % 3
        label.position = CGPoint(x: pos.x - camBase.x, y: Tune.lookAhead + 48 + CGFloat(popupSlot) * 30)
        label.zPosition = 90
        cam.addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 50, duration: 0.9),
                    .sequence([.wait(forDuration: 0.5), .fadeOut(withDuration: 0.4)])]),
            .removeFromParent(),
        ]))
    }

    /// Dev aid: writes what the camera sees to a PNG (no screen-recording permission needed).
    func snapshot(to url: URL) {
        let crop = CGRect(x: cam.position.x - size.width / 2, y: cam.position.y - size.height / 2,
                          width: size.width, height: size.height)
        guard let image = view?.texture(from: self, crop: crop)?.cgImage() else { return }
        let rep = NSBitmapImageRep(cgImage: image)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    static func label(_ text: String, size: CGFloat, bold: Bool = true, font: String? = nil) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: font ?? (bold ? "AvenirNext-Heavy" : "AvenirNext-DemiBold"))
        label.text = text
        label.fontSize = size
        label.fontColor = Palette.ink
        label.verticalAlignmentMode = .center
        return label
    }
}
