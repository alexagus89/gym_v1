// lib/main.dart
import 'package:flutter/material.dart';            // 👈 IMPORT NECESARIO
import 'state/app_state.dart';
import 'screens/start_tab.dart';
import 'screens/templates_tab.dart';
import 'screens/history_tab.dart';
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
              // Reiniciar datos
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
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Sí, reiniciar'),
                        ),
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

              // Exportar / Compartir CSV (WhatsApp, Gmail, etc.)
              // Exportar / Compartir SOLO el historial (sessions.csv)
              IconButton(
                tooltip: 'Exportar historial (CSV)',
                icon: const Icon(Icons.ios_share),
                onPressed: () async {
                  try {
                    // Si no hay sesiones, avisamos y salimos
                    if (widget.state.sessions.isEmpty) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No hay sesiones para exportar.')),
                      );
                      return;
                    }

                    // 1) Generar SOLO el CSV de sesiones (historial)
                    final file = await widget.state.exportSessionsCsv();

                    // 2) Compartir el archivo por WhatsApp, Gmail, etc.
                    await Share.shareXFiles(
                      [
                        XFile(
                          file.path,
                          name: file.path.split(Platform.pathSeparator).last, // p.ej. sessions.csv
                        )
                      ],
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
              NavigationDestination(
                icon: Icon(Icons.playlist_add),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.fact_check_outlined),
                label: 'Plantillas',
              ),
              NavigationDestination(
                icon: Icon(Icons.history),
                label: 'Historial',
              )
            ],
          ),
        );
      },
    );
  }
}
