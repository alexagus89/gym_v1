import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GymLogApp());
}

// ===================== MODELOS =====================
// UID único garantizado (timestamp + contador)
int _uidCounter = 0;
String uid() {
  _uidCounter++;
  return '${DateTime.now().microsecondsSinceEpoch}_$_uidCounter';
}

class ExerciseTemplate {
  String id;
  String name; // Nombre del ejercicio
  int sets; // nº de series planificadas
  int targetReps; // reps objetivo (mín del rango)

  ExerciseTemplate({
    String? id,
    required this.name,
    required this.sets,
    required this.targetReps,
  }) : id = id ?? uid();

  factory ExerciseTemplate.fromJson(Map<String, dynamic> j) => ExerciseTemplate(
    id: j['id'],
    name: j['name'],
    sets: j['sets'],
    targetReps: j['targetReps'],
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sets': sets,
    'targetReps': targetReps,
  };
}

class WorkoutTemplate {
  String id;
  String name; // p.ej. Torso A
  List<ExerciseTemplate> exercises;

  WorkoutTemplate({String? id, required this.name, required this.exercises})
      : id = id ?? uid();

  factory WorkoutTemplate.fromJson(Map<String, dynamic> j) => WorkoutTemplate(
    id: j['id'],
    name: j['name'],
    exercises:
    (j['exercises'] as List).map((e) => ExerciseTemplate.fromJson(e)).toList(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
}

class SetEntry {
  String id;
  String exerciseName; // nombre del ejercicio (copiado/renombrable por sesión)
  int setIndex; // nº de serie (1..n)
  int reps; // reps realizadas
  double weight; // kg
  int targetReps; // guía
  bool done;

  SetEntry({
    String? id,
    required this.exerciseName,
    required this.setIndex,
    required this.reps,
    required this.weight,
    required this.targetReps,
    this.done = false,
  }) : id = id ?? uid();

  factory SetEntry.fromJson(Map<String, dynamic> j) => SetEntry(
    id: j['id'],
    exerciseName: j['exerciseName'],
    setIndex: j['setIndex'],
    reps: j['reps'],
    weight: (j['weight'] as num).toDouble(),
    targetReps: j['targetReps'],
    done: j['done'] ?? false,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseName': exerciseName,
    'setIndex': setIndex,
    'reps': reps,
    'weight': weight,
    'targetReps': targetReps,
    'done': done,
  };
}

class SessionData {
  String id;
  DateTime date;
  String templateId;
  String templateName;
  List<SetEntry> sets;
  String notes;

  SessionData({
    String? id,
    required this.date,
    required this.templateId,
    required this.templateName,
    required this.sets,
    this.notes = '',
  }) : id = id ?? uid();

  double get totalVolume =>
      sets.fold(0, (p, s) => p + (s.weight * s.reps.toDouble()));
  int get totalReps => sets.fold(0, (p, s) => p + s.reps);

  factory SessionData.fromJson(Map<String, dynamic> j) => SessionData(
    id: j['id'],
    date: DateTime.parse(j['date']),
    templateId: j['templateId'],
    templateName: j['templateName'],
    sets: (j['sets'] as List).map((e) => SetEntry.fromJson(e)).toList(),
    notes: j['notes'] ?? '',
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'templateId': templateId,
    'templateName': templateName,
    'sets': sets.map((e) => e.toJson()).toList(),
    'notes': notes,
  };
}

// ===================== ESTADO =====================
class AppState extends ChangeNotifier {
  // Subir la versión si quieres forzar reset de datos guardados
  static const _kTemplates = 'gymlog.templates.v5';
  static const _kSessions = 'gymlog.sessions.v5';

  final List<WorkoutTemplate> templates = [];
  final List<SessionData> sessions = [];

  AppState() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final tRaw = prefs.getString(_kTemplates);
    final sRaw = prefs.getString(_kSessions);

    if (tRaw == null) {
      templates
        ..clear()
        ..addAll(_defaultTemplates());
      await prefs.setString(
        _kTemplates,
        jsonEncode(templates.map((e) => e.toJson()).toList()),
      );
    } else {
      final list = (jsonDecode(tRaw) as List)
          .map((e) => WorkoutTemplate.fromJson(e))
          .toList();
      templates
        ..clear()
        ..addAll(list);
    }

    if (sRaw != null) {
      final list =
      (jsonDecode(sRaw) as List).map((e) => SessionData.fromJson(e)).toList();
      sessions
        ..clear()
        ..addAll(list);
    }
    notifyListeners();
  }
  // --- Exportación a CSV (disco) ---

  Future<Directory> _getExportDir() async {
    final base = await getApplicationDocumentsDirectory(); // carpeta de documentos de la app (Windows/Android/Mac/Linux)
    final dir = Directory('${base.path}/GymLog');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _writeCsv(List<List<dynamic>> rows, String fileName) async {
    final dir = await _getExportDir();
    final file = File('${dir.path}/$fileName');
    final csvData = const ListToCsvConverter().convert(rows);
    await file.writeAsString(csvData);
    return file;
  }

  /// Exporta plantillas a CSV (una fila por ejercicio de cada plantilla)
  Future<File> exportTemplatesCsv() async {
    final rows = <List<dynamic>>[
      ['template_id', 'template_name', 'exercise_id', 'exercise_name', 'sets', 'target_reps'],
    ];
    for (final t in templates) {
      for (final e in t.exercises) {
        rows.add([t.id, t.name, e.id, e.name, e.sets, e.targetReps]);
      }
    }
    return _writeCsv(rows, 'templates.csv');
  }

  /// Exporta sesiones a CSV (una fila por set de cada sesión)
  Future<File> exportSessionsCsv() async {
    final rows = <List<dynamic>>[
      [
        'session_id',
        'date_iso',
        'template_id',
        'template_name',
        'set_id',
        'exercise_name',
        'set_index',
        'reps',
        'weight_kg',
        'target_reps',
        'done',
        'notes' // repetimos notas por fila para tener contexto
      ],
    ];
    for (final s in sessions) {
      for (final st in s.sets) {
        rows.add([
          s.id,
          s.date.toIso8601String(),
          s.templateId,
          s.templateName,
          st.id,
          st.exerciseName,
          st.setIndex,
          st.reps,
          st.weight,
          st.targetReps,
          st.done,
          s.notes,
        ]);
      }
    }
    return _writeCsv(rows, 'sessions.csv');
  }

  /// Exporta TODO a CSV y devuelve las rutas
  Future<List<String>> exportAllCsv() async {
    final tFile = await exportTemplatesCsv();
    final sFile = await exportSessionsCsv();
    return [tFile.path, sFile.path];
  }

  /// (Opcional) Saber dónde se guarda
  Future<String> dataFolderPath() async {
    final d = await _getExportDir();
    return d.path;
  }


  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kTemplates,
      jsonEncode(templates.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _kSessions,
      jsonEncode(sessions.map((e) => e.toJson()).toList()),
    );
  }

  // --- Plantillas ---
  void addTemplate(WorkoutTemplate t) {
    templates.insert(0, t);
    _persist();
    notifyListeners();
  }

  void updateTemplate(WorkoutTemplate t) {
    final idx = templates.indexWhere((x) => x.id == t.id);
    if (idx >= 0) templates[idx] = t;
    _persist();
    notifyListeners();
  }

  void removeTemplate(String id) {
    templates.removeWhere((e) => e.id == id);
    _persist();
    notifyListeners();
  }

  // --- Sesiones ---
  void addSession(SessionData s) {
    final i = sessions.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      sessions[i] = s;
    } else {
      sessions.insert(0, s);
    }
    _persist();
    notifyListeners();
  }

