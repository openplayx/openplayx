// Run from the app root: swift tool/generate_tvos_icons.swift
// Reuses the existing brand master for the tvOS layered icon and Top Shelf.
import AppKit
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("assets/branding/app_icon_foreground.png")
let master = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(source as CFURL, nil)!, 0, nil)!
let assets = root.appendingPathComponent("tvos/Runner/Assets.xcassets/AppIcon.brandassets")
for case let file as URL in FileManager.default.enumerator(at: assets, includingPropertiesForKeys: nil)! {
  guard file.pathExtension == "png" else { continue }
  let previous = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(file as CFURL, nil)!, 0, nil)!
  let w = previous.width, h = previous.height
  let cs = CGColorSpace(name: CGColorSpace.sRGB)!
  let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  let back = file.lastPathComponent.contains("back") || file.lastPathComponent.contains("shelf")
  if back {
    ctx.setFillColor(CGColor(colorSpace: cs, components: [16/255, 17/255, 22/255, 1])!)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
  }
  if file.lastPathComponent.contains("front") || file.lastPathComponent.contains("shelf") {
    let size = CGFloat(h) * 0.72
    ctx.interpolationQuality = .high
    ctx.draw(master, in: CGRect(x: (CGFloat(w)-size)/2, y: (CGFloat(h)-size)/2, width: size, height: size))
  }
  let dest = CGImageDestinationCreateWithURL(file as CFURL, "public.png" as CFString, 1, nil)!
  CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
  precondition(CGImageDestinationFinalize(dest))
}
print("Generated tvOS brand assets")
