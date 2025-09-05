// lib/screens/templates_tab.dart
import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../models/models.dart';

class TemplatesTab extends StatefulWidget {
  final AppState state;
  const TemplatesTab({super.key, required this.state});
  @override State<TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<TemplatesTab> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Plantillas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...widget.state.templates.map((t) => _TemplateCard(
          template: t,
          onChanged: (updated) => widget.state.updateTemplate(updated),
          onRemove: () => widget.state.removeTemplate(t.id),
        )),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            final nt = WorkoutTemplate(name: 'Nueva plantilla', exercises: [
              ExerciseTemplate(name: 'Nuevo ejercicio', sets: 3, targetReps: 10),
            ]);
            widget.state.addTemplate(nt);
          },
          icon: const Icon(Icons.add), label: const Text('Añadir plantilla'),
        )
      ],
    );
  }
}

class _TemplateCard extends StatefulWidget {
  final WorkoutTemplate template;
  final ValueChanged<WorkoutTemplate> onChanged;
  final VoidCallback onRemove;
  const _TemplateCard({required this.template, required this.onChanged, required this.onRemove});
  @override State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  late WorkoutTemplate t;
  @override void initState() {
    super.initState();
    t = WorkoutTemplate(
      id: widget.template.id, name: widget.template.name,
      exercises: widget.template.exercises.map((e) => ExerciseTemplate(id: e.id, name: e.name, sets: e.sets, targetReps: e.targetReps)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: TextFormField(
              initialValue: t.name,
              decoration: const InputDecoration(labelText: 'Nombre de plantilla', border: OutlineInputBorder()),
              onChanged: (v) => setState(() => t.name = v),
            )),
            const SizedBox(width: 8),
            IconButton(onPressed: widget.onRemove, icon: const Icon(Icons.delete_outline), tooltip: 'Eliminar plantilla'),
          ]),
          const SizedBox(height: 8),
          ...t.exercises.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(flex: 3, child: TextFormField(
                initialValue: e.name,
                decoration: const InputDecoration(labelText: 'Ejercicio', border: OutlineInputBorder()),
                onChanged: (v) => setState(() => e.name = v),
              )),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(
                initialValue: e.sets.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Series', border: OutlineInputBorder()),
                onChanged: (v) => setState(() => e.sets = int.tryParse(v) ?? e.sets),
              )),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(
                initialValue: e.targetReps.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Reps objetivo', border: OutlineInputBorder()),
                onChanged: (v) => setState(() => e.targetReps = int.tryParse(v) ?? e.targetReps),
              )),
              IconButton(
                tooltip: 'Eliminar ejercicio',
                onPressed: () => setState(() => t.exercises.removeWhere((x) => x.id == e.id)),
                icon: const Icon(Icons.remove_circle_outline),
              )
            ]),
          )),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => t.exercises.add(ExerciseTemplate(name: 'Nuevo ejercicio', sets: 3, targetReps: 10))),
              icon: const Icon(Icons.add), label: const Text('Añadir ejercicio'),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(onPressed: () => widget.onChanged(t), icon: const Icon(Icons.save), label: const Text('Guardar cambios')),
          )
        ]),
      ),
    );
  }
}