  void removeSession(String id) {
    sessions.removeWhere((e) => e.id == id);
    _persist();
    notifyListeners();
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTemplates);
    await prefs.remove(_kSessions);
    templates
      ..clear()
      ..addAll(_defaultTemplates());
    sessions.clear();
    await _persist();
    notifyListeners();
  }

  // Helpers
  List<WorkoutTemplate> _defaultTemplates() {
    return [
      WorkoutTemplate(
        name: 'Torso A',
        exercises: [
          ExerciseTemplate(name: 'Press banca plano con barra', sets: 4, targetReps: 6),
          ExerciseTemplate(name: 'Press inclinado con mancuernas', sets: 3, targetReps: 8),
          ExerciseTemplate(name: 'Face pulls en polea', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Elevaciones laterales con mancuernas', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Curl bíceps barra Z', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Extensión tríceps polea alta', sets: 3, targetReps: 10),
        ],
      ),
      WorkoutTemplate(
        name: 'Pierna A',
        exercises: [
          ExerciseTemplate(name: 'Sentadilla trasera barra', sets: 4, targetReps: 6),
          ExerciseTemplate(name: 'Prensa inclinada', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Zancadas caminando con mancuernas', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Curl femoral tumbado máquina', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Elevación de talones de pie (gemelos)', sets: 4, targetReps: 15),
          ExerciseTemplate(name: 'Plancha abdominal (segundos)', sets: 3, targetReps: 40),
        ],
      ),
      WorkoutTemplate(
        name: 'Torso B',
        exercises: [
          ExerciseTemplate(name: 'Press militar con barra de pie', sets: 4, targetReps: 6),
          ExerciseTemplate(name: 'Press banca inclinado barra', sets: 3, targetReps: 8),
          ExerciseTemplate(name: 'Aperturas en máquina o mancuernas', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Pájaros (elevaciones posteriores)', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Curl martillo mancuernas', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Fondos en paralelas asistidos', sets: 3, targetReps: 8),
        ],
      ),
      WorkoutTemplate(
        name: 'Pierna B',
        exercises: [
          ExerciseTemplate(name: 'Sentadilla frontal con barra', sets: 4, targetReps: 6),
          ExerciseTemplate(name: 'Hip Thrust con barra', sets: 4, targetReps: 8),
          ExerciseTemplate(name: 'Extensión de cuádriceps en máquina', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Elevación de talones sentado (gemelos)', sets: 4, targetReps: 15),
          ExerciseTemplate(name: 'Abs', sets: 3, targetReps: 8),
        ],
      ),
    ];
  }
}

// ===================== APP / UI =====================
class GymLogApp extends StatelessWidget {
  const GymLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Log',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueGrey),
      home: AppRoot(state: AppState()),
    );
  }
}

class AppRoot extends StatefulWidget {
  final AppState state;
  const AppRoot({super.key, required this.state});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  int tab = 0; // 0 start, 1 templates, 2 history

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Gym Log'),
            actions: [
              IconButton(
                tooltip: 'Reiniciar datos',
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Reiniciar datos'),
                      content: const Text(
                        'Esto borrará tus sesiones y restaurará las plantillas por defecto. ¿Continuar?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Sí, reiniciar'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await widget.state.resetAll();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Datos reiniciados')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.restart_alt),
              ),

              // 👇 NUEVO BOTÓN: Exportar a CSV
              IconButton(
                tooltip: 'Exportar a CSV',
                icon: const Icon(Icons.table_view),
                onPressed: () async {
                  try {
                    final paths = await widget.state.exportAllCsv();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 5),
                        content: Text(
                          'CSV exportados:\n${paths.join('\n')}',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error exportando CSV: $e')),
                    );
                  }
                },
              ),
            ],
          ),
          body: switch (tab) {
            0 => StartTab(state: widget.state),
            1 => TemplatesTab(state: widget.state),
            _ => HistoryTab(state: widget.state),
          },
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.playlist_add),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.fact_check_outlined),
                label: 'Plantillas',
              ),
              NavigationDestination(
                icon: Icon(Icons.history),
                label: 'Historial',
              )
            ],
          ),
        );
      },
    );
  }
}


