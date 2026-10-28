import AppKit
import SpriteKit

private enum Key {
    static let left: Set<UInt16> = [123, 0]    // ←, A
    static let right: Set<UInt16> = [124, 2]   // →, D
    static let tuck: Set<UInt16> = [125, 1]    // ↓, S
    static let brake: Set<UInt16> = [126, 13]  // ↑, W
    static let jump: UInt16 = 49               // Space
    static let pause: Set<UInt16> = [35, 53]   // P, Esc
    static let restart: Set<UInt16> = [36, 15] // Return, R
}

/// Gameplay tuning. Distances are scene points; 10 points = 1 meter.
private enum Tune {
    static let halfWidth: CGFloat = 1100      // the run is 2,200 pt wide
    static let maxHeading: CGFloat = 1.35     // ~77° from straight downhill
    static let steerRate: CGFloat = 2.8       // rad/s
    static let gravity: CGFloat = 400
    static let drag: CGFloat = 0.42
    static let tuckBoost: CGFloat = 1.4
    static let brake: CGFloat = 560
    static let maxSpeed: CGFloat = 1250
    static let spinRate: CGFloat = 10         // rad/s while airborne
    static let pointsPerMeter: CGFloat = 10
    static let lookAhead: CGFloat = 200       // skier sits this far above screen center
    static let maxGap: CGFloat = 1200         // avalanche never falls further behind than this
    static let rowSpacing: CGFloat = 80
}

final class GameScene: SKScene {
    private enum State { case title, playing, paused, over }

    private final class Obstacle {
        enum Kind { case tree, rock, mogul, ramp, gate, decor }
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

    private var state = State.title
    private let world = SKNode()
    private let cam = SKCameraNode()
    private var camBase = CGPoint.zero
    private let skier = SKNode()
    private let skierArt = Art.skier()
    private let skierShadow = Art.ellipse(26, 10, fill: Palette.shade)
    private let avalanche = SKNode()
    private let overlay = SKNode()
    private let distanceLabel = GameScene.label("", size: 28)
    private let scoreLabel = GameScene.label("", size: 28)
    private let bestLabel = GameScene.label("", size: 15, bold: false)
    private let meterFill = SKSpriteNode(color: Palette.gate, size: CGSize(width: 236, height: 8))
    private var textures: [String: (SKTexture, CGPoint)] = [:]
    private static let trackFade = SKAction.sequence([.wait(forDuration: 1.5), .fadeOut(withDuration: 1.0), .removeFromParent()])

    private var pos = CGPoint.zero
    private var heading: CGFloat = 0
    private var vel: CGFloat = 0
    private var airLeft: CGFloat = 0
    private var airTotal: CGFloat = 0
    private var canSpin = false
    private var spin: CGFloat = 0
    private var stun: CGFloat = 0
    private var avY: CGFloat = 540
    private var spawnedTo: CGFloat = 0
    private var obstacles: [Obstacle] = []
    private var keys = Set<UInt16>()
    private var lastTime: TimeInterval = 0
    private var points = 0
    private var combo = 0
    private var shake: CGFloat = 0
    private var overTimer: CGFloat = 0

    private var meters: Int { Int(max(0, -pos.y) / Tune.pointsPerMeter) }
    private var score: Int { meters + points }
    private var best: Int {
        get { UserDefaults.standard.integer(forKey: "bestScore") }
        set { UserDefaults.standard.set(newValue, forKey: "bestScore") }
    }

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

        if autostart {
            start()
        } else {
            showOverlay(title: "AVALANCHE RUN", lines: [
                "Outrun the avalanche. Ski as far as you can.",
                "← →  steer     ↓  tuck     ↑  brake     Space  jump",
                "Off a ramp, hold ← or → to spin. Land straight for points.",
                "Pass between blue gates for a speed boost.",
                "",
                "Press Space to start",
            ])
        }
    }

