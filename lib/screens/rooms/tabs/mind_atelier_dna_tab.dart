import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../services/user_dna_service.dart';
import '../../../models/user_dna_model.dart';

class MindAtelierDNATab extends StatefulWidget {
  const MindAtelierDNATab({super.key});

  @override
  State<MindAtelierDNATab> createState() => _MindAtelierDNATabState();
}

class _MindAtelierDNATabState extends State<MindAtelierDNATab> {
  UserDNAModel? _dna;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDNA();
  }

  Future<void> _loadDNA() async {
    final dna = await UserDNAService.getDNA();
    if (mounted) {
      setState(() {
        _dna = dna;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.sageGreen));
    }

    final hasData = _dna != null && (_dna!.mbti != null || (_dna!.personalityTraits?.isNotEmpty ?? false));

    return RefreshIndicator(
      onRefresh: _loadDNA,
      color: AppTheme.sageGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDNAHeader(context, hasData),
            const SizedBox(height: 24),
            _buildArketypeCard(context, _dna?.mbti),
            const SizedBox(height: 24),
            if (_dna?.personalityTraits?.isNotEmpty ?? false) ...[
              _buildTraitsList(_dna!.personalityTraits!),
              const SizedBox(height: 24),
            ],
            if (_dna?.coreValues?.isNotEmpty ?? false)
              _buildValuesGrid(_dna!.coreValues!),
            
            if (!hasData)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    'Analiz almak için Persona Seansı başlatın.',
                    style: TextStyle(color: AppTheme.mutedSage, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDNAHeader(BuildContext context, bool hasData) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.sageGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            hasData ? Icons.auto_awesome_rounded : Icons.hourglass_empty_rounded,
            color: AppTheme.sageGreen,
            size: 30,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasData ? 'Persona DNA\'nız Hazır' : 'Persona DNA\'nız İşleniyor',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.forestCharcoal,
                      ),
                ),
                Text(
                  hasData 
                    ? 'Karakter haritanız son seansınıza göre güncellendi.'
                    : 'Sohbet ettikçe karakter haritanız burada şekillenecek.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

  Widget _buildArketypeCard(BuildContext context, String? mbti) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.warmCream,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            mbti ?? 'Henüz Bir Arketip Belirlenmedi',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.forestCharcoal,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            mbti != null 
              ? 'Kişilik tipiniz derin seanslarınız sonucu $mbti olarak saptandı.'
              : 'Persona Psikoloji\'de gerçekleştireceğiniz seanslar sonrası yapay zeka karakterinizi analiz edecektir.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.mutedSage,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Icon(
            mbti != null ? Icons.verified_user_rounded : Icons.lock_person_rounded,
            size: 40,
            color: AppTheme.sageGreen.withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildTraitsList(List<String> traits) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Baskın Özellikler',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        ...traits.map((t) => _buildTraitTag(t)),
      ],
    );
  }

  Widget _buildTraitTag(String trait) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppTheme.sageGreen),
          const SizedBox(width: 12),
          Text(trait, style: const TextStyle(fontSize: 14, color: AppTheme.forestCharcoal)),
        ],
      ),
    );
  }

  Widget _buildValuesGrid(List<String> values) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Temel Değerler',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((v) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.sageGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              v,
              style: const TextStyle(fontSize: 12, color: AppTheme.sageGreen, fontWeight: FontWeight.bold),
            ),
          )).toList(),
        ),
      ],
    );
  }
}
