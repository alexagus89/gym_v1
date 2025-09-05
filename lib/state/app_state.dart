// lib/state/app_state.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import '../models/models.dart';

class AppState extends ChangeNotifier {
  static const _kTemplates = 'gymlog.templates.v5';
  static const _kSessions  = 'gymlog.sessions.v5';

  final List<WorkoutTemplate> templates = [];
  final List<SessionData> sessions = [];

  AppState() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final tRaw = prefs.getString(_kTemplates);
    final sRaw = prefs.getString(_kSessions);

    if (tRaw == null) {
      templates..clear()..addAll(_defaultTemplates());
      await prefs.setString(_kTemplates, jsonEncode(templates.map((e) => e.toJson()).toList()));
    } else {
      templates..clear()..addAll(((jsonDecode(tRaw) as List).map((e) => WorkoutTemplate.fromJson(e))));
    }
    if (sRaw != null) {
      sessions..clear()..addAll(((jsonDecode(sRaw) as List).map((e) => SessionData.fromJson(e))));
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
  Future<File> exportTemplatesCsv() async {
    final rows = <List<dynamic>>[
      ['template_id','template_name','exercise_id','exercise_name','sets','target_reps'],
    ];
    for (final t in templates) {
      for (final e in t.exercises) { rows.add([t.id,t.name,e.id,e.name,e.sets,e.targetReps]); }
    }
    return _writeCsv(rows, 'templates.csv');
  }
  Future<File> exportSessionsCsv() async {
    final rows = <List<dynamic>>[
      ['session_id','date_iso','template_id','template_name','set_id','exercise_name','set_index','reps','weight_kg','target_reps','done','notes'],
    ];
    for (final s in sessions) {
      for (final st in s.sets) {
        rows.add([s.id,s.date.toIso8601String(),s.templateId,s.templateName,st.id,st.exerciseName,st.setIndex,st.reps,st.weight,st.targetReps,st.done,s.notes]);
      }
    }
    return _writeCsv(rows, 'sessions.csv');
  }
  Future<List<String>> exportAllCsv() async {
    final t = await exportTemplatesCsv();
    final s = await exportSessionsCsv();
    return [t.path, s.path];
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTemplates, jsonEncode(templates.map((e) => e.toJson()).toList()));
    await prefs.setString(_kSessions,  jsonEncode(sessions.map((e) => e.toJson()).toList()));
  }

  // --- PR & prefill ---
  double _epley1RM(int reps, double weight) => reps <= 1 ? weight : weight * (1 + reps / 30.0);
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
        if (st.exerciseName == exerciseName && st.setIndex == setIndex) return st;
      }
    }
    return null;
  }

  // --- Mutaciones ---
  Future<void> addTemplate(WorkoutTemplate t) async { templates.insert(0, t); await _persist(); notifyListeners(); }
  Future<void> updateTemplate(WorkoutTemplate t) async {
    final idx = templates.indexWhere((x) => x.id == t.id);
    if (idx >= 0) templates[idx] = t;
    await _persist(); notifyListeners();
  }
  Future<void> removeTemplate(String id) async { templates.removeWhere((e) => e.id == id); await _persist(); notifyListeners(); }

  Future<void> addSession(SessionData s) async {
    final i = sessions.indexWhere((x) => x.id == s.id);
    if (i >= 0) sessions[i] = s; else sessions.insert(0, s);
    await _persist(); notifyListeners();
  }
  Future<void> removeSession(String id) async { sessions.removeWhere((e) => e.id == id); await _persist(); notifyListeners(); }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTemplates); await prefs.remove(_kSessions);
    templates..clear()..addAll(_defaultTemplates());
    sessions.clear();
    await _persist(); notifyListeners();
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
    ];
  }
}
