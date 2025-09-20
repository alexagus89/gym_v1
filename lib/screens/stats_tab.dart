// lib/screens/stats_tab.dart
import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../models/models.dart';

class StatsTab extends StatefulWidget {
  final AppState state;
  const StatsTab({super.key, required this.state});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  String? selectedExercise;

  @override
  void initState() {
    super.initState();
    final names = widget.state.allExerciseNames();
    if (names.isNotEmpty) {
      selectedExercise = names.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = widget.state.allExerciseNames();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Progreso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),

        // Selector de ejercicio
        DropdownButtonFormField<String>(
          value: selectedExercise,
          items: names.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
          onChanged: (v) => setState(() => selectedExercise = v),
          decoration: const InputDecoration(labelText: 'Ejercicio'),
        ),

        const SizedBox(height: 12),

        if (selectedExercise == null)
          const Text('No hay ejercicios todavía.')
        else
          _ExerciseStats(
            state: widget.state,
            exerciseName: selectedExercise!,
          ),
      ],
    );
  }
}

class _ExerciseStats extends StatelessWidget {
  final AppState state;
  final String exerciseName;
  const _ExerciseStats({required this.state, required this.exerciseName});

  @override
  Widget build(BuildContext context) {
    final samples = state.getRecentExerciseSamples(exerciseName, limit: 50);
    final best1rm = state.best1RMFor(exerciseName);
    final bestVol = state.bestVolumeSet(exerciseName);
    final avg = state.recentAverages(exerciseName, sessionsCount: 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Resumen
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exerciseName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _StatChip(label: 'Mejor 1RM', value: best1rm > 0 ? '${best1rm.toStringAsFixed(1)} kg' : '-'),
                      _StatChip(label: 'Mejor set (kg·reps)', value: bestVol.bestVolume > 0 ? bestVol.bestVolume.toStringAsFixed(1) : '-'),
                      _StatChip(label: 'Promedio últimas 3 (reps)', value: avg.avgReps > 0 ? avg.avgReps.toStringAsFixed(1) : '-'),
                      _StatChip(label: 'Promedio últimas 3 (kg)', value: avg.avgKg > 0 ? avg.avgKg.toStringAsFixed(1) : '-'),
                    ],
                  ),
                  if (bestVol.date != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Mejor set el: ${_fmtDate(bestVol.date!)}', style: const TextStyle(color: Colors.grey)),
                    ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Lista de muestras recientes
        const Text('Últimos resultados', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (samples.isEmpty)
          const Text('Sin historial para este ejercicio.')
        else
          ...samples.map((s) {
            final isPR = s.est1rm > 0 && s.est1rm > best1rm - 0.0001 && s.est1rm >= best1rm; // por si empata
            return Card(
              child: ListTile(
                dense: true,
                title: Text('${_fmtDate(s.date)}  •  Serie #${s.setIndex}'),
                subtitle: Text('Reps: ${s.reps}   •   Kg: ${s.weight.toStringAsFixed(1)}   •   1RM est: ${s.est1rm > 0 ? s.est1rm.toStringAsFixed(1) : '-'}'),
                trailing: isPR ? const Text('🏆 PR') : null,
              ),
            );
          }),
      ],
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
