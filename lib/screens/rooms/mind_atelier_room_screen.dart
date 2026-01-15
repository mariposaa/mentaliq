import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import 'tabs/mind_atelier_chat_tab.dart'; // Yeni oluşturulacak
import 'tabs/mind_atelier_dna_tab.dart';  // Yeni oluşturulacak

class MindAtelierRoomScreen extends StatefulWidget {
  const MindAtelierRoomScreen({super.key});

  @override
  State<MindAtelierRoomScreen> createState() => _MindAtelierRoomScreenState();
}

class _MindAtelierRoomScreenState extends State<MindAtelierRoomScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_TabInfo> _tabs = [
    _TabInfo(label: 'Zihin Seansı', icon: Icons.psychology_outlined),
    _TabInfo(label: 'Zihin DNA', icon: Icons.hub_outlined),
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
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  MindAtelierChatTab(), // Sesli chat alanı
                  MindAtelierDNATab(),  // Analiz sonuçları
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/persona.png'),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.sageGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('🌱', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Persona Psikoloji',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.forestCharcoal,
                          ),
                    ),
                    Text(
                      'Zihinsel denge ve derin öz-analiz',
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
          color: AppTheme.sageGreen,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.forestCharcoal,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: _tabs.map((tab) => Tab(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tab.icon, size: 16),
              const SizedBox(width: 6),
              Text(tab.label, style: const TextStyle(fontSize: 12)),
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
