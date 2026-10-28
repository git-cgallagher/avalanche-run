import SpriteKit

/// A local who turns up uninvited. One attacks at a time, picked at random.
final class Creature {
    enum Kind: CaseIterable {
        case yeti, penguin, bear, narwhal

        var name: String {
            switch self {
            case .yeti: "Yeti"
            case .penguin: "Penguin"
            case .bear: "Polar bear"
            case .narwhal: "Narwhal"
            }
        }
        var texture: String {
            switch self {
            case .yeti: "yeti"
            case .penguin: "penguin"
            case .bear: "bear"
            case .narwhal: "narwhal"
            }
        }
        var radius: CGFloat {
            switch self {
            case .yeti: 26
            case .penguin: 18
            case .bear: 26
            case .narwhal: 26
            }
        }
        var call: Sound.Effect {
            switch self {
            case .yeti: .yeti
            case .penguin: .penguin
            case .bear: .bear
            case .narwhal: .narwhal
            }
        }
        var crashMessage: String {
            switch self {
            case .yeti: "Yeti bonk!"
            case .penguin: "Penguin strike!"
            case .bear: "Bear hug!"
            case .narwhal: "Narwhaled!"
            }
        }
    }

    let kind: Kind
    let node: SKSpriteNode
    let badge: SKNode
    var pos = CGPoint.zero
    var vel = CGVector.zero
    var age: CGFloat = 0
    var side: CGFloat = 1
    var facing: CGFloat = 0
    var hurts = true
    var spent = false  // already hit, hopped or near-missed: no more contact or bonus
    var closest = CGFloat.greatestFiniteMagnitude
    var done = false
    var thrown = 0
    var ripple: SKNode?
    var breachAge: CGFloat = -1

    init(kind: Kind, node: SKSpriteNode, badge: SKNode) {
        self.kind = kind
        self.node = node
        self.badge = badge
    }
}

final class Snowball {
    let ball: SKSpriteNode
    let shadow: SKShapeNode
    let from: CGPoint
    let to: CGPoint
    let flight: CGFloat = 0.85
    var t: CGFloat = 0
    var done = false

    init(ball: SKSpriteNode, shadow: SKShapeNode, from: CGPoint, to: CGPoint) {
        self.ball = ball
        self.shadow = shadow
        self.from = from
        self.to = to
    }
}

/// Behaviors:
/// - Penguin belly-slides across the run in front of you.
/// - Polar bear charges uphill at you, steering for the first moment, then committing.
/// - Yeti runs along the edge of the screen and lobs three snowballs at where you're headed.
/// - Narwhal leaves a ripple in the snow ahead, then breaches out of it as you arrive.
extension GameScene {
    func updateCreatures(_ dt: CGFloat) {
        if creatures.isEmpty && (debugCreatures || meters >= Tune.creaturesFrom) {
            nextAttack -= dt
            if nextAttack <= 0 {
                spawnCreature()
                scheduleNextAttack()
            }
        }
        for creature in creatures {
            advance(creature, dt)
            if !creature.done { checkContact(creature) }
        }
        for snowball in snowballs { advance(snowball, dt) }

        creatures.removeAll { creature in
            guard creature.done else { return false }
            creature.node.removeFromParent()
            creature.badge.removeFromParent()
            creature.ripple?.removeFromParent()
            return true
        }
        snowballs.removeAll { snowball in
            guard snowball.done else { return false }
            snowball.ball.removeFromParent()
            snowball.shadow.removeFromParent()
            return true
        }
    }

    /// Attacks get more frequent the further down the mountain you are.
    func scheduleNextAttack() {
        if debugCreatures {
            nextAttack = 1.2
            return
        }
        let low = max(4, 11 - CGFloat(meters) / 350)
        nextAttack = .random(in: low...(low + 6))
    }

