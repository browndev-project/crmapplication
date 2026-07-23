import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  static var initialNotificationPayload: [AnyHashable: Any]?
  static var methodChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    
    // Capture initial remote notification from launchOptions
    if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      print("🍎 [AppDelegate] Launched from remote notification: \(remoteNotification)")
      AppDelegate.initialNotificationPayload = remoteNotification
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    
    setupMethodChannelWithRetry()
  }

  private func setupMethodChannelWithRetry(attempts: Int = 0) {
    if let messenger = self.getBinaryMessenger() {
      print("🍎 [AppDelegate] Binary messenger is ready. Initializing MethodChannel...")
      let channel = FlutterMethodChannel(name: "com.browndev.crm/notifications", binaryMessenger: messenger)
      AppDelegate.methodChannel = channel
      
      channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        print("🍎 [AppDelegate] Method call received: \(call.method)")
        if call.method == "getInitialNotification" {
          if let payload = AppDelegate.initialNotificationPayload {
            print("🍎 [AppDelegate] Returning initialNotificationPayload: \(payload)")
            let stringPayload = self?.stringifyDictionary(payload)
            result(stringPayload)
            AppDelegate.initialNotificationPayload = nil
          } else {
            print("🍎 [AppDelegate] No initialNotificationPayload stored.")
            result(nil)
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    } else {
      if attempts < 10 {
        print("🍎 [AppDelegate] Binary messenger not ready yet. Retrying in 0.5s (attempt \(attempts + 1))...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
          self?.setupMethodChannelWithRetry(attempts: attempts + 1)
        }
      } else {
        print("🍎 [AppDelegate] Failed to get binary messenger after 10 attempts. MethodChannel not initialized.")
      }
    }
  }

  private func getBinaryMessenger() -> FlutterBinaryMessenger? {
    if let controller = self.window?.rootViewController as? FlutterViewController {
      return controller.binaryMessenger
    }
    if let controller = UIApplication.shared.windows.first?.rootViewController as? FlutterViewController {
      return controller.binaryMessenger
    }
    if let controller = UIApplication.shared.delegate?.window??.rootViewController as? FlutterViewController {
      return controller.binaryMessenger
    }
    return nil
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    print("🍎 [AppDelegate] Notification tapped! userInfo: \(userInfo)")
    
    let stringPayload = self.stringifyDictionary(userInfo)
    
    if let channel = AppDelegate.methodChannel {
      print("🍎 [AppDelegate] Channel is ready. Invoking onNotificationTapped...")
      channel.invokeMethod("onNotificationTapped", arguments: stringPayload)
    } else {
      print("🍎 [AppDelegate] Channel not ready. Saving payload as initialNotificationPayload.")
      AppDelegate.initialNotificationPayload = userInfo
    }
    
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  private func stringifyDictionary(_ dict: [AnyHashable: Any]) -> [String: String] {
    var stringMap: [String: String] = [:]
    for (key, value) in dict {
      let stringKey = String(describing: key)
      let stringVal = String(describing: value)
      stringMap[stringKey] = stringVal
    }
    return stringMap
  }
}
