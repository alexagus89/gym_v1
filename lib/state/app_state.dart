// lib/state/app_state.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import '../models/models.dart';

class AppState extends ChangeNotifier {
  // ⬇️ Subimos la clave de plantillas para garantizar que coja los nuevos defaults
  static const _kTemplates = 'gymlog.templates.v6'; // antes v5
  static const _kSessions  = 'gymlog.sessions.v5';

  // Control de versión del "seed" de plantillas: súbelo cuando cambies _defaultTemplates()
  static const _kTemplatesSeedVersionKey = 'gymlog.templates.seed_version';
  static const int kTemplatesSeedVersion = 2;

  final List<WorkoutTemplate> templates = [];
  final List<SessionData> sessions = [];

  AppState() {
    _load();
  }

  // Renombra un ejercicio en TODAS las plantillas y en TODO el historial de sesiones
  Future<void> renameExerciseEverywhere(String oldName, String newName) async {
    final from = oldName.trim();
    final to   = newName.trim();
    if (from.isEmpty || to.isEmpty || from == to) return;

    bool changed = false;

    // Plantillas
    for (final t in templates) {
      for (final e in t.exercises) {
        if (e.name == from) {
          e.name = to;
          changed = true;
        }
      }
    }

    // Historial de sesiones
    for (final ses in sessions) {
      for (final st in ses.sets) {
        if (st.exerciseName == from) {
          st.exerciseName = to;
          changed = true;
        }
      }
    }

    if (changed) {
      await _persist();
      notifyListeners();
    }
  }


  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final tRaw = prefs.getString(_kTemplates);
    final sRaw = prefs.getString(_kSessions);
    final storedSeed = prefs.getInt(_kTemplatesSeedVersionKey) ?? 0;

    // --- Plantillas ---
    // Si no hay plantillas guardadas (instalación limpia) o el seed es antiguo → resembrar
    if (tRaw == null || storedSeed < kTemplatesSeedVersion) {
      templates
        ..clear()
        ..addAll(_defaultTemplates());
      await prefs.setString(
        _kTemplates,
        jsonEncode(templates.map((e) => e.toJson()).toList()),
      );
      await prefs.setInt(_kTemplatesSeedVersionKey, kTemplatesSeedVersion);
    } else {
      final list = (jsonDecode(tRaw) as List)
          .map((e) => WorkoutTemplate.fromJson(e))
          .toList();
      templates
        ..clear()
        ..addAll(list);
    }

    // --- Sesiones (sin tocarlas) ---
    if (sRaw != null) {
      final list = (jsonDecode(sRaw) as List)
          .map((e) => SessionData.fromJson(e))
          .toList();
      sessions
        ..clear()
        ..addAll(list);
    }

