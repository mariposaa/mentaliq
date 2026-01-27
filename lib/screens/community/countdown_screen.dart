import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/cohort_model.dart';
import '../../services/campfire_service.dart';
import 'lobby_screen.dart';

/// Geri Sayım Ekranı - Countdown
/// Oturum bitti, sönmüş ateş, bir sonrakine geri sayım
class CountdownScreen extends StatefulWidget {
  final CohortModel cohort;

  const CountdownScreen({super.key, required this.cohort});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> with SingleTickerProviderStateMixin {
  Duration _remainingTime = Duration.zero;
  Timer? _timer;
  bool _canEnterLobby = false;
  CohortModel? _currentCohort;
  late AnimationController _emberController;

  @override
  void initState() {
    super.initState();
    _currentCohort = widget.cohort;
    
    _emberController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    _watchCohort();
    _startCountdown();
  }

  void _watchCohort() {
    CampfireService.watchCohort(widget.cohort.id).listen((cohort) {
      if (cohort != null && mounted) {
        setState(() => _currentCohort = cohort);
        _updateRemainingTime();
      }
    });
  }

  void _startCountdown() {
    _updateRemainingTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemainingTime();
    });
  }

  void _updateRemainingTime() {
    final nextSession = _currentCohort?.nextSessionTime;
    if (nextSession == null) {
      setState(() {
        _remainingTime = Duration.zero;
        _canEnterLobby = false;
      });
      return;
    }

    final now = DateTime.now();
    final difference = nextSession.difference(now);
    
    setState(() {
      _remainingTime = difference.isNegative ? Duration.zero : difference;
      _canEnterLobby = difference.inMinutes <= 10;
    });
  }

  void _enterLobby() {
    // TODO: Nickname'i bir yerden almamız gerekiyor
    // Şimdilik varsayılan isim
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LobbyScreen(
          cohort: _currentCohort!,
          nickname: 'Katılımcı', // Gerçek uygulamada cached nickname
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emberController.dispose();
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
            
            const Spacer(flex: 1),
            
            // Dairesel sönmüş ateş
            _buildEmberCircle(screenSize),
            
            const SizedBox(height: 40),
            
            // Geri sayım
            _buildCountdown(),
            
            const SizedBox(height: 24),
            
            // Grup bilgisi
            _buildGroupInfo(),
            
            const Spacer(flex: 2),
            
            // Lobiye giriş butonu
            if (_canEnterLobby) _buildEnterButton(),
            
            const SizedBox(height: 24),
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
            child: Text(
              _currentCohort?.groupName ?? 'Grup',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildEmberCircle(Size screenSize) {
    final circleRadius = screenSize.width * 0.28;
    const logSize = 45.0;
    const totalLogs = 7;
    final memberCount = _currentCohort?.memberCount ?? 0;
    
    return SizedBox(
      width: circleRadius * 2 + logSize,
      height: circleRadius * 2 + logSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sönmüş ateş - köz halinde
          AnimatedBuilder(
            animation: _emberController,
            builder: (context, child) {
              final glowIntensity = 0.1 + (_emberController.value * 0.08);
              
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(glowIntensity),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.red.withOpacity(glowIntensity * 0.5),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Köz efekti
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.orange.withOpacity(0.3),
                            Colors.red.withOpacity(0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Text(
                      '🪵',
                      style: TextStyle(
                        fontSize: 35,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Kütükler (soluk)
          ...List.generate(totalLogs, (index) {
            final angle = (index * 2 * pi / totalLogs) - (pi / 2);
            final x = cos(angle) * circleRadius;
            final y = sin(angle) * circleRadius;
            
            final isAI = index == 0;
            final memberIndex = index - 1;
            final hasMember = !isAI && memberIndex < memberCount;
            
            return Positioned(
              left: circleRadius + x - logSize / 2 + logSize / 2,
              top: circleRadius + y - logSize / 2 + logSize / 2,
              child: _buildLog(
                isAI: isAI,
                hasMember: hasMember,
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
    required double logSize,
  }) {
    // Tüm kütükler soluk
    final opacity = 0.3;
    
    Color bgColor;
    Color borderColor;
    Widget content;
    
    if (isAI) {
      bgColor = AppTheme.terracotta.withOpacity(0.1);
      borderColor = AppTheme.terracotta.withOpacity(0.2);
      content = Text(
        '🔥',
        style: TextStyle(
          fontSize: 18,
          color: Colors.white.withOpacity(opacity),
        ),
      );
    } else if (hasMember) {
      bgColor = Colors.white.withOpacity(0.05);
      borderColor = Colors.white.withOpacity(0.15);
      content = Text(
        '👤',
        style: TextStyle(
          fontSize: 18,
          color: Colors.white.withOpacity(opacity),
        ),
      );
    } else {
      bgColor = Colors.white.withOpacity(0.02);
      borderColor = Colors.white.withOpacity(0.05);
      content = Icon(
        Icons.person_outline,
        color: Colors.white.withOpacity(0.1),
        size: 18,
      );
    }
    
    return Container(
      width: logSize,
      height: logSize,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Center(child: content),
    );
  }

  Widget _buildCountdown() {
    if (_remainingTime == Duration.zero && _currentCohort?.nextSessionTime == null) {
      return Column(
        children: [
          Text(
            'Sonraki oturum planlanmadı',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
        ],
      );
    }

    final hours = _remainingTime.inHours;
    final minutes = _remainingTime.inMinutes % 60;
    final seconds = _remainingTime.inSeconds % 60;

    return Column(
      children: [
        Text(
          'Ateşin tekrar yanmasına',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTimeBox(hours.toString().padLeft(2, '0'), 'Saat'),
            _buildTimeSeparator(),
            _buildTimeBox(minutes.toString().padLeft(2, '0'), 'Dakika'),
            _buildTimeSeparator(),
            _buildTimeBox(seconds.toString().padLeft(2, '0'), 'Saniye'),
          ],
        ),
        
        if (_canEnterLobby)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Text(
                'Lobiye girebilirsin!',
                style: TextStyle(
                  color: Colors.green.shade300,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTimeSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        ':',
        style: TextStyle(
          color: AppTheme.terracotta.withOpacity(0.6),
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTimeBox(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: AppTheme.terracotta,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildGroupInfo() {
    final totalSessions = _currentCohort?.totalSessions ?? 0;
    final maxSessions = 5;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoItem('👥', '${_currentCohort?.memberCount ?? 0}', 'Üye'),
              Container(
                width: 1,
                height: 30,
                color: Colors.white.withOpacity(0.1),
              ),
              _buildInfoItem('🔥', '$totalSessions / $maxSessions', 'Oturum'),
            ],
          ),
          
          // Oturum progress bar
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalSessions / maxSessions,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.terracotta.withOpacity(0.7)),
              minHeight: 4,
            ),
          ),
          
          if (totalSessions >= maxSessions - 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                totalSessions >= maxSessions 
                    ? 'Bu grup son oturumunu tamamladı'
                    : 'Son oturuma yaklaşıyorsunuz',
                style: TextStyle(
                  color: Colors.orange.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildEnterButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _enterLobby,
          icon: const Icon(Icons.login_rounded, size: 20),
          label: const Text('Lobiye Gir'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.terracotta,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
