import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../config/app_theme.dart';
import '../../models/cohort_model.dart';
import '../../models/session_model.dart';
import '../../models/campfire_message.dart';
import '../../services/campfire_service.dart';
import '../../services/campfire_ai_service.dart';
import '../../services/token_service.dart';
import 'countdown_screen.dart';

/// Aktif Oturum Ekranı - Dairesel Kamp Ateşi
/// Ortada ateş, etrafında 7 kütük (6 kullanıcı + 1 AI)
class SessionScreen extends StatefulWidget {
  final CohortModel cohort;
  final SessionModel session;

  const SessionScreen({
    super.key,
    required this.cohort,
    required this.session,
  });

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> with TickerProviderStateMixin {
  // Sabit süreler
  static const Duration _lockDuration = Duration(minutes: 10);
  static const Duration _sessionDuration = Duration(minutes: 30);
  static const Duration _midSessionTime = Duration(minutes: 15);
  static const Duration _bubbleVisibleDuration = Duration(seconds: 10);
  
  // Odun atma maliyeti
  static const int _woodCost = 3;
  
  final TextEditingController _messageController = TextEditingController();
  
  // Speech to Text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _speechText = '';
  
  // Animasyon kontrolcüleri
  late AnimationController _fireController;
  late AnimationController _woodBurstController;
  
  List<CampfireMessage> _messages = [];
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _sessionSubscription;
  SessionModel? _currentSession;
  
  // Timers
  Timer? _lockTimer;
  Timer? _sessionEndTimer;
  Timer? _aiSilenceTimer;
  Timer? _midSessionTimer;
  Timer? _groupDynamicsTimer;
  Timer? _bubbleTimer;
  
  Duration _remainingLockTime = _lockDuration;
  Duration _remainingSessionTime = _sessionDuration;
  bool _openingGenerated = false;
  bool _midSessionCheckInDone = false;
  
  // Aktif konuşma balonu
  CampfireMessage? _activeBubbleMessage;
  List<CampfireMessage> _lastThreeMessages = [];
  bool _showExpandedBubbles = false;
  
  // Ateş harlama
  int _woodCount = 0;
  bool _isWoodBursting = false;

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session;
    
    // Animasyon kontrolcüleri
    _fireController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _woodBurstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _initSpeech();
    _watchMessages();
    _watchSession();
    _startLockTimer();
    _startSessionEndTimer();
    _startAIListener();
    _startMidSessionTimer();
    _startGroupDynamicsTimer();
    _generateOpeningMessage();
    
    // Aktif session'a katıl (sadece ilk kez katılanlar için hoş geldin mesajı)
    if (widget.session.status == SessionStatus.active || 
        widget.session.status == SessionStatus.locked) {
      _joinActiveSessionIfNeeded();
    }
  }

  /// Aktif session'a katıl (sadece ilk kez katılanlar için)
  Future<void> _joinActiveSessionIfNeeded() async {
    // Nickname'i bir yerden al (şimdilik placeholder)
    final nickname = 'Katılımcı'; // TODO: Cache'den gerçek nickname al
    
    await CampfireService.joinActiveSession(
      cohortId: widget.cohort.id,
      sessionId: widget.session.id,
      participantName: nickname,
    );
  }

