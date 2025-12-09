// lib/state/app_state.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import '../models/models.dart';

String normalizeExerciseKey(String input) {
  const Map<String, String> map = {
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

  input = input.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final codeUnit in input.runes) {
    final ch = String.fromCharCode(codeUnit);
    buffer.write(map[ch] ?? ch);
  }
  return buffer.toString();
}

bool sameExerciseName(String a, String b) =>
    normalizeExerciseKey(a) == normalizeExerciseKey(b);

class AppState extends ChangeNotifier {
  // ⬇️ Subimos la clave de plantillas para garantizar que coja los nuevos defaults
  static const _kTemplates = 'gymlog.templates.v6'; // antes v5
  static const _kSessions  = 'gymlog.sessions.v5';

  // Control de versión del "seed" de plantillas: súbelo cuando cambies _defaultTemplates()
  static const _kTemplatesSeedVersionKey = 'gymlog.templates.seed_version';
  static const int kTemplatesSeedVersion = 3;

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
  double _epley1RM(double reps, double weight) =>
      reps <= 1 ? weight : weight * (1 + reps / 30.0);

  /// RM máximo histórico (estimado) para un ejercicio (ignorando tildes)
  double best1RMFor(String exerciseName) {
    double best = 0;
    final key = normalizeExerciseKey(exerciseName);

    for (final s in sessions) {
      for (final st in s.sets) {
        if (normalizeExerciseKey(st.exerciseName) == key &&
            st.reps > 0 &&
            st.weight > 0) {
          final est = _epley1RM(st.reps, st.weight);
          if (est > best) best = est;
        }
      }
    }
    return best;
  }

  /// Peso máximo histórico (carga absoluta en kg) para un ejercicio (ignorando tildes)
  double bestWeightFor(String exerciseName) {
    double best = 0;
    final key = normalizeExerciseKey(exerciseName);

    for (final s in sessions) {
      for (final st in s.sets) {
        if (normalizeExerciseKey(st.exerciseName) == key &&
            st.weight > 0) {
          if (st.weight > best) best = st.weight;
        }
      }
    }
    return best;
  }

  /// 🔥 Últimas mejores marcas (con fecha) para un ejercicio (ignorando tildes)
  List<BestMark> recentBestMarksFor(String exerciseName, {int limit = 5}) {
    final exKey = normalizeExerciseKey(exerciseName);
    if (exKey.isEmpty) return const <BestMark>[];

    final marks = <BestMark>[];

    for (final ses in sessions) {
      for (final st in ses.sets) {
        if (normalizeExerciseKey(st.exerciseName) != exKey) continue;
        if (st.reps > 0 && st.weight > 0) {
          final est1rm = _epley1RM(st.reps, st.weight);
          marks.add(
            BestMark(
              date: ses.date,
              weight: st.weight,
              reps: st.reps,
              est1RM: est1rm,
            ),
          );
        }
      }
    }

    // Orden preliminar por 1RM desc
    marks.sort((a, b) => b.est1RM.compareTo(a.est1RM));

    // Elimina duplicados por misma fecha y mismo 1RM (±0.1)
    final unique = <String, BestMark>{};
    for (final m in marks) {
      final key = '${m.date.year}-${m.date.month}-${m.date.day}-${m.est1RM.toStringAsFixed(1)}';
      unique.putIfAbsent(key, () => m);
    }

    // Ahora ordena por fecha reciente y limita
    final result = unique.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return result.take(limit).toList();
  }

  /// Último set para un ejercicio/índice (ignorando tildes)
  SetEntry? lastSetFor(String exerciseName, int setIndex) {
    for (final s in sessions) {
      for (final st in s.sets) {
        if (sameExerciseName(st.exerciseName, exerciseName) &&
            st.setIndex == setIndex) {
          return st;
        }
      }
    }
    return null;
  }