    private func spawnCreature() {
        let kinds = Creature.Kind.allCases
        let kind = debugCreatures ? kinds[attackCount % kinds.count] : kinds.filter { $0 != lastCreature }.randomElement()!
        attackCount += 1
        lastCreature = kind

        let creature = Creature(kind: kind, node: sprite(kind.texture), badge: makeBadge(kind.name))
        creature.side = Bool.random() ? 1 : -1
        let halfScreen = size.width / 2

        switch kind {
        case .penguin:
            let ahead = max(260, min(520, vel + 150))
            creature.pos = CGPoint(x: camBase.x + creature.side * (halfScreen + 60), y: pos.y - ahead)
            creature.vel = CGVector(dx: -creature.side * 480, dy: -max(200, vel * 0.7))
            creature.node.xScale = -creature.side
        case .bear:
            creature.pos = CGPoint(x: pos.x + CGFloat.random(in: -180...180), y: camBase.y - size.height / 2 - 60)
        case .yeti:
            creature.pos = CGPoint(x: camBase.x + creature.side * (halfScreen + 80), y: pos.y - 120)
        case .narwhal:
            let lead = max(260, min(540, vel))
            let limit = Tune.halfWidth - 60
            let jitter = CGFloat.random(in: -40...40)
            let aheadX: CGFloat = pos.x + sin(heading) * lead + jitter
            let aheadY: CGFloat = pos.y - cos(heading) * lead
            let target = CGPoint(x: max(-limit, min(limit, aheadX)), y: min(aheadY, pos.y - 220))
            creature.pos = target
            creature.node.isHidden = true
            creature.hurts = false
            creature.ripple = makeRipple(at: target)
        }

        creature.node.position = creature.pos
        creature.node.zPosition = kind == .narwhal ? 50 : depth(creature.pos.y)
        world.addChild(creature.node)
        cam.addChild(creature.badge)
        creatures.append(creature)
        Sound.shared.play(.warn, volume: 0.7)
        if kind != .narwhal { Sound.shared.play(kind.call) }
    }

    private func advance(_ c: Creature, _ dt: CGFloat) {
        c.age += dt
        switch c.kind {
        case .penguin:
            c.pos.x += c.vel.dx * dt
            c.pos.y += c.vel.dy * dt
            c.node.zRotation = sin(c.age * 14) * 0.12
            if c.age > 1, abs(c.pos.x - camBase.x) > size.width / 2 + 160 { c.done = true }

        case .bear:
            if c.age < 1.6 {
                let want = atan2(-(pos.x - c.pos.x), pos.y - c.pos.y)
                var diff = want - c.facing
                while diff > .pi { diff -= 2 * .pi }
                while diff < -.pi { diff += 2 * .pi }
                c.facing += max(-1.1 * dt, min(1.1 * dt, diff))
            }
            c.pos.x += -sin(c.facing) * 250 * dt
            c.pos.y += cos(c.facing) * 250 * dt
            c.node.zRotation = c.facing
            c.node.yScale = 1 + sin(c.age * 16) * 0.06
            if c.pos.y > camBase.y + size.height / 2 + 120 || c.age > 9 { c.done = true }

        case .yeti:
            let inX = camBase.x + c.side * (size.width / 2 - 70)
            let outX = camBase.x + c.side * (size.width / 2 + 90)
            let leaving = c.thrown >= 3 && c.age > 4.2
            c.pos.x += ((leaving ? outX : inX) - c.pos.x) * min(1, dt * 5)
            c.pos.y = pos.y - 120 + sin(c.age * 9) * 4
            c.node.yScale = 1 + sin(c.age * 10) * 0.05
            let throwTimes: [CGFloat] = [1.0, 2.0, 3.0]
            if c.thrown < throwTimes.count, c.age >= throwTimes[c.thrown] {
                throwSnowball(from: c)
                c.thrown += 1
            }
            if leaving, abs(c.pos.x - outX) < 12 { c.done = true }

        case .narwhal:
            if c.breachAge < 0 {
                if (c.age > 0.5 && pos.y - c.pos.y < 170) || c.age > 1.8 { breach(c) }
            } else {
                let t = c.age - c.breachAge
                c.hurts = t > 0.08 && t < 0.9
                if t > 1.3 { c.done = true }
            }
        }

        c.node.position = c.pos
        if c.kind != .narwhal { c.node.zPosition = depth(c.pos.y) }

        // Edge-of-screen warning while it's arriving.
        c.badge.isHidden = c.age > 1.3
        let hx = size.width / 2 - 44, hy = size.height / 2 - 44
        c.badge.position = CGPoint(x: max(-hx, min(hx, c.pos.x - camBase.x)),
                                   y: max(-hy + 10, min(hy - 100, c.pos.y - camBase.y)))
    }

    private func checkContact(_ c: Creature) {
        guard c.hurts, !c.spent else { return }
        let distance = hypot(c.pos.x - pos.x, c.pos.y - pos.y)
        if distance < c.kind.radius + 10 {
            if airLeft > 0 && canSpin {
                c.spent = true
                award("Hopped the \(c.kind.name.lowercased())", 250, sound: .clear)
            } else if airLeft <= 0 && stun <= 0 {
                c.spent = true
                crash(c.kind.crashMessage)
            }
        } else if c.kind != .yeti {
            c.closest = min(c.closest, distance)
            if c.closest < c.kind.radius + 70, distance > c.closest + 60, stun <= 0 {
                c.spent = true
                award("Close call", 150, sound: .clear)
            }
        }
    }

