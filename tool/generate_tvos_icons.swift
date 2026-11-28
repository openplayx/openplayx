// Run from the app root: swift tool/generate_tvos_icons.swift
// Reuses the existing brand master for the tvOS layered icon and Top Shelf.
import AppKit

/// Stops the generator with a message when a required resource is missing.
func need<T>(_ value: T?, _ what: String) -> T {
  guard let value else { fatalError("generate_tvos_icons: \(what)") }
  return value
}

func loadImage(_ url: URL) -> CGImage {
  let source = need(CGImageSourceCreateWithURL(url as CFURL, nil), "cannot open \(url.lastPathComponent)")
  return need(CGImageSourceCreateImageAtIndex(source, 0, nil), "cannot decode \(url.lastPathComponent)")
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let source = root.appendingPathComponent("assets/branding/app_icon_foreground.png")
let master = loadImage(source)
let assets = root.appendingPathComponent("tvos/Runner/Assets.xcassets/AppIcon.brandassets")
for case let file as URL in need(FileManager.default.enumerator(at: assets, includingPropertiesForKeys: nil), "cannot list \(assets.path)") {
  guard file.pathExtension == "png" else { continue }
  let previous = loadImage(file)
  let w = previous.width, h = previous.height
  let cs = need(CGColorSpace(name: CGColorSpace.sRGB), "sRGB color space")
  let ctx = need(CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), "bitmap context")
  let back = file.lastPathComponent.contains("back") || file.lastPathComponent.contains("shelf")
  if back {
    ctx.setFillColor(need(CGColor(colorSpace: cs, components: [16/255, 17/255, 22/255, 1]), "background color"))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
  }
  if file.lastPathComponent.contains("front") || file.lastPathComponent.contains("shelf") {
    let size = CGFloat(h) * 0.72
    ctx.interpolationQuality = .high
    ctx.draw(master, in: CGRect(x: (CGFloat(w)-size)/2, y: (CGFloat(h)-size)/2, width: size, height: size))
  }
  let dest = need(CGImageDestinationCreateWithURL(file as CFURL, "public.png" as CFString, 1, nil), "cannot write \(file.lastPathComponent)")
  CGImageDestinationAddImage(dest, need(ctx.makeImage(), "render \(file.lastPathComponent)"), nil)
  precondition(CGImageDestinationFinalize(dest))
}
print("Generated tvOS brand assets")
