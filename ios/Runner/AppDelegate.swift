import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging
import UserNotifications
import GoogleMobileAds
import AppTrackingTransparency
import AdSupport

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Inizializza Firebase
    FirebaseApp.configure()

    // Inizializza Google Mobile Ads
    MobileAds.shared.start(completionHandler: nil)

    // Richiesta permesso tracking (iOS 14+)
    if #available(iOS 14, *) {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        ATTrackingManager.requestTrackingAuthorization { status in
          switch status {
          case .authorized:
            print("Tracking autorizzato ✅ IDFA: \(ASIdentifierManager.shared().advertisingIdentifier)")
          case .denied:
            print("Tracking negato ❌")
          case .restricted:
            print("Tracking ristretto ⚠️")
          case .notDetermined:
            print("Tracking non determinato ℹ️")
          @unknown default:
            print("Stato tracking sconosciuto")
          }
        }
      }
    }

    // Configura notifiche push
    configurePushNotifications(application)

    // Registra i plugin Flutter
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configurePushNotifications(_ application: UIApplication) {
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
      let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }

    application.registerForRemoteNotifications()
  }

  // Ricezione del token APNs da Apple
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
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
