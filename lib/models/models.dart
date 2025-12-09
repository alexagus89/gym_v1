// lib/models/models.dart


int _uidCounter = 0;
String uid() {
  _uidCounter++;
  return '${DateTime.now().microsecondsSinceEpoch}_$_uidCounter';
}

class ExerciseTemplate {
  String id;
  String name;
  int sets;
  int targetReps;
  ExerciseTemplate({
    String? id,
    required this.name,
    required this.sets,
    required this.targetReps,
  }) : id = id ?? uid();

  factory ExerciseTemplate.fromJson(Map<String, dynamic> j) => ExerciseTemplate(
      id: j['id'], name: j['name'], sets: j['sets'], targetReps: j['targetReps']);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'sets': sets, 'targetReps': targetReps};
}

class WorkoutTemplate {
  String id;
  String name;
  List<ExerciseTemplate> exercises;
  WorkoutTemplate({String? id, required this.name, required this.exercises}) : id = id ?? uid();

  factory WorkoutTemplate.fromJson(Map<String, dynamic> j) => WorkoutTemplate(
    id: j['id'],
    name: j['name'],
    exercises: (j['exercises'] as List).map((e) => ExerciseTemplate.fromJson(e)).toList(),
  );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'exercises': exercises.map((e) => e.toJson()).toList()};
}

class SetEntry {
  String id;
  String exerciseName;
  int setIndex;
  double reps;
  double weight;
  int targetReps;
  bool done;
  double rir;
  SetEntry({
    String? id,
    required this.exerciseName,
    required this.setIndex,
    required this.reps,
    required this.weight,
    required this.targetReps,
    this.done = false,
    this.rir = 0,
  }) : id = id ?? uid();

  factory SetEntry.fromJson(Map<String, dynamic> j) => SetEntry(
    id: j['id'],
    exerciseName: j['exerciseName'],
    setIndex: j['setIndex'],
    reps: (j['reps'] as num).toDouble(),
    weight: (j['weight'] as num).toDouble(),
    targetReps: j['targetReps'],
    done: j['done'] ?? false,
    rir: (j['rir'] as num?)?.toDouble() ?? 10.0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseName': exerciseName,
    'setIndex': setIndex,
    'reps': reps,
    'weight': weight,
    'targetReps': targetReps,
    'done': done,
    'rir': rir,
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

  String targetRepsFromJson(dynamic v) {
    if (v == null) return '';
    if (v is int || v is double) return v.toString();
    return v.toString();
  }

  double get totalVolume => sets.fold(0, (p, s) => p + (s.weight * s.reps.toDouble()));
  double get totalReps => sets.fold(0, (p, s) => p + s.reps);

  factory SessionData.fromJson(Map<String, dynamic> j) => SessionData(
    id: j['id'],
    date: DateTime.parse(j['date']),
    templateId: j['templateId'],
    templateName: j['templateName'],
    sets: (j['sets'] as List).map((e) => SetEntry.fromJson(e)).toList(),
    notes: j['notes'] ?? '',
  );
  Map<String, dynamic> toJson() => {
    'id': id, 'date': date.toIso8601String(), 'templateId': templateId,
    'templateName': templateName, 'sets': sets.map((e) => e.toJson()).toList(), 'notes': notes,
  };
}
