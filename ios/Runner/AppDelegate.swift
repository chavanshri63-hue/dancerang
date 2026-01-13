import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Set notification center delegate AFTER plugin registration
    // This ensures our delegate handles foreground notifications
    // We set it after to override any plugin delegate settings
    UNUserNotificationCenter.current().delegate = self
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Show notifications even when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show banner, sound, and badge even when app is in foreground
    if #available(iOS 14.0, *) {
      // iOS 14+ supports banner and list
      completionHandler([.banner, .sound, .badge, .list])
    } else {
      // iOS 13 and below use alert
      completionHandler([.alert, .sound, .badge])
    }
  }
  
  // Handle notification tap
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    // Let Flutter handle the notification tap
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