// --------------------- TAB: INICIO ---------------------
class StartTab extends StatefulWidget {
  final AppState state;
  const StartTab({super.key, required this.state});

  @override
  State<StartTab> createState() => _StartTabState();
}

class _StartTabState extends State<StartTab> {
  DateTime date = DateTime.now();
  String? templateId;

  @override
  Widget build(BuildContext context) {
    // 1) Deduplicar por id para evitar items con el mismo value
    final uniqueById = <String, WorkoutTemplate>{};
    for (final t in widget.state.templates) {
      uniqueById[t.id] = t;
    }
    final templates = uniqueById.values.toList();

    // 2) Selección válida
    final ids = templates.map((t) => t.id).toSet();
    final String? currentValue =
    (templateId != null && ids.contains(templateId)) ? templateId : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            // Scrollable content
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
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: currentValue,
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
                        template:
                        templates.firstWhere((e) => e.id == currentValue),
                      ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text('Consejo',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    const Text(
                        'Dentro de la sesión puedes editar el nombre del ejercicio (por ejemplo cambiar "Abs" por "Crunch en polea").'),
                  ],
                ),
              ),
            ),
            // Fixed action button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (currentValue == null)
                        ? null
                        : () {
                      final t =
                      templates.firstWhere((e) => e.id == currentValue);
                      final sets = <SetEntry>[];
                      for (final ex in t.exercises) {
                        for (int i = 0; i < ex.sets; i++) {
                          sets.add(SetEntry(
                            exerciseName: ex.name,
                            setIndex: i + 1,
                            reps: 0,
                            weight: 0,
                            targetReps: ex.targetReps,
                          ));
                        }
                      }
                      final s = SessionData(
                        date: date,
                        templateId: t.id,
                        templateName: t.name,
                        sets: sets,
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SessionScreen(
                            state: widget.state,
                            session: s,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Empezar sesión'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
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

// --------------------- TAB: PLANTILLAS ---------------------
class TemplatesTab extends StatefulWidget {
  final AppState state;
  const TemplatesTab({super.key, required this.state});

  @override
  State<TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<TemplatesTab> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Plantillas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...widget.state.templates.map(
              (t) => _TemplateCard(
            template: t,
            onChanged: (updated) {
              widget.state.updateTemplate(updated);
            },
            onRemove: () => widget.state.removeTemplate(t.id),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            final nt = WorkoutTemplate(name: 'Nueva plantilla', exercises: [
              ExerciseTemplate(name: 'Nuevo ejercicio', sets: 3, targetReps: 10),
            ]);
            widget.state.addTemplate(nt);
          },
          icon: const Icon(Icons.add),
          label: const Text('Añadir plantilla'),
        )
      ],
    );
  }
}

