import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../l10n/app_translations.dart';
import 'tabs/style_closet_tab.dart';
import 'tabs/style_analysis_tab.dart';
import 'tabs/style_trend_tab.dart';

class StyleRoomScreen extends StatefulWidget {
  const StyleRoomScreen({super.key});

  @override
  State<StyleRoomScreen> createState() => _StyleRoomScreenState();
}

class _StyleRoomScreenState extends State<StyleRoomScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late final List<_TabInfo> _tabs = [
    _TabInfo(label: AppTranslations.get('styleAnalysis'), icon: Icons.insights_rounded),
    _TabInfo(label: AppTranslations.get('myCloset'), icon: Icons.straighten_rounded),
    _TabInfo(label: 'Kayitlar', icon: Icons.bookmark_outline_rounded),
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
    final isCompact = context.isCompactPhone;
    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(isCompact),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  StyleAnalysisTab(),
                  StyleClosetTab(),
                  StyleTrendTab(),
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
    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/style_modern.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                      AppTheme.sandBeige.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 20, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.terracotta.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('👗', style: TextStyle(fontSize: 22)),
                ),
              ),
              SizedBox(width: isCompact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.get('styleConsulting'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.forestCharcoal,
                            fontSize: isCompact ? 22 : null,
                          ),
                    ),
                    Text(
                      AppTranslations.get('digitalArchiveAssistant'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.mutedSage,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(bool isCompact) {
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
          color: AppTheme.terracotta,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.forestCharcoal,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: _tabs.map((tab) => Tab(
          height: isCompact ? 36 : 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tab.icon, size: isCompact ? 14 : 16),
              SizedBox(width: isCompact ? 4 : 6),
              Text(tab.label, style: TextStyle(fontSize: isCompact ? 11 : 12)),
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
