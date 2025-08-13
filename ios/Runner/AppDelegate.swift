import UIKit
import Flutter
import Firebase
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Inizializza Firebase
    FirebaseApp.configure()

    // Richiesta permesso notifiche (solo iOS 10+)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { _, _ in }
    } else {
      // Supporto vecchi iOS (quasi sempre inutile oggi)
      let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }

    // Registrazione per le notifiche push
    application.registerForRemoteNotifications()

    // Registra i plugin Flutter
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
