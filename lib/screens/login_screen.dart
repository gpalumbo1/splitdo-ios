// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:splitdo_app/services/auth_service.dart';
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

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;
    final nick = _nickCtrl.text.trim();
    setState(() {
      _loading = true;
      _suggestion = null;
    });
    try {
      final taken = await _auth.isNicknameTaken(nick);
      if (taken) {
        final suggestion = await _auth.suggestNickname(nick);
        setState(() {
          _loading = false;
          _suggestion = suggestion;
        });
        return;
      }
      await _auth.registerWithNickname(nickname: nick);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GroupsScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: ${e.toString()}')),
      );
    } finally {
      if (mounted && _suggestion == null) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        color: Colors.blue.shade800.withOpacity(0.15),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                margin: const EdgeInsets.all(24),
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
                          style: theme.textTheme.headlineSmall!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nickCtrl,
                          cursorColor: Colors.blue.shade700,
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: Colors.blue.shade700,
                            ),
                            hintText: 'Username',
                            filled: true,
                            fillColor:
                                theme.colorScheme.primary.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Inserisci un username';
                            }
                            return null;
                          },
                        ),
                        if (_suggestion != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Username non disponibile perché già utilizzato',
                                  style: theme.textTheme.bodyMedium!.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.lightbulb_outline,
                                      color: theme.colorScheme.error,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Suggerimento: ',
                                      style: theme.textTheme.bodyMedium!.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _nickCtrl.text = _suggestion!;
                                          _suggestion = null;
                                          _loading = false;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(4),
                                      splashColor: theme.colorScheme.primary.withOpacity(0.2),
                                      child: Text(
                                        _suggestion!,
                                        style: theme.textTheme.bodyMedium!.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _loading ? null : _onRegister,
                          child: _loading
                              ? SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Entra',
                                  style: theme.textTheme.labelLarge!
                                      .copyWith(color: Colors.white),
                                ),
                        ),
                        const SizedBox(height: 48),
                        Theme(
                          data: theme.copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding:
                                const EdgeInsets.symmetric(horizontal: 0),
                            title: Text(
                              'Informativa Accesso',
                              style: theme.textTheme.bodyMedium!.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            childrenPadding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            children: [
                              Text(
                                'L’app utilizza un accesso anonimo senza registrazione. In caso di cambio dispositivo o disinstallazione, il tuo username non sarà più disponibile e potrai sceglierne uno nuovo al prossimo accesso.',
                                style: theme.textTheme.bodySmall!.copyWith(
                                    color: Colors.grey.shade800),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


