import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var appInfoChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MiPasajeAppInfo") else { return }
    let channel = FlutterMethodChannel(name: "com.transita.bolivia/app_info", binaryMessenger: registrar.messenger())
    appInfoChannel = channel
    channel.setMethodCallHandler { call, result in
      if call.method == "appVersion" {
        result([
          "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
          "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        ])
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
