// lib/services/goal_service.dart
// Motivasyon Modülü - Hedef Servisi

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/goal_model.dart';
import 'auth_service.dart';
import 'user_dna_service.dart';
import '../models/user_dna_model.dart';

/// Goal Service - Hedef CRUD işlemleri
class GoalService {
  static GoalModel? _currentGoal;
  static const _uuid = Uuid();

  /// Get current goal (cached)
  static GoalModel? get currentGoal => _currentGoal;

  /// Get user's active goal from Firebase
  static Future<GoalModel?> getActiveGoal() async {
    try {
      final uid = AuthService.userId;
      if (uid == null) {
        debugPrint('GoalService: No user ID');
        return null;
      }

      debugPrint('GoalService: Getting goals for user: $uid');

      final querySnapshot = await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection('goals')
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('GoalService: No goals found');
        _currentGoal = null;
        return null;
      }

      _currentGoal = GoalModel.fromFirestore(querySnapshot.docs.first);
      debugPrint('GoalService: Loaded goal: ${_currentGoal?.title}');
      return _currentGoal;
    } catch (e) {
      debugPrint('GoalService: Error getting active goal: $e');
      return null;
    }
  }

  /// Create new goal (Tab 1)
  static Future<GoalModel?> createGoal({
    required String title,
    required String currentStatus,
    required int dailyHours,
    String? skills,
    String? specialNotes,
  }) async {
    try {
      final uid = AuthService.userId;
      if (uid == null) {
        debugPrint('GoalService: Cannot create goal - no user ID');
        return null;
      }

      debugPrint('GoalService: Creating goal for user: $uid');
      debugPrint('GoalService: Title: $title, Status: $currentStatus, Hours: $dailyHours');

      final goalId = _uuid.v4();
      final now = DateTime.now();

      final goal = GoalModel(
        id: goalId,
        title: title,
        currentStatus: currentStatus,
        dailyHours: dailyHours,
        skills: skills,
        specialNotes: specialNotes,
        createdAt: now,
        updatedAt: now,
      );

      debugPrint('GoalService: Saving to Firebase...');
      
      // Save to Firebase
      await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection('goals')
          .doc(goalId)
          .set(goal.toFirestoreBasic());

      debugPrint('GoalService: Goal saved to Firebase ✓');

      // Update UserDNA with goal info (don't fail if this fails)
      try {
        await _updateUserDNAWithGoal(goal);
      } catch (e) {
        debugPrint('GoalService: UserDNA update failed (non-critical): $e');
      }

      _currentGoal = goal;
      debugPrint('GoalService: Goal created successfully: $goalId');
      return goal;
    } catch (e) {
      debugPrint('GoalService: Error creating goal: $e');
      debugPrint('GoalService: Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Update goal
  static Future<bool> updateGoal(GoalModel goal) async {
    try {
      final uid = AuthService.userId;
      if (uid == null) return false;

      await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection('goals')
          .doc(goal.id)
          .update(goal.toFirestore());

      _currentGoal = goal;
      debugPrint('GoalService: Goal updated: ${goal.id}');
      return true;
    } catch (e) {
      debugPrint('GoalService: Error updating goal: $e');
      return false;
    }
  }

  /// Save roadmap to goal (Tab 2)
  static Future<bool> saveRoadmap(String goalId, GoalRoadmap roadmap) async {
    try {
      final uid = AuthService.userId;
      if (uid == null) return false;

      await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection('goals')
          .doc(goalId)
          .update({
            'roadmap': roadmap.toJson(),
            'updated_at': Timestamp.now(),
          });

      // Update cached goal
      if (_currentGoal?.id == goalId) {
        _currentGoal = _currentGoal!.copyWith(roadmap: roadmap);
      }

      debugPrint('GoalService: Roadmap saved for goal: $goalId');
      return true;
    } catch (e) {
      debugPrint('GoalService: Error saving roadmap: $e');
      return false;
    }
  }

  /// Toggle step completion status (Tab 2)
  static Future<bool> toggleStepCompletion(int stepNo, bool isCompleted) async {
    try {
      if (_currentGoal == null || _currentGoal!.roadmap == null) {
        debugPrint('GoalService: No goal or roadmap to update');
        return false;
      }

      final uid = AuthService.userId;
      if (uid == null) return false;

      // Update the step in the roadmap
      final updatedSteps = _currentGoal!.roadmap!.steps.map((step) {
        if (step.stepNo == stepNo) {
          return RoadmapStep(
            stepNo: step.stepNo,
            title: step.title,
            description: step.description,
            deadline: step.deadline,
            difficulty: step.difficulty,
            isCompleted: isCompleted,
          );
        }
        return step;
      }).toList();

      final updatedRoadmap = GoalRoadmap(
        steps: updatedSteps,
        generatedAt: _currentGoal!.roadmap!.generatedAt,
      );

      // Save to Firebase
      await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection('goals')
          .doc(_currentGoal!.id)
          .update({
            'roadmap': updatedRoadmap.toJson(),
            'updated_at': Timestamp.now(),
          });

      // Update cache
      _currentGoal = _currentGoal!.copyWith(roadmap: updatedRoadmap);

      debugPrint('GoalService: Step $stepNo completion toggled to $isCompleted');
      return true;
    } catch (e) {
      debugPrint('GoalService: Error toggling step completion: $e');
      return false;
    }
  }

  /// Toggle individual task completion within a step (Tab 2)
  static Future<bool> toggleIndividualTaskCompletion(int stepNo, String taskId, bool isCompleted) async {
    try {
      if (_currentGoal == null || _currentGoal!.roadmap == null) {
        return false;
      }

      final uid = AuthService.userId;
      if (uid == null) return false;

      // Update the roadmap steps
      final updatedSteps = _currentGoal!.roadmap!.steps.map((step) {
        if (step.stepNo == stepNo) {
          // Update the specific task within the step
          final updatedTasks = step.tasks.map((task) {
            if (task.id == taskId) {
              return GoalTask(
                id: task.id,
                title: task.title,
                stepNo: task.stepNo,
                isCompleted: isCompleted,
                dueDate: task.dueDate,
              );
            }
            return task;
          }).toList();

          // Also check if ALL tasks are completed to mark the step as completed
          final allTasksCompleted = updatedTasks.every((t) => t.isCompleted);

          return step.copyWith(
            tasks: updatedTasks,
            isCompleted: allTasksCompleted,
          );
        }
        return step;
      }).toList();

      final updatedRoadmap = GoalRoadmap(
        steps: updatedSteps,
        generatedAt: _currentGoal!.roadmap!.generatedAt,
      );

      // Save to Firebase
      await AuthService.firestore
          .collection('users')
          .doc(uid)
          .collection('goals')
          .doc(_currentGoal!.id)
          .update({
            'roadmap': updatedRoadmap.toJson(),
            'updated_at': Timestamp.now(),
          });

      // Update cache
      _currentGoal = _currentGoal!.copyWith(roadmap: updatedRoadmap);

      debugPrint('GoalService: Task $taskId toggled to $isCompleted');
      return true;
    } catch (e) {
      debugPrint('GoalService: Error toggling individual task: $e');
      return false;
    }
  }

  /// Get goal context for AI (used in roadmap generation)
  static String getGoalContextForAI(GoalModel goal) {
    final buffer = StringBuffer();
    
    buffer.writeln('### HEDEF BİLGİLERİ:');
    buffer.writeln('Ana Hedef: ${goal.title}');
    buffer.writeln('Mevcut Durum: ${goal.currentStatus}');
    buffer.writeln('Günlük Ayrılabilecek Süre: ${goal.dailyHours} saat');
    
    if (goal.skills != null && goal.skills!.isNotEmpty) {
      buffer.writeln('Kullanıcının Yetenekleri: ${goal.skills}');
    }

    if (goal.specialNotes != null && goal.specialNotes!.isNotEmpty) {
      buffer.writeln('Özel Notlar/Kısıtlar: ${goal.specialNotes}');
    }
    
    return buffer.toString();
  }

  /// Update UserDNA with goal information
  static Future<void> _updateUserDNAWithGoal(GoalModel goal) async {
    try {
      // Extract profession from currentStatus if available
      final dnaUpdate = UserDNAModel(
        profession: goal.currentStatus.isNotEmpty ? goal.currentStatus : null,
        lifeStage: 'hedef odaklı',
      );
      
      await UserDNAService.updateDNA(dnaUpdate);
      debugPrint('GoalService: UserDNA updated with goal info');
    } catch (e) {
      debugPrint('GoalService: Error updating UserDNA: $e');
    }
  }

  /// Get pre-fill data from UserDNA
  static Future<Map<String, dynamic>> getPreFillData() async {
    try {
      final dna = await UserDNAService.getDNA();
      if (dna == null) return {};

      return {
        'currentStatus': dna.profession ?? '',
        'age': dna.age,
      };
    } catch (e) {
      debugPrint('GoalService: Error getting pre-fill data: $e');
      return {};
    }
  }

  /// Check if user has an active goal
  static Future<bool> hasActiveGoal() async {
    final goal = await getActiveGoal();
    return goal != null;
  }

  /// Clear cache
  static void clearCache() {
    _currentGoal = null;
  }
}
