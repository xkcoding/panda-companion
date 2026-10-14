import AppKit
// Original vector mark: panda silhouette and a branching route.
let image = NSImage(size: NSSize(width: 512, height: 512))
image.lockFocus()
let tile = NSBezierPath(roundedRect: NSRect(x: 28, y: 28, width: 456, height: 456), xRadius: 106, yRadius: 106)
NSGradient(starting: NSColor(calibratedRed: 0.39, green: 0.85, blue: 0.76, alpha: 1), ending: NSColor(calibratedRed: 0.06, green: 0.53, blue: 0.48, alpha: 1))!.draw(in: tile, angle: -70)
let ink = NSColor(calibratedRed: 0.08, green: 0.20, blue: 0.21, alpha: 1)
ink.setFill()
for x: CGFloat in [91, 315] { NSBezierPath(ovalIn: NSRect(x: x, y: 318, width: 106, height: 106)).fill() }
let face = NSBezierPath(roundedRect: NSRect(x: 98, y: 105, width: 316, height: 277), xRadius: 130, yRadius: 130)
NSColor(calibratedRed: 0.97, green: 0.99, blue: 0.95, alpha: 1).setFill(); face.fill()
ink.setFill()
for x: CGFloat in [151, 283] { NSBezierPath(ovalIn: NSRect(x: x, y: 239, width: 78, height: 91)).fill() }
NSColor.white.setFill()
for x: CGFloat in [192, 298] { NSBezierPath(ovalIn: NSRect(x: x, y: 286, width: 15, height: 19)).fill() }
// The small route is also the panda's nose and mouth.
let route = NSBezierPath(); route.move(to: NSPoint(x: 256, y: 155)); route.line(to: NSPoint(x: 256, y: 191)); route.line(to: NSPoint(x: 222, y: 220))
route.move(to: NSPoint(x: 256, y: 191)); route.line(to: NSPoint(x: 290, y: 220))
route.lineWidth = 17; route.lineCapStyle = .round; route.lineJoinStyle = .round
NSColor(calibratedRed: 0.08, green: 0.55, blue: 0.46, alpha: 1).setStroke(); route.stroke()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