    private func bakeTextures(in view: SKView) {
        let art: [String: SKNode] = [
            "tree": Art.tree(), "rock": Art.rock(), "mogul": Art.mogul(), "ramp": Art.ramp(),
            "poleL": Art.gatePole(flagRight: true), "poleR": Art.gatePole(flagRight: false),
            "post": Art.post(), "dimple": Art.dimple(),
        ]
        for (name, node) in art {
            let frame = node.calculateAccumulatedFrame()
            guard let texture = view.texture(from: node) else { continue }
            let anchor = CGPoint(x: -frame.minX / frame.width, y: -frame.minY / frame.height)
            textures[name] = (texture, anchor)
        }
    }

    private func sprite(_ name: String) -> SKSpriteNode {
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
        let meterTitle = GameScene.label("AVALANCHE GAP", size: 13)
        meterTitle.fontColor = Palette.ink.withAlphaComponent(0.6)
        meterTitle.position = CGPoint(x: 0, y: 330)

        for node in [distanceLabel, scoreLabel, bestLabel, meterBack, meterTitle] as [SKNode] {
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

    private func depth(_ y: CGFloat) -> CGFloat { 10 + -y / 100_000 }

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
        keys.insert(event.keyCode)
        guard !event.isARepeat else { return }
        let code = event.keyCode
        switch state {
        case .title:
            if code == Key.jump || Key.restart.contains(code) { start() }
        case .playing:
            if code == Key.jump { jump() }
            if Key.pause.contains(code) { setPaused(true) }
        case .paused:
            if Key.pause.contains(code) || code == Key.jump { setPaused(false) }
        case .over:
            if Key.restart.contains(code) && !overlay.isHidden { restart() }
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

    // MARK: - Game flow

    private func start() {
        state = .playing
        overlay.isHidden = true
    }

    private func setPaused(_ paused: Bool) {
        if paused {
            state = .paused
            showOverlay(title: "PAUSED", lines: ["Press P to keep skiing"])
        } else {
            state = .playing
            overlay.isHidden = true
        }
    }

    private func restart() {
        guard let view else { return }
        let next = GameScene(size: size)
        next.scaleMode = scaleMode
        next.autostart = true
        view.presentScene(next, transition: .crossFade(withDuration: 0.35))
    }

    private func bury() {
        state = .over
        overTimer = 0
        vel = 0
        skier.run(.fadeOut(withDuration: 0.4))
        skierShadow.run(.fadeOut(withDuration: 0.4))
    }

    private func showGameOver() {
        let final = score
        let isBest = final > best
        if isBest { best = final }
        showOverlay(title: "BURIED!", lines: [
            "\(meters.formatted()) m   ·   score \(final.formatted())",
            isBest ? "New best!" : "Best \(best.formatted())",
            "",
            "Press Return to ski again",
        ])
    }

    private func showOverlay(title: String, lines: [String]) {
        overlay.removeAllChildren()
        let height = 130 + CGFloat(lines.count) * 30
        let panel = SKShapeNode(rectOf: CGSize(width: 640, height: height), cornerRadius: 20)
        panel.fillColor = SKColor(white: 1, alpha: 0.9)
        panel.strokeColor = Palette.shade
        panel.lineWidth = 2
        overlay.addChild(panel)

        let top = height / 2
        let heading = GameScene.label(title, size: 48)
        heading.position = CGPoint(x: 0, y: top - 60)
        overlay.addChild(heading)
        for (i, text) in lines.enumerated() {
            let line = GameScene.label(text, size: 19, bold: false)
            line.position = CGPoint(x: 0, y: top - 115 - CGFloat(i) * 30)
            overlay.addChild(line)
        }
        overlay.isHidden = false
    }

    // MARK: - Simulation

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 1.0 / 60 : CGFloat(min(currentTime - lastTime, 1.0 / 30))
        lastTime = currentTime
        switch state {
        case .playing: step(dt)
        case .over: stepBuried(dt)
        case .title, .paused: break
        }
        updateCamera(dt: dt)
        updateHUD()
    }

    private func step(_ dt: CGFloat) {
        let prevY = pos.y

        if stun > 0 {
            stun -= dt
            if stun <= 0 {
                skierArt.removeAllActions()
                skierArt.zRotation = 0
            }
        } else if airLeft > 0 {
            if canSpin {
                if held(Key.left) { spin -= Tune.spinRate * dt }
                if held(Key.right) { spin += Tune.spinRate * dt }
            }
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

        collide(prevY: prevY)
        layTracks(dt)
        updateSkierVisuals()

        let avalancheSpeed = min(320 + -pos.y * 0.014, 860)
        avY = min(avY - avalancheSpeed * dt, pos.y + Tune.maxGap)
        let gap = avY - pos.y
        if gap < 420 { shake = max(shake, (420 - gap) / 420 * 6) }
        if gap <= 6 { bury() }

        spawnRows()
        cleanup()
    }

    private func stepBuried(_ dt: CGFloat) {
        overTimer += dt
        if overTimer < 1.2 { avY -= 380 * dt }
        if overTimer > 1.2 && overlay.isHidden { showGameOver() }
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
                guard grounded, hypot(dx, dy) < obstacle.radius + 8 else { continue }
                obstacle.used = true
                crash(obstacle.kind == .tree ? "Timber!" : "Rocked!")
            case .mogul:
                guard grounded, abs(dx) < obstacle.radius, abs(dy) < 12 else { continue }
                obstacle.used = true
                vel *= 0.65
                launch(0.18, spinnable: false)
            case .ramp:
                guard grounded, abs(dx) < 28, abs(dy) < 16 else { continue }
                obstacle.used = true
                launch(0.5 + vel / 1400, spinnable: true)
            case .gate:
                guard prevY > p.y, pos.y <= p.y else { continue }
                obstacle.used = true
                if abs(dx) < obstacle.radius - 4 {
                    points += 100
                    vel = min(Tune.maxSpeed, vel + 110)
                    popup("Gate +100", color: Palette.gate)
                }
            case .decor:
                break
            }
        }
    }

    private func jump() {
        guard airLeft <= 0, stun <= 0, vel > 120 else { return }
        launch(0.42, spinnable: true)
    }

    private func launch(_ time: CGFloat, spinnable: Bool) {
        airLeft = time
        airTotal = time
        canSpin = spinnable
        spin = 0
    }

    private func land() {
        airLeft = 0
        let turn = CGFloat.pi * 2
        let turns = (spin / turn).rounded()
        let miss = abs(spin - turns * turn)
        spin = 0
        guard miss < 0.8 else {
            crash("Wipeout!")
            return
        }
        let spins = Int(abs(turns))
        guard spins > 0 else { return }
        combo += 1
        let bonus = spins * 250 + (combo - 1) * 100
        points += bonus
        popup("\(spins * 360)°  +\(bonus)", color: Palette.gate)
    }

    private func crash(_ message: String) {
        stun = 1.1
        vel = 0
        combo = 0
        airLeft = 0
        spin = 0
        shake = 10
        skierArt.run(.rotate(byAngle: .pi * 4, duration: 0.7))
        popup(message, color: Palette.danger)
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
        bestLabel.text = "best \(best.formatted())"
        let fraction = max(0, min(1, (avY - pos.y) / Tune.maxGap))
        meterFill.xScale = max(0.02, fraction)
        meterFill.color = fraction < 0.3 ? Palette.danger : fraction < 0.6 ? Palette.amber : Palette.gate
    }

    private func popup(_ text: String, color: SKColor) {
        let label = GameScene.label(text, size: 24)
        label.fontColor = color
        label.position = CGPoint(x: pos.x - camBase.x, y: Tune.lookAhead + 48)
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

    private static func label(_ text: String, size: CGFloat, bold: Bool = true) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: bold ? "AvenirNext-Heavy" : "AvenirNext-DemiBold")
        label.text = text
        label.fontSize = size
        label.fontColor = Palette.ink
        label.verticalAlignmentMode = .center
        return label
    }
}

/// Small deterministic generator so the avalanche front has a stable shape.
private struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
