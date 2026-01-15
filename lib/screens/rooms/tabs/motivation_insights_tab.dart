import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../config/app_theme.dart';
import '../../../models/goal_model.dart';
import '../../../services/goal_service.dart';
import '../../../services/progress_analysis_service.dart';
import '../../../services/token_service.dart';
import '../../../widgets/token_dialog.dart';

/// Tab 4: İlerleme Analizi & Rapor - Review Layer
/// Karne ve denetim alanı. İlerleme grafiği ve AI analizi.
class MotivationInsightsTab extends StatefulWidget {
  const MotivationInsightsTab({super.key});

  @override
  State<MotivationInsightsTab> createState() => _MotivationInsightsTabState();
}

class _MotivationInsightsTabState extends State<MotivationInsightsTab>
    with AutomaticKeepAliveClientMixin {
  
  bool _isLoading = true;
  bool _isAnalyzing = false;
  GoalModel? _goal;
  ProgressStats? _stats;
  ProgressAnalysis? _analysis;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final goal = await GoalService.getActiveGoal();
    
    if (mounted) {
      setState(() {
        _goal = goal;
        _stats = ProgressAnalysisService.calculateStats(goal);
        _analysis = goal?.analysis != null 
            ? ProgressAnalysis(
                summary: goal!.analysis!.aiComment,
                strengths: [],
                improvements: [],
                nextFocus: '',
              )
            : null;
        _isLoading = false;
      });
    }
  }

  Future<void> _runAnalysis() async {
    // Check tokens
    final hasTokens = await TokenService.hasEnoughTokensForAnalysis();
    if (!hasTokens) {
      if (!mounted) return;
      final gotTokens = await TokenDialog.show(context);
      if (!gotTokens) return;
    }

    setState(() => _isAnalyzing = true);
    
    await TokenService.useTokensForAnalysis();
    final analysis = await ProgressAnalysisService.generateAnalysis();
    
    if (mounted) {
      setState(() {
        _analysis = analysis;
        _isAnalyzing = false;
      });
    }
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Card with Chart
          _buildProgressCard(),
          const SizedBox(height: 20),
          
          // Stats Row
          _buildStatsRow(),
          const SizedBox(height: 20),
          
          // Analyze Button
          _buildAnalyzeButton(),
          const SizedBox(height: 20),
          
          // Analysis Result
          if (_analysis != null) _buildAnalysisCard(),
          
          const SizedBox(height: 40),
        ],
      ),
    );
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
                child: Text('📊', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Henüz analiz edilecek veri yok',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.forestCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Önce "Kimlik" sekmesinden hedefini belirle.',
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

  Widget _buildProgressCard() {
    final progress = _stats?.progressRate ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF9C27B0).withOpacity(0.1),
            const Color(0xFF7B1FA2).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF9C27B0).withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // Title
          Text(
            'Genel İlerleme',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.forestCharcoal,
            ),
          ),
          const SizedBox(height: 24),
          
          // Pie Chart
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(
                    value: progress.toDouble(),
                    color: const Color(0xFF9C27B0),
                    radius: 25,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: (100 - progress).toDouble(),
                    color: const Color(0xFF9C27B0).withOpacity(0.15),
                    radius: 25,
                    showTitle: false,
                  ),
                ],
              ),
            ),
          ),
          
          // Center text overlay
          Transform.translate(
            offset: const Offset(0, -90),
            child: Column(
              children: [
                Text(
                  '%$progress',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9C27B0),
                  ),
                ),
                Text(
                  'Tamamlandı',
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

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.flag_rounded,
            value: '${_stats?.completedSteps ?? 0}/${_stats?.totalSteps ?? 0}',
            label: 'Adım',
            color: const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle_rounded,
            value: '${_stats?.completedTasks ?? 0}/${_stats?.totalTasks ?? 0}',
            label: 'Görev',
            color: const Color(0xFF2196F3),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warmCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.forestCharcoal,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.mutedSage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return GestureDetector(
      onTap: _isAnalyzing ? null : _runAnalysis,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isAnalyzing
                ? [Colors.grey.shade400, Colors.grey.shade500]
                : [const Color(0xFF9C27B0), const Color(0xFF7B1FA2)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isAnalyzing
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF9C27B0).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isAnalyzing) ...[
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Icon(
              _isAnalyzing ? null : Icons.insights_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _isAnalyzing ? 'Analiz Ediliyor...' : '🔍 İlerlemeyi Analiz Et',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.warmCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.softBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Analiz Raporu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.forestCharcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Summary
          Text(
            _analysis!.summary,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.forestCharcoal,
              height: 1.6,
            ),
          ),
          
          // Strengths
          if (_analysis!.strengths.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildListSection(
              title: '✅ Güçlü Yönler',
              items: _analysis!.strengths,
              color: Colors.green,
            ),
          ],
          
          // Improvements
          if (_analysis!.improvements.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildListSection(
              title: '⚠️ Geliştirilecek',
              items: _analysis!.improvements,
              color: Colors.orange,
            ),
          ],
          
          // Next Focus
          if (_analysis!.nextFocus.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sonraki Odak: ${_analysis!.nextFocus}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9C27B0),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListSection({
    required String title,
    required List<String> items,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•', style: TextStyle(color: color)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.forestCharcoal,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}
