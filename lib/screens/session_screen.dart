// lib/screens/session_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import 'dart:async';

const double _pageMaxWidth = 620.0;
const _kKeyboardAnim = Duration(milliseconds: 120); // animación rápida teclado

// ------- util: ids únicos para sets -------
int _idSeed = 0;
String _newId() {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final r = (++_idSeed).toRadixString(36);
  return 'st_$t$r';
}
String _normalizeForSearch(String input) {
  const Map<String, String> _map = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
    'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
    'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
    'ñ': 'n', 'Ñ': 'N',
  };
  final buffer = StringBuffer();
  for (final codeUnit in input.runes) {
    final ch = String.fromCharCode(codeUnit);
    buffer.write(_map[ch] ?? ch);
  }
  return buffer.toString();
}


/// -----------------------------
/// Utils: Picker con buscador
/// -----------------------------
/// (Sigue disponible para "Añadir ejercicio")
Future<String?> showExercisePickerBottomSheet({
  required BuildContext context,
  required List<String> allExerciseNames,
  String title = 'Buscar o crear ejercicio',
}) async {
  allExerciseNames = allExerciseNames.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  final controller = TextEditingController();
  final ValueNotifier<String> query = ValueNotifier<String>('');

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) {
      final media = MediaQuery.of(c);
      final height = media.size.height * 0.85;

      return SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Escribe para buscar…',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (txt) => query.value = txt.trim(),
                onSubmitted: (txt) {
                  final q = txt.trim();
                  if (q.isEmpty) return;
                  Navigator.pop(c, q);
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: query,
                  builder: (_, q, __) {
                    final lower = q.toLowerCase();
                    final normalizedQuery = _normalizeForSearch(lower);
                    final filtered = normalizedQuery.isEmpty
                        ? allExerciseNames
                        : allExerciseNames
                        .where((e) => _normalizeForSearch(e.toLowerCase()).contains(normalizedQuery))
                        .toList();


                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (q.isNotEmpty &&
                            !allExerciseNames.any(
                                  (e) => _normalizeForSearch(e.toLowerCase()) == normalizedQuery,
                            ))

                          ListTile(
                            leading: const Icon(Icons.add),
                            title: Text('Crear "$q"'),
                            onTap: () => Navigator.pop(c, q),
                          ),
                        Expanded(
                          child: filtered.isEmpty
                              ? const Center(
                            child: Text('Sin resultados',
                                style: TextStyle(color: Colors.grey)),
                          )
                              : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final name = filtered[i];
                              return ListTile(
                                title: Text(name),
                                onTap: () => Navigator.pop(c, name),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(c, null),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        final q = controller.text.trim();
                        if (q.isEmpty) return;
                        Navigator.pop(c, q);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Usar este nombre'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Diálogo para configurar nº de series y reps objetivo
Future<(int series, int repsPerSet)?> showSeriesConfigDialog({
  required BuildContext context,
  String title = 'Configurar series',
  int initialSeries = 3,
  int initialReps = 10,
}) async {
  final setsCtrl = TextEditingController(text: initialSeries.toString());
  final repsCtrl = TextEditingController(text: initialReps.toString());

  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Aceptar')),
      ],
    ),
  );

  if (ok == true) {
    final setsN = int.tryParse(setsCtrl.text) ?? 0;
    final repsN = int.tryParse(repsCtrl.text) ?? 0;
    if (setsN > 0 && repsN > 0) return (setsN, repsN);
  }
  return null;
}

class SessionScreen extends StatefulWidget {
  final AppState state;
  final SessionData session;

  /// Si vienes desde Historial, guarda cada cambio inmediatamente.
  final bool fromHistory;

  const SessionScreen({
    super.key,
    required this.state,
    required this.session,
    this.fromHistory = false,
  });

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late SessionData s;
  late final TextEditingController notesCtrl;
  bool _dirty = false;

  String get _draftKey => 'gymlog.draft.session.${s.templateId}';

  void _ensureSetIds() {
    for (final st in s.sets) {
      if (st.id.isEmpty) {
        st.id = _newId();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Copia editable
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
        rir: e.rir,
        done: e.done,
      ))
          .toList(),
      notes: widget.session.notes,
    );
    _ensureSetIds();

    notesCtrl = TextEditingController(text: s.notes);
  }

  Timer? _autosaveTimer;

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(s.toJson()));
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Future<void> _onDirty() async {
    _dirty = true;
    if (widget.fromHistory) {
      // Debounce ~800ms para no guardar en cada tecla
      _autosaveTimer?.cancel();
      _autosaveTimer = Timer(const Duration(milliseconds: 800), () async {
        await widget.state.addSession(s); // actualiza sesión en historial
      });
    } else {
      await _saveDraft();
    }
    // Evita rebuild inmediato mientras teclean en Historial
    if (mounted && !widget.fromHistory) setState(() {});
  }

  // Guarda final con normalización/reindexado seguro
  Future<void> _finalizeAndSave(BuildContext context) async {
    try {
      // 1) Quita sets sin nombre
      s.sets.removeWhere((st) => st.exerciseName.trim().isEmpty);

      // 2) Reindexa y normaliza por ejercicio
      final Map<String, List<SetEntry>> byName = {};
      for (final st in s.sets) {
        byName.putIfAbsent(st.exerciseName.trim(), () => []).add(st);
      }

      final List<SetEntry> fixed = [];
      for (final entry in byName.entries) {
        final name = entry.key;
        final sets = entry.value..sort((a, b) => a.setIndex.compareTo(b.setIndex));

        int idx = 0;
        for (final st in sets) {
          idx += 1;
          final safeReps = st.reps < 0 ? 0.0 : st.reps;
          final safeRir = st.rir.clamp(0.0, 20.0);
          final safeKg = st.weight.isNaN ? 0.0 : (st.weight < 0 ? 0.0 : st.weight);
          final String id = (st.id.isEmpty) ? _newId() : st.id;

          fixed.add(SetEntry(
            id: id,
            exerciseName: name,
            setIndex: idx,
            reps: safeReps,
            weight: safeKg,
            targetReps: st.targetReps,
            rir: safeRir,
            done: st.done,
          ));
        }
      }

      s.sets
        ..clear()
        ..addAll(fixed);

      // 3) Guarda en historial
      await widget.state.addSession(s);

      // 4) Limpia borrador y marca limpio
      await _clearDraft();
      _dirty = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión guardada ✅')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la sesión: $e')),
      );
    }
  }

  // === Añadir ejercicio con buscador ===
  Future<void> _onAddExercisePressed() async {
    final allNames = widget.state.allExerciseNames();
    final pickedName = await showExercisePickerBottomSheet(
      context: context,
      allExerciseNames: allNames,
      title: 'Añadir ejercicio',
    );
    if (pickedName == null) return;
    final name = pickedName.trim();
    if (name.isEmpty) return;

    final cfg = await showSeriesConfigDialog(
      context: context,
      initialSeries: 3,
      initialReps: 10,
    );
    if (cfg == null) return;
    final (seriesN, repsTarget) = cfg;

    // Crear series vacías del ejercicio con IDs únicos
    final newSets = <SetEntry>[];
    int baseIndex = 0;
    for (final st in s.sets) {
      if (st.exerciseName == name && st.setIndex > baseIndex) baseIndex = st.setIndex;
    }
    for (int i = 0; i < seriesN; i++) {
      final nextIndex = baseIndex + i + 1;
      newSets.add(SetEntry(
        id: _newId(),
        exerciseName: name,
        setIndex: nextIndex,
        reps: 0.0,
        weight: 0.0,
        targetReps: repsTarget,
        rir: 0.0,
        done: false,
      ));
    }

    setState(() => s.sets.addAll(newSets));
    await _onDirty();
  }

  // === Reemplazar/renombrar ejercicio ===
  Future<void> _replaceExercise({
    required String oldName,
    required String newName,
    bool resetSets = false,
    int series = 0,
    int targetReps = 0,
  }) async {
    setState(() {
      if (resetSets) {
        s.sets.removeWhere((st) => st.exerciseName == oldName);
        for (int i = 0; i < series; i++) {
          s.sets.add(SetEntry(
            id: _newId(),
            exerciseName: newName,
            setIndex: i + 1,
            reps: 0.0,
            weight: 0.0,
            targetReps: targetReps,
            rir: 0.0,
            done: false,
          ));
        }
      } else {
        for (final st in s.sets) {
          if (st.exerciseName == oldName) {
            st.exerciseName = newName;
          }
        }
      }
    });
    await _onDirty();
  }

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
      await _onDirty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<SetEntry>> groups = {};
    for (final set in s.sets) {
      groups.putIfAbsent(set.exerciseName, () => []).add(set);
    }

    final baseTheme = Theme.of(context);

    final compactTheme = baseTheme.copyWith(
      visualDensity: VisualDensity.compact,
      cardTheme: baseTheme.cardTheme.copyWith(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: baseTheme.colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: baseTheme.textTheme.labelSmall,
        side: BorderSide(color: baseTheme.colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    final mq = MediaQuery.of(context);

    return MediaQuery(
      data: mq.copyWith(textScaler: const TextScaler.linear(0.95)),
      child: Theme(
        data: compactTheme,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (widget.fromHistory) {
              // ✅ Siempre guarda lo último al salir desde Historial
              await widget.state.addSession(s);
            } else {
              if (_dirty) {
                await _saveDraft();
              }
            }
            if (mounted) Navigator.of(context).pop();
          },
          child: Scaffold(
            resizeToAvoidBottomInset: false, // usamos nuestra propia animación
            appBar: AppBar(
              title: Text(
                'Sesión • ${s.templateName}',
                style: baseTheme.textTheme.titleMedium,
              ),
              centerTitle: false,
              actions: [
                IconButton(
                  tooltip: 'Añadir ejercicio',
                  onPressed: _onAddExercisePressed,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            // Animación rápida de padding según teclado
            body: AnimatedPadding(
              duration: _kKeyboardAnim,
              curve: Curves.fastOutSlowIn,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              // Tap en cualquier zona para ocultar teclado
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _pageMaxWidth),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      children: [
                        // Fecha en “píldora”
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: baseTheme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: baseTheme.colorScheme.outlineVariant),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}',
                                style: baseTheme.textTheme.labelMedium,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Tarjetas de ejercicios
                        ...groups.entries.map(
                              (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ExerciseCard(
                              appState: widget.state,
                              name: e.key,
                              sets: e.value,
                              onChanged: _onDirty,
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
                                await _onDirty();
                              },
                              onAddSet: (newSet) async {
                                setState(() => s.sets.add(newSet));
                                await _onDirty();
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
                                await _onDirty();
                              },
                              onDeleteExercise: () => _removeExerciseGroup(e.key),
                              onReplaceExercise: ({
                                required String newName,
                                required bool resetSets,
                                int series = 0,
                                int targetReps = 0,
                              }) async {
                                await _replaceExercise(
                                  oldName: e.key,
                                  newName: newName,
                                  resetSets: resetSets,
                                  series: series,
                                  targetReps: targetReps,
                                );
                              },
                              // Nombres para el autocomplete
                              allExerciseNames: widget.state.allExerciseNames(),
                            ),
                          ),
                        ),

                        // Botón añadir ejercicio inferior
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _onAddExercisePressed,
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
                          ),
                          minLines: 2,
                          maxLines: 4,
                          onChanged: (v) async {
                            s.notes = v;
                            await _onDirty();
                          },
                        ),

                        const SizedBox(height: 14),

                        // Guardado / info inferior
                        FilledButton(
                          onPressed:
                          s.sets.isEmpty ? null : () => _finalizeAndSave(context),
                          child: const Text('Guardar sesión'),
                        ),
                        const SizedBox(height: 10),
                        if (widget.fromHistory) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant),
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context).colorScheme.surface,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.auto_fix_high, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Cambios guardados automáticamente',
                                    style:
                                    Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        Text(
                          'Volumen total: ${s.totalVolume.toStringAsFixed(1)} kg·reps   •   Reps: ${s.totalReps}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).hintColor,
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

class _ExerciseCard extends StatefulWidget {
  final String name;
  final List<SetEntry> sets;

  final Future<void> Function() onChanged;
  final ValueChanged<String> onRename;
  final ValueChanged<SetEntry> onAddSet;
  final Future<void> Function() onRemoveLast;
  final VoidCallback onDeleteExercise;
  final AppState appState;

  final Future<void> Function({
  required String newName,
  required bool resetSets,
  int series,
  int targetReps,
  }) onReplaceExercise;

  /// Nombres para las sugerencias del autocomplete
  final List<String> allExerciseNames;

  const _ExerciseCard({
    required this.name,
    required this.sets,
    required this.onChanged,
    required this.onRename,
    required this.onAddSet,
    required this.onRemoveLast,
    required this.onDeleteExercise,
    required this.appState,
    required this.onReplaceExercise,
    required this.allExerciseNames,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  late final TextEditingController _nameCtrl;
  late final FocusNode _nameFocus;

  final Map<String, TextEditingController> _repsCtrls = {};
  final Map<String, TextEditingController> _kgCtrls = {};
  final Map<String, TextEditingController> _rirCtrls = {};

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.name);
    _nameFocus = FocusNode();
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) {
        _commitRename(_nameCtrl.text); // commit al perder foco
      }
    });
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

  String _formatNumber(num value) {
    final v = value.toDouble();
    if (v == 0.0) return '';

    // Mostramos el valor tal cual, pero quitando el ".0" si es entero exacto
    var s = v.toString();
    if (s.endsWith('.0')) {
      s = s.substring(0, s.length - 2);
    }
    return s;
  }


  void _syncControllers() {
    final currentIds = widget.sets.map((s) => s.id).toSet();
    for (final s in widget.sets) {
      _repsCtrls.putIfAbsent(
        s.id,
            () => TextEditingController(text: _formatNumber(s.reps)),
      );
      _kgCtrls.putIfAbsent(
        s.id,
            () => TextEditingController(text: _formatNumber(s.weight)),
      );
      _rirCtrls.putIfAbsent(
        s.id,
            () => TextEditingController(text: _formatNumber(s.rir)),
      );
    }
    // Limpieza explícita (evita avisos del analizador)
    final repsToRemove = _repsCtrls.keys.where((k) => !currentIds.contains(k)).toList();
    for (final k in repsToRemove) {
      _repsCtrls.remove(k)?.dispose();
    }
    final kgToRemove = _kgCtrls.keys.where((k) => !currentIds.contains(k)).toList();
    for (final k in kgToRemove) {
      _kgCtrls.remove(k)?.dispose();
    }
    final rirToRemove = _rirCtrls.keys.where((k) => !currentIds.contains(k)).toList();
    for (final k in rirToRemove) {
      _rirCtrls.remove(k)?.dispose();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    for (final c in _repsCtrls.values) c.dispose();
    for (final c in _kgCtrls.values) c.dispose();
    for (final c in _rirCtrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _commitRename(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _nameCtrl.text = widget.name;
      _nameCtrl.selection =
          TextSelection.fromPosition(TextPosition(offset: _nameCtrl.text.length));
      return;
    }
    if (trimmed.toLowerCase() == widget.name.toLowerCase()) return;
    await widget.onReplaceExercise(newName: trimmed, resetSets: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Cálculos de PR y 1RM
    final bestHistorical = widget.appState.best1RMFor(widget.name);
    final currentBest = widget.sets.fold<double>(0, (p, s) {
      if (s.reps > 0 && s.weight > 0) {
        final est = (s.weight * (1 + s.reps / 30.0));
        return est > p ? est : p;
      }
      return p;
    });
    final isPR = currentBest > 0 && currentBest > bestHistorical + 0.1;

    // Últimas mejores marcas (para sección Progreso)
    final recentBests = widget.appState.recentBestMarksFor(widget.name, limit: 5);

    // Helper UI: pill de marca personal
    Widget _markTile(BestMark m) {
      final d = m.date;
      final fecha =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_outlined, size: 16),
            const SizedBox(width: 6),
            Text('${m.weight.toStringAsFixed(1)} kg × ${m.reps}',
                style: theme.textTheme.labelMedium),
            const SizedBox(width: 8),
            Text('• ${m.est1RM.toStringAsFixed(1)} 1RM', style: theme.textTheme.labelSmall),
            const SizedBox(width: 8),
            Text(fecha, style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
          ],
        ),
      );
    }

    Future<void> addOneSet() async {
      final nextIndex = (widget.sets.isEmpty
          ? 0
          : widget.sets.map((x) => x.setIndex).reduce((a, b) => a > b ? a : b)) +
          1;
      final target = widget.sets.isNotEmpty ? widget.sets.first.targetReps : 10;

      final newSet = SetEntry(
        id: _newId(),
        exerciseName: widget.name,
        setIndex: nextIndex,
        reps: 0.0,
        weight: 0.0,
        targetReps: target,
        rir: 0.0,
        done: false,
      );

      widget.onAddSet(newSet);
      await widget.onChanged();
    }

    Future<void> removeLastSet() async {
      if (widget.sets.isEmpty) return;
      await widget.onRemoveLast();
      await widget.onChanged();
    }

    // ---------- CAMPO "EJERCICIO" CON AUTOCOMPLETE SIN CONFIRMACIONES ----------
    final lowerNames =
    widget.allExerciseNames.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Expanded(
                child: RawAutocomplete<String>(
                  textEditingController: _nameCtrl,
                  focusNode: _nameFocus,
                  optionsBuilder: (TextEditingValue tev) {
                    final q = tev.text.trim().toLowerCase();
                    if (q.isEmpty) return const Iterable<String>.empty();
                    return lowerNames.where((name) => name.toLowerCase().contains(q));
                  },
                  onSelected: (String selection) async {
                    if (selection.trim().isEmpty) return;
                    if (selection.toLowerCase() == widget.name.toLowerCase()) return;
                    _nameCtrl.text = selection;
                    await widget.onReplaceExercise(newName: selection.trim(), resetSets: false);
                  },
                  fieldViewBuilder: (ctx, controller, focus, onFieldSubmitted) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focus,
                      decoration: const InputDecoration(
                        labelText: 'Ejercicio',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (txt) async {
                        await _commitRename(txt); // Enter → commit
                      },
                    );
                  },
                  optionsViewBuilder: (ctx, onSelected, options) {
                    final opts = options.toList(growable: false);
                    if (opts.isEmpty) return const SizedBox.shrink();
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints:
                          const BoxConstraints(maxHeight: 180, minWidth: 240),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: opts.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final item = opts[i];
                              return InkWell(
                                onTap: () => onSelected(item),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Text(item,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Eliminar ejercicio',
                onPressed: widget.onDeleteExercise,
                icon: const Icon(Icons.delete_outline),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                const BoxConstraints.tightFor(width: 36, height: 36),
              ),
            ],
          ),

          if (isPR) ...[
            const SizedBox(height: 6),
            Row(children: [
              Chip(label: Text('🏆 Nuevo PR: ${currentBest.toStringAsFixed(1)} kg 1RM')),
            ]),
          ],
          const SizedBox(height: 6),

          // ======== Sección Progreso (visual) ========
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Progreso', style: theme.textTheme.titleSmall),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: theme.colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          const Text('RM máx '),
                          Text(
                            '${bestHistorical.toStringAsFixed(1)} kg',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (recentBests.isEmpty)
                  Text(
                    'Sin marcas previas. ¡Empieza hoy! 💪',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final m in recentBests) ...[
                          _markTile(m),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Filas de series (compactas)
          ...widget.sets.map((s) {
            final repsCtrl = _repsCtrls[s.id]!;
            final kgCtrl = _kgCtrls[s.id]!;
            final rirCtrl = _rirCtrls[s.id]!;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 26,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('#${s.setIndex}',
                            style: theme.textTheme.labelMedium),
                      ),
                    ),

                    // Reps (decimales)
                    Expanded(
                      child: TextFormField(
                        controller: repsCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Reps',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                        ),
                        onChanged: (v) async {
                          if (v.trim().isEmpty) return;
                          final parsed = double.tryParse(
                              v.replaceAll(',', '.'));
                          if (parsed != null) {
                            s.reps = parsed;
                            await widget.onChanged();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Kg (ya permitía decimales)
                    Expanded(
                      child: TextFormField(
                        controller: kgCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Kg',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                        ),
                        onChanged: (v) async {
                          if (v.trim().isEmpty) return;
                          final parsed = double.tryParse(
                              v.replaceAll(',', '.'));
                          if (parsed != null) {
                            s.weight = parsed;
                            await widget.onChanged();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 6),

                    // RIR (también con decimales)
                    SizedBox(
                      width: 86,
                      child: TextFormField(
                        controller: rirCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'RIR',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                        ),
                        onChanged: (v) async {
                          if (v.trim().isEmpty) return;
                          final parsed = double.tryParse(
                              v.replaceAll(',', '.'));
                          if (parsed != null) {
                            s.rir = parsed.clamp(0.0, 20.0);
                            final txt = _formatNumber(s.rir);
                            if (txt != rirCtrl.text) {
                              rirCtrl.text = txt;
                              rirCtrl.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(offset: rirCtrl.text.length),
                                  );
                            }
                            await widget.onChanged();
                          }
                        },
                      ),
                    ),
                  ]),
            );
          }),

          const SizedBox(height: 6),

          // Pie
          Row(
            children: [
              Expanded(
                child: Text(
                  'Objetivo: ${widget.sets.isNotEmpty ? widget.sets.first.targetReps : '-'} reps  •  Series: ${widget.sets.length}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  OutlinedButton(
                    onPressed:
                    widget.sets.isEmpty ? null : () async => await removeLastSet(),
                    child: const Text('-'),
                  ),
                  FilledButton(
                    onPressed: () async => addOneSet(),
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
