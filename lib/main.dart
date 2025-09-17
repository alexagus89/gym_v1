// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'state/app_state.dart';
import 'screens/start_tab.dart';
import 'screens/templates_tab.dart';
import 'screens/history_tab.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' show Platform;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const GymLogApp());
}

class GymLogApp extends StatelessWidget {
  const GymLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Log',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueGrey),
      home: const AuthGate(), // 👈 pantalla de login si no hay usuario
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<void> _signInWithGoogle() async {
    try {
      // v7: usar el singleton y (opcional) inicializar
      final signIn = GoogleSignIn.instance;
      await signIn.initialize(); // seguro llamar antes de usar

      // v7: ya no existe signIn(); ahora authenticate()
      final user = await signIn.authenticate();

      // v7: GoogleSignInAuthentication solo tiene idToken (no accessToken)
      final gAuth = await user.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: gAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      // Si el usuario cancela o hay error, lo capturamos y mostramos algo opcional
      debugPrint('Sign-in error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Gym Log')),
            body: Center(
              child: FilledButton.icon(
                onPressed: _signInWithGoogle,
                icon: const Icon(Icons.login),
                label: const Text('Iniciar sesión con Google'),
              ),
            ),
          );
        }
        return AppRoot(state: AppState());
      },
    );
  }
}

class AppRoot extends StatefulWidget {
  final AppState state;
  const AppRoot({super.key, required this.state});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  int tab = 0; // 0 start, 1 templates, 2 history

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Gym Log'),
            actions: [
              // Cerrar sesión
              IconButton(
                tooltip: 'Cerrar sesión',
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  // v7: signOut desde el singleton
                  await GoogleSignIn.instance.signOut();
                  await FirebaseAuth.instance.signOut();
                },
              ),

              // Reiniciar datos (todo)
              IconButton(
                tooltip: 'Reiniciar datos',
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Reiniciar datos'),
                      content: const Text(
                        'Esto borrará tus sesiones y restaurará las plantillas por defecto. ¿Continuar?',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí, reiniciar')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await widget.state.resetAll();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Datos reiniciados')),
                    );
                  }
                },
                icon: const Icon(Icons.restart_alt),
              ),

              // Exportar historial (CSV)
              IconButton(
                tooltip: 'Exportar historial (CSV)',
                icon: const Icon(Icons.ios_share),
                onPressed: () async {
                  try {
                    if (widget.state.sessions.isEmpty) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No hay sesiones para exportar.')),
                      );
                      return;
                    }
                    final file = await widget.state.exportSessionsCsv();
                    await Share.shareXFiles(
                      [XFile(file.path, name: file.path.split(Platform.pathSeparator).last)],
                      text: 'Historial de entrenamientos (CSV).',
                      subject: 'Historial Gym Log',
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al compartir: $e')),
                    );
                  }
                },
              ),
            ],
          ),
          body: switch (tab) {
            0 => StartTab(state: widget.state),
            1 => TemplatesTab(state: widget.state),
            _ => HistoryTab(state: widget.state),
          },
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.playlist_add), label: 'Inicio'),
              NavigationDestination(icon: Icon(Icons.fact_check_outlined), label: 'Plantillas'),
              NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
            ],
          ),
        );
      },
    );
  }
}
