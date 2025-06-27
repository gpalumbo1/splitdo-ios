// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore offline
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:app_links/app_links.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'screens/login_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/group_detail_screen.dart';
import 'screens/friends_screen.dart';
import 'services/auth_service.dart';
import 'services/ad_service.dart';
import 'firebase_options.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
final navigatorKey = GlobalKey<NavigatorState>();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'group_actions',
  'Azioni di Gruppo',
  description: 'Notifiche per nuove adesioni al gruppo e completamento task',
  importance: Importance.max,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage msg) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Abilita Firestore offline
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Registra il background handler di FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // **Qui** inizializzi l’AdService in anticipo (carica l’interstitial subito)
  await AdService.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _initialNickname;
  bool _initialized = false;

  // ▼ cambia il tipo di subscription (ora è List<ConnectivityResult>)
  late final StreamSubscription<List<ConnectivityResult>> _connSub;

  bool _firstEvent = true;
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();

    // Carica nickname locale
    AuthService().loadLocalNickname().then((nick) {
      setState(() => _initialNickname = nick);
    });

    // Gestisci cold‐start da notifica o deep link
    _handleInitialMessageAndLink().then((_) {
      setState(() => _initialized = true);
    });

    // Listener connettività (ora riceviamo una lista di risultati)
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      if (_firstEvent) {
        _firstEvent = false;
        return;
      }

      final messenger = scaffoldMessengerKey.currentState!;
      final offline = results.isEmpty ||
          results.every((r) => r == ConnectivityResult.none);

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.grey.shade900.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          content: Row(
            children: [
              Icon(
                offline ? Icons.wifi_off : Icons.wifi,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  offline
                      ? 'Connessione assente: i dati potrebbero essere obsoleti.'
                      : 'Connessione ripristinata: tutti i dati sono aggiornati.',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: '✕',
            textColor: Colors.white,
            onPressed: () => messenger.hideCurrentSnackBar(),
          ),
          duration: offline
              ? const Duration(days: 1)
              : const Duration(seconds: 2),
        ),
      );
    });
  }

  Future<void> _handleInitialMessageAndLink() async {
    // Cold‐start da notifica
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    final notifGroupId = initialMessage?.data['groupId'] as String?;
    if (notifGroupId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.pushNamed(
          '/groupDetail',
          arguments: {'groupId': notifGroupId, 'joinOnOpen': true},
        );
      });
    }

    // Cold‐start da deep link
    try {
      final uri = await _appLinks.getInitialLink();
      final deepLinkGroupId = uri?.queryParameters['groupId'];
      if (deepLinkGroupId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.pushNamed(
            '/groupDetail',
            arguments: {'groupId': deepLinkGroupId, 'joinOnOpen': true},
          );
        });
      }
    } catch (_) {}

    // Runtime deep link
    _appLinks.uriLinkStream.listen((uri) {
      final id = uri.queryParameters['groupId'];
      if (id != null) {
        navigatorKey.currentState?.pushNamed(
          '/groupDetail',
          arguments: {'groupId': id, 'joinOnOpen': true},
        );
      }
    });
  }

  @override
  void dispose() {
    _connSub.cancel();
    super.dispose();
  }

  Future<void> _setupNotifications() async {
    // Crea canale Android (non await bloccante)
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Inizializza plugin notifiche locali
    flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          final data = jsonDecode(response.payload!);
          final groupId = data['groupId'] as String?;
          if (groupId != null) {
            navigatorKey.currentState?.pushNamed(
              '/groupDetail',
              arguments: {'groupId': groupId, 'joinOnOpen': true},
            );
          }
        }
      },
    );

    // Foreground FCM
    FirebaseMessaging.instance.requestPermission();
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n != null) {
        flutterLocalNotificationsPlugin.show(
          n.hashCode,
          n.title,
          n.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: jsonEncode(msg.data),
        );
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      final groupId = msg.data['groupId'] as String?;
      if (groupId != null) {
        navigatorKey.currentState?.pushNamed(
          '/groupDetail',
          arguments: {'groupId': groupId, 'joinOnOpen': true},
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final loggedIn = _initialNickname != null;
    final themeBlue = Colors.blue.shade800;

    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'SplitDo',
      theme: ThemeData(
        primaryColor: themeBlue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeBlue,
          primary: themeBlue,
          secondary: themeBlue,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: themeBlue,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: themeBlue,
          unselectedItemColor: themeBlue.withOpacity(0.6),
        ),
        floatingActionButtonTheme:
            const FloatingActionButtonThemeData(backgroundColor: Colors.amber),
      ),
      initialRoute: !loggedIn ? '/login' : '/',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/': (_) => loggedIn ? const GroupsScreen() : const LoginScreen(),
        '/groupDetail': (ctx) {
          final raw = ModalRoute.of(ctx)?.settings.arguments;
          String? id;
          bool joinFlag = false;

          if (raw is Map<String, dynamic>) {
            id = raw['groupId'] as String?;
            joinFlag = raw['joinOnOpen'] as bool? ?? false;
          } else if (raw is String) {
            id = raw;
            joinFlag = false;
          }

          if (id == null) {
            return loggedIn ? const GroupsScreen() : const LoginScreen();
          }
          return GroupDetailScreen(
            groupId: id,
            joinOnOpen: joinFlag,
          );
        },
        '/friends': (_) => const FriendsScreen(),
      },
    );
  }
}

