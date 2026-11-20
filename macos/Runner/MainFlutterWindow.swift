import Cocoa
import FlutterMacOS
import desktop_multi_window

final class PlayerWindowCloser: NSObject, NSWindowDelegate {
  static var key: UInt8 = 0
  private let channel: FlutterMethodChannel
  init(channel: FlutterMethodChannel) { self.channel = channel }
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    channel.invokeMethod("windowClosing", arguments: nil)
    return false
  }
}

/// Native full screen for the Flutter player (`openplayx/window`). Each
/// Flutter view controller (main window and player windows) gets its own
/// channel; Dart is told when the user changes full screen natively.
final class WindowFullScreenChannel: NSObject {
  static var key: UInt8 = 0
  private let channel: FlutterMethodChannel
  private weak var controller: FlutterViewController?
  private var observers: [NSObjectProtocol] = []

  static func register(_ controller: FlutterViewController) {
    let handler = WindowFullScreenChannel(controller)
    objc_setAssociatedObject(controller, &key, handler, .OBJC_ASSOCIATION_RETAIN)
  }

  private init(_ controller: FlutterViewController) {
    self.controller = controller
    channel = FlutterMethodChannel(
      name: "openplayx/window", binaryMessenger: controller.engine.binaryMessenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let window = self?.controller?.view.window else {
        result(false)
        return
      }
      let isFull = window.styleMask.contains(.fullScreen)
      switch call.method {
      case "isFullScreen":
        result(isFull)
      case "setFullScreen":
        let wanted = call.arguments as? Bool ?? !isFull
        if wanted != isFull { window.toggleFullScreen(nil) }
        result(wanted)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    for name in [NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification] {
      observers.append(
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
          [weak self] note in
          guard let self = self, let window = note.object as? NSWindow,
            window === self.controller?.view.window
          else { return }
          self.channel.invokeMethod(
            "fullScreenChanged", arguments: window.styleMask.contains(.fullScreen))
        })
    }
  }

  deinit {
    observers.forEach(NotificationCenter.default.removeObserver)
  }
}

class MainFlutterWindow: NSWindow {
  private var sourceAccess: FlutterMethodChannel?
  private var accessedURLs: [URL] = []
  private let sourceAccessQueue = DispatchQueue(label: "openplayx.source-access")
  private static func configurePlayerWindow(_ controller: FlutterViewController) {
    guard let window = controller.view.window else { return }
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.styleMask.insert(.fullSizeContentView)
    window.appearance = NSAppearance(named: .darkAqua)
    window.backgroundColor = .black
    window.minSize = NSSize(width: 480, height: 300)
    window.setContentSize(NSSize(width: 1100, height: 650))
    window.center()
    let channel = FlutterMethodChannel(
      name: "openplayx/player_window", binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak window] call, result in
      if call.method == "close" {
        window?.close()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    // Hold back a native close (red button, Cmd+W) until Dart stopped playback;
    // its `close` call above then closes the window for real.
    let closer = PlayerWindowCloser(channel: channel)
    window.delegate = closer
    objc_setAssociatedObject(window, &PlayerWindowCloser.key, closer, .OBJC_ASSOCIATION_RETAIN)
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    FlutterMethodChannel(name: "openplayx/transfer_storage", binaryMessenger: flutterViewController.engine.binaryMessenger)
      .setMethodCallHandler { call, result in
        guard call.method == "availableBytes" else { result(FlutterMethodNotImplemented); return }
        do {
          let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSTemporaryDirectory())
          result((attrs[.systemFreeSize] as? NSNumber)?.int64Value)
        } catch { result(FlutterError(code: "storage_unavailable", message: "Unable to check cache space", details: nil)) }
      }
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // Let Flutter fill the title area while retaining the native window controls.
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)
    if #available(macOS 11.0, *) {
      titlebarSeparatorStyle = .none
    }
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

    // Start the engine before registering plugins. Otherwise it only starts in
    // viewWillAppear, and desktop_multi_window's registration sends
    // `onWindowsChanged` to a not-yet-running engine ("Invalid engine handle").
    if !flutterViewController.engine.run(withEntrypoint: nil) {
      NSLog("openplayx: failed to start the main Flutter engine")
    }
    RegisterGeneratedPlugins(registry: flutterViewController)

    // Playback opens in its own window with its own Flutter engine. Each one
    // needs the plugins registered and the same integrated title bar.
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      RegisterGeneratedPlugins(registry: controller)
      MainFlutterWindow.configurePlayerWindow(controller)
      WindowFullScreenChannel.register(controller)
    }
    WindowFullScreenChannel.register(flutterViewController)

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
