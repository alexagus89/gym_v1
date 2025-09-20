// lib/screens/start_tab.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/app_state.dart';
import '../models/models.dart';
import 'session_screen.dart';

class StartTab extends StatefulWidget {
  final AppState state;
  const StartTab({super.key, required this.state});
  @override
  State<StartTab> createState() => _StartTabState();
}

class _StartTabState extends State<StartTab> {
  DateTime date = DateTime.now();
  String? templateId;

  // Key para el dropdown
  final GlobalKey<FormFieldState<String>> _ddKey =
  GlobalKey<FormFieldState<String>>();

  Future<SessionData?> _loadDraftForTemplate(String templateId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('gymlog.draft.session.$templateId');
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SessionData.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearDraftForTemplate(String templateId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gymlog.draft.session.$templateId');
  }

  SessionData _buildEmptySessionFromTemplate(WorkoutTemplate t) {
    final sets = <SetEntry>[];
    for (final ex in t.exercises) {
      for (int i = 0; i < ex.sets; i++) {
        sets.add(SetEntry(
          exerciseName: ex.name,
          setIndex: i + 1,
          reps: 0,
          weight: 0.0,
          targetReps: ex.targetReps,
          rir: 0,
          done: false,
        ));
      }
    }
    return SessionData(
      date: date,
      templateId: t.id,
      templateName: t.name,
      sets: sets,
      notes: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final uniqueById = <String, WorkoutTemplate>{};
    for (final t in widget.state.templates) {
      uniqueById[t.id] = t;
    }
    final templates = uniqueById.values.toList();

    final ids = templates.map((t) => t.id).toSet();
    final String? currentValue =
    (templateId != null && ids.contains(templateId)) ? templateId : null;

    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Crear sesión desde plantilla',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 18),
                const SizedBox(width: 8),
                Text(
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}')
              ]),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.edit_calendar),
                label: const Text('Cambiar fecha'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2010),
                    lastDate: DateTime(2100),
                    initialDate: date,
                  );
                  if (picked != null) setState(() => date = picked);
                },
              ),
              const SizedBox(height: 12),

              // Usa initialValue en vez de value y añade key
              DropdownButtonFormField<String>(
                key: _ddKey,
                initialValue: currentValue,
                items: templates
                    .map((t) => DropdownMenuItem<String>(
                  value: t.id,
                  child: Text(t.name),
                ))
                    .toList(),
                onChanged: (v) => setState(() => templateId = v),
                decoration: const InputDecoration(
                  labelText: 'Plantilla',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              if (currentValue != null)
                _TemplatePreview(
                  key: ValueKey(currentValue), // ⬅️ añadimos un Key
                  template:
                  templates.firstWhere((e) => e.id == currentValue),
                ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Top 5 • Mejores 1RM',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),

              Builder(
                builder: (context) {
                  final names = widget.state.allExerciseNames();
                  final entries = <MapEntry<String, double>>[];
                  for (final n in names) {
                    final best = widget.state.best1RMFor(n);
                    if (best > 0) entries.add(MapEntry(n, best));
                  }
                  entries.sort((a, b) => b.value.compareTo(a.value));
                  final top5 = entries.take(5).toList();

                  if (top5.isEmpty) {
                    return const Text(
                      'Aún no hay marcas registradas. Registra series con peso y reps para ver tus mejores 1RM aquí.',
                      style: TextStyle(color: Colors.grey),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < top5.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${i + 1}. '),
                              Expanded(
                                child: Text(
                                  '${top5[i].key}  —  ${top5[i].value.toStringAsFixed(1)} kg (1RM)',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),

      // Botón inferior fijo
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Empezar sesión'),
              onPressed: (currentValue == null)
                  ? null
                  : () async {
                final t = templates.firstWhere((e) => e.id == currentValue);

                final draft = await _loadDraftForTemplate(t.id);

                if (draft == null) {
                  final empty = _buildEmptySessionFromTemplate(t);
                  if (!mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SessionScreen(
                        state: widget.state,
                        session: empty,
                      ),
                    ),
                  );
                  return;
                }

                if (!mounted) return;
                final choice = await showModalBottomSheet<String>(
                  context: context,
                  showDragHandle: true,
                  builder: (c) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Sesión sin terminar encontrada',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '¿Quieres continuar donde lo dejaste o empezar una sesión nueva en blanco?',
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () =>
                                Navigator.pop(c, 'continue'),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Continuar borrador'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pop(c, 'new'),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Empezar en blanco'),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                );

                if (!mounted) return;
                if (choice == 'continue') {
                  final restored = SessionData.fromJson(draft.toJson());
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SessionScreen(
                        state: widget.state,
                        session: restored,
                      ),
                    ),
                  );
                } else if (choice == 'new') {
                  await _clearDraftForTemplate(t.id);
                  final empty = _buildEmptySessionFromTemplate(t);
                  if (!mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SessionScreen(
                        state: widget.state,
                        session: empty,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ),
    ]);
  }
}

class _TemplatePreview extends StatelessWidget {
  final WorkoutTemplate template;
  const _TemplatePreview({super.key, required this.template});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(template.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...template.exercises.map(
                  (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(e.name)),
                    Text('${e.sets} x ${e.targetReps}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
