import Flutter
import UIKit
import LocalAuthentication

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var deviceSecurityChannel: FlutterMethodChannel?
  private var biometricContext: LAContext?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MiPasajeDeviceSecurity") else { return }
    let channel = FlutterMethodChannel(name: "com.transita.bolivia/device_security", binaryMessenger: registrar.messenger())
    deviceSecurityChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "appVersion":
        result([
          "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
          "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        ])
      case "biometricAvailable":
        let context = LAContext()
        result(context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil))
      case "authenticate":
        guard let self = self, self.biometricContext == nil else { result(false); return }
        let context = LAContext()
        context.localizedCancelTitle = "Cancelar"
        context.localizedFallbackTitle = ""
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { result(false); return }
        self.biometricContext = context
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Confirma tu identidad para continuar en Mi Pasaje") { [weak self] success, _ in
          DispatchQueue.main.async {
            self?.biometricContext = nil
            result(success)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