    notifyListeners();
  }

  // --- CSV ---
  Future<Directory> _getExportDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/GymLog');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _writeCsv(List<List<dynamic>> rows, String fileName) async {
    final dir = await _getExportDir();
    final file = File('${dir.path}/$fileName');
    final csvData = const ListToCsvConverter().convert(rows);
    await file.writeAsString(csvData);
    return file;
  }

  /// Exporta solo sesiones (historial)
  Future<File> exportSessionsCsv() async {
    final rows = <List<dynamic>>[
      ['session_id','date_iso','template_id','template_name','set_id','exercise_name','set_index','reps','weight_kg','target_reps','rir','done','notes'],
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
          st.rir,
          st.done,
          s.notes,
        ]);
      }
    }
    return _writeCsv(rows, 'sessions.csv');
  }

  /// (Sigue existiendo si lo quieres usar en algún sitio)
  Future<File> exportTemplatesCsv() async {
    final rows = <List<dynamic>>[
      ['template_id','template_name','exercise_id','exercise_name','sets','target_reps'],
    ];
    for (final t in templates) {
      for (final e in t.exercises) {
        rows.add([t.id,t.name,e.id,e.name,e.sets,e.targetReps]);
      }
    }
    return _writeCsv(rows, 'templates.csv');
  }

  Future<List<String>> exportAllCsv() async {
    final t = await exportTemplatesCsv();
    final s = await exportSessionsCsv();
    return [t.path, s.path];
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

  // --- PR & prefill ---
  double _epley1RM(int reps, double weight) =>
      reps <= 1 ? weight : weight * (1 + reps / 30.0);

  double best1RMFor(String exerciseName) {
    double best = 0;
    for (final s in sessions) {
      for (final st in s.sets) {
        if (st.exerciseName == exerciseName && st.reps > 0 && st.weight > 0) {
          final est = _epley1RM(st.reps, st.weight);
          if (est > best) best = est;
        }
      }
    }
    return best;
  }

  SetEntry? lastSetFor(String exerciseName, int setIndex) {
    for (final s in sessions) {
      for (final st in s.sets) {
        if (st.exerciseName == exerciseName && st.setIndex == setIndex) {
          return st;
        }
      }
    }
    return null;
  }

  // --- Mutaciones ---
  Future<void> addTemplate(WorkoutTemplate t) async {
    templates.insert(0, t);
    await _persist();
    notifyListeners();
  }

  Future<void> updateTemplate(WorkoutTemplate t) async {
    final idx = templates.indexWhere((x) => x.id == t.id);
    if (idx >= 0) templates[idx] = t;
    await _persist();
    notifyListeners();
  }

  Future<void> removeTemplate(String id) async {
    templates.removeWhere((e) => e.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> addSession(SessionData s) async {
    final i = sessions.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      sessions[i] = s;
    } else {
      sessions.insert(0, s);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> removeSession(String id) async {
    sessions.removeWhere((e) => e.id == id);
    await _persist();
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

    // Marcamos el seed actual para que no resembrar inmediatamente otra vez
    await prefs.setInt(_kTemplatesSeedVersionKey, kTemplatesSeedVersion);

    await _persist();
    notifyListeners();
  }

  Future<void> resetTemplatesOnly() async {
    final prefs = await SharedPreferences.getInstance();

    // Restaura las plantillas por defecto
    templates
      ..clear()
      ..addAll(_defaultTemplates());

    // Persiste SOLO plantillas (no sesiones)
    await prefs.setString(
      _kTemplates,
      jsonEncode(templates.map((e) => e.toJson()).toList()),
    );

    // Marca la versión de seed actual
    await prefs.setInt(_kTemplatesSeedVersionKey, kTemplatesSeedVersion);

    notifyListeners();
  }

  // === Tus plantillas por defecto ===
  List<WorkoutTemplate> _defaultTemplates() {
    return [
      WorkoutTemplate(
        name: 'Torso A',
        exercises: [
          ExerciseTemplate(name: 'Press militar mancuernas', sets: 5, targetReps: 8),
          ExerciseTemplate(name: 'Elevaciones laterales', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Press horizontal en maquina', sets: 4, targetReps: 8),
          ExerciseTemplate(name: 'Press inclinado con mancuernas', sets: 3, targetReps: 8),
          ExerciseTemplate(name: 'Remo Hammer', sets: 4, targetReps: 8),
          ExerciseTemplate(name: 'Curl bíceps barra Z', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Extensión tríceps polea alta', sets: 3, targetReps: 10),
        ],
      ),
      WorkoutTemplate(
        name: 'Pierna A',
        exercises: [
          ExerciseTemplate(name: 'Prensa horizontal', sets: 4, targetReps: 6),
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
          ExerciseTemplate(name: 'Elevaciones laterales polea', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Pajaros de pie polea unilateral', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Jalones al pecho', sets: 4, targetReps: 8),
          ExerciseTemplate(name: 'Remo sentado', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Aperturas maquina', sets: 4, targetReps: 12),
          ExerciseTemplate(name: 'Extension triceps encima cabeza polea', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Curl bayesian', sets: 3, targetReps: 10),
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
      WorkoutTemplate(
        name: 'Maigler 3 dias A',
        exercises: [
          ExerciseTemplate(name: 'Jalones al pecho', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Remo hammer', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Press inclinado barra', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Press plano maquina', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Curl barra Z', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Press frances', sets: 3, targetReps: 12),
        ],
      ),
      WorkoutTemplate(
        name: 'Maigler 3 dias B',
        exercises: [
          ExerciseTemplate(name: 'Sentadilla', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Hip Thrust', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Extensión de cuádriceps en máquina', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Gemelos o abductores', sets: 3, targetReps: 15),
          ExerciseTemplate(name: 'Elevaciones laterales mancuerna', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Abs', sets: 3, targetReps: 12),
        ],
      ),
      WorkoutTemplate(
        name: 'Maigler 3 dias C',
        exercises: [
          ExerciseTemplate(name: 'Press banca', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Jalon pecho agarre estrecho', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Prensa inclinada', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Curl femoral', sets: 4, targetReps: 15),
          ExerciseTemplate(name: 'Extension de triceps', sets: 3, targetReps: 8),
          ExerciseTemplate(name: 'Curl de biceps', sets: 3, targetReps: 8),
          ExerciseTemplate(name: 'Abs', sets: 3, targetReps: 8),
        ],
      ),
    ];
  }
  /// Nombres únicos de ejercicios (plantillas + historial)
  List<String> allExerciseNames() {
    final s = <String>{};
    for (final t in templates) {
      for (final e in t.exercises) {
        s.add(e.name);
      }
    }
    for (final ses in sessions) {
      for (final st in ses.sets) {
        s.add(st.exerciseName);
      }
    }
    final list = s.toList()..sort();
    return list;
  }

  /// Muestras recientes de un ejercicio: fecha + set + reps + kg + 1RM estimado
  List<_ExerciseSample> getRecentExerciseSamples(String exerciseName, {int limit = 50}) {
    final samples = <_ExerciseSample>[];
    for (final ses in sessions) {
      for (final st in ses.sets) {
        if (st.exerciseName == exerciseName) {
          final est = _epley1RM(st.reps, st.weight);
          samples.add(_ExerciseSample(
            date: ses.date,
            setIndex: st.setIndex,
            reps: st.reps,
            weight: st.weight,
            est1rm: st.reps > 0 && st.weight > 0 ? est : 0,
            sessionId: ses.id,
          ));
        }
      }
    }
    samples.sort((a, b) => b.date.compareTo(a.date)); // más recientes primero
    if (samples.length > limit) {
      return samples.sublist(0, limit);
    }
    return samples;
  }

  /// Mejor set por carga total (kg*reps)
  _BestSetSummary bestVolumeSet(String exerciseName) {
    double bestVol = 0;
    DateTime? bestDate;
    for (final ses in sessions) {
      for (final st in ses.sets) {
        if (st.exerciseName == exerciseName) {
          final vol = st.weight * st.reps;
          if (vol > bestVol) {
            bestVol = vol;
            bestDate = ses.date;
          }
        }
      }
    }
    return _BestSetSummary(bestVolume: bestVol, date: bestDate);
  }

  /// Promedio reps y kg en las últimas N sesiones donde aparece el ejercicio
  _Averages recentAverages(String exerciseName, {int sessionsCount = 3}) {
    // Tomamos últimas N fechas únicas que contengan el ejercicio
    final perDate = <DateTime, List<SetEntry>>{};
    for (final ses in sessions) {
      final sets = ses.sets.where((st) => st.exerciseName == exerciseName).toList();
      if (sets.isNotEmpty) {
        perDate[ses.date] = sets;
      }
    }
    final dates = perDate.keys.toList()..sort((a, b) => b.compareTo(a));
    final take = dates.take(sessionsCount);

    double repsSum = 0;
    double kgSum = 0;
    int n = 0;

    for (final d in take) {
      final sets = perDate[d]!;
      for (final st in sets) {
        repsSum += st.reps;
        kgSum += st.weight;
        n++;
      }
    }

    return n == 0 ? _Averages(avgReps: 0, avgKg: 0) : _Averages(avgReps: repsSum / n, avgKg: kgSum / n);
  }
}

/// Modelitos internos para el tab de progreso
class _ExerciseSample {
  final DateTime date;
  final int setIndex;
  final int reps;
  final double weight;
  final double est1rm;
  final String sessionId;
  _ExerciseSample({
    required this.date,
    required this.setIndex,
    required this.reps,
    required this.weight,
    required this.est1rm,
    required this.sessionId,
  });
}

class _BestSetSummary {
  final double bestVolume;
  final DateTime? date;
  _BestSetSummary({required this.bestVolume, required this.date});
}

class _Averages {
  final double avgReps;
  final double avgKg;
  _Averages({required this.avgReps, required this.avgKg});
}


