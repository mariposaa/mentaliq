import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../services/ad_service.dart';
import '../../config/app_theme.dart';
import '../../services/user_dna_service.dart';
import '../../models/user_dna_model.dart';
import '../../services/astro_service.dart';
import '../../models/astro_model.dart';
import '../../services/token_service.dart';
import '../../services/auth_service.dart';
import '../../services/dream_service.dart';
import '../../models/dream_model.dart';
import '../../services/horoscope_service.dart';
import '../../models/horoscope_model.dart';

/// Astroloji ve Rüya Room - Kozmik HUD Tasarımı
class AstrologyDreamRoomScreen extends StatefulWidget {
  const AstrologyDreamRoomScreen({super.key});

  @override
  State<AstrologyDreamRoomScreen> createState() => _AstrologyDreamRoomScreenState();
}

class _AstrologyDreamRoomScreenState extends State<AstrologyDreamRoomScreen> 
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  late TextEditingController _dateController;
  late TextEditingController _timeController;
  late TextEditingController _locationController;
  late AstroService _astroService;
  
  bool _isSaving = false;
  bool _isLoading = true;
  bool _isAnalyzing = false;
  AstroData? _astrologyData;
  final GlobalKey _shareKey = GlobalKey();
  bool _isCapturing = false;

  // Rüya Tabiri States (Sync with MindAtelier)
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _dreamText = '';
  double _confidence = 1.0;
  bool _isDreamAnalyzing = false;
  DreamData? _dreamData;
  int _activeAnalysisTab = 0; // 0: Modern, 1: Classic

  // Günlük Yorum States
  HoroscopeData? _dailyHoroscope;
  HoroscopeData? _weeklyHoroscope;
  bool _isHoroscopeLoading = false;
  int _activeHoroscopeTab = 0; // 0: Günlük, 1: Haftalık
  String _userZodiac = 'Aries';

  // Tab tanımları
  final List<_TabInfo> _tabs = [
    _TabInfo(label: 'Astroloji', icon: Icons.auto_awesome_rounded),
    _TabInfo(label: 'Rüya Tabiri', icon: Icons.nightlight_round),
    _TabInfo(label: 'Günlük Yorum', icon: Icons.calendar_today_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _dateController = TextEditingController();
    _timeController = TextEditingController();
    _locationController = TextEditingController();
    
    // Initialize AstroService with API Key from dotenv
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    _astroService = AstroService(apiKey);
    
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Load birth info for inputs
    final dna = await UserDNAService.getDNA();
    if (dna != null) {
      setState(() {
        _dateController.text = dna.birthDate ?? '';
        _timeController.text = dna.birthTime ?? '';
        _locationController.text = dna.birthLocation ?? '';
      });
    }

    // Check if there is saved astro data for today
    final savedAstro = await _astroService.getSavedDailyAstro();
    if (savedAstro != null) {
      setState(() {
        _astrologyData = savedAstro;
      });
    }

    // Horoscope Initialization
    if (dna != null) {
      _loadHoroscopeData();
    }

    _initSpeech();
    setState(() => _isLoading = false);
  }

  void _initSpeech() async {
    try {
      await _speech.initialize();
    } catch (e) {
      debugPrint('Speech init error: $e');
    }
  }

  Future<void> _runAstrologyAnalysis() async {
    if (_dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce doğum tarihinizi girin.')),
      );
      return;
    }

    // Check tokens first
    final hasEnough = await TokenService.hasEnoughTokensForAstroHud();
    if (!hasEnough) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Yetersiz token! Kozmik HUD için 10 token gerekiyor.'),
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _astrologyData = null;
    });

    try {
      // Use tokens
      final used = await TokenService.useTokensForAstroHud();
      if (!used) throw Exception("Token kullanılamadı");

      // Sign logic (can be improved later)
      final data = await _astroService.getDailyAstro("Kullanıcı");
      
      // Save result to Firestore
      await _astroService.saveDailyAstro(data);

      setState(() {
        _astrologyData = data;
      });
    } catch (e) {
      debugPrint('Astro Service Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kozmik veriler alınırken bir hata oluştu.')),
        );
      }
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _saveData() async {
    if (_dateController.text.isEmpty || _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tarih ve yer bilgilerini giriniz.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final updates = UserDNAModel(
      birthDate: _dateController.text.trim(),
      birthTime: _timeController.text.trim(),
      birthLocation: _locationController.text.trim(),
    );
    
    final success = await UserDNAService.updateDNA(updates);
    
    if (success) {
      debugPrint('AstrologyDreamRoomScreen: DNA updated, reloading horoscope...');
      await _loadHoroscopeData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Doğum bilgileriniz güncellendi.'),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Bilgiler kaydedilemedi.'),
          ),
        );
      }
    }

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // --- Rüya Tabiri (STT Sync - Bas-Durdur) ---

  void _listen() async {
    if (!_isListening) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) return;

      bool available = await _speech.initialize(
        onStatus: (val) => debugPrint('onStatus: $val'),
        onError: (val) => debugPrint('onError: $val'),
      );
      if (available) {
        setState(() {
          _isListening = true;
          _dreamText = '';
        });
        _speech.listen(
          localeId: 'tr_TR',
          onResult: (val) => setState(() {
            _dreamText = val.recognizedWords;
            if (val.hasConfidenceRating && val.confidence > 0) {
              _confidence = val.confidence;
            }
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_dreamText.isNotEmpty) {
        // Küçük bir gecikme ile son kelimelerin yakalanmasını sağlama
        Future.delayed(const Duration(milliseconds: 500), () {
          _runDreamAnalysis();
        });
      }
    }
  }

  Future<void> _runDreamAnalysis() async {
    if (_dreamText.isEmpty) return;

    // 1. Check tokens
    final hasEnough = await TokenService.hasEnoughTokensForDream();
    if (!hasEnough) {
      _showTokenError();
      return;
    }

    // 2. Confirm payment
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Kozmik Rüya Analizi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Bu derin analiz için 20 token kullanılacak. Onaylıyor musun?', 
          style: TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('İPTAL', style: TextStyle(color: Colors.white38))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent.withOpacity(0.2),
              foregroundColor: Colors.cyanAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('EVET (20 🪙)'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDreamAnalyzing = true);

    try {
      // 3. Use tokens
      final used = await TokenService.useTokensForDream();
      if (!used) {
        setState(() => _isDreamAnalyzing = false);
        return;
      }

      // 4. Analyze with Text service
      final result = await DreamService.analyzeTextDream(_dreamText);
      if (result != null) {
        await DreamService.saveDreamResult(result);
        setState(() {
          _dreamData = result;
        });
      } else {
        throw Exception('Analiz başarısız oldu.');
      }
    } catch (e) {
      debugPrint('Dream Analysis Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rüya analiz edilirken bir sorun oluştu.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDreamAnalyzing = false);
      }
    }
  }

  void _showTokenError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3F),
        title: const Text('Token Yetersiz', style: TextStyle(color: Colors.white)),
        content: const Text('Rüya analizi için 20 token gerekiyor. Reklam izleyerek 30 token kazanmak ister misin?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İPTAL', style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isDreamAnalyzing = true);
              final earned = await AdService.showRewardedAd();
              if (earned) {
                await TokenService.addTokens(TokenService.adRewardTokens);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(backgroundColor: Colors.green, content: Text('Tebrikler! 30 Token hesabına eklendi.')),
                  );
                }
                _runDreamAnalysis(); // Jeton kazanınca tekrar dene
              } else {
                setState(() => _isDreamAnalyzing = false);
              }
            }, 
            child: const Text('İZLE (+30 🪙)', style: TextStyle(color: Colors.orangeAccent))
          ),
        ],
      ),
    );
  }

  // --- Günlük Yorum Logic ---

  Future<void> _loadHoroscopeData() async {
    debugPrint('AstrologyDreamRoomScreen: _loadHoroscopeData called');
    if (!mounted) return;
    setState(() => _isHoroscopeLoading = true);
    
    try {
      final dna = await UserDNAService.getDNA();
      debugPrint('AstrologyDreamRoomScreen: DNA: ${dna?.birthDate}, ${dna?.birthTime}, ${dna?.birthLocation}');
      
      if (dna == null || dna.birthDate == null || dna.birthDate!.isEmpty) {
        debugPrint('AstrologyDreamRoomScreen: Birth data missing');
        if (mounted) setState(() => _isHoroscopeLoading = false);
        return;
      }

      final daily = await HoroscopeService.getHoroscope(
        birthDate: dna.birthDate!,
        birthTime: dna.birthTime ?? '12:00',
        birthLocation: dna.birthLocation ?? 'Istanbul',
        isWeekly: false,
      );

      final weekly = await HoroscopeService.getHoroscope(
        birthDate: dna.birthDate!,
        birthTime: dna.birthTime ?? '12:00',
        birthLocation: dna.birthLocation ?? 'Istanbul',
        isWeekly: true,
      );

      if (mounted) {
        setState(() {
          _dailyHoroscope = daily;
          _weeklyHoroscope = weekly;
        });

        if (daily == null || weekly == null) {
          final error = HoroscopeService.lastError ?? 'Bilinmeyen bir hata oluştu.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.amber,
              content: Text('Yorumlar hazırlanamadı: $error'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Horoscope load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isHoroscopeLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F0C29), Color(0xFF302B63)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildPremiumHeader(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAstrologyTab(),
                    _buildDreamTab(),
                    _buildHoroscopeTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAstrologyTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          _buildBirthInfoCard(),
          const SizedBox(height: 24),
          if (_isAnalyzing)
            _buildAnalyzingState()
          else if (_astrologyData != null)
            _buildKozmikHUD()
          else
            _buildInitialState(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBirthInfoCard() {
    return _GlassCard(
      child: ExpansionTile(
        title: const Text('Doğum Bilgileri', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: const Icon(Icons.stars_rounded, color: Colors.cyanAccent),
        trailing: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
        childrenPadding: const EdgeInsets.all(16),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white60,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        children: [
          _buildInputField(_dateController, 'Doğum Tarihi', '12.05.1995', Icons.calendar_today),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInputField(_timeController, 'Saat', '14:30', Icons.access_time)),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _buildInputField(_locationController, 'Yer', 'İstanbul', Icons.location_on)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                foregroundColor: Colors.cyanAccent,
                side: const BorderSide(color: Colors.cyanAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('BİLGİLERİ KAYDET'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, String hint, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            prefixIcon: Icon(icon, color: Colors.white60, size: 18),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialState() {
    return _GlassCard(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.cyanAccent, size: 64),
          const SizedBox(height: 20),
          const Text('Astroloji Merkezi', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Yıldızların bugünkü konumlarını senin için inceleyelim.', 
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _runAstrologyAnalysis,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('GEZEGENLERİ TARA', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return Column(
      children: [
        CircularPercentIndicator(
          radius: 70.0,
          lineWidth: 10.0,
          percent: 0.8,
          animation: true,
          animationDuration: 1500,
          center: const Icon(Icons.sync_problem_rounded, color: Colors.cyanAccent, size: 40),
          circularStrokeCap: CircularStrokeCap.round,
          progressColor: Colors.cyanAccent,
          backgroundColor: Colors.white10,
        ),
        const SizedBox(height: 20),
        const Text('Yıldızlar İnceleniyor...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDreamTab() {
    if (_isDreamAnalyzing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.cyanAccent),
            const SizedBox(height: 20),
            Text('Rüyan Analiz Ediliyor...', 
              style: GoogleFonts.orbitron(color: Colors.cyanAccent, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 8),
            const Text('Gemini rüyanı dinliyor...', style: TextStyle(color: Colors.white30, fontSize: 11)),
          ],
        ),
      );
    }

    if (_dreamData != null) {
      return _buildDreamResultView();
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('RÜYA TABİRİ', 
            style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 4, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _listen,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _isListening ? 140 : 120,
              height: _isListening ? 140 : 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(_isListening ? 0.6 : 0.3),
                    spreadRadius: _isListening ? 20 : 10,
                    blurRadius: _isListening ? 30 : 15,
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _isListening ? (_dreamText.isEmpty ? 'Dinliyorum...' : _dreamText) : 'Rüyanı anlatmak için dokun...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isListening ? Colors.cyanAccent : Colors.white60,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                fontStyle: _isListening ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDreamResultView() {
    final data = _dreamData!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Dream Image & Mood
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  height: 240,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: Image.network(
                    'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=800&q=80', // Placeholder for image generation
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                bottom: 15,
                right: 15,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(data.moodEmoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Title & Transcription
          Text(data.dreamTitle, 
            style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Text(data.transcription, 
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic)),
          const SizedBox(height: 24),
          
          // Analysis Tabs
          Row(
            children: [
              _buildAnalysisTabItem(0, '🧠 BİLİNÇALTI', Colors.purpleAccent),
              const SizedBox(width: 12),
              _buildAnalysisTabItem(1, '📜 TABİR', Colors.amberAccent),
            ],
          ),
          const SizedBox(height: 16),
          
          _GlassCard(
            padding: const EdgeInsets.all(20),
            child: Text(
              _activeAnalysisTab == 0 ? data.modernAnalysis : data.classicTabir,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.6),
            ),
          ),
          const SizedBox(height: 30),
          
          // Reset Button
          TextButton(
            onPressed: () => setState(() => _dreamData = null),
            child: const Text('YENİ RÜYA ANLAT', style: TextStyle(color: Colors.white24)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisTabItem(int index, String label, Color color) {
    bool active = _activeAnalysisTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeAnalysisTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: active ? color : Colors.white10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? color : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHoroscopeTab() {
    if (_isHoroscopeLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
    }

    final currentData = _activeHoroscopeTab == 0 ? _dailyHoroscope : _weeklyHoroscope;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Period Switcher
          Row(
            children: [
              _buildSimpleTabItem(0, 'GÜNLÜK', Icons.today),
              const SizedBox(width: 12),
              _buildSimpleTabItem(1, 'HAFTALIK', Icons.date_range),
            ],
          ),
          const SizedBox(height: 25),

          if (currentData == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const Text('Burç yorumları şu an hazırlanamadı. Lütfen bilgilerinizi kontrol edin ve tekrar deneyin.', 
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white24)),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: _loadHoroscopeData,
                      icon: const Icon(Icons.refresh, color: Colors.purpleAccent),
                      label: const Text('YENİDEN DENE', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Sun Sign Card
            _buildSignDetailCard(
              title: 'GÜNEŞ BURCU',
              signName: currentData.sunSign,
              interpretation: currentData.sunInterpretation,
              icon: Icons.wb_sunny_rounded,
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 20),

            // Rising Sign Card
            _buildSignDetailCard(
              title: 'YÜKSELEN BURCU',
              signName: currentData.risingSign,
              interpretation: currentData.risingInterpretation,
              icon: Icons.north_east_rounded,
              color: Colors.cyanAccent,
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSignDetailCard({
    required String title,
    required String signName,
    required String interpretation,
    required IconData icon,
    required Color color,
  }) {
    return _GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, 
                    style: TextStyle(color: color.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(signName.toUpperCase(), 
                    style: GoogleFonts.orbitron(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 1,
            width: 40,
            color: color.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            interpretation,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.6,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleTabItem(int index, String label, IconData icon) {
    bool active = _activeHoroscopeTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeHoroscopeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? Colors.purpleAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: active ? Colors.purpleAccent : Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? Colors.purpleAccent : Colors.white24),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: active ? Colors.white : Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildKozmikHUD() {
    final data = _astrologyData!;
    return Column(
      children: [
        // Top: Kozmik Batarya
        CircularPercentIndicator(
          radius: 80.0,
          lineWidth: 12.0,
          percent: data.batteryLevel / 100,
          animation: true,
          center: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('%${data.batteryLevel}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const Text('Enerji', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          circularStrokeCap: CircularStrokeCap.round,
          progressColor: _getStatusColor(data.batteryLevel > 70 ? 'GREEN' : (data.batteryLevel > 40 ? 'YELLOW' : 'RED')),
          backgroundColor: Colors.white10,
        ),
        const SizedBox(height: 8),
        const Text('KOZMİK BATARYA', style: TextStyle(color: Colors.white38, letterSpacing: 2, fontSize: 10)),
        
        const SizedBox(height: 30),

        // Middle: Traffic Lights
        Row(
          children: [
            Expanded(child: _buildTrafficCard('Aşk', Icons.favorite, data.trafficLights['love'] ?? 'YELLOW', data.trafficComments['love'] ?? '')),
            const SizedBox(width: 10),
            Expanded(child: _buildTrafficCard('İş', Icons.work, data.trafficLights['career'] ?? 'YELLOW', data.trafficComments['career'] ?? '')),
            const SizedBox(width: 10),
            Expanded(child: _buildTrafficCard('Enerji', Icons.bolt, data.trafficLights['energy'] ?? 'YELLOW', data.trafficComments['energy'] ?? '')),
          ],
        ),

        const SizedBox(height: 30),

        // Info Panel
        Row(
          children: [
            Expanded(child: _buildInfoCard('🕒 GÜÇ SAATİ', data.powerHour, color: Colors.amberAccent)),
          ],
        ),
        const SizedBox(height: 12),
        _buildTotemCard(data.totemEmoji, data.totemName),
        const SizedBox(height: 12),
        _buildMottoCard(data.motto),

        const SizedBox(height: 30),

        // Bottom: Mission Button & Share
        _buildMissionButton(data.mission),
        const SizedBox(height: 16),
        _buildShareButton(),
        
        // Hidden share card for capture (Must be painted for capture, so we use IgnorePointer + very low opacity)
        IgnorePointer(
          child: Opacity(
            opacity: 0.01,
            child: RepaintBoundary(
              key: _shareKey,
              child: _KozmikShareCard(data: data),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrafficCard(String title, IconData icon, String status, String comment) {
    final color = _getStatusColor(status);
    return InkWell(
      onTap: () => _showCommentDialog(title, comment, color),
      child: _GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _showCommentDialog(String title, String comment, Color color) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A3F).withOpacity(0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: color.withOpacity(0.5))),
          title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          content: Text(comment, style: const TextStyle(color: Colors.white, fontSize: 16)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('KAPAT', style: TextStyle(color: Colors.white60))),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String content, {Color color = Colors.white}) {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTotemCard(String emoji, String name) {
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('GÜNÜN TOTEMİ', style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMottoCard(String motto) {
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text('"$motto"', 
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            color: Colors.white, 
            fontSize: 18, 
            fontStyle: FontStyle.italic, 
            fontWeight: FontWeight.w500,
          )),
      ),
    );
  }

  Widget _buildMissionButton(String mission) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurpleAccent.withOpacity(0.4), 
            blurRadius: 20, 
            spreadRadius: 2,
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.05),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), 
            side: BorderSide(color: Colors.deepPurpleAccent.withOpacity(0.5), width: 1.5),
          ),
        ),
        child: Column(
          children: [
            const Text(
              'GÜNÜN MİSYONU', 
              style: TextStyle(
                color: Colors.cyanAccent, 
                fontSize: 10, 
                fontWeight: FontWeight.bold, 
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mission, 
              textAlign: TextAlign.center, 
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'GREEN': return Colors.greenAccent;
      case 'YELLOW': return Colors.amberAccent;
      case 'RED': return Colors.pinkAccent;
      default: return Colors.white60;
    }
  }

  Widget _buildPremiumHeader() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/astrology_dream.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.5),
                      Colors.transparent,
                      Colors.transparent,
                      const Color(0xFF0F0C29).withOpacity(0.8),
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
                  color: Colors.purpleAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('🌙', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Astroloji ve Rüya',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Yıldız ve Rüya Analizleri',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.radar_rounded, color: Colors.cyanAccent),
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
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(color: Colors.cyanAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.cyanAccent)),
        labelColor: Colors.cyanAccent,
        unselectedLabelColor: Colors.white38,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
      ),
    );
  }

  Widget _buildEmptyTab(String message) {
    return Center(child: Text(message, style: const TextStyle(color: Colors.white38)));
  }

  Widget _buildShareButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _isCapturing ? null : _captureAndShare,
        icon: _isCapturing 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
          : const Icon(Icons.share_rounded, color: Colors.cyanAccent),
        label: Text(_isCapturing ? 'LÜTFEN BEKLE...' : 'ANALİZİ PAYLAŞ', 
          style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 1)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.cyanAccent.withOpacity(0.3)),
          ),
        ),
      ),
    );
  }

  Future<void> _captureAndShare() async {
    try {
      setState(() => _isCapturing = true);

      // Give a tiny delay to ensure the IgnorePointer/Opacity 0.01 widget is built and ready for paint
      await Future.delayed(const Duration(milliseconds: 100));

      // 1. Check if already generated today
      bool alreadyPaid = await _astroService.isCardGeneratedToday();
      
      if (!alreadyPaid) {
        // 2. Check tokens
        final hasEnough = await TokenService.hasEnoughTokensForAstroCard();
        if (!hasEnough) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Colors.redAccent,
                content: Text('Yetersiz token! Kozmik Kart için 10 token gerekiyor.'),
              ),
            );
          }
          return;
        }

        // 3. Confirm payment
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A3F),
            title: const Text('Analiz Kartı Oluştur', style: TextStyle(color: Colors.white)),
            content: const Text('Bu işlem için 10 token kullanılacak. Onaylıyor musun?', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İPTAL', style: TextStyle(color: Colors.white38))),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('EVET (10 🪙)', style: TextStyle(color: Colors.cyanAccent))),
            ],
          ),
        );

        if (confirm != true) return;

        // 4. Use tokens
        final used = await TokenService.useTokensForAstroCard();
        if (!used) return;

        // 5. Mark as paid
        await _astroService.markCardAsGenerated();
      }

      // 6. Capture Image
      RenderRepaintBoundary boundary = _shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // 7. Share logic
      // Native sharing logic using memory bytes (Compatible with Mobile & Web)
      await Share.shareXFiles(
        [XFile.fromData(
          pngBytes, 
          name: 'mentaliq_kozmik_${DateTime.now().millisecondsSinceEpoch}.png', 
          mimeType: 'image/png'
        )],
        text: 'Astroloji analizimi Mentaliq ile keşfettim! ✨ #mentaliq #astroloji',
      );
    } catch (e) {
      debugPrint('Capture Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kart oluşturulurken bir sorun çıktı.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }
}

class _KozmikShareCard extends StatelessWidget {
  final AstroData data;
  const _KozmikShareCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 340,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F0C29), Color(0xFF302B63)],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MENTALIQ', 
                style: GoogleFonts.orbitron(color: Colors.cyanAccent, letterSpacing: 4, fontSize: 10, fontWeight: FontWeight.bold)),
              Text(DateFormat('dd.MM.yyyy').format(DateTime.now()), 
                style: const TextStyle(color: Colors.white30, fontSize: 10)),
            ],
          ),
          FittedBox(
            child: Column(
              children: [
                Text(data.totemEmoji, style: const TextStyle(fontSize: 60)),
                const SizedBox(height: 5),
                Text('GÜNÜN TOTEMİ', 
                  style: TextStyle(color: Colors.cyanAccent.withOpacity(0.6), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 2)),
                Text(data.totemName, 
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '"${data.motto}"', 
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.playfairDisplay(
                color: Colors.white, 
                fontSize: 16, 
                fontStyle: FontStyle.italic, 
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStatus('Aşk', data.trafficLights['love'] ?? 'YELLOW'),
                _miniStatus('İş', data.trafficLights['career'] ?? 'YELLOW'),
                _miniStatus('Enerji', data.trafficLights['energy'] ?? 'YELLOW'),
                Column(
                  children: [
                    Text('%${data.batteryLevel}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    const Text('BATARYA', style: TextStyle(color: Colors.white30, fontSize: 7)),
                  ],
                ),
              ],
            ),
          ),
          const Text('Astroloji analizini Mentaliq ile keşfet.', 
            style: TextStyle(color: Colors.white24, fontSize: 8)),
        ],
      ),
    );
  }

  Widget _miniStatus(String label, String status) {
    Color color = Colors.amberAccent;
    if (status == 'GREEN') color = Colors.greenAccent;
    if (status == 'RED') color = Colors.pinkAccent;

    return Column(
      children: [
        Icon(Icons.circle, color: color, size: 10),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 8)),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _GlassCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TabInfo {
  final String label;
  final IconData icon;
  _TabInfo({required this.label, required this.icon});
}