    private func breach(_ c: Creature) {
        c.breachAge = c.age
        c.ripple?.removeFromParent()
        c.ripple = nil
        c.node.isHidden = false
        c.node.setScale(0.2)
        c.node.zRotation = CGFloat.pi / 2 + CGFloat.random(in: -0.35...0.35)
        c.node.run(.sequence([
            .scale(to: 1.1, duration: 0.18),
            .wait(forDuration: 0.6),
            .group([.scale(to: 0.3, duration: 0.3), .fadeOut(withDuration: 0.3)]),
        ]))
        let spray = SKEmitterNode()
        spray.particleTexture = Art.dotTexture(radius: 6)
        spray.numParticlesToEmit = 60
        spray.particleBirthRate = 400
        spray.particleLifetime = 0.8
        spray.emissionAngleRange = 2 * .pi
        spray.particleSpeed = 160
        spray.particleSpeedRange = 80
        spray.particleScale = 0.6
        spray.particleScaleRange = 0.4
        spray.particleAlphaSpeed = -1.2
        spray.particleColor = .white
        spray.particleColorBlendFactor = 1
        spray.position = c.pos
        spray.zPosition = 51
        world.addChild(spray)
        spray.run(.sequence([.wait(forDuration: 1.2), .removeFromParent()]))
        Sound.shared.play(.narwhal)
        shake = max(shake, 4)
    }

    private func throwSnowball(from c: Creature) {
        let lead: CGFloat = 0.85
        let travel: CGFloat = vel * lead
        let jitterX = CGFloat.random(in: -25...25), jitterY = CGFloat.random(in: -25...25)
        let target = CGPoint(x: pos.x + sin(heading) * travel + jitterX,
                             y: pos.y - cos(heading) * travel + jitterY)
        let start = CGPoint(x: c.pos.x - c.side * 22, y: c.pos.y + 30)
        let ball = sprite("snowball")
        ball.zPosition = 56
        let shadow = Art.ellipse(18, 7, fill: Palette.shade)
        shadow.zPosition = 9
        world.addChild(ball)
        world.addChild(shadow)
        snowballs.append(Snowball(ball: ball, shadow: shadow, from: start, to: target))
        Sound.shared.play(.toss, volume: 0.7)
    }

    private func advance(_ s: Snowball, _ dt: CGFloat) {
        s.t += dt / s.flight
        let k = min(1, s.t)
        let ground = CGPoint(x: s.from.x + (s.to.x - s.from.x) * k, y: s.from.y + (s.to.y - s.from.y) * k)
        let height = sin(.pi * k) * 130
        s.shadow.position = ground
        s.ball.position = CGPoint(x: ground.x, y: ground.y + height)
        s.ball.setScale(1 + height / 200)
        guard k >= 1 else { return }

        s.done = true
        let splat = Art.ellipse(36, 14, fill: .white, stroke: Palette.shade, width: 2, at: s.to)
        splat.zPosition = 3
        world.addChild(splat)
        splat.run(.sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 0.6), .removeFromParent()]))
        Sound.shared.play(.splat)

        let distance = hypot(pos.x - s.to.x, pos.y - s.to.y)
        if distance < 30 {
            if airLeft <= 0 && stun <= 0 {
                crash("Snowballed!")
            } else if airLeft > 0 && canSpin {
                award("Dodged", 100, sound: .clear)
            }
        } else if distance < 80 && stun <= 0 {
            award("Close call", 75, sound: nil)
        }
    }

    private func makeBadge(_ name: String) -> SKNode {
        let badge = SKNode()
        let disc = SKShapeNode(circleOfRadius: 22)
        disc.fillColor = Palette.danger
        disc.strokeColor = .white
        disc.lineWidth = 3
        badge.addChild(disc)
        let mark = GameScene.label("!", size: 30)
        mark.fontColor = .white
        badge.addChild(mark)
        let text = GameScene.label(name.uppercased(), size: 13)
        text.fontColor = Palette.danger
        text.position = CGPoint(x: 0, y: -36)
        badge.addChild(text)
        badge.zPosition = 95
        badge.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.25), .scale(to: 1, duration: 0.25)])))
        return badge
    }

    private func makeRipple(at p: CGPoint) -> SKNode {
        let ripple = SKNode()
        ripple.position = p
        ripple.zPosition = 3
        for (w, h) in [(80.0, 30.0), (50.0, 18.0)] {
            let ring = Art.ellipse(w, h, fill: .clear, stroke: Palette.iceEdge, width: 3)
            ring.run(.repeatForever(.sequence([.scale(to: 1.25, duration: 0.3), .scale(to: 0.8, duration: 0.3)])))
            ripple.addChild(ring)
        }
        world.addChild(ripple)
        return ripple
    }
}
