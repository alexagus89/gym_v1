// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../models/models.dart';
import 'session_screen.dart';

class HistoryScreen extends StatelessWidget {
  final AppState state;
  const HistoryScreen({super.key, required this.state});

  String _ddmmyyyy(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: state,
      builder: (_, __) {
        // Copia ordenada (más recientes primero)
        final sessions = List<SessionData>.from(state.sessions)
          ..sort((a, b) => b.date.compareTo(a.date));

        return Scaffold(
          appBar: AppBar(title: const Text('Historial')),
          body: sessions.isEmpty
              ? Center(
            child: Text(
              'Sin sesiones aún',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
            ),
          )
              : ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final s = sessions[i];
              final dateStr = _ddmmyyyy(s.date);
              final rutina  = s.templateName.isNotEmpty ? s.templateName : 'Sesión';
              final volumen = '${s.totalVolume.toStringAsFixed(1)} kg·reps';
              final reps    = 'Reps: ${s.totalReps}';

              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SessionScreen(
                        state: state,
                        session: s,
                        fromHistory: true, // ✅ edición con guardado inmediato
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // Icono decorativo
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.fitness_center, size: 18),
                      ),
                      const SizedBox(width: 10),

                      // Dos líneas compactas
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Línea 1: fecha    tipo rutina
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    dateStr,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    rutina,
                                    textAlign: TextAlign.right,
                                    style: theme.textTheme.bodyMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            // Línea 2: volumen    Reps
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    volumen,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.hintColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    reps,
                                    textAlign: TextAlign.right,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.hintColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
