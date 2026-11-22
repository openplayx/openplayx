import Flutter
import UIKit
import Darwin
import tvos_services

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The tvOS embedder does not emit Dart native-asset mappings. Keep the
    // system SQLite loaded globally so sqlite3's @Native bindings resolve.
    guard dlopen("/usr/lib/libsqlite3.dylib", RTLD_NOW | RTLD_GLOBAL) != nil else {
      fatalError("Unable to load tvOS SQLite")
    }
    TVServicesPlugin.registerBackgroundPlugins = { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    TVServicesPlugin.registerBackgroundTask()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