class _TemplateCard extends StatefulWidget {
  final WorkoutTemplate template;
  final ValueChanged<WorkoutTemplate> onChanged;
  final VoidCallback onRemove;
  const _TemplateCard(
      {required this.template, required this.onChanged, required this.onRemove});

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  late WorkoutTemplate t;

  @override
  void initState() {
    super.initState();
    t = WorkoutTemplate(
      id: widget.template.id,
      name: widget.template.name,
      exercises: widget.template.exercises
          .map((e) => ExerciseTemplate(
          id: e.id, name: e.name, sets: e.sets, targetReps: e.targetReps))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: TextFormField(
                initialValue: t.name,
                decoration: const InputDecoration(
                    labelText: 'Nombre de plantilla',
                    border: OutlineInputBorder()),
                onChanged: (v) => setState(() => t.name = v),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: widget.onRemove,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar plantilla',
            ),
          ]),
          const SizedBox(height: 8),
          ...t.exercises.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: e.name,
                  decoration: const InputDecoration(
                      labelText: 'Ejercicio', border: OutlineInputBorder()),
                  onChanged: (v) => setState(() => e.name = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: e.sets.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Series', border: OutlineInputBorder()),
                  onChanged: (v) => setState(
                          () => e.sets = int.tryParse(v) ?? e.sets),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: e.targetReps.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Reps objetivo',
                      border: OutlineInputBorder()),
                  onChanged: (v) => setState(() =>
                  e.targetReps = int.tryParse(v) ?? e.targetReps),
                ),
              ),
              IconButton(
                tooltip: 'Eliminar ejercicio',
                onPressed: () => setState(() =>
                    t.exercises.removeWhere((x) => x.id == e.id)),
                icon: const Icon(Icons.remove_circle_outline),
              )
            ]),
          )),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  t.exercises.add(ExerciseTemplate(
                      name: 'Nuevo ejercicio', sets: 3, targetReps: 10));
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Añadir ejercicio'),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => widget.onChanged(t),
              icon: const Icon(Icons.save),
              label: const Text('Guardar cambios'),
            ),
          )
        ]),
      ),
    );
  }
}

