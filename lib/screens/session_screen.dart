// lib/screens/session_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../state/app_state.dart';

class SessionScreen extends StatefulWidget {
  final AppState state;
  final SessionData session;
  const SessionScreen({super.key, required this.state, required this.session});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late SessionData s;
  late final TextEditingController notesCtrl;

  @override
  void initState() {
    super.initState();
    // Clonamos la sesión para editar sin tocar la instancia original
    s = SessionData(
      id: widget.session.id,
      date: widget.session.date,
      templateId: widget.session.templateId,
      templateName: widget.session.templateName,
      sets: widget.session.sets
          .map((e) => SetEntry(
        id: e.id,
        exerciseName: e.exerciseName,
        setIndex: e.setIndex,
        reps: e.reps,
        weight: e.weight,
        targetReps: e.targetReps,
        rir: e.rir, // requiere que SetEntry tenga 'rir' en models.dart
        done: e.done,
      ))
          .toList(),
      notes: widget.session.notes,
    );
    notesCtrl = TextEditingController(text: s.notes);
  }

  @override
  void dispose() {
    notesCtrl.dispose();
    super.dispose();
  }

  // ===== Draft (borrador) por plantilla: persiste si sales sin guardar =====
  String get _draftKey => 'gymlog.draft.session.${s.templateId}';

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(s.toJson()));
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  // ===== Añadir ejercicio (diálogo) =====
  Future<void> _addExerciseDialog() async {
    final nameCtrl = TextEditingController();
    final setsCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '10');

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Añadir ejercicio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del ejercicio',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: setsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Series',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: repsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Reps objetivo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Añadir')),
        ],
      ),
    );

    if (ok != true) return;

    final name = nameCtrl.text.trim();
    final setsN = int.tryParse(setsCtrl.text) ?? 0;
    final target = int.tryParse(repsCtrl.text) ?? 0;
    if (name.isEmpty || setsN <= 0 || target <= 0) return;

    // Crear series nuevas; pre-fill con histórico si existe
    final newSets = <SetEntry>[];
    int baseIndex = 0; // por si ya existe el mismo ejercicio en la sesión
    for (final st in s.sets) {
      if (st.exerciseName == name && st.setIndex > baseIndex) baseIndex = st.setIndex;
    }
    for (int i = 0; i < setsN; i++) {
      final nextIndex = baseIndex + i + 1;
      final last = widget.state.lastSetFor(name, nextIndex);
      newSets.add(SetEntry(
        exerciseName: name,
        setIndex: nextIndex,
        reps: last?.reps ?? 0,
        weight: last?.weight ?? 0.0,
        targetReps: target,
        rir: last?.rir ?? 0,
        done: false,
      ));
    }

    setState(() {
      s.sets.addAll(newSets);
    });
    await _saveDraft();
  }

  // ===== Eliminar ejercicio completo (todas sus series) =====
  Future<void> _removeExerciseGroup(String exerciseName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar ejercicio'),
        content: Text('¿Eliminar “$exerciseName” y todas sus series de esta sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        s.sets.removeWhere((st) => st.exerciseName == exerciseName);
      });
      await _saveDraft();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Agrupar sets por ejercicio (mantiene el orden en que aparecen)
    final Map<String, List<SetEntry>> groups = {};
    for (final set in s.sets) {
      groups.putIfAbsent(set.exerciseName, () => []).add(set);
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Guarda el borrador cuando se intenta/consigue salir
        _saveDraft();
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Sesión • ${s.templateName}')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 18),
              const SizedBox(width: 8),
              Text(
                '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}',
              ),
            ]),
            const SizedBox(height: 12),

            // Tarjetas de ejercicios
            ...groups.entries.map(
                  (e) => _ExerciseCard(
                appState: widget.state,
                name: e.key,
                sets: e.value,
                onChanged: () async {
                  setState(() {});
                  await _saveDraft();
                },
                onRename: (newName) async {
                  setState(() {
                    final trimmed = newName.trim();
                    if (trimmed.isEmpty) return;
                    for (final st in s.sets) {
                      if (st.exerciseName == e.key) {
                        st.exerciseName = trimmed;
                      }
                    }
                  });
                  await _saveDraft();
                },
                onAddSet: (newSet) async {
                  setState(() {
                    s.sets.add(newSet);
                  });
                  await _saveDraft();
                },
                onRemoveLast: () async {
                  setState(() {
                    final setsOfExercise = s.sets
                        .where((st) => st.exerciseName == e.key)
                        .toList()
                      ..sort((a, b) => a.setIndex.compareTo(b.setIndex));
                    if (setsOfExercise.isEmpty) return;
                    final last = setsOfExercise.last;
                    s.sets.removeWhere((st) => st.id == last.id);
                  });
                  await _saveDraft();
                },
                onDeleteExercise: () => _removeExerciseGroup(e.key),
              ),
            ),

            const SizedBox(height: 8),

            // Botón añadir ejercicio
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _addExerciseDialog,
                icon: const Icon(Icons.add),
                label: const Text('Añadir ejercicio'),
              ),
            ),

            const SizedBox(height: 12),

            // Notas
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (v) async {
                s.notes = v;
                await _saveDraft();
              },
            ),

            const SizedBox(height: 16),

            // Guardar
            FilledButton(
              onPressed: () async {
                await widget.state.addSession(s);
                await _clearDraft(); // limpiamos borrador al guardar con éxito
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('Guardar sesión'),
            ),

            const SizedBox(height: 12),
            Text(
              'Volumen total: ${s.totalVolume.toStringAsFixed(1)} kg·reps   •   Reps: ${s.totalReps}',
            ),
          ],
        ),
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
  final VoidCallback onRemoveLast;
  final VoidCallback onDeleteExercise; // botón de papelera
  final AppState appState;

  const _ExerciseCard({
    required this.name,
    required this.sets,
    required this.onChanged,
    required this.onRename,
    required this.onAddSet,
    required this.onRemoveLast,
    required this.onDeleteExercise,
    required this.appState,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  late final TextEditingController _nameCtrl;
  final Map<String, TextEditingController> _repsCtrls = {};
  final Map<String, TextEditingController> _kgCtrls = {};
  final Map<String, TextEditingController> _rirCtrls = {};

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
      _rirCtrls.putIfAbsent(
        s.id,
            () => TextEditingController(text: (s.rir == 0) ? '' : s.rir.toString()),
      );
    }
    // Limpieza de controladores huérfanos
    _repsCtrls.keys.where((k) => !currentIds.contains(k)).toList().forEach(_repsCtrls.remove);
    _kgCtrls.keys.where((k) => !currentIds.contains(k)).toList().forEach(_kgCtrls.remove);
    _rirCtrls.keys.where((k) => !currentIds.contains(k)).toList().forEach(_rirCtrls.remove);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _repsCtrls.values) c.dispose();
    for (final c in _kgCtrls.values) c.dispose();
    for (final c in _rirCtrls.values) c.dispose();
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
      final nextIndex =
          (widget.sets.isEmpty ? 0 : widget.sets.map((x) => x.setIndex).reduce((a, b) => a > b ? a : b)) + 1;
      final last = widget.appState.lastSetFor(widget.name, nextIndex);
      final target = widget.sets.isNotEmpty ? widget.sets.first.targetReps : 10;

      final newSet = SetEntry(
        exerciseName: widget.name,
        setIndex: nextIndex,
        reps: last?.reps ?? 0,
        weight: last?.weight ?? 0.0,
        targetReps: target,
        rir: last?.rir ?? 0,
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
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ejercicio',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  onChanged: widget.onRename,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Eliminar ejercicio',
                onPressed: widget.onDeleteExercise,
                icon: const Icon(Icons.delete_outline),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              ),
            ],
          ),

          if (isPR) ...[
            const SizedBox(height: 8),
            Row(children: [
              Chip(label: Text('🏆 Nuevo PR: ${currentBest.toStringAsFixed(1)} kg 1RM')),
            ]),
          ],
          const SizedBox(height: 8),

          // Filas de series (solo texto; sin botones +/- en Reps/Kg/RIR)
          ...widget.sets.map((s) {
            final repsCtrl = _repsCtrls[s.id]!;
            final kgCtrl = _kgCtrls[s.id]!;
            final rirCtrl = _rirCtrls[s.id]!;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 28, child: Text('#${s.setIndex}')),

                // Reps
                Expanded(
                  child: TextFormField(
                    controller: repsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Reps',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (v) {
                      s.reps = int.tryParse(v) ?? 0;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 6),

                // Kg
                Expanded(
                  child: TextFormField(
                    controller: kgCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Kg',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (v) {
                      s.weight = double.tryParse(v.replaceAll(',', '.')) ?? 0;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 6),

                // RIR
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    controller: rirCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'RIR',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (v) {
                      final parsed = int.tryParse(v) ?? 0;
                      s.rir = parsed.clamp(0, 5);
                      if (s.rir.toString() != rirCtrl.text) {
                        rirCtrl.text = s.rir == 0 ? '' : s.rir.toString();
                        rirCtrl.selection = TextSelection.fromPosition(
                          TextPosition(offset: rirCtrl.text.length),
                        );
                      }
                      widget.onChanged();
                    },
                  ),
                ),
              ]),
            );
          }),

          const SizedBox(height: 8),

          // Pie: info + acciones (botones compactos: "-" y "+")
          Row(
            children: [
              Expanded(
                child: Text(
                  'Objetivo: ${widget.sets.isNotEmpty ? widget.sets.first.targetReps : '-'} reps  •  Series: ${widget.sets.length}',
                  style: const TextStyle(color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  OutlinedButton(
                    onPressed: widget.sets.isEmpty ? null : removeLastSet,
                    child: const Text('-'),
                  ),
                  FilledButton(
                    onPressed: addOneSet,
                    child: const Text('+'),
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
