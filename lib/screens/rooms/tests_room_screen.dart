import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_translations.dart';
import '../../config/app_constants.dart';
import '../chat/chat_screen.dart';
import '../rooms/test_execution_screen.dart';
import '../../data/test_data.dart';

class TestsRoomScreen extends StatelessWidget {
  const TestsRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.forestCharcoal),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppTranslations.get('mindTests'),
          style: const TextStyle(color: AppTheme.forestCharcoal, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 32),
            Text(
              AppTranslations.get('availableTests'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.forestCharcoal,
              ),
            ),
            const SizedBox(height: 16),
            _buildTestGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
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
            AppTranslations.get('discoverWithData'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.forestCharcoal,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            AppTranslations.get('testsDescription'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.mutedSage,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/tests.png',
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Asset load error: $error');
                return Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.sageGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.psychology_rounded, size: 48, color: AppTheme.sageGreen),
                      const SizedBox(height: 8),
                      Text(AppTranslations.get('mindAnalysisModule'), style: const TextStyle(color: AppTheme.sageGreen, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestGrid(BuildContext context) {
    final tests = [
      {
        'id': 'iq_testi',
        'title': AppTranslations.get('iqTest'),
        'subtitle': AppTranslations.get('cognitiveAbility'),
        'icon': '🧩',
        'color': AppTheme.sageGreen,
        'tokens': '20',
      },
      {
        'id': 'eq_testi',
        'title': AppTranslations.get('eqTest'),
        'subtitle': AppTranslations.get('emotionalIntelligence'),
        'icon': '❤️',
        'color': AppTheme.terracotta,
        'tokens': '15',
      },
      {
        'id': 'travma_analizi',
        'title': AppTranslations.get('traumaAnalysis'),
        'subtitle': AppTranslations.get('emotionalBurdens'),
        'icon': '🩹',
        'color': Colors.blueGrey,
        'tokens': '25',
      },
      {
        'id': 'mbti_kisilik',
        'title': AppTranslations.get('mbtiPersonality'),
        'subtitle': AppTranslations.get('characterType'),
        'icon': '🎭',
        'color': Colors.indigo,
        'tokens': '15',
      },
      {
        'id': 'anksiyete_olcegi',
        'title': AppTranslations.get('anxietyScale'),
        'subtitle': AppTranslations.get('stressLevel'),
        'icon': '🌪️',
        'color': Colors.orangeAccent,
        'tokens': '10',
      },
      {
        'id': 'sevgi_dili',
        'title': AppTranslations.get('loveLanguage'),
        'subtitle': AppTranslations.get('relationshipStyle'),
        'icon': '💌',
        'color': Colors.pinkAccent,
        'tokens': '10',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: tests.length,
      itemBuilder: (context, index) {
        final test = tests[index];
        return _buildTestCard(context, test);
      },
    );
  }

  Widget _buildTestCard(BuildContext context, Map<String, dynamic> test) {
    return GestureDetector(
      onTap: () {
        // Find test data
        final testId = test['id'];
        final mentalTest = TestData.allTests.firstWhere(
          (t) => t.id == testId,
          orElse: () => TestData.allTests.first,
        );

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TestExecutionScreen(
              test: mentalTest,
              tokenCost: int.tryParse(test['tokens']) ?? 15,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.softBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (test['color'] as Color).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                test['icon'],
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              test['title'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppTheme.forestCharcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              test['subtitle'],
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.mutedSage,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.warmCream,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('✨', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 4),
                  Text(
                    test['tokens'],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.forestCharcoal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