// --------------------- TAB: HISTORIAL ---------------------
class HistoryTab extends StatelessWidget {
  final AppState state;
  const HistoryTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.sessions.isEmpty) {
      return const Center(child: Text('Sin sesiones aún'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.sessions.length,
      itemBuilder: (context, i) {
        final s = state.sessions[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SessionScreen(state: state, session: s),
            )),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Row(children: [
                      IconButton(
                        tooltip: 'Eliminar sesión',
                        onPressed: () =>
                            _confirmDelete(context, () => state.removeSession(s.id)),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ])
                  ],
                ),
                Text(s.templateName, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Text(
                    'Volumen: ${s.totalVolume.toStringAsFixed(1)}  •  Reps: ${s.totalReps}'),
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

// --------------------- PANTALLA: SESIÓN ---------------------
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

  @override
  Widget build(BuildContext context) {
    // Agrupar sets por nombre de ejercicio
    final Map<String, List<SetEntry>> groups = {};
    for (final set in s.sets) {
      groups.putIfAbsent(set.exerciseName, () => []).add(set);
    }

    return Scaffold(
      appBar: AppBar(title: Text('Sesión • ${s.templateName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 18),
            const SizedBox(width: 8),
            Text(
                '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}'),
          ]),
          const SizedBox(height: 12),
          ...groups.entries.map((e) => _ExerciseCard(
            name: e.key,
            sets: e.value,
            onChanged: () => setState(() {}),
            onRename: (newName) {
              setState(() {
                final trimmed = newName.trim();
                if (trimmed.isEmpty) return;
                for (final st in s.sets) {
                  if (st.exerciseName == e.key) {
                    st.exerciseName = trimmed;
                  }
                }
              });
            },
          )),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notas (opcional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            onChanged: (v) => s.notes = v,
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: () {
                  widget.state.addSession(s);
                  Navigator.of(context).pop();
                },
                child: const Text('Guardar sesión'),
              ),
            )
          ]),
          const SizedBox(height: 12),
          Text(
              'Volumen total: ${s.totalVolume.toStringAsFixed(1)} kg·reps   •   Reps: ${s.totalReps}')
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  final String name;
  final List<SetEntry> sets;
  final VoidCallback onChanged;
  final ValueChanged<String> onRename; // editar nombre
  const _ExerciseCard(
      {required this.name,
        required this.sets,
        required this.onChanged,
        required this.onRename});

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.name);
  }

  @override
  void didUpdateWidget(covariant _ExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name && _nameCtrl.text != widget.name) {
      _nameCtrl.text = widget.name;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
                labelText: 'Ejercicio', border: OutlineInputBorder()),
            onChanged: widget.onRename,
          ),
          const SizedBox(height: 8),
          ...widget.sets.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(width: 36, child: Text('#${s.setIndex}')),
              Expanded(
                child: TextFormField(
                  initialValue: s.reps == 0 ? '' : s.reps.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reps'),
                  onChanged: (v) {
                    s.reps = int.tryParse(v) ?? 0;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: s.weight == 0 ? '' : s.weight.toString(),
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Kg'),
                  onChanged: (v) {
                    s.weight =
                        double.tryParse(v.replaceAll(',', '.')) ?? 0;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Checkbox(
                value: s.done,
                onChanged: (v) {
                  setState(() => s.done = v ?? false);
                  widget.onChanged();
                },
              ),
            ]),
          )),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
                'Objetivo aprox: ${widget.sets.isNotEmpty ? widget.sets.first.targetReps : '-'} reps',
                style: const TextStyle(color: Colors.grey)),
          )
        ]),
      ),
    );
  }
}
