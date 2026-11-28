import Cocoa
// FlutterMethodNotImplemented is a constant sentinel that C exports as a
// mutable global; @preconcurrency keeps references to it from being flagged.
@preconcurrency import FlutterMacOS
import desktop_multi_window

// Everything in this file runs on the main thread: Flutter invokes method
// channel handlers there, AppKit posts the window notifications there (block
// observers also name the main queue), and the NSWindow APIs are main-actor
// isolated. The types say so with @MainActor.

@MainActor
final class PlayerWindowCloser: NSObject, NSWindowDelegate {
  /// Association key; only its address is used.
  nonisolated(unsafe) static var key: UInt8 = 0
  private let channel: FlutterMethodChannel
  init(channel: FlutterMethodChannel) { self.channel = channel }
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    channel.invokeMethod("windowClosing", arguments: nil)
    return false
  }
}

/// The only place that calls `toggleFullScreen`. AppKit throws from
/// -[NSWindow _reallySetFrame:] when a full-screen toggle lands while a
/// transition of the same window is still running (a second double-click or
/// Esc during the enter animation, picture in picture leaving full screen),
/// so requests made then are deferred until the transition finishes.
/// Enforced by the `toggle-fullscreen-unguarded` CI rule.
@MainActor
final class FullScreenGuard {
  static let shared = FullScreenGuard()
  /// Windows between will{Enter,Exit}FullScreen and did{Enter,Exit}FullScreen,
  /// mapped to a generation that expires a stuck flag.
  private var transitioning: [ObjectIdentifier: Int] = [:]
  private var pending: [ObjectIdentifier: Bool] = [:]
  private var generation = 0
  private var observers: [NSObjectProtocol] = []

  private init() {
    let starts = [NSWindow.willEnterFullScreenNotification, NSWindow.willExitFullScreenNotification]
    let ends = [NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification]
    for name in starts + ends {
      let isStart = starts.contains(name)
      observers.append(
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
          [weak self] note in
          let window = note.object as? NSWindow
          MainActor.assumeIsolated {
            guard let self = self, let window = window else { return }
            isStart ? self.began(window) : self.ended(window)
          }
        })
    }
  }

  func isTransitioning(_ window: NSWindow) -> Bool {
    transitioning[ObjectIdentifier(window)] != nil
  }

  /// Applies the full-screen state now, or once the running transition has
  /// finished. Returns false when the request was deferred.
  @discardableResult
  func request(_ window: NSWindow, fullScreen wanted: Bool) -> Bool {
    let id = ObjectIdentifier(window)
    if transitioning[id] != nil {
      pending[id] = wanted
      return false
    }
    pending[id] = nil
    if wanted != window.styleMask.contains(.fullScreen) { window.toggleFullScreen(nil) }
    return true
  }

  private func began(_ window: NSWindow) {
    let id = ObjectIdentifier(window)
    generation &+= 1
    let mine = generation
    transitioning[id] = mine
    // A failed transition only reaches the window delegate, not a
    // notification; never leave requests blocked for good.
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
      MainActor.assumeIsolated {
        guard let self = self, self.transitioning[id] == mine else { return }
        self.transitioning[id] = nil
      }
    }
  }

  private func ended(_ window: NSWindow) {
    let id = ObjectIdentifier(window)
    transitioning[id] = nil
    guard let wanted = pending.removeValue(forKey: id) else { return }
    // Next run-loop turn: AppKit is still unwinding the transition.
    Task { @MainActor [weak self, weak window] in
      guard let self = self, let window = window else { return }
      self.request(window, fullScreen: wanted)
    }
  }
}

