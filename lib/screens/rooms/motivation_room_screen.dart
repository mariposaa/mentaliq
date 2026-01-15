import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import 'tabs/motivation_chat_tab.dart';
import 'tabs/motivation_goals_tab.dart';
import 'tabs/motivation_habits_tab.dart';
import 'tabs/motivation_insights_tab.dart';

/// Motivasyon Kişisel Gelişim Room - 4 Tab yapısı
class MotivationRoomScreen extends StatefulWidget {
  const MotivationRoomScreen({super.key});

  @override
  State<MotivationRoomScreen> createState() => _MotivationRoomScreenState();
}

class _MotivationRoomScreenState extends State<MotivationRoomScreen> 
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;

  // Tab tanımları - 4 sekme (doğru sıralama)
  final List<_TabInfo> _tabs = [
    _TabInfo(label: 'Hedef', icon: Icons.flag_outlined),
    _TabInfo(label: 'Yol Haritası', icon: Icons.map_outlined),
    _TabInfo(label: 'Motivasyon', icon: Icons.bolt_rounded),
    _TabInfo(label: 'Analiz', icon: Icons.insights_rounded),
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
                  MotivationGoalsTab(),     // 1. Kimlik & Hedef (Form)
                  MotivationHabitsTab(),    // 2. Yol Haritası (Timeline)
                  MotivationChatTab(),      // 3. Öz Motivasyon (Poster)
                  MotivationInsightsTab(),  // 4. Analiz (Charts)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
              color: const Color(0xFF9C27B0).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('🚀', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Motivasyon & Kişisel Gelişim',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  'Hedefler, alışkanlıklar ve büyüme',
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.warmCream,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.softBorder, width: 1),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF9C27B0), // Purple theme
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9C27B0).withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.forestCharcoal,
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        splashBorderRadius: BorderRadius.circular(10),
        tabs: _tabs.map((tab) => Tab(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, size: 14),
              const SizedBox(width: 4),
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
