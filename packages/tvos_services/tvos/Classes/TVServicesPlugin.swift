import Flutter
import UIKit
import AuthenticationServices
import AVKit
import AVFoundation
import BackgroundTasks

public final class TVServicesPlugin: NSObject, FlutterPlugin, AVContinuityDevicePickerViewControllerDelegate {
  public static var registerBackgroundPlugins: ((FlutterPluginRegistry) -> Void)?
  private static let taskID = "com.openplayx.app.metadata"
  private static var engine: FlutterEngine?
  private static var channel: FlutterMethodChannel?
  private var authentication: ASWebAuthenticationSession?
  private var microphoneResult: FlutterResult?
  private weak var presenter: UIViewController?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = TVServicesPlugin()
    instance.presenter = registrar.viewController
    let channel = FlutterMethodChannel(name: "openplayx/tvos", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
    let auth = FlutterMethodChannel(name: "flutter_web_auth_2", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: auth)
  }

  public static func registerBackgroundTask() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: .main) { task in
      let engine = FlutterEngine(name: "openplayx-tvos-metadata", project: nil, allowHeadlessExecution: true)
      self.engine = engine
      let channel = FlutterMethodChannel(name: "openplayx/tvos_background", binaryMessenger: engine.binaryMessenger)
      self.channel = channel
      channel.setMethodCallHandler { call, result in
        guard call.method == "complete" else { result(FlutterMethodNotImplemented); return }
        task.setTaskCompleted(success: call.arguments as? Bool ?? false)
        self.engine?.destroyContext(); self.engine = nil; self.channel = nil
        result(nil)
      }
      task.expirationHandler = {
        self.channel?.invokeMethod("stop", arguments: nil)
        task.setTaskCompleted(success: false)
        DispatchQueue.main.async { self.engine?.destroyContext(); self.engine = nil; self.channel = nil }
      }
      guard engine.run(withEntrypoint: "tvosMetadataBackgroundMain", libraryURI: "package:openplayx/capabilities/metadata/metadata_background.dart") else {
        task.setTaskCompleted(success: false); return
      }
      registerBackgroundPlugins?(engine)
    }
  }

  private func currentPresenter() -> UIViewController? {
    var controller = presenter ?? UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
      .first(where: { $0.isKeyWindow })?.rootViewController
    while let presented = controller?.presentedViewController { controller = presented }
    return controller
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "authenticate":
      guard authentication == nil, let value = args["url"] as? String, let url = URL(string: value), url.scheme == "https" else {
        result(FlutterError(code: "INVALID_URL", message: "An HTTPS authentication URL is required", details: nil)); return
      }
      authentication = ASWebAuthenticationSession(url: url, callbackURLScheme: args["callbackUrlScheme"] as? String) { [weak self] callback, error in
        self?.authentication = nil
        if let callback { result(callback.absoluteString) }
        else { result(FlutterError(code: "CANCELED", message: error?.localizedDescription, details: nil)) }
      }
      // tvOS presents Apple's nearby-device authentication sheet; presentation
      // anchors, ephemeral browser preferences and programmatic cancel are not
      // part of this platform's API.
      if authentication?.start() != true {
        authentication = nil; result(FlutterError(code: "AUTH_FAILED", message: "Authentication could not start", details: nil))
      }
    case "cleanUpDanglingCalls": result(nil)
    case "pickFile", "pickDirectory":
      let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("OpenPlayX")
      do { try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true) }
      catch { result(FlutterError(code: "STORAGE", message: "Local storage unavailable", details: nil)); return }
      guard let host = currentPresenter() else {
        result(FlutterError(code: "NO_WINDOW", message: "No active TV window", details: nil)); return
      }
      let picker = LocalFilePicker(root: root, directory: root, foldersOnly: call.method == "pickDirectory", extensions: args["extensions"] as? [String] ?? []) { selected in
        host.dismiss(animated: true)
        result(selected?.path)
      }
      let navigation = UINavigationController(rootViewController: picker)
      host.present(navigation, animated: true)
    case "connectMicrophone":
      guard microphoneResult == nil else { result(FlutterError(code: "BUSY", message: "Device picker already open", details: nil)); return }
      guard let host = currentPresenter() else {
        result(FlutterError(code: "NO_WINDOW", message: "No active TV window", details: nil)); return
      }
      microphoneResult = result
      let picker = AVContinuityDevicePickerViewController()
      picker.delegate = self
      host.present(picker, animated: true)
    case "scheduleMetadata":
      let request = BGProcessingTaskRequest(identifier: Self.taskID)
      request.requiresNetworkConnectivity = args["online"] as? Bool ?? true
      request.requiresExternalPower = false
      request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
      do { try BGTaskScheduler.shared.submit(request); result(nil) }
      catch { result(FlutterError(code: "BACKGROUND_UNAVAILABLE", message: error.localizedDescription, details: nil)) }
    case "bundledWhisperModel":
      let bundles = [Bundle.main, Bundle(for: TVServicesPlugin.self)]
      let path = bundles.compactMap { $0.url(forResource: "OpenPlayXModels", withExtension: "bundle") }
        .compactMap { Bundle(url: $0)?.path(forResource: "ggml-tiny", ofType: "bin") }.first
      result(path)
    case "capabilities": result(["authentication": true, "localFilePicker": true, "continuityMicrophone": true, "backgroundProcessing": true])
    default: result(FlutterMethodNotImplemented)
    }
  }
  public func continuityDevicePickerWillBeginPresenting(_ pickerViewController: AVContinuityDevicePickerViewController) {}
  public func continuityDevicePicker(_ pickerViewController: AVContinuityDevicePickerViewController, didConnect device: AVContinuityDevice) {
    microphoneResult?(true); microphoneResult = nil
  }
  public func continuityDevicePickerDidCancel(_ pickerViewController: AVContinuityDevicePickerViewController) {
    microphoneResult?(false); microphoneResult = nil
  }
  public func continuityDevicePickerDidEndPresenting(_ pickerViewController: AVContinuityDevicePickerViewController) {}
}

