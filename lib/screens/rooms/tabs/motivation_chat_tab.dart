import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_theme.dart';
import '../../../l10n/app_translations.dart';
import '../../../models/goal_model.dart';
import '../../../services/goal_service.dart';
import '../../../services/dream_series_service.dart';
import '../../../services/token_service.dart';
import '../../../widgets/token_dialog.dart';
import '../../../services/shadow_memory_service.dart';

/// Tab 3: Gelecek Dizisi - Future Series
/// Kullanıcının hedefine ulaştığı sahneleri (bölümleri) içeren hikaye akışı.
class MotivationChatTab extends StatefulWidget {
  const MotivationChatTab({super.key});

  @override
  State<MotivationChatTab> createState() => _MotivationChatTabState();
}

class _MotivationChatTabState extends State<MotivationChatTab>
    with AutomaticKeepAliveClientMixin {
  
  bool _isLoading = true;
  bool _isGenerating = false;
  GoalModel? _goal;
  final TextEditingController _inputController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final goal = await GoalService.getActiveGoal();
    
    if (mounted) {
      setState(() {
        _goal = goal;
        _isLoading = false;
      });
    }
  }

  Future<void> _startJourney() async {
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
    
    final series = await DreamSeriesService.generatePilotEpisode(_goal!);
    
    if (mounted) {
      setState(() {
        _goal = _goal!.copyWith(series: series);
        _isGenerating = false;
      });
    }
  }

  Future<void> _submitInput(String input) async {
    if (_goal == null || input.trim().isEmpty) return;

    // Token kontrolü
    final hasEnough = await TokenService.hasEnoughTokens();
    if (!hasEnough) {
      if (mounted) {
        final watchedAd = await TokenDialog.show(context);
        if (!watchedAd) return; // Reklam izlenmediyse veya iptal edildiyse dur
      }
    }
    
    setState(() {
      _isGenerating = true;
      _inputController.clear();
    });

    // Token kullan (5 token)
    await TokenService.useTokensForMessage();

    // Shadow Memory analizi - Motivasyon etkileşimlerini DNA'ya işle
    ShadowMemoryService.analyzeAndUpdate(input, category: 'motivasyon');
    
    final series = await DreamSeriesService.generateNextEpisode(_goal!, input.trim());
    
    if (mounted) {
      if (series != null) {
        setState(() {
          _goal = _goal!.copyWith(series: series);
          _isGenerating = false;
        });
        // Scroll to bottom after generation
      } else {
        setState(() => _isGenerating = false);
        _showSnackbar(AppTranslations.get('errorSceneCreation'));
      }
    }
  }

  Future<void> _resetSeries() async {
    if (_goal == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppTranslations.get('resetScenario')),
        content: Text(AppTranslations.get('resetScenarioConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppTranslations.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9C27B0),
              foregroundColor: Colors.white,
            ),
            child: Text(AppTranslations.get('resetAndStartOver')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      await DreamSeriesService.resetSeries(_goal!.id);
      await _loadData();
      if (mounted) {
        _showSnackbar(AppTranslations.get('scenarioResetSuccess'));
      }
    }
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

    if (_goal == null) {
      return _buildNoGoalState();
    }

    if (_goal!.series == null) {
      return _buildStartJourneyState();
    }

    return _buildStoryStream();
  }

  Widget _buildNoGoalState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              AppTranslations.get('noGoalTitle'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              AppTranslations.get('noGoalMessage'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.mutedSage),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartJourneyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Text('🎬', style: TextStyle(fontSize: 64)),
          ),
          const SizedBox(height: 32),
          Text(
            AppTranslations.get('futureSeriesTitle'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            AppTranslations.get('futureSeriesDesc'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppTheme.mutedSage),
          ),
          const SizedBox(height: 48),
          _buildPrimaryButton(
            onTap: _isGenerating ? null : _startJourney,
            label: _isGenerating ? AppTranslations.get('scenePreparing') : AppTranslations.get('playPilotEpisode'),
            isLoading: _isGenerating,
            icon: Icons.play_arrow_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildStoryStream() {
    final series = _goal!.series!;
    
    return Container(
      decoration: BoxDecoration(color: AppTheme.sandBeige.withOpacity(0.3)),
      child: Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: 4, // Fixed episodes: Pilot, Ep2, Ep3, Final
            itemBuilder: (context, index) {
              final isUnlocked = index <= series.currentEpisodeIndex;
              
              if (isUnlocked) {
                final episode = series.episodes[index];
                final isCurrent = index == series.currentEpisodeIndex;
                return _buildEpisodeItem(episode, isCurrent);
              } else {
                return _buildLockedItem(index);
              }
            },
          ),
          // Reset Button
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(30),
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF9C27B0), size: 24),
                onPressed: _resetSeries,
                tooltip: AppTranslations.get('resetScenarioTooltip'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeItem(DreamEpisode episode, bool isCurrent) {
    return Column(
      children: [
        // Episode Card
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: isCurrent 
                ? Border.all(color: const Color(0xFF9C27B0).withOpacity(0.3), width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    episode.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9C27B0),
                    ),
                  ),
                  if (episode.timeJump != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C27B0).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        episode.timeJump!,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                episode.storyText,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Color(0xFF2C3E50),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.bottomRight,
                child: Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 20),
              ),
            ],
          ),
        ),

        // User Input / Next Question logic
        if (isCurrent && episode.question != null && episode.index < 3)
          _buildInputArea(episode),
        
        // Timeline Connector
        if (episode.index < 3)
          Container(
            width: 2,
            height: 40,
            color: const Color(0xFF9C27B0).withOpacity(0.2),
          ),
      ],
    );
  }

  Widget _buildInputArea(DreamEpisode episode) {
    if (_isGenerating) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircularProgressIndicator(color: Color(0xFF9C27B0)),
            const SizedBox(height: 12),
            Text(AppTranslations.get('sceneSettingUp'), style: TextStyle(color: AppTheme.mutedSage, fontSize: 13)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.warmCream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.movie_creation_outlined, size: 18, color: Color(0xFF9C27B0)),
              const SizedBox(width: 8),
              Text(
                AppTranslations.get('directorNote'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            episode.question!,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _inputController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: AppTranslations.get('ideaInputHint'),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.softBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF9C27B0)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _submitInput(_inputController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(AppTranslations.get('playNextEpisode')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedItem(int index) {
    String title = '';
    switch (index) {
      case 1: title = AppTranslations.get('episode2'); break;
      case 2: title = AppTranslations.get('episode3'); break;
      case 3: title = AppTranslations.get('finalEpisode'); break;
    }

    return Opacity(
      opacity: 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.lock_person_rounded, color: Colors.grey, size: 32),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              AppTranslations.get('unlockPrevious'),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback? onTap,
    required String label,
    IconData? icon,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9C27B0).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            else if (icon != null)
              Icon(icon, color: Colors.white, size: 24),
            if (icon != null || isLoading) const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

