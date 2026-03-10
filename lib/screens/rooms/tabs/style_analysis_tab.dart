import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../config/app_theme.dart';
import '../../../config/responsive.dart';
import '../../../models/style_item.dart';
import '../../../models/style_outfit_record.dart';
import '../../../services/style_analysis_service.dart';
import '../../../services/style_outfit_history_service.dart';
import '../../../services/token_service.dart';
import '../../../services/ad_service.dart';
import '../../../l10n/app_translations.dart';
import '../../../widgets/responsive_card.dart';

class StyleAnalysisTab extends StatefulWidget {
  const StyleAnalysisTab({super.key});

  @override
  State<StyleAnalysisTab> createState() => _StyleAnalysisTabState();
}

class _StyleAnalysisTabState extends State<StyleAnalysisTab> {
  bool _isLoading = false;
  bool _hasAnalyzed = false;
  StyleAnalysisResult? _analysisResult;
  List<StyleOutfitSuggestion> _outfitSuggestions = [];
  String _recommendation = '';
  String _lastAnalyzedQuery = '';
  
  final TextEditingController _commandController = TextEditingController();
  String _selectedWeather = AppTranslations.get('sunny');
  String _selectedTemp = AppTranslations.get('warm');
  bool _isHybrid = false;

  List<String> get _weatherList => [AppTranslations.get('sunny'), AppTranslations.get('cloudy'), AppTranslations.get('rainy'), AppTranslations.get('snowy')];
  List<String> get _tempList => [AppTranslations.get('hot'), AppTranslations.get('warm'), AppTranslations.get('cold')];

