// lib/screens/templates_tab.dart
import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../models/models.dart';

class TemplatesTab extends StatefulWidget {
  final AppState state;
  const TemplatesTab({super.key, required this.state});

  @override
  State<TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<TemplatesTab> {
  @override
  Widget build(BuildContext context) {
    final templates = widget.state.templates;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 🔥 Botón para volver a cargar _defaultTemplates() SIN tocar sesiones
        OutlinedButton.icon(
          onPressed: () async {
            await widget.state.resetTemplatesOnly();
            if (mounted) setState(() {}); // refresca la lista
          },
          icon: const Icon(Icons.restore),
          label: const Text('Restaurar plantillas por defecto'),
        ),

        const SizedBox(height: 16),

        const Text(
          'Plantillas',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),

        // Lista de plantillas
        ...templates.map(
              (t) => _TemplateCard(
            key: ValueKey(t.id),
            template: t,
            onChanged: (updated) async {
              await widget.state.updateTemplate(updated);
            },
            onRemove: () async {
              await widget.state.removeTemplate(t.id);
              if (mounted) setState(() {});
            },
          ),
        ),

        const SizedBox(height: 16),

        // Botón para añadir nueva plantilla (se añade al final de la lista)
        OutlinedButton.icon(
          onPressed: () async {
            final nt = WorkoutTemplate(
              name: 'Nueva plantilla',
              exercises: [
                ExerciseTemplate(
                  name: 'Nuevo ejercicio',
                  sets: 3,
                  targetReps: 10,
                ),
              ],
            );

            await widget.state.addTemplate(nt);   // 👉 la añade al final
            if (mounted) setState(() {});         // 👉 refresca la lista
          },
          icon: const Icon(Icons.add),
          label: const Text('Añadir plantilla'),
        ),
      ],
    );
  }
}

class _TemplateCard extends StatefulWidget {
  final WorkoutTemplate template;
  final ValueChanged<WorkoutTemplate> onChanged;
  final VoidCallback onRemove;

  const _TemplateCard({
    super.key,
    required this.template,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  late WorkoutTemplate t;

  @override
  void initState() {
    super.initState();
    // Copia editable
    t = WorkoutTemplate(
      id: widget.template.id,
      name: widget.template.name,
      exercises: widget.template.exercises
          .map(
            (e) => ExerciseTemplate(
          id: e.id,
          name: e.name,
          sets: e.sets,
          targetReps: e.targetReps,
        ),
      )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre de la plantilla + borrar
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: t.name,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de plantilla',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      setState(() => t.name = v);
                      // opcional: guardar nombre al vuelo
                      widget.onChanged(t);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar plantilla',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Ejercicios
            ...t.exercises.map(
                  (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    // Nombre ejercicio
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        initialValue: e.name,
                        decoration: const InputDecoration(
                          labelText: 'Ejercicio',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => e.name = v),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Series
                    Expanded(
                      child: TextFormField(
                        initialValue: e.sets.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Series',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(
                              () => e.sets = int.tryParse(v) ?? e.sets,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Reps objetivo
                    Expanded(
                      child: TextFormField(
                        initialValue: e.targetReps.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Reps objetivo',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(
                              () => e.targetReps = int.tryParse(v) ?? e.targetReps,
                        ),
                      ),
                    ),

                    // Eliminar ejercicio
                    IconButton(
                      tooltip: 'Eliminar ejercicio',
                      onPressed: () {
                        setState(() {
                          t.exercises.removeWhere((x) => x.id == e.id);
                        });
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              ),
            ),

            // Añadir ejercicio
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    t.exercises.add(
                      ExerciseTemplate(
                        name: 'Nuevo ejercicio',
                        sets: 3,
                        targetReps: 10,
                      ),
                    );
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Añadir ejercicio'),
              ),
            ),

            const SizedBox(height: 8),

            // Guardar cambios
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () {
                  widget.onChanged(t);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Plantilla guardada')),
                  );
                },
                icon: const Icon(Icons.save),
                label: const Text('Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
