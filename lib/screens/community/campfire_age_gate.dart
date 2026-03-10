import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_translations.dart';
import '../../services/forum_service.dart';

/// 18+ tek seferlik onay; sadece onaylarsa Kamp Ateşi açılır.
class CampfireAgeGate extends StatelessWidget {
  const CampfireAgeGate({super.key, required this.onConfirmed});

  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_fire_department_rounded, size: 72, color: AppTheme.terracotta.withOpacity(0.8)),
              const SizedBox(height: 24),
              Text(AppTranslations.get('campfire'), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.terracotta)),
              const SizedBox(height: 12),
              Text(AppTranslations.get('ageGateMessage'), textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: AppTheme.forestCharcoal)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.forestCharcoal, side: BorderSide(color: AppTheme.softBorder)),
                    child: Text(AppTranslations.get('no')),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: () async {
                      await ForumService.setCampfireAgeConfirmed();
                      onConfirmed();
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.terracotta),
                    child: Text(AppTranslations.get('confirmAge')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
