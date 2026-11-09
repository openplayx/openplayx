import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var sourceAccess: FlutterMethodChannel?
  private var accessedURLs: [URL] = []
  private let sourceAccessQueue = DispatchQueue(label: "openplayx.source-access")
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // Start with enough space for the media library and connection dialogs,
    // while fitting smaller laptop displays without opening off-screen.
    let visibleFrame = self.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
    let contentSize = NSSize(
      width: min(1280, max(320, (visibleFrame?.width ?? 1320) - 40)),
      height: min(800, max(320, (visibleFrame?.height ?? 860) - 60))
    )
    self.setContentSize(contentSize)
    self.contentMinSize = NSSize(width: min(960, contentSize.width), height: min(640, contentSize.height))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    sourceAccess = FlutterMethodChannel(name: "openplayx/source_access", binaryMessenger: flutterViewController.engine.binaryMessenger)
    sourceAccess?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      do {
        switch call.method {
        case "create":
          guard let path = call.arguments as? String else { result(nil); return }
          let url = URL(fileURLWithPath: path)
          let data = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
          result(data.base64EncodedString())
        case "restore":
          guard let raw = call.arguments as? String, let data = Data(base64Encoded: raw) else { result(nil); return }
          // Resolving a bookmark can block on an unavailable volume. Never
          // wait for mounts or system authorization UI on Flutter's main thread.
          self.sourceAccessQueue.async {
            do {
              var stale = false
              let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale)
              let accessed = url.startAccessingSecurityScopedResource()
              let readable = accessed || FileManager.default.isReadableFile(atPath: url.path)
              DispatchQueue.main.async {
                if accessed { self.accessedURLs.append(url) }
                if readable {
                  result(url.path)
                } else {
                  result(FlutterError(code: "permissionDenied", message: "请重新选择文件夹以恢复授权。", details: nil))
                }
              }
            } catch {
              DispatchQueue.main.async {
                result(FlutterError(code: "permissionDenied", message: "请重新选择文件夹以恢复授权。", details: nil))
              }
            }
          }
        case "releaseAll":
          for url in self.accessedURLs { url.stopAccessingSecurityScopedResource() }
          self.accessedURLs.removeAll()
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "permissionDenied", message: "请重新选择文件夹以恢复授权。", details: nil))
      }
    }
    super.awakeFromNib()
  }
}
