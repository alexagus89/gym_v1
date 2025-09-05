// lib/screens/start_tab.dart
import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../models/models.dart';
import 'session_screen.dart';

class StartTab extends StatefulWidget {
  final AppState state;
  const StartTab({super.key, required this.state});
  @override State<StartTab> createState() => _StartTabState();
}

class _StartTabState extends State<StartTab> {
  DateTime date = DateTime.now();
  String? templateId;

  @override
  Widget build(BuildContext context) {
    final uniqueById = <String, WorkoutTemplate>{};
    for (final t in widget.state.templates) { uniqueById[t.id] = t; }
    final templates = uniqueById.values.toList();
    final ids = templates.map((t) => t.id).toSet();
    final String? currentValue = (templateId != null && ids.contains(templateId)) ? templateId : null;

    return Column(children: [
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Crear sesión desde plantilla', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 18), const SizedBox(width: 8),
            Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
          ]),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.edit_calendar), label: const Text('Cambiar fecha'),
            onPressed: () async {
              final picked = await showDatePicker(context: context, firstDate: DateTime(2010), lastDate: DateTime(2100), initialDate: date);
              if (picked != null) setState(() => date = picked);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: currentValue,
            items: templates.map((t) => DropdownMenuItem<String>(value: t.id, child: Text(t.name))).toList(),
            onChanged: (v) => setState(() => templateId = v),
            decoration: const InputDecoration(labelText: 'Plantilla', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          if (currentValue != null) _TemplatePreview(template: templates.firstWhere((e) => e.id == currentValue)),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          const Text('Consejo', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Dentro de la sesión puedes editar el nombre del ejercicio.'),
        ]),
      )),
      SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (currentValue == null) ? null : () {
              final t = templates.firstWhere((e) => e.id == currentValue);
              final sets = <SetEntry>[];
              for (final ex in t.exercises) {
                for (int i = 0; i < ex.sets; i++) {
                  final last = widget.state.lastSetFor(ex.name, i + 1);
                  sets.add(SetEntry(
                    exerciseName: ex.name, setIndex: i + 1,
                    reps: last?.reps ?? 0, weight: last?.weight ?? 0, targetReps: ex.targetReps, done: false,
                  ));
                }
              }
              final s = SessionData(date: date, templateId: t.id, templateName: t.name, sets: sets);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionScreen(state: widget.state, session: s)));
            },
            icon: const Icon(Icons.play_arrow), label: const Text('Empezar sesión'),
          ),
        ),
      )),
    ]);
  }
}

class _TemplatePreview extends StatelessWidget {
  final WorkoutTemplate template;
  const _TemplatePreview({super.key, required this.template});
  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(template.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...template.exercises.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(e.name)), Text('${e.sets} x ${e.targetReps}'),
          ]),
        )),
      ]),
    ));
  }
}
