// lib/screens/stats_tab.dart
import 'package:flutter/material.dart';
import '../state/app_state.dart';

class StatsTab extends StatefulWidget {
  final AppState state;
  const StatsTab({super.key, required this.state});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  String? _selectedExercise;

  void _onExerciseSelected(String? name) {
    setState(() => _selectedExercise = name);
  }

  Future<void> _showRenameDialog() async {
    final oldName = _selectedExercise;
    if (oldName == null) return;

    final ctrl = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Renombrar ejercicio'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nuevo nombre',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );

    if (newName == null) return;
    if (newName.isEmpty || newName == oldName) return;

    await widget.state.renameExerciseEverywhere(oldName, newName);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ejercicio renombrado')),
    );
    setState(() => _selectedExercise = newName);
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    // Nombres únicos (plantillas + historial), ordenados
    final allNames = widget.state.allExerciseNames()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final initial =
    allNames.contains(_selectedExercise) ? _selectedExercise : null;

    // ===== Estadísticas derivadas =====
    final name = initial;
    double best1RM = 0;
    double avgReps = 0;
    double avgKg = 0;
    int sessionsWithExercise = 0;

    // Muestras recientes: (fecha, set, reps, kg, 1rm)
    final recentSamples = <_SampleRow>[];

    if (name != null) {
      // Mejor 1RM
      best1RM = widget.state.best1RMFor(name);

      // Agrupar por fecha las series del ejercicio
      final perDate = <DateTime, List<_SampleRow>>{};
      for (final ses in widget.state.sessions) {
        final rows = <_SampleRow>[];
        for (final st in ses.sets) {
          if (st.exerciseName == name) {
            final est1rm = (st.reps > 0 && st.weight > 0)
                ? st.weight * (1 + st.reps / 30.0)
                : 0.0;
            rows.add(_SampleRow(
              date: ses.date,
              setIndex: st.setIndex,
              reps: st.reps,
              kg: st.weight,
              est1rm: est1rm,
            ));
          }
        }
        if (rows.isNotEmpty) {
          perDate[ses.date] = rows;
        }
      }

      // Fechas de más reciente a más antigua
      final dates = perDate.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      sessionsWithExercise = dates.length;

      // Medias sobre últimas 3 sesiones que incluyeron el ejercicio
      final take = dates.take(3).toList();
      double repsSum = 0;
      double kgSum = 0;
      int n = 0;
      for (final d in take) {
        final rows = perDate[d]!;
        for (final r in rows) {
          repsSum += r.reps.toDouble();
          kgSum += r.kg;
          n++;
        }
      }
      if (n > 0) {
        avgReps = repsSum / n;
        avgKg = kgSum / n;
      }

      // Construir muestras recientes (limit 12)
      final flat = <_SampleRow>[];
      for (final d in dates) {
        flat.addAll(perDate[d]!);
      }
      flat.sort((a, b) => b.date.compareTo(a.date));
      recentSamples.addAll(flat.take(12));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Progreso',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),

        // Selector de ejercicio (usa initialValue en lugar de value)
        DropdownButtonFormField<String>(
          key: ValueKey(initial), // para que respete cambios programáticos
          initialValue: initial,
          items: allNames
              .map(
                (n) => DropdownMenuItem<String>(
              value: n,
              child: Text(n, overflow: TextOverflow.ellipsis),
            ),
          )
              .toList(),
          onChanged: _onExerciseSelected,
          decoration: const InputDecoration(
            labelText: 'Ejercicio',
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 12),

        // Botón Renombrar (abre diálogo)
        Row(
          children: [
            FilledButton.icon(
              onPressed: (initial == null) ? null : _showRenameDialog,
              icon: const Icon(Icons.edit),
              label: const Text('Renombrar'),
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),

        if (initial != null) ...[
          // Resumen superior
          Text(
            'Resumen: $initial',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _StatChip(label: 'Mejor 1RM', value: '${best1RM.toStringAsFixed(1)} kg'),
              _StatChip(label: 'Media reps (últ. 3)', value: avgReps.toStringAsFixed(1)),
              _StatChip(label: 'Media kg (últ. 3)', value: avgKg.toStringAsFixed(1)),
              _StatChip(label: 'Sesiones totales', value: '$sessionsWithExercise'),
            ],
          ),

          const SizedBox(height: 16),
          const Text(
            'Muestras recientes',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          if (recentSamples.isEmpty)
            const Text('Sin datos aún. Registra algunas series para ver el histórico.')
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // cabecera
                    Row(
                      children: const [
                        Expanded(flex: 28, child: Text('Fecha', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 20, child: Text('Set', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 26, child: Text('Reps × Kg', style: TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 26, child: Text('Est. 1RM', style: TextStyle(fontWeight: FontWeight.w600))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final r in recentSamples) ...[
                      Row(
                        children: [
                          Expanded(flex: 28, child: Text(_fmtDate(r.date))),
                          Expanded(flex: 20, child: Text('#${r.setIndex}')),
                          Expanded(flex: 26, child: Text('${r.reps} × ${r.kg.toStringAsFixed(1)}')),
                          Expanded(flex: 26, child: Text(r.est1rm > 0 ? r.est1rm.toStringAsFixed(1) : '—')),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    );
  }
}

class _SampleRow {
  final DateTime date;
  final int setIndex;
  final int reps;
  final double kg;
  final double est1rm;
  _SampleRow({
    required this.date,
    required this.setIndex,
    required this.reps,
    required this.kg,
    required this.est1rm,
  });
}
