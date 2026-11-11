import Flutter
import UIKit
import Network

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let networkMonitor = NWPathMonitor()
  private let networkQueue = DispatchQueue(label: "openplayx.network-policy")
  private var networkChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    networkMonitor.start(queue: networkQueue)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OpenPlayXNetworkPolicy") {
      let channel = FlutterMethodChannel(name: "openplayx/network_policy", binaryMessenger: registrar.messenger())
      networkChannel = channel
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
