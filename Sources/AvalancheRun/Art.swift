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

    static func ellipse(_ w: CGFloat, _ h: CGFloat, fill: SKColor, at p: CGPoint = .zero) -> SKShapeNode {
        let node = shape(CGPath(ellipseIn: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), transform: nil), fill: fill)
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
