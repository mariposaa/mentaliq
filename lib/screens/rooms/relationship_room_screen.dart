import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../l10n/app_translations.dart';
import 'tabs/relationship_chat_tab.dart';
import 'tabs/relationship_tests_tab.dart';
import 'tabs/relationship_tips_tab.dart';

/// İlişki Desteği Room - 3 Tab yapısı
class RelationshipRoomScreen extends StatefulWidget {
  const RelationshipRoomScreen({super.key});

  @override
  State<RelationshipRoomScreen> createState() => _RelationshipRoomScreenState();
}

class _RelationshipRoomScreenState extends State<RelationshipRoomScreen> 
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;

  // Tab tanımları - Partner Bilgileri ilk sırada
  late final List<_TabInfo> _tabs = [
    _TabInfo(label: AppTranslations.get('partnerInfo'), icon: Icons.favorite_outline_rounded),
    _TabInfo(label: AppTranslations.get('relationshipAnalysis'), icon: Icons.chat_bubble_outline_rounded),
    _TabInfo(label: AppTranslations.get('analysisTips'), icon: Icons.lightbulb_outline_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and title
            _buildHeader(),
            
            // Tab Bar
            _buildTabBar(),
            
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  RelationshipTestsTab(),     // 1. Testler
                  RelationshipChatTab(),      // 2. İlişki Analizi - Chat
                  RelationshipTipsTab(),      // 3. Tavsiyeler
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isCompact = context.isCompactPhone;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: 12,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
            color: AppTheme.forestCharcoal,
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE91E63).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('💕', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTranslations.get('relationshipSupport'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: isCompact ? 15 : null,
                      ),
                ),
                Text(
                  AppTranslations.get('romanticRelationships'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

  Widget _buildTabBar() {
    final isCompact = context.isCompactPhone;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.warmCream,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.softBorder, width: 1),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          color: AppTheme.sageGreen,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppTheme.sageGreen.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.forestCharcoal, // Darker for visibility
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        splashBorderRadius: BorderRadius.circular(10),
        tabs: _tabs.map((tab) => Tab(
          height: isCompact ? 36 : 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, size: isCompact ? 14 : 16),
              SizedBox(width: isCompact ? 3 : 4),
              Flexible(
                child: Text(
                  tab.label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _TabInfo {
  final String label;
  final IconData icon;

  _TabInfo({required this.label, required this.icon});
}
