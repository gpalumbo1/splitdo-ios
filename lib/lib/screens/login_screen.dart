import 'package:flutter/material.dart';
import 'package:splitdo_app/services/auth_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import 'groups_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nickCtrl = TextEditingController();
  final _auth = AuthService();

  bool _loading = false;
  String? _suggestion;
  bool _gdprAccepted = false;
  bool _showPrivacyBox = false;
  bool _privacyChecked = false;

  @override
  void initState() {
    super.initState();
    _checkGdprStatus();
  }

  Future<void> _checkGdprStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _gdprAccepted = prefs.getBool('gdpr_accepted') ?? false;
      _showPrivacyBox = !_gdprAccepted;
    });
  }

  Future<void> _acceptGdpr() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gdpr_accepted', true);
    setState(() {
      _gdprAccepted = true;
      _showPrivacyBox = false;
    });
  }

  void _rejectGdpr() {
    if (Platform.isAndroid) {
      Future.delayed(const Duration(milliseconds: 100), () {
        exit(0);
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openPrivacy() async {
    await launchUrl(
      Uri.parse('https://sites.google.com/view/splitdo-privacy'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _onRegister() async {
    if (!_gdprAccepted) {
      setState(() => _showPrivacyBox = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devi accettare la privacy policy')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final nick = _nickCtrl.text.trim();
      final taken = await _auth.isNicknameTaken(nick);

      if (taken) {
        setState(() {
          _suggestion = null;
          _loading = false;
        });
        final suggestion = await _auth.suggestNickname(nick);
        setState(() {
          _suggestion = suggestion;
        });
        return;
      }

      await _auth.registerWithNickname(nickname: nick);
      await FirebaseMessaging.instance.requestPermission();
      await _auth.updateFcmTokenIfPossible();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GroupsScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    super.dispose();
  }

  Widget _privacyPolicyBox() {
    final theme = Theme.of(context);
    final isAcceptEnabled = _privacyChecked;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 0),
      elevation: 8,
      color: theme.colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.privacy_tip, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'Accetta la privacy policy',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Per usare SplitDo devi accettare la nostra privacy policy in conformità al GDPR. Prima di accettare, ti chiediamo di leggere la policy aggiornata.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Leggi Privacy Policy'),
              onPressed: _openPrivacy,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _privacyChecked,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (v) => setState(() => _privacyChecked = v ?? false),
              title: const Text(
                "Ho preso visione della Privacy Policy",
                style: TextStyle(fontSize: 16),
              ),
              contentPadding: const EdgeInsets.only(left: 0, right: 0),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: _rejectGdpr,
                  child: const Text('Rifiuta'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAcceptEnabled
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isAcceptEnabled ? _acceptGdpr : null,
                  child: Text(
                    'Accetta',
                    style: TextStyle(
                      color: isAcceptEnabled ? Colors.white : Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Benvenuto su SplitDo',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_showPrivacyBox) _privacyPolicyBox(),
                  // Testo informativo sull'account anonimo e cambio device
                  if (_gdprAccepted) ...[
                    const SizedBox(height: 8),
                    Text(
                      'L’app utilizza un accesso anonimo senza registrazione. '
                      'In caso di cambio dispositivo o disinstallazione, il tuo username non sarà più disponibile e potrai sceglierne uno nuovo al prossimo accesso.',
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: Colors.grey.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nickCtrl,
                    enabled: _gdprAccepted && !_loading,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Inserisci un username' : null,
                  ),
                  if (_suggestion != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Username già usato, prova: $_suggestion',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: (_gdprAccepted && !_loading) ? _onRegister : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entra'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

