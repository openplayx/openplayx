// FlutterMethodNotImplemented is a constant sentinel that C exports as a
// mutable global; @preconcurrency keeps references to it from being flagged.
@preconcurrency import Flutter
import UIKit
import UniformTypeIdentifiers

/// Local folder access on iOS (`openplayx/source_access`), the counterpart of
/// the macOS handler in MainFlutterWindow.swift.
///
/// A folder picked in Files is outside the sandbox: it is readable only while
/// its security scope is active, and only a bookmark brings it back after the
/// App restarts.
///
/// - `pickDirectory`: shows the system folder picker; returns the path, or nil
///   when cancelled. The picked folder stays accessible for this session.
/// - `create`: bookmark (base64) for a path picked in this session.
/// - `restore`: path of a bookmark, with its access started.
/// - `releaseAll`: stops every access started here.
///
/// Main actor: Flutter invokes the handler on the main thread, and the
/// document picker delegate is main-actor isolated.
@MainActor
final class SourceAccess: NSObject, UIDocumentPickerDelegate {
  private let channel: FlutterMethodChannel
  private var accessed: [URL] = []
  /// Folders picked this session, by path, so `create` bookmarks the URL that
  /// carries the security scope.
  private var picked: [String: URL] = [:]
  private var pending: FlutterResult?
  private let queue = DispatchQueue(label: "openplayx.source-access")

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "openplayx/source_access", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result)
    }
  }

  private static func denied() -> FlutterError {
    FlutterError(code: "permissionDenied", message: "请重新选择文件夹以恢复授权。", details: nil)
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "pickDirectory":
      pickDirectory(result)
    case "create":
      guard let path = call.arguments as? String else { result(nil); return }
      let url = picked[path] ?? URL(fileURLWithPath: path)
      do {
        let data = try url.bookmarkData(
          options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        result(data.base64EncodedString())
      } catch {
        result(Self.denied())
      }
    case "restore":
      guard let raw = call.arguments as? String, let data = Data(base64Encoded: raw) else {
        result(nil)
        return
      }
      // Resolving can block on a file provider; keep it off the main thread.
      let queue = self.queue
      Task { @MainActor in
        guard case let (url, started, readable)? = await Self.resolveBookmark(data, on: queue) else {
          result(Self.denied())
          return
        }
        if started { self.accessed.append(url) }
        result(readable ? url.path : Self.denied())
      }
    case "releaseAll":
      for url in accessed { url.stopAccessingSecurityScopedResource() }
      accessed.removeAll()
      picked.removeAll()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
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
        guard
          let url = try? URL(
            resolvingBookmarkData: data, options: [], relativeTo: nil,
            bookmarkDataIsStale: &stale)
        else {
          continuation.resume(returning: nil)
          return
        }
        let started = url.startAccessingSecurityScopedResource()
        let readable = started || FileManager.default.isReadableFile(atPath: url.path)
        continuation.resume(returning: (url, started, readable))
      }
    }
  }

  private func pickDirectory(_ result: @escaping FlutterResult) {
    guard pending == nil else {
      result(FlutterError(code: "busy", message: "A folder picker is already open.", details: nil))
      return
    }
    guard let presenter = Self.topViewController() else {
      result(FlutterError(code: "noWindow", message: "No window to present from.", details: nil))
      return
    }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
    picker.allowsMultipleSelection = false
    picker.delegate = self
    pending = result
    presenter.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pending else { return }
    pending = nil
    guard let url = urls.first else { result(nil); return }
    if url.startAccessingSecurityScopedResource() { accessed.append(url) }
    picked[url.path] = url
    result(url.path)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?(nil)
    pending = nil
  }

  private static func topViewController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}
