import SpriteKit

/// All colors live here so the look can be retuned in one place.
enum Palette {
    static let snow = SKColor(red: 0.95, green: 0.97, blue: 1.00, alpha: 1)
    static let shade = SKColor(red: 0.80, green: 0.86, blue: 0.95, alpha: 1)
    static let track = SKColor(red: 0.68, green: 0.76, blue: 0.90, alpha: 0.75)
    static let pine = SKColor(red: 0.14, green: 0.45, blue: 0.33, alpha: 1)
    static let pineDark = SKColor(red: 0.07, green: 0.30, blue: 0.22, alpha: 1)
    static let trunk = SKColor(red: 0.42, green: 0.27, blue: 0.16, alpha: 1)
    static let rock = SKColor(red: 0.46, green: 0.50, blue: 0.56, alpha: 1)
    static let rockLight = SKColor(red: 0.63, green: 0.67, blue: 0.72, alpha: 1)
    static let rockDark = SKColor(red: 0.32, green: 0.35, blue: 0.40, alpha: 1)
    static let ice = SKColor(red: 0.80, green: 0.91, blue: 1.00, alpha: 1)
    static let iceEdge = SKColor(red: 0.45, green: 0.65, blue: 0.90, alpha: 1)
    static let jacket = SKColor(red: 0.93, green: 0.33, blue: 0.20, alpha: 1)
    static let jacketDark = SKColor(red: 0.65, green: 0.18, blue: 0.10, alpha: 1)
    static let pants = SKColor(red: 0.15, green: 0.20, blue: 0.36, alpha: 1)
    static let helmet = SKColor(red: 0.98, green: 0.80, blue: 0.20, alpha: 1)
    static let helmetDark = SKColor(red: 0.75, green: 0.55, blue: 0.08, alpha: 1)
    static let ink = SKColor(red: 0.10, green: 0.14, blue: 0.24, alpha: 1)
    static let gate = SKColor(red: 0.10, green: 0.50, blue: 0.85, alpha: 1)
    static let boundary = SKColor(red: 0.98, green: 0.55, blue: 0.10, alpha: 1)
    static let amber = SKColor(red: 0.95, green: 0.65, blue: 0.10, alpha: 1)
    static let danger = SKColor(red: 0.86, green: 0.18, blue: 0.20, alpha: 1)
    // The locals
    static let penguin = SKColor(red: 0.13, green: 0.14, blue: 0.20, alpha: 1)
    static let beak = SKColor(red: 0.98, green: 0.60, blue: 0.12, alpha: 1)
    static let bearFur = SKColor(red: 0.99, green: 0.97, blue: 0.91, alpha: 1)
    static let bearEdge = SKColor(red: 0.72, green: 0.74, blue: 0.80, alpha: 1)
    static let bearPaw = SKColor(red: 0.88, green: 0.86, blue: 0.80, alpha: 1)
    static let fur = SKColor(red: 0.60, green: 0.66, blue: 0.90, alpha: 1)
    static let furDark = SKColor(red: 0.38, green: 0.42, blue: 0.70, alpha: 1)
    static let furFace = SKColor(red: 0.86, green: 0.89, blue: 0.99, alpha: 1)
    static let horn = SKColor(red: 0.93, green: 0.84, blue: 0.62, alpha: 1)
    static let narwhal = SKColor(red: 0.45, green: 0.58, blue: 0.66, alpha: 1)
    static let narwhalDark = SKColor(red: 0.28, green: 0.38, blue: 0.46, alpha: 1)
    static let narwhalBelly = SKColor(red: 0.78, green: 0.85, blue: 0.88, alpha: 1)
    static let tusk = SKColor(red: 0.96, green: 0.93, blue: 0.82, alpha: 1)
}

/// Vector art for every sprite. Obstacles are baked to textures once per scene;
/// the skier stays as live nodes so it can be posed.
enum Art {
    static func shape(_ path: CGPath, fill: SKColor, stroke: SKColor = .clear, width: CGFloat = 0) -> SKShapeNode {
        let node = SKShapeNode(path: path)
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = width
        return node
    }

