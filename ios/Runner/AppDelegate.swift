
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
      UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
        if let error = error {
          print("Errore autorizzazione notifiche: \(error.localizedDescription)")
        } else {
          print("Autorizzazione notifiche concessa: \(granted)")
        }
      }
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

  // Ricezione del token APNs da Apple
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Passa il token APNs a Firebase
    Messaging.messaging().apnsToken = deviceToken

    // (Facoltativo) Stampa il token per debug
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("APNs device token ricevuto: \(tokenString)")
  }

  // Gestione errori nella registrazione per notifiche remote
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("Registrazione notifiche fallita: \(error.localizedDescription)")
  }
}
