import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_translations.dart';
import 'campfire_feed_tab.dart';
import 'campfire_daily_tab.dart';
import 'campfire_share_tab.dart';
import 'campfire_my_tab.dart';
import 'campfire_silent_flirt_tab.dart';

class CampfireTabsScreen extends StatefulWidget {
  const CampfireTabsScreen({super.key});

  @override
  State<CampfireTabsScreen> createState() => _CampfireTabsScreenState();
}

class _CampfireTabsScreenState extends State<CampfireTabsScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      appBar: AppBar(
        backgroundColor: AppTheme.sandBeige,
        elevation: 0,
        title: Text(AppTranslations.get('campfire'), style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.forestCharcoal)),
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          CampfireFeedTab(),
          CampfireDailyTab(),
          CampfireShareTab(),
          CampfireMyTab(),
          CampfireSilentFlirtTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: AppTheme.warmCream, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]),
        child: SafeArea(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _nav(0, Icons.home_rounded, AppTranslations.get('feed')),
                _nav(1, Icons.help_outline_rounded, AppTranslations.get('dailyQuestion')),
                _nav(2, Icons.add_circle_outline_rounded, AppTranslations.get('share')),
                _nav(3, Icons.person_outline_rounded, AppTranslations.get('mine')),
                _nav(4, Icons.favorite_border_rounded, AppTranslations.get('silentFlirt')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _nav(int i, IconData icon, String label) {
    final sel = _index == i;
    return GestureDetector(
      onTap: () => setState(() => _index = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppTheme.terracotta.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: sel ? AppTheme.terracotta : AppTheme.mutedSage),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.w500, color: sel ? AppTheme.terracotta : AppTheme.mutedSage)),
          ],
        ),
      ),
    );
  }
}
