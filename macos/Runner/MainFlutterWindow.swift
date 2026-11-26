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
      PictureInPictureWindowChannel.register(controller)
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

/// Reuses the playing window and engine, so tracks, decoder and playback
/// position survive both transitions without reopening the media.
final class PictureInPictureWindowChannel: NSObject {
  static var key: UInt8 = 0
  private let channel: FlutterMethodChannel
  private weak var controller: FlutterViewController?
  private var savedFrame: NSRect?
  private var savedStyle: NSWindow.StyleMask = []
  private var savedMin = NSSize.zero
  private var savedContentMin = NSSize.zero
  private var savedAspect = NSSize.zero
  private var savedLevel: NSWindow.Level = .normal
  private var savedCollection: NSWindow.CollectionBehavior = []
  private var savedMovable = false
  private var savedButtonHidden: [NSWindow.ButtonType: Bool] = [:]
  private var restoreFullscreen = false
  private var exitObserver: NSObjectProtocol?

  static func register(_ controller: FlutterViewController) {
    let handler = PictureInPictureWindowChannel(controller)
    objc_setAssociatedObject(controller, &key, handler, .OBJC_ASSOCIATION_RETAIN)
  }

  private init(_ controller: FlutterViewController) {
    self.controller = controller
    channel = FlutterMethodChannel(name: "openplayx/picture_in_picture",
                                  binaryMessenger: controller.engine.binaryMessenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self, let window = self.controller?.view.window else {
        result(false); return
      }
      switch call.method {
      case "isSupported": result(true)
      case "enter":
        if self.savedFrame != nil { result(true); return }
        let args = call.arguments as? [String: Any]
        let raw = args?["aspectRatio"] as? Double ?? 16.0 / 9.0
        let ratio = raw.isFinite ? min(2.39, max(1.0 / 2.39, raw)) : 16.0 / 9.0
        if window.styleMask.contains(.fullScreen) {
          self.restoreFullscreen = true
          self.exitObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didExitFullScreenNotification, object: window, queue: .main
          ) { [weak self, weak window] _ in
            guard let self = self, let window = window else { return }
            if let observer = self.exitObserver { NotificationCenter.default.removeObserver(observer) }
            self.exitObserver = nil
            self.enter(window, ratio: ratio)
            result(true)
          }
          window.toggleFullScreen(nil)
        } else {
          self.enter(window, ratio: ratio)
          result(true)
        }
      case "exit":
        self.restore(window)
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func enter(_ window: NSWindow, ratio: Double) {
    savedFrame = window.frame
    savedStyle = window.styleMask
    savedMin = window.minSize
    savedContentMin = window.contentMinSize
    savedAspect = window.contentAspectRatio
    savedLevel = window.level
    savedCollection = window.collectionBehavior
    savedMovable = window.isMovableByWindowBackground
    window.minSize = NSSize(width: 240, height: 135)
    window.contentMinSize = NSSize(width: 240, height: 135)
    // A titled window can become key again after another app takes focus.
    // A borderless NSWindow cannot, which would break keyboard controls.
    window.styleMask = [.titled, .resizable, .fullSizeContentView]
    for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
      savedButtonHidden[type] = window.standardWindowButton(type)?.isHidden ?? false
      window.standardWindowButton(type)?.isHidden = true
    }
    window.isMovableByWindowBackground = true
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.contentAspectRatio = NSSize(width: ratio, height: 1)
    let screen = window.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
    let width = min(420.0, min(screen.width * 0.45, (screen.height - 40) * ratio))
    let height = width / ratio
    window.setFrame(NSRect(x: screen.maxX - width - 20, y: screen.minY + 20,
                           width: width, height: height), display: true)
    channel.invokeMethod("changed", arguments: true)
  }

  private func restore(_ window: NSWindow) {
    guard let frame = savedFrame else { return }
    savedFrame = nil
    window.contentAspectRatio = savedAspect
    window.styleMask = savedStyle
    for (type, hidden) in savedButtonHidden {
      window.standardWindowButton(type)?.isHidden = hidden
    }
    savedButtonHidden.removeAll()
    window.level = savedLevel
    window.collectionBehavior = savedCollection
    window.isMovableByWindowBackground = savedMovable
    window.minSize = savedMin
    window.contentMinSize = savedContentMin
    window.setFrame(frame, display: true)
    window.makeKeyAndOrderFront(nil)
    channel.invokeMethod("changed", arguments: false)
    if restoreFullscreen {
      restoreFullscreen = false
      window.toggleFullScreen(nil)
    }
  }

  deinit {
    if let observer = exitObserver { NotificationCenter.default.removeObserver(observer) }
  }
}
