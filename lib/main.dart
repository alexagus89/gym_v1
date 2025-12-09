// lib/main.dart
import 'package:flutter/material.dart';
import 'state/app_state.dart';
import 'screens/start_tab.dart';
import 'screens/templates_tab.dart';
import 'screens/history_tab.dart';
import 'screens/stats_tab.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' show Platform;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GymLogApp());
}

class GymLogApp extends StatelessWidget {
  const GymLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Log',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueGrey),
      home: AppRoot(state: AppState()),
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
  int tab = 0; // 0 start, 1 templates, 2 history, 3 stats

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Gym Log'),
            actions: [
              // Exportar SOLO historial (CSV)
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
            2 => HistoryScreen(state: widget.state),
            3 => StatsTab(state: widget.state),
            _ => StartTab(state: widget.state), // fallback defensivo
          },
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.playlist_add), label: 'Inicio'),
              NavigationDestination(icon: Icon(Icons.fact_check_outlined), label: 'Plantillas'),
              NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
              NavigationDestination(icon: Icon(Icons.query_stats), label: 'Progreso'),
            ],
          ),
        );
      },
    );
  }
}
