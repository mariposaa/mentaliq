// lib/models/goal_model.dart
// Motivasyon Modülü - Hedef Veri Modeli

import 'package:cloud_firestore/cloud_firestore.dart';

/// Goal Model - Kullanıcının kişisel gelişim hedefi
class GoalModel {
  final String id;
  final String title;           // Ana hedef
  final String currentStatus;   // Mevcut durum/meslek
  final int dailyHours;         // Günlük ayrılabilecek saat
  final String? skills;         // Yetenekler/Deneyimler
  final String? specialNotes;   // Özel notlar/kısıtlar
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Tab 2: Yol Haritası
  final GoalRoadmap? roadmap;
  
  // Tab 3: Gelecek Dizisi (Future Series)
  final DreamSeries? series;
  
  // Tab 3: Gelişme Notları
  final List<ProgressLog>? progressLogs;
  
  // Tab 4: Analiz
  final GoalAnalysis? analysis;

  GoalModel({
    required this.id,
    required this.title,
    required this.currentStatus,
    required this.dailyHours,
    this.skills,
    this.specialNotes,
    required this.createdAt,
    required this.updatedAt,
    this.roadmap,
    this.series,
    this.progressLogs,
    this.analysis,
  });

  /// Firebase'den parse et
  factory GoalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return GoalModel(
      id: doc.id,
      title: data['title'] ?? '',
      currentStatus: data['current_status'] ?? '',
      dailyHours: data['daily_hours'] ?? 2,
      skills: data['skills'],
      specialNotes: data['special_notes'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      roadmap: data['roadmap'] != null 
          ? GoalRoadmap.fromJson(data['roadmap']) 
          : null,
      series: data['series'] != null 
          ? DreamSeries.fromJson(data['series']) 
          : null,
      progressLogs: (data['progress_logs'] as List<dynamic>?)
          ?.map((l) => ProgressLog.fromJson(l))
          .toList(),
      analysis: data['analysis'] != null 
          ? GoalAnalysis.fromJson(data['analysis']) 
          : null,
    );
  }

  /// Firebase'e kaydet (Tab 1 verileri)
  Map<String, dynamic> toFirestoreBasic() {
    return {
      'title': title,
      'current_status': currentStatus,
      'daily_hours': dailyHours,
      'skills': skills,
      'special_notes': specialNotes,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(DateTime.now()),
    };
  }

  /// Tüm veriyi Firebase'e kaydet
  Map<String, dynamic> toFirestore() {
    return {
      ...toFirestoreBasic(),
      if (roadmap != null) 'roadmap': roadmap!.toJson(),
      if (series != null) 'series': series!.toJson(),
      if (progressLogs != null) 'progress_logs': progressLogs!.map((l) => l.toJson()).toList(),
      if (analysis != null) 'analysis': analysis!.toJson(),
    };
  }

  GoalModel copyWith({
    String? title,
    String? currentStatus,
    int? dailyHours,
    String? skills,
    String? specialNotes,
    GoalRoadmap? roadmap,
    DreamSeries? series,
    List<ProgressLog>? progressLogs,
    GoalAnalysis? analysis,
  }) {
    return GoalModel(
      id: id,
      title: title ?? this.title,
      currentStatus: currentStatus ?? this.currentStatus,
      dailyHours: dailyHours ?? this.dailyHours,
      skills: skills ?? this.skills,
      specialNotes: specialNotes ?? this.specialNotes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      roadmap: roadmap ?? this.roadmap,
      series: series ?? this.series,
      progressLogs: progressLogs ?? this.progressLogs,
      analysis: analysis ?? this.analysis,
    );
  }
}

/// Tab 3: Gelecek Dizisi (Dream Series)
class DreamSeries {
  final List<DreamEpisode> episodes;
  final int currentEpisodeIndex;
  final Map<int, String> userInputs;

  DreamSeries({
    required this.episodes,
    this.currentEpisodeIndex = 0,
    this.userInputs = const {},
  });

  factory DreamSeries.fromJson(Map<String, dynamic> json) {
    return DreamSeries(
      episodes: (json['episodes'] as List<dynamic>?)
          ?.map((e) => DreamEpisode.fromJson(e))
          .toList() ?? [],
      currentEpisodeIndex: json['current_episode_index'] ?? 0,
      userInputs: (json['user_inputs'] as Map<String, dynamic>?)
          ?.map((key, value) => MapEntry(int.parse(key), value.toString())) ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'episodes': episodes.map((e) => e.toJson()).toList(),
    'current_episode_index': currentEpisodeIndex,
    'user_inputs': userInputs.map((key, value) => MapEntry(key.toString(), value)),
  };

  DreamSeries copyWith({
    List<DreamEpisode>? episodes,
    int? currentEpisodeIndex,
    Map<int, String>? userInputs,
  }) {
    return DreamSeries(
      episodes: episodes ?? this.episodes,
      currentEpisodeIndex: currentEpisodeIndex ?? this.currentEpisodeIndex,
      userInputs: userInputs ?? this.userInputs,
    );
  }
}

/// Gelecek Dizisi Bölümü
class DreamEpisode {
  final int index;
  final String title;
  final String storyText;
  final String? question;
  final bool isUnlocked;
  final String? timeJump;

