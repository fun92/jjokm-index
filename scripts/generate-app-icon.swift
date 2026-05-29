import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("Assets/AppIcon.iconset", isDirectory: true)
let icns = root.appendingPathComponent("Assets/JjokkomIndex.icns")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let outputs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func drawHeart(in rect: CGRect) {
    let path = NSBezierPath()
    let x = rect.minX
    let y = rect.minY
    let w = rect.width
    let h = rect.height
    path.move(to: CGPoint(x: x + w * 0.50, y: y + h * 0.14))
    path.curve(to: CGPoint(x: x + w * 0.08, y: y + h * 0.56),
               controlPoint1: CGPoint(x: x + w * 0.22, y: y + h * 0.34),
               controlPoint2: CGPoint(x: x + w * 0.08, y: y + h * 0.44))
    path.curve(to: CGPoint(x: x + w * 0.32, y: y + h * 0.84),
               controlPoint1: CGPoint(x: x + w * 0.08, y: y + h * 0.74),
               controlPoint2: CGPoint(x: x + w * 0.24, y: y + h * 0.86))
    path.curve(to: CGPoint(x: x + w * 0.50, y: y + h * 0.72),
               controlPoint1: CGPoint(x: x + w * 0.40, y: y + h * 0.84),
               controlPoint2: CGPoint(x: x + w * 0.46, y: y + h * 0.78))
    path.curve(to: CGPoint(x: x + w * 0.68, y: y + h * 0.84),
               controlPoint1: CGPoint(x: x + w * 0.54, y: y + h * 0.78),
               controlPoint2: CGPoint(x: x + w * 0.60, y: y + h * 0.84))
    path.curve(to: CGPoint(x: x + w * 0.92, y: y + h * 0.56),
               controlPoint1: CGPoint(x: x + w * 0.76, y: y + h * 0.86),
               controlPoint2: CGPoint(x: x + w * 0.92, y: y + h * 0.74))
    path.curve(to: CGPoint(x: x + w * 0.50, y: y + h * 0.14),
               controlPoint1: CGPoint(x: x + w * 0.92, y: y + h * 0.42),
               controlPoint2: CGPoint(x: x + w * 0.72, y: y + h * 0.30))
    path.close()
    path.fill()
}

func makeIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let scale = size / 1024
    func r(_ value: CGFloat) -> CGFloat { value * scale }
    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
        NSRect(x: r(x), y: r(y), width: r(width), height: r(height))
    }

    let bg = NSBezierPath(roundedRect: rect(94, 94, 836, 836), xRadius: r(210), yRadius: r(210))
    NSShadow().with {
        $0.shadowOffset = NSSize(width: 0, height: -r(18))
        $0.shadowBlurRadius = r(48)
        $0.shadowColor = color(57, 47, 36, 0.22)
    }.set()
    color(249, 252, 246).setFill()
    bg.fill()
    NSShadow().set()

    let edge = NSBezierPath(roundedRect: rect(138, 156, 92, 712), xRadius: r(46), yRadius: r(46))
    color(166, 217, 218).setFill()
    edge.fill()

    let note = NSBezierPath(roundedRect: rect(204, 166, 648, 692), xRadius: r(88), yRadius: r(88))
    NSShadow().with {
        $0.shadowOffset = NSSize(width: r(22), height: -r(28))
        $0.shadowBlurRadius = r(42)
        $0.shadowColor = color(128, 100, 42, 0.24)
    }.set()
    color(255, 239, 98).setFill()
    note.fill()
    NSShadow().set()

    color(219, 183, 72, 0.36).setStroke()
    note.lineWidth = r(10)
    note.stroke()

    let fold = NSBezierPath()
    fold.move(to: NSPoint(x: r(728), y: r(858)))
    fold.line(to: NSPoint(x: r(852), y: r(734)))
    fold.line(to: NSPoint(x: r(852), y: r(858)))
    fold.close()
    color(255, 248, 154).setFill()
    fold.fill()
    color(227, 199, 88, 0.42).setStroke()
    fold.lineWidth = r(8)
    fold.stroke()

    color(61, 49, 29, 0.20).setFill()
    for y in [382, 500, 618] as [CGFloat] {
        NSBezierPath(roundedRect: rect(328, y, 398, 34), xRadius: r(17), yRadius: r(17)).fill()
    }

    let tab = NSBezierPath(roundedRect: rect(602, 244, 188, 188), xRadius: r(94), yRadius: r(94))
    NSShadow().with {
        $0.shadowOffset = NSSize(width: 0, height: -r(10))
        $0.shadowBlurRadius = r(22)
        $0.shadowColor = color(52, 111, 112, 0.22)
    }.set()
    color(166, 217, 218).setFill()
    tab.fill()
    NSShadow().set()

    color(255, 238, 92).setFill()
    drawHeart(in: CGRect(x: r(642), y: r(284), width: r(108), height: r(104)))

    image.unlockFocus()
    return image
}

extension NSShadow {
    func with(_ update: (NSShadow) -> Void) -> NSShadow {
        update(self)
        return self
    }
}

var rendered: [String: Data] = [:]

for output in outputs {
    let image = makeIcon(size: output.1)
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let data = rep.representation(using: .png, properties: [:])
    else {
        fatalError("Could not render \(output.0)")
    }
    try data.write(to: iconset.appendingPathComponent(output.0))
    rendered[output.0] = data
}

func appendUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    data.append(Data(bytes: &bigEndian, count: 4))
}

func appendChunk(type: String, png: Data, to data: inout Data) {
    data.append(type.data(using: .ascii)!)
    appendUInt32(UInt32(png.count + 8), to: &data)
    data.append(png)
}

let chunks: [(String, String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

var body = Data()
for chunk in chunks {
    guard let png = rendered[chunk.1] else {
        fatalError("Missing \(chunk.1)")
    }
    appendChunk(type: chunk.0, png: png, to: &body)
}

var file = Data()
file.append("icns".data(using: .ascii)!)
appendUInt32(UInt32(body.count + 8), to: &file)
file.append(body)
try file.write(to: icns)