  // --- Mutaciones ---
  Future<void> addTemplate(WorkoutTemplate t) async {
    templates.add(t);
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

  /*Future<void> resetAll() async {
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
*/
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
      WorkoutTemplate(
        name: 'Día A – Empuje',
        exercises: [
          ExerciseTemplate(name: 'Press banca', sets: 4, targetReps: 8),
          ExerciseTemplate(name: 'Press inclinado mancuernas', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Press militar mancuernas', sets: 3, targetReps: 8),
          ExerciseTemplate(name: 'Elevaciones laterales', sets: 3, targetReps: 15),
          ExerciseTemplate(name: 'Press francés / polea tríceps', sets: 3, targetReps: 12),
        ],
      ),
      WorkoutTemplate(
        name: 'Día B – Pierna (Cuádriceps) + Hombros',
        exercises: [
          ExerciseTemplate(name: 'Sentadilla', sets: 3, targetReps: 8),
          ExerciseTemplate(name: 'Prensa de piernas', sets: 4, targetReps: 10),
          ExerciseTemplate(name: 'Sentadilla búlgara', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Extensión de piernas', sets: 3, targetReps: 15),
          ExerciseTemplate(name: 'Pájaros unilateral', sets: 3, targetReps: 15),
          ExerciseTemplate(name: 'Elevaciones laterales cable', sets: 3, targetReps: 12),
        ],
      ),
      WorkoutTemplate(
        name: 'Día C – Tirón',
        exercises: [
          ExerciseTemplate(name: 'Dominadas / Jalón al pecho', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Remo en polea o mancuerna', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Pájaros unilateral', sets: 3, targetReps: 15),
          ExerciseTemplate(name: 'Curl bíceps barra', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Curl bayesian', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Crunch cable + plancha', sets: 3, targetReps: 15),
        ],
      ),
      WorkoutTemplate(
        name: 'Día 1 – Empuje',
        exercises: [
          ExerciseTemplate(name: 'Press militar mancuernas', sets: 3, targetReps: 8),
          ExerciseTemplate(name: 'Press banca', sets: 4, targetReps: 8),
          ExerciseTemplate(name: 'Press inclinado mancuernas', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Aperturas maquina', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Press francés / polea tríceps', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Abs', sets: 3, targetReps: 12),
        ],
      ),
      WorkoutTemplate(
        name: 'Día 2 – Pierna (Cuádriceps) + Hombros',
        exercises: [
          ExerciseTemplate(name: 'Sentadilla', sets: 3, targetReps: 8),
          ExerciseTemplate(name: 'Prensa de piernas', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Extensión de piernas', sets: 3, targetReps: 15),
          ExerciseTemplate(name: 'Elevaciones laterales mancuerna', sets: 3, targetReps: 12),
        ],
      ),
      WorkoutTemplate(
        name: 'Día 3 – Tirón',
        exercises: [
          ExerciseTemplate(name: 'Dominadas / Jalón al pecho', sets: 5, targetReps: 8),
          ExerciseTemplate(name: 'Remo hammer', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Pull over unilateral polea alta', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Pájaros unilateral polea', sets: 3, targetReps: 15),
          ExerciseTemplate(name: 'Curl bíceps barra z', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Abs', sets: 3, targetReps: 15),
        ],
      ),
      WorkoutTemplate(
        name: 'Día 4 – Pierna (Femorales, Glúteos, Gemelos)',
        exercises: [
          ExerciseTemplate(name: 'Peso muerto rumano', sets: 3, targetReps: 8),
          ExerciseTemplate(name: 'Sentadilla bulgara (gluteos)', sets: 3, targetReps: 10),
          ExerciseTemplate(name: 'Curl de piernas', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Abducción máquina', sets: 3, targetReps: 15),
          ExerciseTemplate(name: 'Elevaciones laterales polea', sets: 3, targetReps: 12),
          ExerciseTemplate(name: 'Gemelos', sets: 3, targetReps: 15),
        ],
      ),
    ];
  }

  /// Nombres únicos de ejercicios (plantillas + historial), sin duplicar por tildes
  List<String> allExerciseNames() {
    // clave normalizada -> nombre que mostraremos en UI
    final Map<String, String> map = {};

    // De plantillas
    for (final t in templates) {
      for (final e in t.exercises) {
        final key = normalizeExerciseKey(e.name);
        map.putIfAbsent(key, () => e.name);
      }
    }

    // De sesiones
    for (final ses in sessions) {
      for (final st in ses.sets) {
        final key = normalizeExerciseKey(st.exerciseName);
        map.putIfAbsent(key, () => st.exerciseName);
      }
    }

    final list = map.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// Muestras recientes de un ejercicio: fecha + set + reps + kg + 1RM estimado
  /// (agrupar por nombre de ejercicio ignorando tildes)
  List<_ExerciseSample> getRecentExerciseSamples(String exerciseName, {int limit = 50}) {
    final key = normalizeExerciseKey(exerciseName);
    final samples = <_ExerciseSample>[];

    for (final ses in sessions) {
      for (final st in ses.sets) {
        if (normalizeExerciseKey(st.exerciseName) != key) continue;
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

    samples.sort((a, b) => b.date.compareTo(a.date)); // más recientes primero
    if (samples.length > limit) {
      return samples.sublist(0, limit);
    }
    return samples;
  }

  /// Mejor set por carga total (kg*reps), ignorando tildes
  _BestSetSummary bestVolumeSet(String exerciseName) {
    final key = normalizeExerciseKey(exerciseName);
    double bestVol = 0;
    DateTime? bestDate;

    for (final ses in sessions) {
      for (final st in ses.sets) {
        if (normalizeExerciseKey(st.exerciseName) != key) continue;
        final vol = st.weight * st.reps;
        if (vol > bestVol) {
          bestVol = vol;
          bestDate = ses.date;
        }
      }
    }
    return _BestSetSummary(bestVolume: bestVol, date: bestDate);
  }

  /// Promedio reps y kg en las últimas N sesiones donde aparece el ejercicio
  /// (ignorando tildes)
  _Averages recentAverages(String exerciseName, {int sessionsCount = 3}) {
    final key = normalizeExerciseKey(exerciseName);

    // Tomamos últimas N fechas únicas que contengan el ejercicio
    final perDate = <DateTime, List<SetEntry>>{};
    for (final ses in sessions) {
      final sets = ses.sets
          .where((st) => normalizeExerciseKey(st.exerciseName) == key)
          .toList();
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

    return n == 0
        ? _Averages(avgReps: 0, avgKg: 0)
        : _Averages(avgReps: repsSum / n, avgKg: kgSum / n);
  }
}

/// ======= Modelos auxiliares =======

/// Público: Marca personal para mostrar en UI
class BestMark {
  final DateTime date;
  final double weight;
  final double reps;
  final double est1RM;
  const BestMark({
    required this.date,
    required this.weight,
    required this.reps,
    required this.est1RM,
  });
}

/// Internos para el tab de progreso (si los usas)
class _ExerciseSample {
  final DateTime date;
  final int setIndex;
  final double reps;
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