  DreamEpisode({
    required this.index,
    required this.title,
    required this.storyText,
    this.question,
    this.isUnlocked = false,
    this.timeJump,
  });

  factory DreamEpisode.fromJson(Map<String, dynamic> json) {
    return DreamEpisode(
      index: json['index'] ?? 0,
      title: json['title'] ?? '',
      storyText: json['story_text'] ?? '',
      question: json['question'],
      isUnlocked: json['is_unlocked'] ?? false,
      timeJump: json['time_jump'],
    );
  }

  Map<String, dynamic> toJson() => {
    'index': index,
    'title': title,
    'story_text': storyText,
    'question': question,
    'is_unlocked': isUnlocked,
    'time_jump': timeJump,
  };
}

/// Tab 2: Yol Haritası
class GoalRoadmap {
  final List<RoadmapStep> steps;
  final DateTime generatedAt;

  GoalRoadmap({required this.steps, required this.generatedAt});

  factory GoalRoadmap.fromJson(Map<String, dynamic> json) {
    return GoalRoadmap(
      steps: (json['steps'] as List<dynamic>?)
          ?.map((s) => RoadmapStep.fromJson(s))
          .toList() ?? [],
      generatedAt: json['generated_at'] != null
          ? (json['generated_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'steps': steps.map((s) => s.toJson()).toList(),
    'generated_at': Timestamp.fromDate(generatedAt),
  };
}

/// Yol haritası adımı
class RoadmapStep {
  final int stepNo;
  final String title;
  final String description;
  final String deadline;     // "1 hafta", "2 hafta" gibi
  final String difficulty;   // "Kolay", "Orta", "Zor"
  final bool isCompleted;
  final List<GoalTask> tasks; // Bireysel görevler

  RoadmapStep({
    required this.stepNo,
    required this.title,
    required this.description,
    required this.deadline,
    required this.difficulty,
    this.isCompleted = false,
    this.tasks = const [],
  });

  factory RoadmapStep.fromJson(Map<String, dynamic> json) {
    return RoadmapStep(
      stepNo: json['step_no'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      deadline: json['deadline'] ?? '',
      difficulty: json['difficulty'] ?? 'Orta',
      isCompleted: json['is_completed'] ?? false,
      tasks: (json['tasks'] as List<dynamic>?)
          ?.map((t) => GoalTask.fromJson(t))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'step_no': stepNo,
    'title': title,
    'description': description,
    'deadline': deadline,
    'difficulty': difficulty,
    'is_completed': isCompleted,
    'tasks': tasks.map((t) => t.toJson()).toList(),
  };

  RoadmapStep copyWith({
    bool? isCompleted,
    List<GoalTask>? tasks,
  }) {
    return RoadmapStep(
      stepNo: stepNo,
      title: title,
      description: description,
      deadline: deadline,
      difficulty: difficulty,
      isCompleted: isCompleted ?? this.isCompleted,
      tasks: tasks ?? this.tasks,
    );
  }
}

/// Tab 3: Görev
class GoalTask {
  final String id;
  final String title;
  final int stepNo;          // Hangi adıma ait
  final bool isCompleted;
  final DateTime? dueDate;

  GoalTask({
    required this.id,
    required this.title,
    required this.stepNo,
    this.isCompleted = false,
    this.dueDate,
  });

  factory GoalTask.fromJson(Map<String, dynamic> json) {
    return GoalTask(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      stepNo: json['step_no'] ?? 0,
      isCompleted: json['is_completed'] ?? false,
      dueDate: json['due_date'] != null
          ? (json['due_date'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'step_no': stepNo,
    'is_completed': isCompleted,
    if (dueDate != null) 'due_date': Timestamp.fromDate(dueDate!),
  };
}

/// Tab 3: Gelişme Notu
class ProgressLog {
  final String id;
  final String note;
  final DateTime date;
  final String? mood;  // 😊, 😐, 😔

  ProgressLog({
    required this.id,
    required this.note,
    required this.date,
    this.mood,
  });

  factory ProgressLog.fromJson(Map<String, dynamic> json) {
    return ProgressLog(
      id: json['id'] ?? '',
      note: json['note'] ?? '',
      date: json['date'] != null
          ? (json['date'] as Timestamp).toDate()
          : DateTime.now(),
      mood: json['mood'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'note': note,
    'date': Timestamp.fromDate(date),
    if (mood != null) 'mood': mood,
  };
}

/// Tab 4: Analiz
class GoalAnalysis {
  final int successRate;      // 0-100
  final String aiComment;
  final DateTime lastUpdatedAt;

  GoalAnalysis({
    required this.successRate,
    required this.aiComment,
    required this.lastUpdatedAt,
  });

  factory GoalAnalysis.fromJson(Map<String, dynamic> json) {
    return GoalAnalysis(
      successRate: json['success_rate'] ?? 0,
      aiComment: json['ai_comment'] ?? '',
      lastUpdatedAt: json['last_updated_at'] != null
          ? (json['last_updated_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'success_rate': successRate,
    'ai_comment': aiComment,
    'last_updated_at': Timestamp.fromDate(lastUpdatedAt),
  };
}
