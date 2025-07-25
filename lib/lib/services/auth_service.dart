import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // <--- AGGIUNTA

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Controlla se un nickname è già in uso
  Future<bool> isNicknameTaken(String nickname) async {
    final snap = await _db
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Suggerisce un nickname alternativo aggiungendo un numero sequenziale
  Future<String> suggestNickname(String nickname) async {
    final start = nickname;
    final end = '$nickname\uf8ff';
    final snap = await _db
        .collection('users')
        .where('nickname', isGreaterThanOrEqualTo: start)
        .where('nickname', isLessThanOrEqualTo: end)
        .get();

    final existing = snap.docs.map((d) => d['nickname'] as String).toSet();

    int i = 1;
    String suggestion;
    do {
      suggestion = '$nickname$i';
      i++;
    } while (existing.contains(suggestion));

    return suggestion;
  }

  /// Registra l’utente in modalità anonima e salva il profilo in Firestore
  Future<void> registerWithNickname({
    required String nickname,
  }) async {
    final cred = await _auth.signInAnonymously();
    final uid = cred.user!.uid;

    await _db.collection('users').doc(uid).set({
      'nickname': nickname,
      'friends': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('nicknames').doc(nickname).set({
      'uid': uid,
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('my_nickname', nickname);
  }

  /// Carica il nickname memorizzato in locale
  Future<String?> loadLocalNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('my_nickname');
  }

  /// Salva o aggiorna il token FCM nel doc utente users/{uid}
  Future<void> saveFcmToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }

  /// Utility: aggiorna il token FCM nel doc utente (se c'è un utente loggato)
  Future<void> updateFcmTokenIfPossible() async { // <--- AGGIUNTA
    final user = _auth.currentUser;
    if (user == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await saveFcmToken(token);
    }
  }

  /// Rimuove il token FCM dal doc utente e dalle prefs
  Future<void> removeFcmToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _db
          .collection('users')
          .doc(uid)
          .set({'fcmToken': FieldValue.delete()}, SetOptions(merge: true));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fcmToken');
  }

  /// Effettua logout completo (Auth, prefs e FCM)
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('my_nickname');
    await prefs.remove('fcmToken');

    await removeFcmToken();
    await _auth.signOut();
  }
}