  void _initSpeech() async {
    try {
      await _speech.initialize();
    } catch (e) {
      debugPrint('Speech init error: $e');
    }
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      var status = await Permission.microphone.request();
      if (status.isDenied) return;

      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'notListening' || val == 'done') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
              if (_messageController.text.isNotEmpty) {
                Future.delayed(const Duration(milliseconds: 500), () => _sendMessage());
              }
            }
          }
        },
        onError: (val) => debugPrint('onError: $val'),
      );
      if (available) {
        setState(() {
          _isListening = true;
          _speechText = '';
        });
        _speech.listen(
          localeId: 'tr_TR',
          onResult: (val) => setState(() {
            _speechText = val.recognizedWords;
            if (val.recognizedWords.isNotEmpty) {
              _messageController.text = val.recognizedWords;
            }
          }),
        );
      }
    } else {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  Future<void> _generateOpeningMessage() async {
    if (_openingGenerated) return;
    _openingGenerated = true;
    
    final participantNames = widget.cohort.members
        .map((id) => 'Katılımcı')
        .toList();
    
    await CampfireAIService.generateSessionOpening(
      cohortId: widget.cohort.id,
      sessionId: widget.session.id,
      cohort: widget.cohort,
      participantNames: participantNames,
    );
  }

  void _startMidSessionTimer() {
    _midSessionTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted || _midSessionCheckInDone) {
        timer.cancel();
        return;
      }
      
      final startedAt = _currentSession?.startedAt ?? DateTime.now();
      
      final elapsed = DateTime.now().difference(startedAt);
      
      if (elapsed >= _midSessionTime && !_midSessionCheckInDone) {
        _midSessionCheckInDone = true;
        timer.cancel();
        
        await CampfireAIService.generateMidSessionCheckIn(
          cohortId: widget.cohort.id,
          sessionId: widget.session.id,
          cohort: widget.cohort,
          messages: _messages,
        );
      }
    });
  }

  void _startGroupDynamicsTimer() {
    _groupDynamicsTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      if (!mounted || _messages.isEmpty) return;
      
      final allParticipantNames = _messages
          .where((m) => !m.isAI && m.type == MessageType.message)
          .map((m) => m.senderName)
          .toSet()
          .toList();
      
      await CampfireAIService.checkQuietMembers(
        cohortId: widget.cohort.id,
        sessionId: widget.session.id,
        cohort: widget.cohort,
        messages: _messages,
        allParticipantNames: allParticipantNames,
      );
      
      await CampfireAIService.checkDominantMember(
        cohortId: widget.cohort.id,
        sessionId: widget.session.id,
        cohort: widget.cohort,
        messages: _messages,
      );
    });
  }

  void _watchMessages() {
    _messagesSubscription = CampfireService.watchMessages(
      widget.cohort.id,
      widget.session.id,
    ).listen((messages) {
      if (mounted) {
        final oldCount = _messages.length;
        setState(() {
          _messages = messages;
          // Son 3 mesajı güncelle
          _lastThreeMessages = messages.length > 3 
              ? messages.sublist(messages.length - 3) 
              : messages;
        });
        
        // Yeni mesaj geldi
        if (messages.length > oldCount && messages.isNotEmpty) {
          final newMessage = messages.last;
          _showBubble(newMessage);
          _handleNewMessage(newMessage);
        }
      }
    });
  }

  void _showBubble(CampfireMessage message) {
    _bubbleTimer?.cancel();
    setState(() {
      _activeBubbleMessage = message;
      _showExpandedBubbles = false;
    });
    
    // 10 saniye sonra kapat
    _bubbleTimer = Timer(_bubbleVisibleDuration, () {
      if (mounted) {
        setState(() => _activeBubbleMessage = null);
      }
    });
  }

  void _handleNewMessage(CampfireMessage message) async {
    if (message.isAI) return;
    
    await CampfireAIService.checkCriticalKeywords(
      cohortId: widget.cohort.id,
      sessionId: widget.session.id,
      cohort: widget.cohort,
      message: message,
      messages: _messages,
    );
    
    await CampfireAIService.checkConflict(
      cohortId: widget.cohort.id,
      sessionId: widget.session.id,
      cohort: widget.cohort,
      message: message,
      messages: _messages,
    );
    
    await CampfireAIService.checkDestructiveMessage(
      cohortId: widget.cohort.id,
      sessionId: widget.session.id,
      cohort: widget.cohort,
      message: message,
      messages: _messages,
    );
    
    await CampfireAIService.checkPeriodicIntervention(
      cohortId: widget.cohort.id,
      sessionId: widget.session.id,
      cohort: widget.cohort,
      messages: _messages,
    );
  }

  void _startAIListener() {
    _aiSilenceTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_messages.isNotEmpty && mounted) {
        await CampfireAIService.checkSilence(
          cohortId: widget.cohort.id,
          sessionId: widget.session.id,
          cohort: widget.cohort,
          messages: _messages,
        );
      }
    });
  }

  void _watchSession() {
    _sessionSubscription = CampfireService.watchSession(
      widget.cohort.id,
      widget.session.id,
    ).listen((session) {
      if (session != null && mounted) {
        setState(() => _currentSession = session);
        
        if (session.status == SessionStatus.ended) {
          _navigateToCountdown();
        }
      }
    });
  }

  void _startLockTimer() {
    if (_currentSession?.status != SessionStatus.active) return;
    
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final startedAt = _currentSession?.startedAt ?? DateTime.now();
      
      final elapsed = DateTime.now().difference(startedAt);
      final remaining = _lockDuration - elapsed;
      
      if (remaining.isNegative) {
        timer.cancel();
        _lockSession();
      } else {
        setState(() => _remainingLockTime = remaining);
      }
    });
  }

  void _startSessionEndTimer() {
    _sessionEndTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final startedAt = _currentSession?.startedAt ?? DateTime.now();
      
      final elapsed = DateTime.now().difference(startedAt);
      final remaining = _sessionDuration - elapsed;
      
      if (remaining.isNegative) {
        timer.cancel();
        _endSession();
      } else {
        setState(() => _remainingSessionTime = remaining);
      }
    });
  }

  Future<void> _endSession() async {
    if (_currentSession?.status == SessionStatus.locked || 
        _currentSession?.status == SessionStatus.active) {
      await CampfireService.endSession(widget.cohort.id, widget.session.id);
    }
  }

  Future<void> _lockSession() async {
    if (_currentSession?.status == SessionStatus.active) {
      await CampfireService.lockSession(widget.cohort.id, widget.session.id);
    }
  }

  void _navigateToCountdown() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CountdownScreen(cohort: widget.cohort),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    
    _messageController.clear();
    
    await CampfireService.sendUserMessage(
      cohortId: widget.cohort.id,
      sessionId: widget.session.id,
      content: content,
    );
  }

  /// Odun at (3 elmas)
  Future<void> _addWood() async {
    // Elmas kontrolü
    final balance = await TokenService.getBalance();
    if (balance < _woodCost) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elmas yetersiz'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Elmas düş
    await TokenService.useTokensForTest(_woodCost);
    
    // Harlama animasyonu
    setState(() {
      _woodCount++;
      _isWoodBursting = true;
    });
    
    _woodBurstController.forward().then((_) {
      _woodBurstController.reset();
      if (mounted) {
        setState(() => _isWoodBursting = false);
      }
    });
    
    // Firestore'a kaydet
    await CampfireService.sendLobbyInteraction(
      cohortId: widget.cohort.id,
      sessionId: widget.session.id,
      type: 'wood',
    );
  }

  /// Kütüğe tıklandığında o kişinin mesajlarını göster
  void _onLogTapped({required bool isAI, String? memberName}) {
    // O kişinin mesajlarını filtrele
    List<CampfireMessage> personMessages;
    String title;
    
    if (isAI) {
      personMessages = _messages.where((m) => m.isAI).toList();
      title = '🔥 Ateş Bekçisi';
    } else if (memberName != null) {
      personMessages = _messages
          .where((m) => !m.isAI && m.senderName == memberName)
          .toList();
      title = '👤 $memberName';
    } else {
      return; // Boş kütük
    }
    
    if (personMessages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAI ? 'Bekçi henüz konuşmadı' : 'Bu kişi henüz mesaj yazmadı'),
          backgroundColor: Colors.grey.shade800,
        ),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isAI ? AppTheme.terracotta : Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${personMessages.length} mesaj',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: personMessages.length,
                itemBuilder: (context, index) {
                  final message = personMessages[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isAI 
                          ? AppTheme.terracotta.withOpacity(0.1)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ateşe tıklayınca mesaj geçmişi
  void _showMessageHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sohbet Geçmişi',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _buildHistoryMessage(message);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryMessage(CampfireMessage message) {
    final isAI = message.isAI;
    final isSystem = message.type == MessageType.system;
    
    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        child: Text(
          message.content,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isAI 
                  ? AppTheme.terracotta.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isAI
                  ? const Text('🔥', style: TextStyle(fontSize: 14))
                  : Text(
                      message.senderName.isNotEmpty 
                          ? message.senderName[0].toUpperCase() 
                          : '?',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderName,
                  style: TextStyle(
                    color: isAI ? AppTheme.terracotta : Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  message.content,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    height: 1.3,
                  ),
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _fireController.dispose();
    _woodBurstController.dispose();
    _messagesSubscription?.cancel();
    _sessionSubscription?.cancel();
    _lockTimer?.cancel();
    _sessionEndTimer?.cancel();
    _aiSilenceTimer?.cancel();
    _midSessionTimer?.cancel();
    _groupDynamicsTimer?.cancel();
    _bubbleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = _currentSession?.status == SessionStatus.locked;
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            _buildAppBar(isLocked),
            
            // Durum banner'ı
            if (!isLocked) _buildLockCountdown(),
            if (isLocked) _buildLockedBanner(),
            
            // Ana alan - Dairesel kamp ateşi
            Expanded(
              child: Stack(
                children: [
                  // Kamp ateşi ve kütükler
                  Center(
                    child: _buildCampfireCircle(screenSize),
                  ),
                  
                  // Aktif konuşma balonu
                  if (_activeBubbleMessage != null)
                    _buildActiveBubble(),
                ],
              ),
            ),
            
            // Input alanı
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isLocked) {
    final minutes = _remainingSessionTime.inMinutes;
    final seconds = _remainingSessionTime.inSeconds % 60;
    
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} kaldı',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Odun at butonu
          GestureDetector(
            onTap: _addWood,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.terracotta.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.terracotta.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🪵', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    '$_woodCost',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(' 💎', style: TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockCountdown() {
    final minutes = _remainingLockTime.inMinutes;
    final seconds = _remainingLockTime.inSeconds % 60;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: AppTheme.terracotta.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_open, color: AppTheme.terracotta, size: 14),
          const SizedBox(width: 6),
          Text(
            'Kapı açık: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: AppTheme.terracotta,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: Colors.green.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock, color: Colors.green, size: 14),
          const SizedBox(width: 6),
          Text(
            'Kapılar kilitlendi',
            style: TextStyle(
              color: Colors.green.shade300,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampfireCircle(Size screenSize) {
    // Ekran boyutuna göre dinamik ayarla
    final availableHeight = screenSize.height * 0.5;
    final maxRadius = (availableHeight - 100) / 2;
    final circleRadius = (screenSize.width * 0.28).clamp(80.0, maxRadius);
    final logSize = 45.0;
    
    // 7 kütük: 1 AI (üstte) + 6 kullanıcı
    final totalLogs = 7;
    final members = widget.cohort.members;
    
    return SizedBox(
      width: circleRadius * 2 + logSize,
      height: circleRadius * 2 + logSize,
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
          // Ortadaki ateş
          GestureDetector(
            onTap: _showMessageHistory,
            child: AnimatedBuilder(
              animation: Listenable.merge([_fireController, _woodBurstController]),
              builder: (context, child) {
                final baseGlow = 0.3 + (_fireController.value * 0.2);
                final woodBoost = _woodCount * 0.03;
                final burstBoost = _isWoodBursting ? _woodBurstController.value * 0.5 : 0.0;
                final glowIntensity = (baseGlow + woodBoost + burstBoost).clamp(0.3, 1.0);
                final scale = 1.0 + (_isWoodBursting ? _woodBurstController.value * 0.3 : 0.0);
                
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(glowIntensity * 0.6),
                          blurRadius: 40 + (_woodCount * 5) + (burstBoost * 30),
                          spreadRadius: 15 + (_woodCount * 2) + (burstBoost * 20),
                        ),
                        BoxShadow(
                          color: Colors.red.withOpacity(glowIntensity * 0.3),
                          blurRadius: 60 + (_woodCount * 8),
                          spreadRadius: 25 + (_woodCount * 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '🔥',
                        style: TextStyle(
                          fontSize: 50 + (_woodCount * 2) + (burstBoost * 15),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Kütükler
          ...List.generate(totalLogs, (index) {
            // Açı hesapla (üstten başla, saat yönünde)
            final angle = (index * 2 * pi / totalLogs) - (pi / 2);
            final x = cos(angle) * circleRadius;
            final y = sin(angle) * circleRadius;
            
            // İlk kütük AI (Ateş Bekçisi)
            final isAI = index == 0;
            final memberIndex = index - 1;
            final hasMember = !isAI && memberIndex < members.length;
            final isEmpty = !isAI && !hasMember;
            
            String? memberName;
            if (hasMember) {
              // Gerçek isim için user service kullanılabilir
              memberName = 'Katılımcı ${memberIndex + 1}';
            }
            
            return Positioned(
              left: circleRadius + x - logSize / 2 + logSize / 2,
              top: circleRadius + y - logSize / 2 + logSize / 2,
              child: GestureDetector(
                onTap: () => _onLogTapped(
                  isAI: isAI,
                  memberName: memberName,
                ),
                child: _buildLog(
                  isAI: isAI,
                  isEmpty: isEmpty,
                  memberName: memberName,
                  logSize: logSize,
                ),
              ),
            );
          }),
        ],
        ),
      ),
    );
  }

  Widget _buildLog({
    required bool isAI,
    required bool isEmpty,
    String? memberName,
    required double logSize,
  }) {
    Color bgColor;
    Color borderColor;
    Widget content;
    
    if (isAI) {
      bgColor = AppTheme.terracotta.withOpacity(0.3);
      borderColor = AppTheme.terracotta;
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 2),
          Text(
            'Ateş\nBekçisi',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.terracotta,
              fontSize: 7,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else if (isEmpty) {
      bgColor = Colors.white.withOpacity(0.05);
      borderColor = Colors.white.withOpacity(0.1);
      content = Icon(
        Icons.person_outline,
        color: Colors.white.withOpacity(0.2),
        size: 24,
      );
    } else {
      bgColor = Colors.white.withOpacity(0.1);
      borderColor = Colors.white.withOpacity(0.3);
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            memberName?.isNotEmpty == true 
                ? memberName![0].toUpperCase() 
                : '?',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (memberName != null)
            Text(
              memberName.split(' ').last,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 8,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
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

  Widget _buildActiveBubble() {
    if (_activeBubbleMessage == null) return const SizedBox.shrink();
    
    final message = _activeBubbleMessage!;
    final inputAreaHeight = 80.0; // Input area yüksekliği
    
    return Positioned(
      bottom: inputAreaHeight + 10,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: () {
          setState(() => _showExpandedBubbles = !_showExpandedBubbles);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.25,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Genişletilmiş son 3 mesaj
                if (_showExpandedBubbles)
                  ..._lastThreeMessages.map((m) => _buildBubbleItem(m, small: true)),
                
                // Aktif mesaj
                if (!_showExpandedBubbles)
                  _buildBubbleItem(message, small: false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubbleItem(CampfireMessage message, {required bool small}) {
    final isAI = message.isAI;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(small ? 10 : 14),
      decoration: BoxDecoration(
        color: isAI 
            ? AppTheme.terracotta.withOpacity(0.2)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAI 
              ? AppTheme.terracotta.withOpacity(0.4)
              : Colors.white.withOpacity(0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: small ? 28 : 36,
            height: small ? 28 : 36,
            decoration: BoxDecoration(
              color: isAI 
                  ? AppTheme.terracotta.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isAI
                  ? Text('🔥', style: TextStyle(fontSize: small ? 14 : 18))
                  : Text(
                      message.senderName.isNotEmpty 
                          ? message.senderName[0].toUpperCase() 
                          : '?',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: small ? 12 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderName,
                  style: TextStyle(
                    color: isAI ? AppTheme.terracotta : Colors.white54,
                    fontSize: small ? 10 : 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  message.content,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: small ? 12 : 14,
                    height: 1.3,
                  ),
                  maxLines: small ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
          // Mikrofon butonu
          GestureDetector(
            onTap: _toggleListening,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isListening 
                    ? Colors.red.withOpacity(0.3)
                    : Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? Colors.red : Colors.white54,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E), // Koyu arka plan
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                cursorColor: AppTheme.terracotta,
                decoration: InputDecoration(
                  hintText: _isListening ? 'Dinleniyor...' : 'Mesajını yaz...',
                  hintStyle: TextStyle(
                    color: _isListening 
                        ? Colors.red.withOpacity(0.5)
                        : Colors.white.withOpacity(0.4),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  filled: false,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.terracotta,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
