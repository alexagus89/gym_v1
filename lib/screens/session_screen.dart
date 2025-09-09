// lib/screens/session_screen.dart
import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../models/models.dart';

class SessionScreen extends StatefulWidget {
  final AppState state;
  final SessionData session;
  const SessionScreen({super.key, required this.state, required this.session});
  @override State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late SessionData s;
  late final TextEditingController notesCtrl;

  @override
  void initState() {
    super.initState();
    s = SessionData(
      id: widget.session.id,
      date: widget.session.date,
      templateId: widget.session.templateId,
      templateName: widget.session.templateName,
      sets: widget.session.sets.map((e) => SetEntry(
        id: e.id, exerciseName: e.exerciseName, setIndex: e.setIndex,
        reps: e.reps, weight: e.weight, targetReps: e.targetReps, done: e.done,
      )).toList(),
      notes: widget.session.notes,
    );
    notesCtrl = TextEditingController(text: s.notes);
  }

  @override void dispose() { notesCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<SetEntry>> groups = {};
    for (final set in s.sets) { groups.putIfAbsent(set.exerciseName, () => []).add(set); }

    return Scaffold(
      appBar: AppBar(title: Text('Sesión • ${s.templateName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 18),
            const SizedBox(width: 8),
            Text('${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}'),
          ]),
          const SizedBox(height: 12),
          ...groups.entries.map((e) => _ExerciseCard(
            appState: widget.state,          // (si ya lo tenías)
            name: e.key,
            sets: e.value,
            onChanged: () => setState(() {}),
            onAddSet: (newSet) {             // (si ya lo tenías)
              setState(() { s.sets.add(newSet); });
            },
            onRemoveLast: () {               // 👈 NUEVO
              setState(() {
                final setsOfExercise = s.sets.where((st) => st.exerciseName == e.key).toList();
                if (setsOfExercise.isEmpty) return;
                setsOfExercise.sort((a, b) => a.setIndex.compareTo(b.setIndex));
                final last = setsOfExercise.last;
                s.sets.removeWhere((st) => st.id == last.id);
              });
            },
            onRename: (newName) {
              setState(() {
                final trimmed = newName.trim();
                if (trimmed.isEmpty) return;
                for (final st in s.sets) {
                  if (st.exerciseName == e.key) st.exerciseName = trimmed;
                }
              });
            },
          )),

          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(labelText: 'Notas (opcional)', border: OutlineInputBorder()),
            maxLines: 3,
            onChanged: (v) => s.notes = v,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async { await widget.state.addSession(s); if (mounted) Navigator.of(context).pop(); },
            child: const Text('Guardar sesión'),
          ),
          const SizedBox(height: 12),
          Text('Volumen total: ${s.totalVolume.toStringAsFixed(1)} kg·reps   •   Reps: ${s.totalReps}'),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  final String name;
  final List<SetEntry> sets;
  final VoidCallback onChanged;
  final ValueChanged<String> onRename;
  final ValueChanged<SetEntry> onAddSet;
  final VoidCallback onRemoveLast; // NUEVO
  final AppState appState;

  const _ExerciseCard({
    required this.name,
    required this.sets,
    required this.onChanged,
    required this.onRename,
    required this.onAddSet,
    required this.onRemoveLast, // NUEVO
    required this.appState,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  late final TextEditingController _nameCtrl;
  final Map<String, TextEditingController> _repsCtrls = {};
  final Map<String, TextEditingController> _kgCtrls = {};

  // ==== Estilos compactos para evitar overflow ====
  ButtonStyle _btnSmallOutlined() => OutlinedButton.styleFrom(
    minimumSize: const Size(36, 36),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  ButtonStyle _btnSmallFilled() => FilledButton.styleFrom(
    minimumSize: const Size(36, 36),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.name);
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _ExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name && _nameCtrl.text != widget.name) {
      _nameCtrl.text = widget.name;
    }
    _syncControllers();
  }

  void _syncControllers() {
    final currentIds = widget.sets.map((s) => s.id).toSet();
    for (final s in widget.sets) {
      _repsCtrls.putIfAbsent(
        s.id,
            () => TextEditingController(text: s.reps == 0 ? '' : s.reps.toString()),
      );
      _kgCtrls.putIfAbsent(
        s.id,
            () => TextEditingController(text: s.weight == 0 ? '' : s.weight.toString()),
      );
    }
    _repsCtrls.keys.where((k) => !currentIds.contains(k)).toList().forEach(_repsCtrls.remove);
    _kgCtrls.keys.where((k) => !currentIds.contains(k)).toList().forEach(_kgCtrls.remove);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _repsCtrls.values) {
      c.dispose();
    }
    for (final c in _kgCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bestHistorical = widget.appState.best1RMFor(widget.name);
    final currentBest = widget.sets.fold<double>(0, (p, s) {
      if (s.reps > 0 && s.weight > 0) {
        final est = (s.weight * (1 + s.reps / 30.0));
        return est > p ? est : p;
      }
      return p;
    });
    final isPR = currentBest > 0 && currentBest > bestHistorical + 0.1;

    void addOneSet() {
      final nextIndex = (widget.sets.isEmpty
          ? 0
          : widget.sets.map((x) => x.setIndex).reduce((a, b) => a > b ? a : b)) +
          1;
      final last = widget.appState.lastSetFor(widget.name, nextIndex);
      final target = widget.sets.isNotEmpty ? widget.sets.first.targetReps : 10;

      final newSet = SetEntry(
        exerciseName: widget.name,
        setIndex: nextIndex,
        reps: last?.reps ?? 0,
        weight: last?.weight ?? 0.0,
        targetReps: target,
        done: false,
      );

      widget.onAddSet(newSet);
      widget.onChanged();
    }

    void removeLastSet() {
      if (widget.sets.isEmpty) return;
      widget.onRemoveLast();
      widget.onChanged();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Ejercicio',
              border: OutlineInputBorder(),
              isDense: true, // un pelín más compacto
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            onChanged: widget.onRename,
          ),
          if (isPR) ...[
            const SizedBox(height: 8),
            Row(children: [
              Chip(label: Text('🏆 Nuevo PR: ${currentBest.toStringAsFixed(1)} kg 1RM')),
            ]),
          ],
          const SizedBox(height: 8),

          ...widget.sets.map((s) {
            final repsCtrl = _repsCtrls[s.id]!;
            final kgCtrl = _kgCtrls[s.id]!;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(width: 28, child: Text('#${s.setIndex}')), // antes 36 → 28

                // Reps con +/- compactos
                Expanded(
                  child: Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: repsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Reps',
                          isDense: true, // compacto
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (v) {
                          s.reps = int.tryParse(v) ?? 0;
                          widget.onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 36,
                      child: OutlinedButton(
                        style: _btnSmallOutlined(),
                        onPressed: () {
                          s.reps = (s.reps + 1).clamp(0, 1000).toInt();
                          repsCtrl.text = s.reps.toString();
                          widget.onChanged();
                        },
                        child: const Text('+'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 36,
                      child: OutlinedButton(
                        style: _btnSmallOutlined(),
                        onPressed: () {
                          s.reps = (s.reps - 1).clamp(0, 1000).toInt();
                          repsCtrl.text = s.reps == 0 ? '' : s.reps.toString();
                          widget.onChanged();
                        },
                        child: const Text('-'),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(width: 8),

                // Kg con +/-2.5 compactos
                Expanded(
                  child: Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: kgCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Kg',
                          isDense: true, // compacto
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (v) {
                          s.weight = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                          widget.onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 36,
                      child: OutlinedButton(
                        style: _btnSmallOutlined(),
                        onPressed: () {
                          s.weight = s.weight + 2.5;
                          kgCtrl.text = s.weight.toString();
                          widget.onChanged();
                        },
                        child: const Text('+2.5'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 36,
                      child: OutlinedButton(
                        style: _btnSmallOutlined(),
                        onPressed: () {
                          s.weight = s.weight - 2.5;
                          if (s.weight < 0) s.weight = 0;
                          kgCtrl.text = s.weight == 0 ? '' : s.weight.toString();
                          widget.onChanged();
                        },
                        child: const Text('-2.5'),
                      ),
                    ),
                  ]),
                ),
              ]),
            );
          }),

          const SizedBox(height: 8),

          // Fila inferior: evita overflow con Wrap en los botones
          Row(
            children: [
              Expanded(
                child: Text(
                  'Objetivo aprox: ${widget.sets.isNotEmpty ? widget.sets.first.targetReps : '-'} reps',
                  style: const TextStyle(color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    style: _btnSmallOutlined(),
                    onPressed: widget.sets.isEmpty ? null : () => removeLastSet(),
                    icon: const Icon(Icons.remove),
                    label: const Text('Eliminar última'),
                  ),
                  FilledButton.icon(
                    style: _btnSmallFilled(),
                    onPressed: addOneSet,
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir serie'),
                  ),
                ],
              ),
            ],
          ),
        ]),
      ),
    );
  }
}