  Future<void> _getRecommendation() async {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;

    // 1. Token Kontrolü
    final hasEnough = await TokenService.hasEnoughTokensForStyleStrategy();
    if (!hasEnough) {
      if (mounted) _showInsufficientTokensDialog();
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 2. Token Düş
      final success = await TokenService.useTokensForStyleStrategy();
      if (!success) {
        setState(() => _isLoading = false);
        return;
      }

      final results = await Future.wait([
        StyleAnalysisService.getCustomRecommendation(
          command: command,
          weather: _selectedWeather,
          temperature: _selectedTemp,
          isHybrid: _isHybrid,
        ),
        StyleAnalysisService.performFullAnalysis(),
        _isHybrid
            ? Future.value(<StyleOutfitSuggestion>[])
            : StyleAnalysisService.getClosetOutfitSuggestions(
                command: command,
                weather: _selectedWeather,
                temperature: _selectedTemp,
              ),
      ]);

      if (mounted) {
        setState(() {
          _lastAnalyzedQuery = command;
          _recommendation = results[0] as String;
          _analysisResult = results[1] as StyleAnalysisResult?;
          _outfitSuggestions = results[2] as List<StyleOutfitSuggestion>;
          _isLoading = false;
          _hasAnalyzed = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _detectMoodTag(String text) {
    final t = text.toLowerCase();
    if (t.contains('uzgun') || t.contains('üzgün') || t.contains('mutsuz')) return 'Uzgün';
    if (t.contains('mutlu') || t.contains('nese') || t.contains('neşe')) return 'Neseli';
    if (t.contains('kaygi') || t.contains('kaygı') || t.contains('endise') || t.contains('endişe')) {
      return 'Kaygili';
    }
    if (t.contains('ofke') || t.contains('öfke') || t.contains('sinir')) return 'Ofkeli';
    if (t.contains('sakin') || t.contains('huzur')) return 'Sakin';
    return null;
  }

  Future<void> _saveCurrentCombination() async {
    final query = _commandController.text.trim().isNotEmpty
        ? _commandController.text.trim()
        : _lastAnalyzedQuery;
    if (!_hasAnalyzed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Önce kombin önerisi oluşturmalısın.')),
        );
      }
      return;
    }
    if (query.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kaydetmek için bir kombin sorgusu gerekli.')),
        );
      }
      return;
    }

    final record = StyleOutfitRecord(
      id: '',
      query: query,
      sourceMode: _isHybrid ? 'gardrop_disi_oneri' : 'sadece_arsivim',
      weather: _selectedWeather,
      temperature: _selectedTemp,
      recommendation: _recommendation,
      moodTag: _detectMoodTag(query),
      createdAt: DateTime.now(),
      outfits: _outfitSuggestions
          .where((o) => o.top != null || o.bottom != null || o.shoes != null || o.outerwear != null)
          .map(
            (o) => StyleOutfitRecordItem(
              title: o.title,
              topImageUrl: o.top?.imageUrl,
              bottomImageUrl: o.bottom?.imageUrl,
              shoesImageUrl: o.shoes?.imageUrl,
              outerwearImageUrl: o.outerwear?.imageUrl,
            ),
          )
          .toList(),
    );

    final saved = await StyleOutfitHistoryService.saveRecord(record);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved ? 'Kombin kaydedildi.' : 'Kombin kaydedilemedi. Oturumunu kontrol edip tekrar dene.',
        ),
      ),
    );
  }

  void _showInsufficientTokensDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.warmCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppTranslations.get('tokensFinished'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(AppTranslations.format('tokensFinishedMsg', [TokenService.styleStrategyTokenCost.toString()])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppTranslations.get('later'), style: TextStyle(color: AppTheme.mutedSage)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final earned = await AdService.showRewardedAd();
              if (earned) {
                await TokenService.addTokens(TokenService.adRewardTokens);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppTranslations.get('tokensEarnedSuccess'))),
                  );
                }
                _getRecommendation(); // Token kazanınca tekrar dene
              } else {
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.terracotta,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppTranslations.get('watchAdEarn')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
// ... (rest of build)
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputSection(),
// ... (rest of column)
          if (_isLoading) ...[
            const SizedBox(height: 40),
            const Center(child: CircularProgressIndicator(color: AppTheme.terracotta)),
            const SizedBox(height: 12),
            Center(child: Text(AppTranslations.get('strategyPreparing'), style: const TextStyle(color: AppTheme.mutedSage, fontSize: 13))),
          ] else if (_hasAnalyzed) ...[
// ... (rest of build logic)
            const SizedBox(height: 30),
            _buildRecommendationCard(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saveCurrentCombination,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Kombini Kaydet'),
              ),
            ),
            if (!_isHybrid && _outfitSuggestions.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildOutfitSuggestionCard(),
            ],
            const SizedBox(height: 24),
            if (_analysisResult != null) ...[
              _buildStyleDNACard(),
              const SizedBox(height: 24),
              _buildColorHarmonyCard(),
              const SizedBox(height: 24),
              _buildShoppingCard(),
            ],
          ] else
            _buildWelcomeState(),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    final isCompact = context.isCompactPhone;
    return ResponsiveCard(
      padding: isCompact ? 14 : 20,
      color: Colors.white,
      radius: 24,
      shadow: AppTheme.cardShadow,
      border: Border.all(color: AppTheme.softBorder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppTranslations.get('styleCommand'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.mutedSage, letterSpacing: 1)),
          const SizedBox(height: 12),
          TextField(
            controller: _commandController,
            maxLength: 50,
            decoration: InputDecoration(
              hintText: AppTranslations.get('styleCommandHint'),
              hintStyle: TextStyle(color: AppTheme.mutedSage.withOpacity(0.5), fontSize: 14),
              filled: true,
              fillColor: AppTheme.warmCream.withOpacity(0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              counterText: '',
            ),
          ),
          const SizedBox(height: 20),
          Text(AppTranslations.get('recommendationMode'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.mutedSage)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSelectionChip(AppTranslations.get('onlyArchive'), !_isHybrid, (val) => setState(() => _isHybrid = false)),
              _buildSelectionChip(AppTranslations.get('hybridMode'), _isHybrid, (val) => setState(() => _isHybrid = true)),
            ],
          ),
          const SizedBox(height: 20),
          Text(AppTranslations.get('weather'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.mutedSage)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _weatherList.map((w) => _buildSelectionChip(w, _selectedWeather == w, (val) => setState(() => _selectedWeather = w))).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Text(AppTranslations.get('temperature'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.mutedSage)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tempList.map((t) => _buildSelectionChip(t, _selectedTemp == t, (val) => setState(() => _selectedTemp = t))).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _getRecommendation,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.terracotta,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(AppTranslations.get('createStrategy'), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionChip(String label, bool isSelected, Function(bool) onSelect) {
    final maxChipWidth = MediaQuery.sizeOf(context).width * 0.78;
    return GestureDetector(
      onTap: () => onSelect(!isSelected),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        constraints: BoxConstraints(maxWidth: maxChipWidth),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.terracotta : AppTheme.warmCream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppTheme.terracotta : AppTheme.softBorder),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.forestCharcoal,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.terracotta, Color(0xFFD86A5A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppTheme.terracotta.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(AppTranslations.get('personalizedStrategy'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _recommendation,
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleDNACard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.softBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppTranslations.get('currentStyleAnalysis'), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 13, color: AppTheme.mutedSage)),
          const SizedBox(height: 20),
          ..._analysisResult!.styleArchetypes.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('%${e.value.round()}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.terracotta)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearPercentIndicator(
                  lineHeight: 8.0,
                  percent: e.value / 100,
                  backgroundColor: AppTheme.warmCream,
                  progressColor: AppTheme.terracotta,
                  barRadius: const Radius.circular(4),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildOutfitSuggestionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.softBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bugun Bunlari Giy',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.forestCharcoal,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ..._outfitSuggestions.map(
            (outfit) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warmCream,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.softBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outfit.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.forestCharcoal,
                    ),
                  ),
                  if (outfit.reason.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      outfit.reason,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.mutedSage,
                        height: 1.3,
                      ),
                    ),
                  ],
                  if ((outfit.missingNote ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      outfit.missingNote!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.terracotta,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (outfit.top != null) _buildPieceImage(outfit.top!, 'Ust'),
                        if (outfit.bottom != null) _buildPieceImage(outfit.bottom!, 'Alt'),
                        if (outfit.shoes != null) _buildPieceImage(outfit.shoes!, 'Ayakkabi'),
                        if (outfit.outerwear != null) _buildPieceImage(outfit.outerwear!, 'Dis Giyim'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieceImage(StyleItem item, String label) {
    return SizedBox(
      width: 88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              item.imageUrl,
              width: 88,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 88,
                height: 100,
                color: AppTheme.sandBeige,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined, size: 18),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildColorHarmonyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppTranslations.get('colorHarmony'), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 13, color: AppTheme.mutedSage)),
          const SizedBox(height: 20),
          Text(AppTranslations.get('dominantColors'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _analysisResult!.primaryColors.map((c) => _buildColorBubble(c, isPrimary: true)).toList(),
          ),
          const SizedBox(height: 20),
          Text(AppTranslations.get('complementaryColors'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.sageGreen)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _analysisResult!.complementaryColors.map((c) => _buildColorBubble(c, isPrimary: false)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildColorBubble(String colorName, {required bool isPrimary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPrimary ? AppTheme.forestCharcoal.withOpacity(0.05) : AppTheme.sageGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(colorName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPrimary ? AppTheme.forestCharcoal : AppTheme.sageGreen)),
    );
  }

  Widget _buildShoppingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.sageGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.sageGreen.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_bag_outlined, color: AppTheme.sageGreen, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppTranslations.get('missingPiece'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.sageGreen)),
                const SizedBox(height: 4),
                Text(
                  _analysisResult!.shoppingAdvice.trim().isNotEmpty
                      ? _analysisResult!.shoppingAdvice
                      : 'Eksik parca analizi icin tekrar strateji olustur.',
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.warmCream,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_fix_high_rounded, size: 64, color: AppTheme.terracotta),
          ),
          const SizedBox(height: 24),
          Text(AppTranslations.get('setupStrategy'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              AppTranslations.get('setupStrategyDesc'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.mutedSage, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
