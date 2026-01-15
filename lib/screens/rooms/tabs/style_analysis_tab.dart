import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../config/app_theme.dart';
import '../../../services/style_analysis_service.dart';
import '../../../services/token_service.dart';
import '../../../services/ad_service.dart';

class StyleAnalysisTab extends StatefulWidget {
  const StyleAnalysisTab({super.key});

  @override
  State<StyleAnalysisTab> createState() => _StyleAnalysisTabState();
}

class _StyleAnalysisTabState extends State<StyleAnalysisTab> {
  bool _isLoading = false;
  bool _hasAnalyzed = false;
  StyleAnalysisResult? _analysisResult;
  String _recommendation = '';
  
  final TextEditingController _commandController = TextEditingController();
  String _selectedWeather = 'Güneşli';
  String _selectedTemp = 'Ilık';
  bool _isHybrid = false;

  final List<String> _weatherList = ['Güneşli', 'Bulutlu', 'Yağmurlu', 'Karlı'];
  final List<String> _tempList = ['Sıcak', 'Ilık', 'Soğuk'];

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
      ]);

      if (mounted) {
        setState(() {
          _recommendation = results[0] as String;
          _analysisResult = results[1] as StyleAnalysisResult?;
          _isLoading = false;
          _hasAnalyzed = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showInsufficientTokensDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.warmCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Jetonun Bitti! 😢', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Strateji oluşturmak için ${TokenService.styleStrategyTokenCost} jetona ihtiyacın var. Kısa bir reklam izleyerek 30 jeton kazanabilirsin!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Daha Sonra', style: TextStyle(color: AppTheme.mutedSage)),
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
                    const SnackBar(content: Text('Tebrikler! 30 jeton kazandın. 🎉')),
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
            child: const Text('Reklam İzle & Kazan'),
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
            const Center(child: Text('Strateji hazırlanıyor...', style: TextStyle(color: AppTheme.mutedSage, fontSize: 13))),
          ] else if (_hasAnalyzed) ...[
// ... (rest of build logic)
            const SizedBox(height: 30),
            _buildRecommendationCard(),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stil Komutu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.mutedSage, letterSpacing: 1)),
          const SizedBox(height: 12),
          TextField(
            controller: _commandController,
            maxLength: 50,
            decoration: InputDecoration(
              hintText: 'Örn: Şık bir akşam yemeği kombini...',
              hintStyle: TextStyle(color: AppTheme.mutedSage.withOpacity(0.5), fontSize: 14),
              filled: true,
              fillColor: AppTheme.warmCream.withOpacity(0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              counterText: '',
            ),
          ),
          const SizedBox(height: 20),
          const Text('Öneri Modu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.mutedSage)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSelectionChip('Sadece Arşivim', !_isHybrid, (val) => setState(() => _isHybrid = false)),
              _buildSelectionChip('Hibrit (Önerili)', _isHybrid, (val) => setState(() => _isHybrid = true)),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Hava Durumu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.mutedSage)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _weatherList.map((w) => _buildSelectionChip(w, _selectedWeather == w, (val) => setState(() => _selectedWeather = w))).toList(),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Sıcaklık', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.mutedSage)),
          const SizedBox(height: 8),
          Row(
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
              child: const Text('STRATEJİ OLUŞTUR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionChip(String label, bool isSelected, Function(bool) onSelect) {
    return GestureDetector(
      onTap: () => onSelect(!isSelected),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.terracotta : AppTheme.warmCream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppTheme.terracotta : AppTheme.softBorder),
        ),
        child: Text(
          label,
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
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('ÖZEL KOMBİN STRATEJİSİ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 13)),
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
          const Text('GÜNCEL STİL ANALİZİ', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 13, color: AppTheme.mutedSage)),
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
          const Text('RENK UYUMU VE TAMAMLAYICILAR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 13, color: AppTheme.mutedSage)),
          const SizedBox(height: 20),
          const Text('Baskın Renklerin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _analysisResult!.primaryColors.map((c) => _buildColorBubble(c, isPrimary: true)).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Kombini Güçlendirecek Renkler', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.sageGreen)),
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
                const Text('EKSİK PARÇA DEDEKTİFİ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.sageGreen)),
                const SizedBox(height: 4),
                Text(_analysisResult!.shoppingAdvice, style: const TextStyle(fontSize: 14, height: 1.4)),
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
          const Text('Stil Stratejinizi Kurun', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'User DNA verileriniz ve gardırobunuz hazır. Bir hava durumu seçin ve ne yapmak istediğinizi yazın.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.mutedSage, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