/// Native full screen for the Flutter player (`openplayx/window`). Each
/// Flutter view controller (main window and player windows) gets its own
/// channel; Dart is told when the user changes full screen natively.
@MainActor
final class WindowFullScreenChannel: NSObject {
  /// Association key; only its address is used.
  nonisolated(unsafe) static var key: UInt8 = 0
  private let channel: FlutterMethodChannel
  private weak var controller: FlutterViewController?

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
        // A deferred request reports the current state; Dart learns the
        // final one from `fullScreenChanged`.
        result(FullScreenGuard.shared.request(window, fullScreen: wanted) ? wanted : isFull)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    // Selector observers are removed when this object is deallocated, so no
    // deinit has to reach main-actor state. AppKit posts these on the main thread.
    for name in [NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification] {
      NotificationCenter.default.addObserver(
        self, selector: #selector(fullScreenChanged(_:)), name: name, object: nil)
    }
  }

  @objc private func fullScreenChanged(_ note: Notification) {
    guard let window = note.object as? NSWindow, window === controller?.view.window else { return }
    channel.invokeMethod("fullScreenChanged", arguments: window.styleMask.contains(.fullScreen))
  }
}

@MainActor
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

  // NSObject declares awakeFromNib nonisolated; AppKit calls it on the main
  // thread while loading MainMenu.xib.
  nonisolated override func awakeFromNib() {
    MainActor.assumeIsolated { setUp() }
    super.awakeFromNib()
  }

  private func setUp() {
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
          let queue = self.sourceAccessQueue
          Task { @MainActor in
            if case let (url, accessed, readable)? = await Self.resolveBookmark(data, on: queue) {
              if accessed { self.accessedURLs.append(url) }
              if readable {
                result(url.path)
                return
              }
            }
            result(FlutterError(code: "permissionDenied", message: "请重新选择文件夹以恢复授权。", details: nil))
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
  }

  /// Resolves a bookmark on `queue` and starts its security scope there.
  /// Returns the URL, whether its access was started, and whether it is
  /// readable; nil when the bookmark cannot be resolved.
  private nonisolated static func resolveBookmark(
    _ data: Data, on queue: DispatchQueue
  ) async -> (URL, Bool, Bool)? {
    await withCheckedContinuation { continuation in
      queue.async {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale) else {
          continuation.resume(returning: nil)
          return
        }
        let accessed = url.startAccessingSecurityScopedResource()
        let readable = accessed || FileManager.default.isReadableFile(atPath: url.path)
        continuation.resume(returning: (url, accessed, readable))
      }
    }
  }
}

/// Reuses the playing window and engine, so tracks, decoder and playback
/// position survive both transitions without reopening the media.
@MainActor
final class PictureInPictureWindowChannel: NSObject {
  /// Association key; only its address is used.
  nonisolated(unsafe) static var key: UInt8 = 0
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
  /// An `enter` waiting for full screen to finish exiting.
  private var pendingEnter: (ratio: Double, result: FlutterResult)?

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
        // Already in picture in picture, or waiting for full screen to exit.
        if self.savedFrame != nil || self.pendingEnter != nil { result(true); return }
        let args = call.arguments as? [String: Any]
        let raw = args?["aspectRatio"] as? Double ?? 16.0 / 9.0
        let ratio = raw.isFinite ? min(2.39, max(1.0 / 2.39, raw)) : 16.0 / 9.0
        if window.styleMask.contains(.fullScreen) {
          self.restoreFullscreen = true
          self.pendingEnter = (ratio, result)
          // A selector observer is removed when this object is deallocated.
          NotificationCenter.default.addObserver(
            self, selector: #selector(self.didExitFullScreen(_:)),
            name: NSWindow.didExitFullScreenNotification, object: window)
          FullScreenGuard.shared.request(window, fullScreen: false)
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

  /// Finishes an `enter` that waited for full screen to exit.
  @objc private func didExitFullScreen(_ note: Notification) {
    NotificationCenter.default.removeObserver(
      self, name: NSWindow.didExitFullScreenNotification, object: note.object)
    guard let window = note.object as? NSWindow, let pending = pendingEnter else { return }
    pendingEnter = nil
    enter(window, ratio: pending.ratio)
    pending.result(true)
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
    let screen = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? window.frame
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
      FullScreenGuard.shared.request(window, fullScreen: true)
    }
  }
}
