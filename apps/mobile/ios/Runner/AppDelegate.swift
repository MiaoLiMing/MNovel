import UIKit
import Flutter
import WebKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "mnovel/js_runner",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "evaluate",
            let arguments = call.arguments as? [String: Any],
            let script = arguments["script"] as? String,
            !script.isEmpty else {
        result(FlutterMethodNotImplemented)
        return
      }
      let webView = WKWebView(frame: .zero)
      webView.evaluateJavaScript(script) { value, error in
        if let error = error {
          result(FlutterError(code: "js_error", message: error.localizedDescription, details: nil))
        } else if let text = value as? String {
          result(text)
        } else if let value = value,
                  JSONSerialization.isValidJSONObject(value),
                  let data = try? JSONSerialization.data(withJSONObject: value),
                  let text = String(data: data, encoding: .utf8) {
          result(text)
        } else {
          result("")
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
