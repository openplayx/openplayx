import Flutter
import UIKit
import Network

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let networkMonitor = NWPathMonitor()
  private let networkQueue = DispatchQueue(label: "openplayx.network-policy")
  private var networkChannel: FlutterMethodChannel?
  private var sourceAccess: SourceAccess?
  private var orientationStream: DeviceOrientationStream?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    networkMonitor.start(queue: networkQueue)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OpenPlayXDeviceOrientation") {
      let stream = DeviceOrientationStream()
      orientationStream = stream
      FlutterEventChannel(name: "openplayx/device_orientation", binaryMessenger: registrar.messenger())
        .setStreamHandler(stream)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OpenPlayXSourceAccess") {
      sourceAccess = SourceAccess(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OpenPlayXTransferStorage") {
      FlutterMethodChannel(name: "openplayx/transfer_storage", binaryMessenger: registrar.messenger())
        .setMethodCallHandler { call, result in
          guard call.method == "availableBytes" else { result(FlutterMethodNotImplemented); return }
          do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSTemporaryDirectory())
            result((attrs[.systemFreeSize] as? NSNumber)?.int64Value)
          } catch { result(FlutterError(code: "storage_unavailable", message: "Unable to check cache space", details: nil)) }
        }
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OpenPlayXNetworkPolicy") {
      let channel = FlutterMethodChannel(name: "openplayx/network_policy", binaryMessenger: registrar.messenger())
      networkChannel = channel
      networkMonitor.pathUpdateHandler = { [weak self] _ in
        DispatchQueue.main.async { self?.networkChannel?.invokeMethod("networkChanged", arguments: nil) }
      }
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "usingCellular" else { result(FlutterMethodNotImplemented); return }
        guard let self = self else { result(FlutterError(code: "network_unknown", message: "Network state unavailable", details: nil)); return }
        let path = self.networkMonitor.currentPath
        guard path.status == .satisfied else { result(FlutterError(code: "network_unknown", message: "Network is not ready", details: nil)); return }
        result(path.usesInterfaceType(.cellular))
      }
    }
  }
}

// Device notifications continue while the interface orientation is locked.
private final class DeviceOrientationStream: NSObject, FlutterStreamHandler {
  private var observer: NSObjectProtocol?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    func emit() {
      switch UIDevice.current.orientation {
      case .portrait: events("portraitUp")
      case .portraitUpsideDown: events("portraitDown")
      case .landscapeLeft: events("landscapeLeft")
      case .landscapeRight: events("landscapeRight")
      default: break // Face-up/down and unknown readings have no screen direction.
      }
    }
    observer = NotificationCenter.default.addObserver(
      forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main
    ) { _ in emit() }
    emit()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer = observer { NotificationCenter.default.removeObserver(observer) }
    observer = nil
    UIDevice.current.endGeneratingDeviceOrientationNotifications()
    return nil
  }
}