private final class LocalFilePicker: UITableViewController {
  let root: URL, directory: URL
  let foldersOnly: Bool
  let extensions: Set<String>
  let completion: (URL?) -> Void
  var entries: [URL] = []
  init(root: URL, directory: URL, foldersOnly: Bool, extensions: [String], completion: @escaping (URL?) -> Void) {
    self.root = root; self.directory = directory; self.foldersOnly = foldersOnly
    self.extensions = Set(extensions.map { $0.lowercased() }); self.completion = completion
    super.init(style: .plain)
    title = directory.lastPathComponent
    entries = ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []).filter { url in
      let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
      return values?.isDirectory == true || (!foldersOnly && (self.extensions.isEmpty || self.extensions.contains(url.pathExtension.lowercased())))
    }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
  }
  required init?(coder: NSCoder) { fatalError("Not used") }
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { entries.count + (foldersOnly ? 2 : 1) }
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    if indexPath.row == 0 { cell.textLabel?.text = "Cancel / 取消" }
    else if foldersOnly && indexPath.row == 1 { cell.textLabel?.text = "Choose this folder / 选择此文件夹" }
    else { cell.textLabel?.text = entries[indexPath.row - (foldersOnly ? 2 : 1)].lastPathComponent }
    return cell
  }
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if indexPath.row == 0 { completion(nil); return }
    if foldersOnly && indexPath.row == 1 { completion(directory); return }
    let selected = entries[indexPath.row - (foldersOnly ? 2 : 1)]
    // Never follow a symlink out of the application-owned cache.
    guard selected.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/") else { return }
    if (try? selected.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
      navigationController?.pushViewController(LocalFilePicker(root: root, directory: selected, foldersOnly: foldersOnly, extensions: Array(extensions), completion: completion), animated: true)
    } else { completion(selected) }
  }
}
