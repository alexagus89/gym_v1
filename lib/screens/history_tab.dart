// lib/screens/history_tab.dart
import 'package:flutter/material.dart';
import '../state/app_state.dart';
import 'session_screen.dart';

class HistoryTab extends StatelessWidget {
  final AppState state;
  const HistoryTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.sessions.isEmpty) return const Center(child: Text('Sin sesiones aún'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.sessions.length,
      itemBuilder: (context, i) {
        final s = state.sessions[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionScreen(state: state, session: s))),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  IconButton(
                    tooltip: 'Eliminar sesión',
                    onPressed: () => _confirmDelete(context, () async {
                      final deleted = s;
                      await state.removeSession(s.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('Sesión eliminada'),
                          action: SnackBarAction(label: 'Deshacer', onPressed: () => state.addSession(deleted)),
                        ));
                      }
                    }),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ]),
                Text(s.templateName, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Text('Volumen: ${s.totalVolume.toStringAsFixed(1)}  •  Reps: ${s.totalReps}'),
              ]),
            ),
          ),
        );
      },
    );
  }
}

void _confirmDelete(BuildContext context, VoidCallback action) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Confirmar'),
      content: const Text('¿Eliminar definitivamente?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
      ],
    ),
  );
  if (ok == true) action();
}
