import UIKit
import Flutter
import Firebase
import FirebaseMessaging
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Inizializza Firebase
    FirebaseApp.configure()

    // Imposta i delegati
    UNUserNotificationCenter.current().delegate = self
    Messaging.messaging().delegate = self

    // Richiesta permesso notifiche
    if #available(iOS 10.0, *) {
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
        if let error = error {
          print("Errore autorizzazione notifiche: \(error.localizedDescription)")
        } else {
          print("Autorizzazione notifiche concessa: \(granted)")
        }
      }
    } else {
      // iOS < 10 (ormai raro)
      let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }

    // Registrazione per notifiche push
    application.registerForRemoteNotifications()

    // Registra i plugin Flutter
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // ✅ Mostrare notifiche anche se l’app è in foreground
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound, .badge]) // iOS 14+
    // Se vuoi compatibilità vecchia: completionHandler([.alert, .sound, .badge])
  }

  // ✅ Gestione tap sulla notifica
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    print("Notifica aperta: \(response.notification.request.content.userInfo)")
    completionHandler()
  }

  // ✅ Ricezione del token FCM
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("FCM token iOS aggiornato: \(fcmToken ?? "")")
    // Qui puoi inviare il token a Firestore come fai già su Android
  }

  // ✅ Ricezione del token APNs
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("APNs device token ricevuto: \(tokenString)")
  }

  // ✅ Gestione errori registrazione
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("Registrazione notifiche fallita: \(error.localizedDescription)")
  }
}
