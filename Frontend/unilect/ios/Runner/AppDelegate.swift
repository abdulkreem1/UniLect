import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScreenProtectionPlugin") {
      ScreenProtectionPlugin.register(with: registrar)
    }
  }
}

/// FR-058 on iOS. Public APIs cannot block screenshots, so this reports
/// screen recording / mirroring (`UIScreen.isCaptured`) to Flutter, which
/// hides protected content while capture is active. `enable`/`disable` are
/// accepted for API parity with Android and are no-ops here.
final class ScreenProtectionPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = ScreenProtectionPlugin()
    let methods = FlutterMethodChannel(
      name: "unilect/screen_protection", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(
      name: "unilect/screen_capture", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "enable", "disable":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    NotificationCenter.default.addObserver(
      self, selector: #selector(captureChanged),
      name: UIScreen.capturedDidChangeNotification, object: nil)
    events(UIScreen.main.isCaptured)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(
      self, name: UIScreen.capturedDidChangeNotification, object: nil)
    sink = nil
    return nil
  }

  @objc private func captureChanged() {
    sink?(UIScreen.main.isCaptured)
  }
}
