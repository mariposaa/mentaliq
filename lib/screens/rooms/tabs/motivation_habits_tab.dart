import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../models/goal_model.dart';
import '../../../services/goal_service.dart';
import '../../../services/roadmap_generator_service.dart';
import '../../../services/token_service.dart';
import '../../../widgets/token_dialog.dart';

/// Tab 2: Stratejik Yol Haritası - Execution Layer
/// Komuta merkezi. Sohbet yok. AI'ın çizdiği statik ama interaktif plan.
class MotivationHabitsTab extends StatefulWidget {
  const MotivationHabitsTab({super.key});

  @override
  State<MotivationHabitsTab> createState() => _MotivationHabitsTabState();
}

class _MotivationHabitsTabState extends State<MotivationHabitsTab>
    with AutomaticKeepAliveClientMixin {
  
  bool _isLoading = true;
  bool _isGenerating = false;
  GoalModel? _goal;
  GoalRoadmap? _roadmap;
  bool _hasLoadedOnce = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadRoadmap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Her tab'a geçişte tekrar yükle
    if (_hasLoadedOnce && _goal == null) {
      _loadRoadmap();
    }
  }

  Future<void> _loadRoadmap() async {
    if (!_isLoading && _hasLoadedOnce) {
      setState(() => _isLoading = true);
    }
    
    final goal = await GoalService.getActiveGoal();
    
    if (mounted) {
      setState(() {
        _goal = goal;
        _roadmap = goal?.roadmap;
        _isLoading = false;
        _hasLoadedOnce = true;
      });

      // MIGRATION: Eğer eski formatta (tasks boş) bir roadmap varsa, otomatik çevir
      if (_goal != null && _roadmap != null && _roadmap!.steps.isNotEmpty) {
        bool needsUpdate = false;
        final updatedSteps = _roadmap!.steps.map((step) {
          if (step.tasks.isEmpty && step.description.isNotEmpty) {
            needsUpdate = true;
            final taskTitles = step.description.split('\n');
            final tasks = taskTitles.map((title) => GoalTask(
              id: DateTime.now().millisecondsSinceEpoch.toString() + title.hashCode.toString(),
              title: title,
              stepNo: step.stepNo,
              isCompleted: false,
            )).toList();
            return step.copyWith(tasks: tasks);
          }
          return step;
        }).toList();

        if (needsUpdate) {
          final updatedRoadmap = GoalRoadmap(
            steps: updatedSteps,
            generatedAt: _roadmap!.generatedAt,
          );
          // UI can be updated first
          setState(() => _roadmap = updatedRoadmap);
          // Then save to Firebase background
          GoalService.saveRoadmap(_goal!.id, updatedRoadmap);
          debugPrint('Roadmap habits: Auto-migrated old roadmap to new task format');
        }
      }
    }

    // If goal exists but no roadmap, generate one
    if (goal != null && goal.roadmap == null) {
      _generateRoadmap();
    }
  }

  Future<void> _generateRoadmap() async {
    if (_goal == null) return;

    // Token kontrolü
    final hasEnough = await TokenService.hasEnoughTokens();
    if (!hasEnough) {
      if (mounted) {
        final watchedAd = await TokenDialog.show(context);
        if (!watchedAd) return; // Reklam izlenmediyse veya iptal edildiyse dur
      }
    }

    setState(() => _isGenerating = true);

    // Token kullan (5 token)
    await TokenService.useTokensForMessage();

    final roadmap = await RoadmapGeneratorService.generateRoadmap(_goal!);

    if (mounted) {
      setState(() {
        _roadmap = roadmap;
        _isGenerating = false;
      });
      
      // Reload to get updated goal with roadmap
      if (roadmap != null) {
        await _loadRoadmap();
      }
    }
  }

  Future<void> _toggleCompletion(RoadmapStep step) async {
    final newStatus = !step.isCompleted;
    
    // Optimistic UI update
    setState(() {
      final updatedSteps = _roadmap!.steps.map((s) {
        if (s.stepNo == step.stepNo) {
          return RoadmapStep(
            stepNo: s.stepNo,
            title: s.title,
            description: s.description,
            deadline: s.deadline,
            difficulty: s.difficulty,
            isCompleted: newStatus,
          );
        }
        return s;
      }).toList();
      _roadmap = GoalRoadmap(steps: updatedSteps, generatedAt: _roadmap!.generatedAt);
    });

    final success = await GoalService.toggleStepCompletion(step.stepNo, newStatus);
    
    if (!success && mounted) {
      // Revert if failed
      _loadRoadmap();
      _showSnackbar('Durum güncellenirken bir hata oluştu.');
    } else if (success) {
      _showSnackbar(newStatus ? 'Görev tamamlandı! 🎉' : 'Görev geri alındı.');
    }
  }

  Future<void> _toggleTaskCompletion(RoadmapStep step, GoalTask task) async {
    // Migration: Eğer step.tasks boşsa, önce migration yapmamız lazım
    if (step.tasks.isEmpty) {
      final taskTitles = step.description.split('\n').where((t) => t.trim().isNotEmpty).toList();
      final newTasks = taskTitles.map((title) => GoalTask(
        id: DateTime.now().millisecondsSinceEpoch.toString() + title.hashCode.toString(),
        title: title.startsWith('•') || title.startsWith('-') ? title.substring(1).trim() : title.trim(),
        stepNo: step.stepNo,
        isCompleted: false,
      )).toList();
      
      final updatedStep = step.copyWith(tasks: newTasks);
      final updatedSteps = _roadmap!.steps.map((s) => s.stepNo == step.stepNo ? updatedStep : s).toList();
      final updatedRoadmap = GoalRoadmap(steps: updatedSteps, generatedAt: _roadmap!.generatedAt);
      
      setState(() => _roadmap = updatedRoadmap);
      await GoalService.saveRoadmap(_goal!.id, updatedRoadmap);
      
      // Şimdi yeni listeden asıl task'ı bulup devam et
      final newTask = updatedStep.tasks.firstWhere((t) => t.title == task.title, orElse: () => updatedStep.tasks.first);
      _toggleTaskCompletion(updatedStep, newTask);
      return;
    }

    final newStatus = !task.isCompleted;

    // Optimistic UI update
    setState(() {
      final updatedSteps = _roadmap!.steps.map((s) {
        if (s.stepNo == step.stepNo) {
          final updatedTasks = s.tasks.map((t) {
            if (t.id == task.id) {
              return GoalTask(
                id: t.id,
                title: t.title,
                stepNo: t.stepNo,
                isCompleted: newStatus,
              );
            }
            return t;
          }).toList();
          
          final allDone = updatedTasks.every((t) => t.isCompleted);
          return s.copyWith(tasks: updatedTasks, isCompleted: allDone);
        }
        return s;
      }).toList();
      _roadmap = GoalRoadmap(steps: updatedSteps, generatedAt: _roadmap!.generatedAt);
    });

    final success = await GoalService.toggleIndividualTaskCompletion(step.stepNo, task.id, newStatus);
    
    if (!success && mounted) {
      _loadRoadmap();
      _showSnackbar('Güncelleme başarısız oldu.');
    }
  }

  Future<void> _confirmRegenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yol Haritasını Yeniden Oluştur?'),
        content: const Text('Bu işlem mevcut yol haritasını ve tamamlanma durumlarını sıfırlayacaktır. Hedefindeki değişikliklere göre yeni bir plan hazırlansın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9C27B0),
              foregroundColor: Colors.white,
            ),
            child: const Text('Yeniden Oluştur'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _generateRoadmap();
    }
  }

  void _addProgressNote(RoadmapStep step) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProgressNoteSheet(
        step: step,
        onSave: (note) {
          // TODO: Save progress note
          Navigator.pop(context);
          _showSnackbar('Not kaydedildi ✓');
        },
      ),
    );
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF9C27B0),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF9C27B0)),
      );
    }

    // No goal yet - show refresh button
    if (_goal == null) {
      return _buildNoGoalState();
    }

    // Generating roadmap
    if (_isGenerating) {
      return _buildGeneratingState();
    }

    // No roadmap yet
    if (_roadmap == null) {
      return _buildNoRoadmapState();
    }

    // Show timeline
    return _buildTimeline();
  }

  Widget _buildNoGoalState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('⚠️', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Önce hedefini tanımla',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.forestCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yol haritası oluşturmak için "Hedef" sekmesinden hedefini gir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.mutedSage,
              ),
            ),
            const SizedBox(height: 20),
            // Refresh button
            GestureDetector(
              onTap: _loadRoadmap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 18, color: const Color(0xFF9C27B0)),
                    const SizedBox(width: 8),
                    Text(
                      'Yenile',
                      style: TextStyle(
                        color: const Color(0xFF9C27B0),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF9C27B0),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Yol Haritası Oluşturuluyor...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.forestCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hedefine özel strateji planı hazırlanıyor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.mutedSage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRoadmapState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🗺️', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Yol haritası hazır değil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.forestCharcoal,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _generateRoadmap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  '🚀 Yol Haritası Oluştur',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 20),
          
          // Timeline
          ..._roadmap!.steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == _roadmap!.steps.length - 1;
            
            return _buildTimelineItem(step, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF9C27B0).withOpacity(0.1),
            const Color(0xFF7B1FA2).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF9C27B0).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('🗺️', style: TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _goal?.title ?? 'Hedefin',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9C27B0),
                        ),
                      ),
                    ),
                    // Refresh icon button
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF9C27B0)),
                      onPressed: _isGenerating ? null : _confirmRegenerate,
                      tooltip: 'Yol Haritasını Yeniden Oluştur',
                    ),
                  ],
                ),
                Text(
                  '${_roadmap!.steps.length} haftalık program',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mutedSage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(RoadmapStep step, bool isLast) {
    final tasks = step.description.split('\n');
    
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line and dot
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Dot (Tıklanabilir yapıldı)
                GestureDetector(
                  onTap: () => _toggleCompletion(step),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: step.isCompleted 
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF9C27B0),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (step.isCompleted 
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF9C27B0)).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: step.isCompleted
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : Text(
                              '${step.stepNo}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: const Color(0xFF9C27B0).withOpacity(0.2),
                    ),
                  ),
              ],
            ),
          ),
          
          // Content card
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warmCream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.softBorder),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.forestCharcoal,
                          ),
                        ),
                      ),
                      _buildDifficultyBadge(step.difficulty),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Tasks
                  if (step.tasks.isNotEmpty)
                    ...step.tasks.map((task) => _buildIndividualTaskItem(step, task))
                  else
                    ...step.description.split('\n').where((t) => t.trim().isNotEmpty).map((taskTitle) {
                      // Geçici bir GoalTask oluştur (migration öncesi görünüm için)
                      final tempTask = GoalTask(
                        id: taskTitle.hashCode.toString(),
                        title: taskTitle.startsWith('•') || taskTitle.startsWith('-') 
                            ? taskTitle.substring(1).trim() 
                            : taskTitle.trim(),
                        stepNo: step.stepNo,
                        isCompleted: false,
                      );
                      
                      return _buildIndividualTaskItem(step, tempTask);
                    }),
                  
                  const SizedBox(height: 8),
                  
                  // Add note button
                  GestureDetector(
                    onTap: () => _addProgressNote(step),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C27B0).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 16,
                            color: const Color(0xFF9C27B0),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Gelişme Notu Ekle',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF9C27B0),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyBadge(String difficulty) {
    Color color;
    switch (difficulty.toLowerCase()) {
      case 'kolay':
        color = Colors.green;
        break;
      case 'zor':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildIndividualTaskItem(RoadmapStep step, GoalTask task) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _toggleTaskCompletion(step, task),
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: task.isCompleted 
                    ? const Color(0xFF4CAF50) 
                    : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: task.isCompleted 
                      ? const Color(0xFF4CAF50) 
                      : AppTheme.mutedSage.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: task.isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  fontSize: 13,
                  color: task.isCompleted 
                      ? AppTheme.mutedSage 
                      : AppTheme.forestCharcoal,
                  height: 1.4,
                  decoration: task.isCompleted 
                      ? TextDecoration.lineThrough 
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress Note Bottom Sheet
class _ProgressNoteSheet extends StatefulWidget {
  final RoadmapStep step;
  final Function(String) onSave;

  const _ProgressNoteSheet({
    required this.step,
    required this.onSave,
  });

  @override
  State<_ProgressNoteSheet> createState() => _ProgressNoteSheetState();
}

class _ProgressNoteSheetState extends State<_ProgressNoteSheet> {
  final _noteController = TextEditingController();
  String? _selectedMood;

  final List<Map<String, String>> _moods = [
    {'emoji': '😊', 'label': 'Kolaydı'},
    {'emoji': '😐', 'label': 'Normal'},
    {'emoji': '😰', 'label': 'Zorlandım'},
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              'Gelişme Notu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.forestCharcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.step.title,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.mutedSage,
              ),
            ),
            const SizedBox(height: 20),
            
            // Mood selection
            Text(
              'Nasıl hissettin?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.forestCharcoal,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: _moods.map((mood) {
                final isSelected = _selectedMood == mood['emoji'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedMood = mood['emoji']),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? const Color(0xFF9C27B0).withOpacity(0.1)
                            : AppTheme.warmCream,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected 
                              ? const Color(0xFF9C27B0)
                              : AppTheme.softBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(mood['emoji']!, style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text(
                            mood['label']!,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected 
                                  ? const Color(0xFF9C27B0)
                                  : AppTheme.mutedSage,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            
            // Note input
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Kısa bir not düş...',
                hintStyle: TextStyle(color: AppTheme.mutedSage),
                filled: true,
                fillColor: AppTheme.warmCream,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Save button
            GestureDetector(
              onTap: () {
                if (_noteController.text.trim().isNotEmpty || _selectedMood != null) {
                  widget.onSave(_noteController.text.trim());
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Kaydet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