    static func ellipse(_ w: CGFloat, _ h: CGFloat, fill: SKColor, stroke: SKColor = .clear, width: CGFloat = 0,
                        at p: CGPoint = .zero) -> SKShapeNode {
        let node = shape(CGPath(ellipseIn: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), transform: nil),
                         fill: fill, stroke: stroke, width: width)
        node.position = p
        return node
    }

    static func polygon(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points)
        path.closeSubpath()
        return path
    }

    /// Pine tree; origin is the base of the trunk (the collision point).
    static func tree() -> SKNode {
        let node = SKNode()
        node.addChild(ellipse(40, 13, fill: Palette.shade, at: CGPoint(x: 9, y: 0)))
        let trunk = SKSpriteNode(color: Palette.trunk, size: CGSize(width: 6, height: 10))
        trunk.position = CGPoint(x: 0, y: 4)
        node.addChild(trunk)
        for (w, h, y) in [(40.0, 26.0, 7.0), (32.0, 22.0, 19.0), (22.0, 18.0, 30.0)] {
            let tier = polygon([CGPoint(x: -w / 2, y: y), CGPoint(x: w / 2, y: y), CGPoint(x: 0, y: y + h)])
            node.addChild(shape(tier, fill: Palette.pine, stroke: Palette.pineDark, width: 1.5))
        }
        let cap = polygon([CGPoint(x: -6, y: 41), CGPoint(x: 6, y: 41), CGPoint(x: 0, y: 48)])
        node.addChild(shape(cap, fill: .white))
        return node
    }

    static func rock() -> SKNode {
        let node = SKNode()
        node.addChild(ellipse(40, 14, fill: Palette.shade, at: CGPoint(x: 6, y: -4)))
        let body = polygon([
            CGPoint(x: -17, y: -6), CGPoint(x: -13, y: 8), CGPoint(x: -2, y: 14), CGPoint(x: 11, y: 11),
            CGPoint(x: 17, y: 0), CGPoint(x: 12, y: -9), CGPoint(x: -4, y: -11),
        ])
        node.addChild(shape(body, fill: Palette.rock, stroke: Palette.rockDark, width: 1.5))
        let light = polygon([CGPoint(x: -11, y: 5), CGPoint(x: -2, y: 11), CGPoint(x: 6, y: 9), CGPoint(x: -3, y: 2)])
        node.addChild(shape(light, fill: Palette.rockLight))
        let cap = polygon([CGPoint(x: -6, y: 11), CGPoint(x: 4, y: 13), CGPoint(x: 9, y: 10), CGPoint(x: 0, y: 9)])
        node.addChild(shape(cap, fill: .white))
        return node
    }

    /// Snow bump: a shaded crescent under a bright dome.
    static func mogul() -> SKNode {
        let node = SKNode()
        node.addChild(ellipse(54, 26, fill: Palette.shade, at: CGPoint(x: 0, y: -4)))
        node.addChild(ellipse(48, 21, fill: .white, at: CGPoint(x: -1, y: 1)))
        return node
    }

    /// Kicker ramp; the lip faces downhill (−y).
    static func ramp() -> SKNode {
        let node = SKNode()
        let lip = SKSpriteNode(color: Palette.shade, size: CGSize(width: 58, height: 8))
        lip.position = CGPoint(x: 0, y: -21)
        node.addChild(lip)
        let deck = polygon([CGPoint(x: -24, y: 17), CGPoint(x: 24, y: 17), CGPoint(x: 29, y: -17), CGPoint(x: -29, y: -17)])
        node.addChild(shape(deck, fill: Palette.ice, stroke: Palette.iceEdge, width: 2))
        for y in [8.0, -4.0] {
            let chevron = CGMutablePath()
            chevron.move(to: CGPoint(x: -10, y: y + 5))
            chevron.addLine(to: CGPoint(x: 0, y: y - 3))
            chevron.addLine(to: CGPoint(x: 10, y: y + 5))
            node.addChild(shape(chevron, fill: .clear, stroke: Palette.iceEdge, width: 3))
        }
        return node
    }

    /// Gate pole with a pennant pointing toward the gate's center.
    static func gatePole(flagRight: Bool) -> SKNode {
        let node = SKNode()
        node.addChild(ellipse(14, 5, fill: Palette.shade, at: CGPoint(x: 5, y: 0)))
        let pole = SKSpriteNode(color: Palette.ink, size: CGSize(width: 3, height: 36))
        pole.position = CGPoint(x: 0, y: 18)
        node.addChild(pole)
        let dir: CGFloat = flagRight ? 1 : -1
        let flag = polygon([CGPoint(x: 0, y: 36), CGPoint(x: 0, y: 22), CGPoint(x: 20 * dir, y: 29)])
        node.addChild(shape(flag, fill: Palette.gate))
        return node
    }

    /// Orange boundary marker at the edge of the run.
    static func post() -> SKNode {
        let node = SKNode()
        node.addChild(ellipse(12, 5, fill: Palette.shade, at: CGPoint(x: 4, y: 0)))
        let pole = SKSpriteNode(color: Palette.boundary, size: CGSize(width: 5, height: 26))
        pole.position = CGPoint(x: 0, y: 13)
        node.addChild(pole)
        let band = SKSpriteNode(color: .white, size: CGSize(width: 5, height: 5))
        band.position = CGPoint(x: 0, y: 16)
        node.addChild(band)
        return node
    }

    static func dimple() -> SKNode {
        ellipse(26, 7, fill: Palette.shade.withAlphaComponent(0.55))
    }

    /// Top-down skier facing −y (downhill). Origin is the center of the boots.
    static func skier() -> SKNode {
        let node = SKNode()
        for x in [-5.0, 5.0] {
            let ski = shape(CGPath(roundedRect: CGRect(x: -1.75, y: -21, width: 3.5, height: 40), cornerWidth: 1.75, cornerHeight: 1.75, transform: nil), fill: Palette.ink)
            ski.position = CGPoint(x: x, y: 0)
            node.addChild(ski)
        }
        for x in [-12.0, 12.0] {
            let pole = SKSpriteNode(color: Palette.rockDark, size: CGSize(width: 1.6, height: 24))
            pole.position = CGPoint(x: x, y: 7)
            pole.zRotation = x > 0 ? 0.18 : -0.18
            node.addChild(pole)
        }
        let pants = shape(CGPath(roundedRect: CGRect(x: -8, y: -11, width: 16, height: 11), cornerWidth: 4, cornerHeight: 4, transform: nil), fill: Palette.pants)
        node.addChild(pants)
        node.addChild(shape(CGPath(ellipseIn: CGRect(x: -11, y: -6, width: 22, height: 17), transform: nil), fill: Palette.jacket, stroke: Palette.jacketDark, width: 1.5))
        let head = shape(CGPath(ellipseIn: CGRect(x: -6.5, y: -8, width: 13, height: 13), transform: nil), fill: Palette.helmet, stroke: Palette.helmetDark, width: 1.2)
        node.addChild(head)
        let goggles = SKSpriteNode(color: Palette.ink, size: CGSize(width: 9, height: 2.5))
        goggles.position = CGPoint(x: 0, y: -6)
        node.addChild(goggles)
        return node
    }

    // MARK: The locals

    /// Belly-sliding penguin, head toward +x.
    static func penguin() -> SKNode {
        let node = SKNode()
        node.addChild(ellipse(46, 14, fill: Palette.shade, at: CGPoint(x: 2, y: -9)))
        for y: CGFloat in [-11, 11] {
            let flipper = ellipse(15, 6, fill: Palette.penguin, at: CGPoint(x: 0, y: y))
            flipper.zRotation = y > 0 ? 0.35 : -0.35
            node.addChild(flipper)
        }
        for y: CGFloat in [-4, 4] { node.addChild(ellipse(8, 5, fill: Palette.beak, at: CGPoint(x: -21, y: y))) }
        node.addChild(ellipse(38, 20, fill: Palette.penguin))
        node.addChild(ellipse(26, 8, fill: .white, at: CGPoint(x: -2, y: -6)))
        node.addChild(ellipse(17, 16, fill: Palette.penguin, at: CGPoint(x: 17, y: 1)))
        node.addChild(ellipse(5, 5, fill: .white, at: CGPoint(x: 20, y: 4)))
        node.addChild(ellipse(2.4, 2.4, fill: Palette.ink, at: CGPoint(x: 21, y: 4)))
        node.addChild(shape(polygon([CGPoint(x: 24, y: 3), CGPoint(x: 33, y: 0), CGPoint(x: 24, y: -2)]), fill: Palette.beak))
        return node
    }

    /// Polar bear seen from above, charging toward +y.
    static func polarBear() -> SKNode {
        let node = SKNode()
        node.addChild(ellipse(48, 62, fill: Palette.shade, at: CGPoint(x: 7, y: -6)))
        for (x, y) in [(-17.0, 16.0), (17.0, 16.0), (-16.0, -21.0), (16.0, -21.0)] {
            node.addChild(ellipse(13, 11, fill: Palette.bearPaw, stroke: Palette.bearEdge, width: 1.5, at: CGPoint(x: x, y: y)))
        }
        node.addChild(ellipse(38, 56, fill: Palette.bearFur, stroke: Palette.bearEdge, width: 2))
        for x: CGFloat in [-10, 10] {
            node.addChild(ellipse(10, 10, fill: Palette.bearFur, stroke: Palette.bearEdge, width: 1.5, at: CGPoint(x: x, y: 40)))
        }
        node.addChild(ellipse(26, 24, fill: Palette.bearFur, stroke: Palette.bearEdge, width: 2, at: CGPoint(x: 0, y: 30)))
        node.addChild(ellipse(12, 10, fill: Palette.bearPaw, at: CGPoint(x: 0, y: 39)))
        node.addChild(ellipse(6, 4, fill: Palette.ink, at: CGPoint(x: 0, y: 43)))
        for x: CGFloat in [-6, 6] { node.addChild(ellipse(3.2, 3.2, fill: Palette.ink, at: CGPoint(x: x, y: 32))) }
        return node
    }

    /// The yeti here is a round, horned periwinkle fuzzball that lobs snowballs.
    static func yeti() -> SKNode {
        let node = SKNode()
        node.addChild(ellipse(62, 20, fill: Palette.shade, at: CGPoint(x: 6, y: -27)))
        for x: CGFloat in [-10, 10] { node.addChild(ellipse(13, 8, fill: Palette.furDark, at: CGPoint(x: x, y: -26))) }
        for x: CGFloat in [-27, 27] {
            let arm = ellipse(16, 27, fill: Palette.fur, stroke: Palette.furDark, width: 2, at: CGPoint(x: x, y: 8))
            arm.zRotation = x > 0 ? -0.5 : 0.5
            node.addChild(arm)
        }
        var fluff: [CGPoint] = []
        for i in 0..<24 {
            let angle = CGFloat(i) / 24 * 2 * .pi
            let r: CGFloat = i % 2 == 0 ? 29 : 23
            fluff.append(CGPoint(x: cos(angle) * r, y: sin(angle) * r))
        }
        node.addChild(shape(polygon(fluff), fill: Palette.fur, stroke: Palette.furDark, width: 2))
        for dir: CGFloat in [-1, 1] {
            let horn = polygon([CGPoint(x: dir * 12, y: 20), CGPoint(x: dir * 6, y: 25), CGPoint(x: dir * 24, y: 42)])
            node.addChild(shape(horn, fill: Palette.horn, stroke: Palette.helmetDark, width: 1))
        }
        node.addChild(ellipse(28, 19, fill: Palette.furFace, at: CGPoint(x: 0, y: 3)))
        for x: CGFloat in [-6, 6] { node.addChild(ellipse(5, 6, fill: Palette.ink, at: CGPoint(x: x, y: 7))) }
        node.addChild(ellipse(13, 6, fill: Palette.ink, at: CGPoint(x: 0, y: -3)))
        for x: CGFloat in [-3, 3] {
            let tooth = SKSpriteNode(color: .white, size: CGSize(width: 2.5, height: 3))
            tooth.position = CGPoint(x: x, y: -1.5)
            node.addChild(tooth)
        }
        return node
    }

    /// Narwhal, tusk toward +x.
    static func narwhal() -> SKNode {
        let node = SKNode()
        node.addChild(shape(polygon([CGPoint(x: 22, y: 3), CGPoint(x: 66, y: 1), CGPoint(x: 22, y: -2)]), fill: Palette.tusk, stroke: Palette.helmetDark, width: 0.8))
        node.addChild(shape(polygon([CGPoint(x: -22, y: 0), CGPoint(x: -38, y: 13), CGPoint(x: -33, y: 0), CGPoint(x: -38, y: -13)]), fill: Palette.narwhalDark))
        node.addChild(ellipse(54, 25, fill: Palette.narwhal, stroke: Palette.narwhalDark, width: 1.5))
        node.addChild(ellipse(34, 9, fill: Palette.narwhalBelly, at: CGPoint(x: 3, y: -6)))
        for (x, y, s) in [(-12.0, 5.0, 5.0), (-3.0, 8.0, 4.0), (6.0, 4.0, 3.5), (-16.0, -2.0, 3.0), (2.0, 1.0, 2.5)] {
            node.addChild(ellipse(s, s * 0.8, fill: Palette.narwhalDark, at: CGPoint(x: x, y: y)))
        }
        node.addChild(ellipse(3, 3, fill: Palette.ink, at: CGPoint(x: 17, y: 3)))
        return node
    }

    static func snowball() -> SKNode {
        ellipse(18, 18, fill: .white, stroke: Palette.shade, width: 2)
    }

    static func dotTexture(radius: CGFloat) -> SKTexture {
        let size = NSSize(width: radius * 2, height: radius * 2)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        return SKTexture(image: image)
    }
}
