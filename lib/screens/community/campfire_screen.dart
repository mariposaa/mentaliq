import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/cohort_model.dart';
import '../../models/session_model.dart';
import '../../services/campfire_service.dart';
import '../../services/token_service.dart';
import '../../widgets/campfire_token_dialog.dart';
import 'check_in_screen.dart';
import 'lobby_screen.dart';
import 'session_screen.dart';
import 'countdown_screen.dart';

/// Kamp Ateşi Ana Ekranı
/// Üst sekmelerle grupları ve keşfet bölümünü gösterir
class CampfireScreen extends StatefulWidget {
  const CampfireScreen({super.key});

  @override
  State<CampfireScreen> createState() => _CampfireScreenState();
}

class _CampfireScreenState extends State<CampfireScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<CohortModel> _userCohorts = [];
  Map<String, SessionModel?> _cohortSessions = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserCohorts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserCohorts() async {
    setState(() => _isLoading = true);
    
    try {
      // Kullanıcının tüm cohort'larını al
      final cohorts = await CampfireService.getUserCohorts();
      
      // Her cohort için aktif session'ı kontrol et
      final sessions = <String, SessionModel?>{};
      for (final cohort in cohorts) {
        final session = await CampfireService.getCurrentSession(cohort.id);
        sessions[cohort.id] = session;
      }
      
      if (mounted) {
        setState(() {
          _userCohorts = cohorts;
          _cohortSessions = sessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToCheckIn() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CheckInScreen()),
    ).then((_) => _loadUserCohorts());
  }

  Future<void> _navigateToCohort(CohortModel cohort) async {
    final session = _cohortSessions[cohort.id];
    
    // 2-5. oturumlar için token kontrolü (ilk oturum check-in'de alındı)
    if (cohort.totalSessions > 0 && 
        (session?.status == SessionStatus.active || session?.status == SessionStatus.waiting)) {
      // Token kontrolü - dialog göster
      final canProceed = await CampfireTokenDialog.showSessionDialog(
        context, 
        cohort.totalSessions + 1,
      );
      if (!canProceed) return;
      
      // Token düş
      final tokenUsed = await TokenService.useTokensForCampfireSession();
      if (!tokenUsed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Elmas yetersiz')),
        );
        return;
      }
    }
    
    Widget targetScreen;
    
    switch (session?.status) {
      case SessionStatus.waiting:
        targetScreen = LobbyScreen(
          cohort: cohort,
          nickname: 'Katılımcı', // TODO: Cache'den gerçek nickname al
        );
        break;
      case SessionStatus.active:
      case SessionStatus.locked:
        targetScreen = SessionScreen(
          cohort: cohort,
          session: session!,
        );
        break;
      case SessionStatus.ended:
      case null:
        targetScreen = CountdownScreen(cohort: cohort);
        break;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => targetScreen),
    ).then((_) => _loadUserCohorts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        elevation: 0,
        title: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Text(
              'Kamp Ateşi',
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.terracotta,
          indicatorWeight: 3,
          labelColor: AppTheme.terracotta,
          unselectedLabelColor: Colors.white.withOpacity(0.5),
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Gruplarım'),
            Tab(text: 'Kamp Bul'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGroupsTab(),
          _buildExploreTab(),
        ],
      ),
    );
  }

  // ==================== GRUPLAR SEKMESİ ====================
  Widget _buildGroupsTab() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppTheme.terracotta,
          strokeWidth: 2,
        ),
      );
    }

    // Aktif ve dağılmış grupları ayır
    final activeGroups = _userCohorts.where((c) => c.isActive).toList();
    final dissolvedGroups = _userCohorts.where((c) => c.isDissolved).toList();

    if (_userCohorts.isEmpty) {
      return _buildEmptyGroupsState();
    }

    return RefreshIndicator(
      onRefresh: _loadUserCohorts,
      color: AppTheme.terracotta,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Aktif gruplar
          if (activeGroups.isNotEmpty) ...[
            _buildSectionHeader('Aktif Gruplar', '🔥'),
            const SizedBox(height: 12),
            ...activeGroups.map((cohort) => _buildCohortCard(cohort)),
            const SizedBox(height: 24),
          ],
          
          // Dağılmış gruplar (arşiv)
          if (dissolvedGroups.isNotEmpty) ...[
            _buildSectionHeader('Geçmiş Gruplar', '📚'),
            const SizedBox(height: 12),
            ...dissolvedGroups.map((cohort) => _buildDissolvedCohortCard(cohort)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyGroupsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.terracotta.withOpacity(0.1),
              ),
              child: const Center(
                child: Text('🪵', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Henüz bir grubun yok',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keşfet sekmesinden yeni bir gruba katılabilirsin',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _tabController.animateTo(1);
              },
              icon: const Icon(Icons.explore, size: 20),
              label: const Text('Keşfet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.terracotta,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String emoji) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCohortCard(CohortModel cohort) {
    final session = _cohortSessions[cohort.id];
    final statusInfo = _getStatusInfo(cohort, session);
    
    return GestureDetector(
      onTap: () => _navigateToCohort(cohort),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              statusInfo.color.withOpacity(0.15),
              statusInfo.color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusInfo.color.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst satır: İsim ve durum
            Row(
              children: [
                Text(statusInfo.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cohort.groupName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusInfo.text,
                        style: TextStyle(
                          color: statusInfo.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.3),
                  size: 16,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Alt satır: İstatistikler
            Row(
              children: [
                _buildMiniStat('👥', '${cohort.memberCount} üye'),
                const SizedBox(width: 16),
                _buildMiniStat('📅', '${cohort.totalSessions}/5 oturum'),
                const Spacer(),
                if (statusInfo.countdown != null)
                  _buildCountdownChip(statusInfo.countdown!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDissolvedCohortCard(CohortModel cohort) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          const Text('🪵', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cohort.groupName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${cohort.totalSessions} oturum tamamlandı',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Tamamlandı',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String emoji, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownChip(String countdown) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.terracotta.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time,
            color: AppTheme.terracotta,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            countdown,
            style: TextStyle(
              color: AppTheme.terracotta,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _StatusInfo _getStatusInfo(CohortModel cohort, SessionModel? session) {
    switch (session?.status) {
      case SessionStatus.waiting:
        return _StatusInfo(
          icon: '⏳',
          text: 'Lobi açık - Bekleniyor',
          color: Colors.amber,
          countdown: null,
        );
      case SessionStatus.active:
        return _StatusInfo(
          icon: '🔥',
          text: 'Oturum aktif!',
          color: Colors.green,
          countdown: 'Şimdi',
        );
      case SessionStatus.locked:
        return _StatusInfo(
          icon: '🔒',
          text: 'Oturum devam ediyor',
          color: Colors.orange,
          countdown: 'Devam',
        );
      case SessionStatus.ended:
      case null:
        final countdown = _formatCountdown(cohort.nextSessionTime);
        return _StatusInfo(
          icon: '🪵',
          text: 'Sonraki oturumu bekliyor',
          color: AppTheme.terracotta,
          countdown: countdown,
        );
    }
  }

  String? _formatCountdown(DateTime? nextSession) {
    if (nextSession == null) return null;
    
    final now = DateTime.now();
    final diff = nextSession.difference(now);
    
    if (diff.isNegative) return 'Hazır';
    
    if (diff.inDays > 0) {
      return '${diff.inDays}g ${diff.inHours % 24}s';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}s ${diff.inMinutes % 60}dk';
    } else {
      return '${diff.inMinutes}dk';
    }
  }

  // ==================== KEŞFET SEKMESİ ====================
  Widget _buildExploreTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // Ateş görseli
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.terracotta.withOpacity(0.3),
                  blurRadius: 50,
                  spreadRadius: 15,
                ),
              ],
            ),
            child: const Center(
              child: Text('🔥', style: TextStyle(fontSize: 70)),
            ),
          ),
          
          const SizedBox(height: 32),
          
          Text(
            'Yeni Bir Ateşe Katıl',
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Benzer deneyimler yaşayan insanlarla güvenli bir ortamda buluş. Grup terapisi formatında, AI moderatörlü oturumlar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Özellikler
          _buildFeatureItem(
            icon: '👥',
            title: 'Küçük Gruplar',
            subtitle: '3-6 kişilik samimi ortam',
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            icon: '🔒',
            title: 'Güvenli Alan',
            subtitle: 'Kapılar kilitlenir, mahremiyet korunur',
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            icon: '🤖',
            title: 'AI Moderatör',
            subtitle: 'Yapay zeka rehberliğinde oturumlar',
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            icon: '📅',
            title: '5 Oturum',
            subtitle: 'Her grup 5 oturum sürer',
          ),
          
          const SizedBox(height: 32),
          
          // Başla butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _navigateToCheckIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.terracotta,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Ateşe Katıl',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required String icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Durum bilgisi yardımcı sınıfı
class _StatusInfo {
  final String icon;
  final String text;
  final Color color;
  final String? countdown;

  _StatusInfo({
    required this.icon,
    required this.text,
    required this.color,
    this.countdown,
  });
}
