import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import '../../models/cohort_model.dart';
import '../../models/session_model.dart';
import '../../services/campfire_service.dart';
import 'session_screen.dart';

/// Bekleme Salonu - Lobby
/// Dairesel tasarım: Sönük ateş, etrafında kütükler
class LobbyScreen extends StatefulWidget {
  final CohortModel cohort;
  final String nickname;

  const LobbyScreen({
    super.key,
    required this.cohort,
    required this.nickname,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with TickerProviderStateMixin {
  // Lobby timeout süresi (30 dakika)
  static const Duration _lobbyTimeout = Duration(minutes: 30);
  
  SessionModel? _session;
  CohortModel? _currentCohort;
  StreamSubscription? _sessionSubscription;
  StreamSubscription? _cohortSubscription;
  StreamSubscription? _interactionsSubscription;
  
  late AnimationController _fireController;
  late AnimationController _woodAnimController;
  late AnimationController _pulseController;
  
  Timer? _timeoutTimer;
  int _currentMemberCount = 0;
  int _woodCount = 0;
  List<String> _recentInteractions = [];
  Duration _remainingTime = _lobbyTimeout;

  @override
  void initState() {
    super.initState();
    _currentCohort = widget.cohort;
    _currentMemberCount = widget.cohort.memberCount;
    
    _fireController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    
    _woodAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _loadSession();
    _watchCohort();
    _startTimeoutTimer();
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final remaining = _remainingTime - const Duration(seconds: 1);
      
      if (remaining.isNegative) {
        timer.cancel();
        _handleTimeout();
      } else {
        setState(() => _remainingTime = remaining);
      }
    });
  }

  void _handleTimeout() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Bekleme Süresi Doldu',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Maalesef 30 dakika içinde yeterli katılımcı bulunamadı. Daha sonra tekrar deneyebilirsin.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              'Tamam',
              style: TextStyle(color: AppTheme.terracotta),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSession() async {
    final session = await CampfireService.getCurrentSession(widget.cohort.id);
    if (session != null && mounted) {
      setState(() => _session = session);
      _watchSession(session.id);
      _watchInteractions(session.id);
      await CampfireService.joinLobby(widget.cohort.id, session.id);
    }
  }

  void _watchInteractions(String sessionId) {
    _interactionsSubscription = CampfireService.watchLobbyInteractions(
      widget.cohort.id,
      sessionId,
    ).listen((interactions) {
      if (mounted) {
        setState(() {
          _woodCount = interactions['woodCount'] ?? 0;
          _recentInteractions = List<String>.from(interactions['recent'] ?? []);
        });
      }
    });
  }

  Future<void> _sendSelam() async {
    if (_session == null) return;
    await CampfireService.sendLobbyInteraction(
      cohortId: widget.cohort.id,
      sessionId: _session!.id,
      type: 'selam',
    );
  }

  Future<void> _addWood() async {
    if (_session == null) return;
    _woodAnimController.forward().then((_) => _woodAnimController.reset());
    await CampfireService.sendLobbyInteraction(
      cohortId: widget.cohort.id,
      sessionId: _session!.id,
      type: 'wood',
    );
  }

  void _watchCohort() {
    _cohortSubscription = CampfireService.watchCohort(widget.cohort.id).listen((cohort) async {
      if (cohort != null && mounted) {
        setState(() {
          _currentMemberCount = cohort.memberCount;
          _currentCohort = cohort;
        });
        
        if (cohort.memberCount >= 3 && _session?.status == SessionStatus.waiting) {
          _startSession();
        }
      }
    });
  }

  void _watchSession(String sessionId) {
    _sessionSubscription = CampfireService.watchSession(widget.cohort.id, sessionId).listen((session) {
      if (session != null && mounted) {
        setState(() => _session = session);
        
        if (session.status == SessionStatus.active || session.status == SessionStatus.locked) {
          _navigateToSession();
        }
      }
    });
  }

  Future<void> _startSession() async {
    if (_session == null) return;
    await CampfireService.startSession(widget.cohort.id, _session!.id);
  }

  void _navigateToSession() {
    if (_session == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SessionScreen(
          cohort: _currentCohort ?? widget.cohort,
          session: _session!,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fireController.dispose();
    _woodAnimController.dispose();
    _pulseController.dispose();
    _sessionSubscription?.cancel();
    _cohortSubscription?.cancel();
    _interactionsSubscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            _buildAppBar(),
            
            // Kalan süre ve durum
            _buildStatusBar(),
            
            // Ana alan - Dairesel kamp ateşi
            Expanded(
              child: Center(
                child: _buildCampfireCircle(screenSize),
              ),
            ),
            
            // Etkileşim butonları
            _buildInteractionButtons(),
            
            // Son etkileşimler
            if (_recentInteractions.isNotEmpty) 
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: _buildRecentInteractions(),
              ),
            
            // Alt bilgi
            _buildBottomInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white54),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.cohort.groupName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Takma adın: ${widget.nickname}',
                  style: TextStyle(
                    color: AppTheme.terracotta.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48), // Balance
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final minutes = _remainingTime.inMinutes;
    final seconds = _remainingTime.inSeconds % 60;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Kişi sayısı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('👥', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  '$_currentMemberCount / 3',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Kalan süre
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, color: Colors.white.withOpacity(0.5), size: 14),
                const SizedBox(width: 6),
                Text(
                  '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampfireCircle(Size screenSize) {
    final circleRadius = screenSize.width * 0.32;
    const logSize = 55.0;
    const totalLogs = 7; // 1 AI + 6 kullanıcı
    
    return SizedBox(
      width: circleRadius * 2 + logSize,
      height: circleRadius * 2 + logSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ortadaki sönük ateş
          AnimatedBuilder(
            animation: Listenable.merge([_fireController, _woodAnimController]),
            builder: (context, child) {
              final baseGlow = 0.15 + (_fireController.value * 0.1);
              final woodBoost = _woodCount * 0.04;
              final glowIntensity = (baseGlow + woodBoost).clamp(0.15, 0.6);
              final scale = 1.0 + (_woodAnimController.value * 0.2);
              
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(glowIntensity * 0.4),
                        blurRadius: 30 + (_woodCount * 4),
                        spreadRadius: 10 + (_woodCount * 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '🪵',
                        style: TextStyle(
                          fontSize: 40,
                          color: Colors.white.withOpacity(0.5 + glowIntensity),
                        ),
                      ),
                      if (_woodCount > 0)
                        Text(
                          '+$_woodCount',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange.withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Kütükler
          ...List.generate(totalLogs, (index) {
            final angle = (index * 2 * pi / totalLogs) - (pi / 2);
            final x = cos(angle) * circleRadius;
            final y = sin(angle) * circleRadius;
            
            final isAI = index == 0;
            final memberIndex = index - 1;
            final hasMember = !isAI && memberIndex < _currentMemberCount;
            final isMe = !isAI && memberIndex == 0; // İlk katılan ben
            
            return Positioned(
              left: circleRadius + x - logSize / 2 + logSize / 2,
              top: circleRadius + y - logSize / 2 + logSize / 2,
              child: _buildLog(
                isAI: isAI,
                hasMember: hasMember,
                isMe: isMe,
                logSize: logSize,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLog({
    required bool isAI,
    required bool hasMember,
    required bool isMe,
    required double logSize,
  }) {
    Color bgColor;
    Color borderColor;
    Widget content;
    
    if (isAI) {
      // AI kütüğü - her zaman görünür ama soluk
      bgColor = AppTheme.terracotta.withOpacity(0.15);
      borderColor = AppTheme.terracotta.withOpacity(0.3);
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '🔥',
            style: TextStyle(
              fontSize: 22,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Bekçi',
            style: TextStyle(
              color: AppTheme.terracotta.withOpacity(0.5),
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    } else if (hasMember) {
      // Dolu kütük
      bgColor = isMe 
          ? AppTheme.terracotta.withOpacity(0.25)
          : Colors.white.withOpacity(0.1);
      borderColor = isMe 
          ? AppTheme.terracotta.withOpacity(0.6)
          : Colors.white.withOpacity(0.3);
      
      content = AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = isMe ? 1.0 + (_pulseController.value * 0.05) : 1.0;
          return Transform.scale(
            scale: pulse,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isMe ? widget.nickname[0].toUpperCase() : '👤',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: isMe ? 20 : 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isMe)
                  Text(
                    'Sen',
                    style: TextStyle(
                      color: AppTheme.terracotta.withOpacity(0.8),
                      fontSize: 9,
                    ),
                  ),
              ],
            ),
          );
        },
      );
    } else {
      // Boş kütük - bekleniyor
      bgColor = Colors.white.withOpacity(0.03);
      borderColor = Colors.white.withOpacity(0.08);
      content = AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final opacity = 0.15 + (_pulseController.value * 0.1);
          return Icon(
            Icons.person_outline,
            color: Colors.white.withOpacity(opacity),
            size: 24,
          );
        },
      );
    }
    
    return Container(
      width: logSize,
      height: logSize,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: content,
    );
  }

  Widget _buildInteractionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Selam butonu
          Expanded(
            child: GestureDetector(
              onTap: _sendSelam,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('👋', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      'Selam',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Odun at butonu
          Expanded(
            child: GestureDetector(
              onTap: _addWood,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.terracotta.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.terracotta.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🪵', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      'Odun At',
                      style: TextStyle(
                        color: AppTheme.terracotta,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentInteractions() {
    return SizedBox(
      height: 28,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _recentInteractions.length,
        itemBuilder: (context, index) {
          final interaction = _recentInteractions[index];
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              interaction,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomInfo() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.terracotta.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🔥', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '3 kişi olduğumuzda ateş yanacak',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Grup tamamlanınca sohbet başlayacak',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
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
