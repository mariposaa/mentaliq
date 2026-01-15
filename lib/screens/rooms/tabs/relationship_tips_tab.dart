// lib/screens/rooms/tabs/relationship_tips_tab.dart
// Analiz Tavsiyeler Tab - THE AUDITOR Analysis System

import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../models/relationship_analysis_model.dart';
import '../../../services/relationship_analysis_service.dart';
import '../../../services/partner_service.dart';
import '../../../services/token_service.dart';
import '../../../widgets/token_dialog.dart';

/// Analiz Tavsiyeler Tab - İlişki durumu analizi ve tavsiyeler
class RelationshipTipsTab extends StatefulWidget {
  const RelationshipTipsTab({super.key});

  @override
  State<RelationshipTipsTab> createState() => _RelationshipTipsTabState();
}

class _RelationshipTipsTabState extends State<RelationshipTipsTab>
    with AutomaticKeepAliveClientMixin {
  
  List<RelationshipAnalysisModel> _analyses = [];
  bool _isLoading = false;
  bool _isAnalyzing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAnalyses();
  }

  Future<void> _loadAnalyses() async {
    setState(() => _isLoading = true);
    
    final analyses = await RelationshipAnalysisService.getAnalyses();
    
    if (mounted) {
      setState(() {
        _analyses = analyses;
        _isLoading = false;
      });
    }
  }

  Future<void> _performAnalysis() async {
    // Check if partner exists
    final partner = await PartnerService.getPrimaryPartner();
    if (partner == null) {
      _showSnackbar('Önce partner bilgilerini girmelisin!', isError: true);
      return;
    }

    // Check tokens (15 token for analysis)
    final hasTokens = await TokenService.hasEnoughTokensForAnalysis();
    if (!hasTokens) {
      // Show token dialog with ad option
      if (!mounted) return;
      final gotTokens = await TokenDialog.show(context);
      if (!gotTokens) return;
      
      // Re-check after watching ad
      final hasTokensNow = await TokenService.hasEnoughTokensForAnalysis();
      if (!hasTokensNow) {
        _showSnackbar('Analiz için 15 token gerekli!', isError: true);
        return;
      }
    }

    setState(() => _isAnalyzing = true);

    // Use tokens for analysis (15 tokens)
    final used = await TokenService.useTokensForAnalysis();
    if (!used) {
      setState(() => _isAnalyzing = false);
      _showSnackbar('Token kullanılamadı!', isError: true);
      return;
    }

    final analysis = await RelationshipAnalysisService.performAnalysis();

    if (mounted) {
      setState(() => _isAnalyzing = false);

      if (analysis != null) {
        // Add to list and show detail
        setState(() {
          _analyses.insert(0, analysis);
        });
        _showAnalysisDetail(analysis);
      } else {
        _showSnackbar('Analiz yapılamadı. Tekrar dene.', isError: true);
      }
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppTheme.sageGreen,
      ),
    );
  }

  void _showAnalysisDetail(RelationshipAnalysisModel analysis) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AnalysisDetailScreen(analysis: analysis),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        // Analysis Button - Fixed at top
        _buildAnalysisButton(),

        // Analysis Cards Grid
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _analyses.isEmpty
                  ? _buildEmptyState()
                  : _buildAnalysisGrid(),
        ),
      ],
    );
  }

  Widget _buildAnalysisButton() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isAnalyzing ? null : _performAnalysis,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isAnalyzing
                    ? [Colors.grey.shade400, Colors.grey.shade500]
                    : [const Color(0xFF667eea), const Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.4),
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
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Analiz Ediliyor...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.psychology_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'İlişkini Analiz Et',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Müfettiş raporunu al',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
                color: AppTheme.sageGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('📊', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Henüz Analiz Yok',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.forestCharcoal,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Yukarıdaki butona basarak ilişkinin durumunu analiz et ve kişisel tavsiyeler al.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mutedSage,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: _analyses.length,
      itemBuilder: (context, index) {
        return _buildAnalysisCard(_analyses[index]);
      },
    );
  }

  Widget _buildAnalysisCard(RelationshipAnalysisModel analysis) {
    // Score color
    Color scoreColor;
    if (analysis.score >= 80) {
      scoreColor = Colors.green;
    } else if (analysis.score >= 60) {
      scoreColor = Colors.amber;
    } else if (analysis.score >= 40) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return GestureDetector(
      onTap: () => _showAnalysisDetail(analysis),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Score Circle
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: scoreColor, width: 3),
              ),
              child: Center(
                child: Text(
                  '${analysis.score}',
                  style: TextStyle(
                    color: scoreColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Date
            Text(
              analysis.formattedDate,
              style: TextStyle(
                color: AppTheme.mutedSage,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            // Emoji
            Text(analysis.scoreEmoji, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ANALYSIS DETAIL SCREEN
// ============================================================

class _AnalysisDetailScreen extends StatefulWidget {
  final RelationshipAnalysisModel analysis;

  const _AnalysisDetailScreen({required this.analysis});

  @override
  State<_AnalysisDetailScreen> createState() => _AnalysisDetailScreenState();
}

class _AnalysisDetailScreenState extends State<_AnalysisDetailScreen> {
  late List<bool> _completedRecommendations;

  @override
  void initState() {
    super.initState();
    _completedRecommendations = List.generate(
      widget.analysis.recommendations.length,
      (_) => false,
    );
  }

  Color get _scoreColor {
    if (widget.analysis.score >= 80) return Colors.green;
    if (widget.analysis.score >= 60) return Colors.amber.shade700;
    if (widget.analysis.score >= 40) return Colors.orange;
    return Colors.red;
  }

  void _toggleRecommendation(int index) {
    setState(() {
      _completedRecommendations[index] = !_completedRecommendations[index];
    });
    
    // Save to Firebase
    RelationshipAnalysisService.toggleRecommendation(
      widget.analysis.id,
      index,
      _completedRecommendations[index],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.forestCharcoal),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Müfettiş Raporu',
          style: TextStyle(color: AppTheme.forestCharcoal, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Score Card
            _buildScoreCard(),
            const SizedBox(height: 16),

            // Title
            _buildTitleCard(),
            const SizedBox(height: 16),

            // Inspector's Note
            _buildInspectorNote(),
            const SizedBox(height: 16),

            // Personality Clash
            _buildPersonalityClash(),
            const SizedBox(height: 24),

            // Recommendations
            _buildRecommendationsSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_scoreColor.withOpacity(0.15), _scoreColor.withOpacity(0.05)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _scoreColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Score Ring
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: widget.analysis.score / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(_scoreColor),
                ),
              ),
              Column(
                children: [
                  Text(
                    '${widget.analysis.score}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _scoreColor,
                    ),
                  ),
                  Text(
                    'puan',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.mutedSage,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.analysis.formattedDate,
            style: TextStyle(
              color: AppTheme.mutedSage,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _scoreColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(widget.analysis.scoreEmoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.analysis.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.forestCharcoal,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.sageGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note_alt_outlined, color: AppTheme.sageGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Müfettiş Notu',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.sageGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.analysis.analysis,
            style: TextStyle(
              color: AppTheme.forestCharcoal,
              height: 1.5,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalityClash() {
    if (widget.analysis.personalityClash.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚔️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Karakter Çatışması',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.terracotta,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.terracotta.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.analysis.personalityClash,
                    style: TextStyle(
                      color: AppTheme.forestCharcoal,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('💊', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              'Reçeten',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.forestCharcoal,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        ...widget.analysis.recommendations.asMap().entries.map((entry) {
          final index = entry.key;
          final rec = entry.value;
          return _buildRecommendationCard(rec, index);
        }),
      ],
    );
  }

  Widget _buildRecommendationCard(AnalysisRecommendation rec, int index) {
    final isCompleted = _completedRecommendations[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCompleted ? AppTheme.sageGreen.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
        border: rec.isHardPill
            ? Border.all(color: Colors.red.withOpacity(0.4), width: 1.5)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleRecommendation(index),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppTheme.sageGreen : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCompleted ? AppTheme.sageGreen : AppTheme.mutedSage,
                      width: 2,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
                const SizedBox(width: 12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(rec.typeIcon, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            rec.typeName,
                            style: TextStyle(
                              color: AppTheme.mutedSage,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (rec.isHardPill) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('⚠️', style: TextStyle(fontSize: 10)),
                                  SizedBox(width: 2),
                                  Text(
                                    'Acı Reçete',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        rec.text,
                        style: TextStyle(
                          color: isCompleted
                              ? AppTheme.mutedSage
                              : AppTheme.forestCharcoal,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
