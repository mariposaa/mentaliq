import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../config/app_theme.dart';
import '../../../services/gemini_service.dart';

class StyleTrendTab extends StatefulWidget {
  const StyleTrendTab({super.key});

  @override
  State<StyleTrendTab> createState() => _StyleTrendTabState();
}

class _StyleTrendTabState extends State<StyleTrendTab> {
  String _trends = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrends();
  }

  Future<void> _loadTrends() async {
    try {
      final trendsDoc = await FirebaseFirestore.instance.collection('trends').doc('style_trends').get();
      
      if (trendsDoc.exists) {
        final data = trendsDoc.data()!;
        final lastUpdated = (data['last_updated'] as Timestamp).toDate();
        final now = DateTime.now();
        
        // Eğer 7 günden az zaman geçmişse cache'den kullan
        if (now.difference(lastUpdated).inDays < 7) {
          if (mounted) {
            setState(() {
              _trends = data['content'] ?? '';
              _isLoading = false;
            });
            return;
          }
        }
      }

      // Cache yok veya eski ise yeni trend oluştur
      final prompt = 'Bugünün tarihine ve mevsime göre şu an dünyada ve Türkiye\'de öne çıkan 3 moda trendini kısa başlıklarla açıkla.';
      final result = await GeminiService.generateResponse(prompt, 'stil_danismanligi');
      
      // Firestore'a kaydet (Maliyet yönetimi için)
      await FirebaseFirestore.instance.collection('trends').doc('style_trends').set({
        'content': result,
        'last_updated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _trends = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trend Radarı 🌟', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
          const SizedBox(height: 8),
          const Text('Bu hafta moda dünyasında neler oluyor?', style: TextStyle(color: AppTheme.mutedSage)),
          const SizedBox(height: 24),
          _buildTrendCard(_trends),
          const SizedBox(height: 40),
          _buildStyleTip('Bir stili tamamlayan en önemli parça, özgüvendir. ✨'),
        ],
      ),
    );
  }

  Widget _buildTrendCard(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.forestCharcoal, AppTheme.forestCharcoal.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Text(
        content,
        style: const TextStyle(color: Colors.white, height: 1.8, fontSize: 15),
      ),
    );
  }

  Widget _buildStyleTip(String tip) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.sageGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.sageGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: AppTheme.sageGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Text(tip, style: const TextStyle(color: AppTheme.sageGreen, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
