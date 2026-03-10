import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../services/ad_service.dart';
import '../../services/user_dna_service.dart';
import '../../models/user_dna_model.dart';
import '../../services/token_service.dart';
import '../../services/dream_service.dart';
import '../../models/dream_model.dart';
import '../../services/horoscope_service.dart';
import '../../models/horoscope_model.dart';
import '../../models/natal_chart_model.dart';
import '../../models/daily_guidance_model.dart';
import '../../services/natal_chart_service.dart';
import '../../services/astro_guidance_service.dart';
import '../../l10n/app_translations.dart';
import '../../config/responsive.dart';

/// Astroloji ve Rüya Room - Kozmik HUD Tasarımı
class AstrologyDreamRoomScreen extends StatefulWidget {
  const AstrologyDreamRoomScreen({super.key});

  @override
  State<AstrologyDreamRoomScreen> createState() => _AstrologyDreamRoomScreenState();
}

class _AstrologyDreamRoomScreenState extends State<AstrologyDreamRoomScreen> {

  late TextEditingController _dateController;
  late TextEditingController _timeController;
  late TextEditingController _locationController;
  
  bool _isSaving = false;
  bool _isLoading = true;
  
  // New Astrology System States
  NatalChartModel? _natalChart;
  DailyGuidanceModel? _dailyGuidance;
  bool _isCalculatingNatal = false;
  bool _isGeneratingGuidance = false;
  int _expandedHouseIndex = -1; // For expandable house cards

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

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController();
    _timeController = TextEditingController();
    _locationController = TextEditingController();
    
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

    // Load saved natal chart
    final savedNatal = await NatalChartService.getSavedNatalChart();
    if (savedNatal != null && savedNatal.isValid) {
      setState(() {
        _natalChart = savedNatal;
      });
      
      // Load today's guidance if natal chart exists
      final savedGuidance = await AstroGuidanceService.getTodaysGuidance();
      if (savedGuidance != null) {
        setState(() {
          _dailyGuidance = savedGuidance;
        });
      }
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

  /// Calculate natal chart (one-time, free)
  Future<void> _calculateNatalChart() async {
    final hasNatal = _natalChart != null && _natalChart!.isValid;
    if (hasNatal && _hasCalculatedNatalToday()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.get('natalRecalculateOncePerDay'))),
        );
      }
      return;
    }

    if (_dateController.text.isEmpty || _timeController.text.isEmpty || _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.get('errorBirthInfoIncomplete'))),
      );
      return;
    }

    setState(() => _isCalculatingNatal = true);

    try {
      final chart = await NatalChartService.calculateNatalChart(
        birthDate: _dateController.text,
        birthTime: _timeController.text,
        birthLocation: _locationController.text,
      );

      if (chart != null && chart.isValid) {
        await NatalChartService.saveNatalChart(chart);
        setState(() {
          _natalChart = chart;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: Text(AppTranslations.get('successNatalChart')),
            ),
          );
        }
      } else {
        throw Exception(NatalChartService.lastError ?? 'Hesaplama başarısız');
      }
    } catch (e) {
      debugPrint('Natal Chart Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppTranslations.get('errorNatalChartFailed')} $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalculatingNatal = false);
    }
  }

  /// Generate daily guidance (15 tokens)
  Future<void> _generateDailyGuidance() async {
    if (_natalChart == null || !_natalChart!.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.get('errorNatalChartRequired'))),
      );
      return;
    }

    // Check if already has guidance for today
    final hasGuidance = await AstroGuidanceService.hasGuidanceForToday();
    if (hasGuidance && _dailyGuidance != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.get('guidanceExists'))),
      );
      return;
    }

    // Check tokens
    final hasEnough = await TokenService.hasEnoughTokensForAstroGuidance();
    if (!hasEnough) {
      _showInsufficientTokensDialog();
      return;
    }

    // Confirm payment
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppTranslations.get('dailyGuidanceTitle'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          AppTranslations.get('dailyGuidanceConfirm'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppTranslations.get('cancel'), style: const TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent.withOpacity(0.2),
              foregroundColor: Colors.cyanAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppTranslations.get('yesWithTokens')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isGeneratingGuidance = true);

    try {
      // Use tokens
      final used = await TokenService.useTokensForAstroGuidance();
      if (!used) throw Exception("Token kullanılamadı");

      final guidance = await AstroGuidanceService.generateDailyGuidance();
      
      if (guidance != null) {
        setState(() {
          _dailyGuidance = guidance;
        });
      } else {
        throw Exception(AstroGuidanceService.lastError ?? 'Yönerge oluşturulamadı');
      }
    } catch (e) {
      debugPrint('Guidance Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yönerge oluşturulamadı: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingGuidance = false);
    }
  }

  void _showInsufficientTokensDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3F),
        title: Text(AppTranslations.get('insufficientTokens'), style: const TextStyle(color: Colors.white)),
        content: Text(
          AppTranslations.get('insufficientTokensMsg'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppTranslations.get('cancel'), style: const TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isGeneratingGuidance = true);
              final earned = await AdService.showRewardedAd();
              if (earned) {
                await TokenService.addTokens(TokenService.adRewardTokens);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.green,
                      content: Text(AppTranslations.get('congratsTokensAdded')),
                    ),
                  );
                }
                _generateDailyGuidance();
              } else {
                setState(() => _isGeneratingGuidance = false);
              }
            },
            child: Text(AppTranslations.get('watchAdTokens'), style: const TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveData() async {
    if (_dateController.text.isEmpty || _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.get('errorDateLocation'))),
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
            SnackBar(
              backgroundColor: Colors.green,
              content: Text(AppTranslations.get('birthInfoUpdated')),
            ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text(AppTranslations.get('errorSaveFailed')),
            ),
        );
      }
    }

    if (mounted) setState(() => _isSaving = false);
  }

  // --- Picker Helpers ---

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.cyanAccent,
              onPrimary: Colors.black,
              surface: Color(0xFF1A1A3F),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1A1A3F),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      if (mounted) {
        setState(() {
          _dateController.text = DateFormat('dd.MM.yyyy').format(picked);
        });
      }
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
         return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.cyanAccent,
              onPrimary: Colors.black,
              surface: Color(0xFF1A1A3F),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      if (mounted) {
        setState(() {
          _timeController.text = DateFormat('HH:mm').format(dt);
        });
      }
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // --- Rüya Tabiri (STT Sync - Bas-Durdur) ---

  void _listen() async {
    if (!_isListening) {
      final status = await Permission.microphone.request();
      if (status.isDenied) return;

      bool available = await _speech.initialize(
        onStatus: (val) {
          debugPrint('onStatus: $val');
          if (val == 'notListening' || val == 'done') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
              if (_dreamText.isNotEmpty) {
                Future.delayed(const Duration(milliseconds: 500), () => _runDreamAnalysis());
              }
            }
          }
        },
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
      _speech.stop();
      setState(() => _isListening = false);
      // Fix: If manually stopped, trigger analysis if we have text
      if (_dreamText.isNotEmpty) {
        _runDreamAnalysis();
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
        title: Text(AppTranslations.get('cosmicDreamAnalysis'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          AppTranslations.get('dreamAnalysisConfirm'), 
          style: const TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: Text(AppTranslations.get('cancel'), style: const TextStyle(color: Colors.white38))
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
          SnackBar(content: Text(AppTranslations.get('errorDreamAnalysis'))),
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
        title: Text(AppTranslations.get('insufficientTokens'), style: const TextStyle(color: Colors.white)),
        content: Text(AppTranslations.get('dreamInsufficientTokens'), style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppTranslations.get('cancel'), style: const TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isDreamAnalyzing = true);
              final earned = await AdService.showRewardedAd();
              if (earned) {
                await TokenService.addTokens(TokenService.adRewardTokens);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: Colors.green, content: Text(AppTranslations.get('congratsTokensAdded'))),
                  );
                }
                _runDreamAnalysis();
              } else {
                setState(() => _isDreamAnalyzing = false);
              }
            }, 
            child: Text(AppTranslations.get('watchAdTokens'), style: const TextStyle(color: Colors.orangeAccent))
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
          final error = HoroscopeService.lastError ?? '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.amber,
              content: Text('${AppTranslations.get('horoscopeUnavailable')} $error'),
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
              Expanded(child: _buildAstrologyTab()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAstrologyTab() {
    final isCompact = context.isCompactPhone;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 14 : 20,
        vertical: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GlassCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.amberAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppTranslations.get('dailyAnalysisOncePerDay'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Birth Info Card (always visible, collapsible)
          _buildBirthInfoCard(),
          const SizedBox(height: 20),
          
          // If no natal chart, show setup prompt
          if (_natalChart == null || !_natalChart!.isValid)
            _buildNatalChartSetup()
          else ...[
            _buildDailyHoroscopeInline(),
            const SizedBox(height: 20),
            // Natal Chart Summary Card
            _buildNatalChartSummary(),
            const SizedBox(height: 20),
            
            // Daily Guidance Section
            if (_isGeneratingGuidance)
              _buildGeneratingState()
            else if (_dailyGuidance != null)
              _buildDailyGuidanceView()
            else
              _buildGuidancePrompt(),
          ],
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDailyHoroscopeInline() {
    final data = _dailyHoroscope;
    final sunSign = _natalChart?.sunSign ?? data?.sunSign ?? '';
    final risingSign = _natalChart?.risingSign ?? data?.risingSign ?? '';
    if (data == null) {
      return _GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.wb_sunny_outlined, color: Colors.white54, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppTranslations.get('horoscopeUnavailable'),
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppTranslations.get('dailyHoroscope'),
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${AppTranslations.get('sunSign')}: $sunSign',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            data.sunInterpretation,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            '${AppTranslations.get('risingSign')}: $risingSign',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            data.risingInterpretation,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthInfoCard() {
    final hasNatal = _natalChart != null && _natalChart!.isValid;
    final canRecalculate = !hasNatal || !_hasCalculatedNatalToday();
    
    return _GlassCard(
      child: ExpansionTile(
        title:         Text(
          hasNatal ? AppTranslations.get('birthInfoVerified') : AppTranslations.get('birthInfo'),
          style: TextStyle(
            color: hasNatal ? Colors.greenAccent : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Icon(
          hasNatal ? Icons.check_circle_rounded : Icons.stars_rounded,
          color: hasNatal ? Colors.greenAccent : Colors.cyanAccent,
        ),
        trailing: _isSaving || _isCalculatingNatal
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
            : null,
        childrenPadding: const EdgeInsets.all(16),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white60,
        initiallyExpanded: !hasNatal,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        children: [
          _buildInputField(_dateController, AppTranslations.get('birthDate'), AppTranslations.get('birthDateHint'), Icons.calendar_today, onTap: _selectDate, readOnly: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInputField(_timeController, AppTranslations.get('birthTimeLabel'), '14:30', Icons.access_time, onTap: _selectTime, readOnly: true)),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _buildInputField(_locationController, AppTranslations.get('birthPlace'), 'Istanbul', Icons.location_on)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppTranslations.get('birthTimeImportance'),
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(AppTranslations.get('save')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: (_isCalculatingNatal || !canRecalculate) ? null : _calculateNatalChart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                    foregroundColor: Colors.cyanAccent,
                    side: const BorderSide(color: Colors.cyanAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isCalculatingNatal
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
                      : Text(hasNatal ? AppTranslations.get('recalculate') : AppTranslations.get('calculateMyChart')),
                ),
              ),
            ],
          ),
          if (hasNatal && !canRecalculate)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                AppTranslations.get('natalRecalculateOncePerDay'),
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  bool _hasCalculatedNatalToday() {
    final ts = _natalChart?.calculatedAt;
    if (ts == null) return false;
    final now = DateTime.now();
    return ts.year == now.year && ts.month == now.month && ts.day == now.day;
  }

  Widget _buildInputField(
      TextEditingController controller, 
      String label, 
      String hint, 
      IconData icon, 
      {VoidCallback? onTap, bool readOnly = false}
    ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
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

  /// Setup prompt when no natal chart exists
  Widget _buildNatalChartSetup() {
    return _GlassCard(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.cyanAccent, size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            AppTranslations.get('personalAstrologyCenter'),
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            AppTranslations.get('natalChartDesc'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                _buildSetupStep(1, AppTranslations.get('enterBirthInfo'), Icons.edit_calendar),
                const SizedBox(height: 12),
                _buildSetupStep(2, AppTranslations.get('calculateNatalChart'), Icons.calculate),
                const SizedBox(height: 12),
                _buildSetupStep(3, AppTranslations.get('getDailyGuidance'), Icons.auto_awesome),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupStep(int number, String text, IconData icon) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, color: Colors.white38, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
      ],
    );
  }

  /// Natal chart summary card
  Widget _buildNatalChartSummary() {
    if (_natalChart == null) return const SizedBox.shrink();
    
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                AppTranslations.get('yourNatalChart'),
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Big 3: Sun, Moon, Rising
          Row(
            children: [
              Expanded(child: _buildBig3Card(AppTranslations.get('sun'), _natalChart!.sunSign, '☀️', Colors.orangeAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildBig3Card(AppTranslations.get('moon'), _natalChart!.moonSign, '🌙', Colors.blueGrey)),
              const SizedBox(width: 12),
              Expanded(child: _buildBig3Card(AppTranslations.get('rising'), _natalChart!.risingSign, '⬆️', Colors.purpleAccent)),
            ],
          ),
          const SizedBox(height: 16),
          // Planets summary
          ExpansionTile(
            title: Text(AppTranslations.get('planetPositions'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
            tilePadding: EdgeInsets.zero,
            iconColor: Colors.white38,
            collapsedIconColor: Colors.white24,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _natalChart!.planets.entries.map((e) {
                  final emoji = PlanetPosition.getPlanetEmoji(e.key);
                  final nameTr = PlanetPosition.getPlanetNameTr(e.key);
                  final signTr = NatalChartModel.getZodiacNameTr(e.value.sign);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$emoji $nameTr: $signTr (${e.value.house}. Ev)',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBig3Card(String label, String sign, String emoji, Color color) {
    final signTr = NatalChartModel.getZodiacNameTr(sign);
    final zodiacEmoji = NatalChartModel.getZodiacEmoji(sign);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '$zodiacEmoji $signTr',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Prompt to generate daily guidance
  Widget _buildGuidancePrompt() {
    return _GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.withOpacity(0.3), Colors.cyanAccent.withOpacity(0.2)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            AppTranslations.get('dailyCosmicGuidance'),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            AppTranslations.get('dailyGuidanceDesc'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _generateDailyGuidance,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome, size: 20),
                  const SizedBox(width: 8),
                  Text(AppTranslations.get('getMyDailyGuidance'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  const Text('(15 🪙)', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Loading state for guidance generation
  Widget _buildGeneratingState() {
    return _GlassCard(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          CircularPercentIndicator(
            radius: 60.0,
            lineWidth: 8.0,
            percent: 0.75,
            animation: true,
            animationDuration: 2000,
            center: const Icon(Icons.auto_awesome, color: Colors.cyanAccent, size: 32),
            circularStrokeCap: CircularStrokeCap.round,
            progressColor: Colors.cyanAccent,
            backgroundColor: Colors.white10,
          ),
          const SizedBox(height: 24),
          Text(
            AppTranslations.get('cosmicChartAnalyzing'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            AppTranslations.get('matchingPlanets'),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Daily guidance view
  Widget _buildDailyGuidanceView() {
    if (_dailyGuidance == null) return const SizedBox.shrink();
    final guidance = _dailyGuidance!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with energy and cosmic weather
        _GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.get('todayEnergy'),
                        style: TextStyle(
                          color: Colors.cyanAccent.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        guidance.date,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getEnergyColor(guidance.overallEnergy).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getEnergyColor(guidance.overallEnergy).withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bolt, color: _getEnergyColor(guidance.overallEnergy), size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '%${guidance.overallEnergy}',
                          style: TextStyle(
                            color: _getEnergyColor(guidance.overallEnergy),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                guidance.cosmicWeather,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
              ),
              if (guidance.powerHour.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, color: Colors.amberAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${AppTranslations.get('powerHour')} ${guidance.powerHour}',
                        style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Cosmic Warning (if any)
        if (guidance.cosmicWarning != null && guidance.cosmicWarning!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      guidance.cosmicWarning!,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Section title
        Text(
          AppTranslations.get('houseGuidance'),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        
        // House guidance cards (sorted by activation)
        ...guidance.getSortedHouses().asMap().entries.map((entry) {
          final index = entry.key;
          final houseEntry = entry.value;
          final houseNum = int.tryParse(houseEntry.key) ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildHouseGuidanceCard(houseNum, houseEntry.value, index),
          );
        }).toList(),
        
        // Daily Motto
        const SizedBox(height: 16),
        _GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.format_quote, color: Colors.cyanAccent, size: 24),
              const SizedBox(height: 12),
              Text(
                '"${guidance.dailyMotto}"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        
        // Lucky Elements
        if (guidance.luckyElements != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildLuckyElement(AppTranslations.get('luckyColor'), guidance.luckyElements!.color, Icons.palette),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildLuckyElement(AppTranslations.get('luckyNumber'), '${guidance.luckyElements!.number}', Icons.tag),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildLuckyElement(AppTranslations.get('direction'), guidance.luckyElements!.direction, Icons.explore),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHouseGuidanceCard(int houseNum, HouseGuidance guidance, int index) {
    final isExpanded = _expandedHouseIndex == index;
    final hasDetail = guidance.detailedAction != null && guidance.detailedAction!.isNotEmpty;
    final activationColor = Color(guidance.activationColorValue);
    
    return GestureDetector(
      onTap: hasDetail ? () => setState(() => _expandedHouseIndex = isExpanded ? -1 : index) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(isExpanded ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: guidance.isHighActivation 
                ? activationColor.withOpacity(0.4)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: activationColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(guidance.themeIcon, style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$houseNum. Ev',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: activationColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              guidance.activationLevel.toUpperCase(),
                              style: TextStyle(
                                color: activationColor,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        guidance.houseName,
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (hasDetail)
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white38,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              guidance.shortAdvice,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              '• Bugün yap: ${guidance.shortAdvice}',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 12, height: 1.3),
            ),
            if (guidance.detailedAction != null && guidance.detailedAction!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '• Bugün kaçın: ${guidance.detailedAction!}',
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, height: 1.3),
              ),
            ],
            if (isExpanded && hasDetail) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: activationColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: activationColor.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.play_arrow, color: activationColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          AppTranslations.get('action'),
                          style: TextStyle(
                            color: activationColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      guidance.detailedAction!,
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLuckyElement(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getEnergyColor(int energy) {
    if (energy >= 70) return Colors.greenAccent;
    if (energy >= 40) return Colors.amberAccent;
    return Colors.redAccent;
  }

  Widget _buildDreamTab() {
    if (_isDreamAnalyzing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.cyanAccent),
            const SizedBox(height: 20),
            Text(AppTranslations.get('dreamAnalyzing'), 
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(AppTranslations.get('geminiListeningDream'), style: const TextStyle(color: Colors.white30, fontSize: 11)),
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
          Text(AppTranslations.get('dreamInterpretationTitle'), 
            style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 4, fontWeight: FontWeight.bold)),
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
              _isListening ? (_dreamText.isEmpty ? AppTranslations.get('listening') : _dreamText) : AppTranslations.get('tapToTellDream'),
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
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Text(data.transcription, 
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic)),
          const SizedBox(height: 24),
          
          // Analysis Tabs
          Row(
            children: [
              _buildAnalysisTabItem(0, '🧠 ${AppTranslations.get('subconscious')}', Colors.purpleAccent),
              const SizedBox(width: 12),
              _buildAnalysisTabItem(1, '📜 ${AppTranslations.get('interpretation')}', Colors.amberAccent),
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
            child: Text(AppTranslations.get('newDream'), style: const TextStyle(color: Colors.white24)),
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
              _buildSimpleTabItem(0, AppTranslations.get('daily'), Icons.today),
              const SizedBox(width: 12),
              _buildSimpleTabItem(1, AppTranslations.get('weekly'), Icons.date_range),
            ],
          ),
          const SizedBox(height: 25),

          if (currentData == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Text(AppTranslations.get('horoscopeUnavailable'), 
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white24)),
                    const SizedBox(height: 20),
                    TextButton.icon(
                      onPressed: _loadHoroscopeData,
                      icon: const Icon(Icons.refresh, color: Colors.purpleAccent),
                      label: Text(AppTranslations.get('retry'), style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Sun Sign Card
            _buildSignDetailCard(
              title: AppTranslations.get('sunSign'),
              signName: currentData.sunSign,
              interpretation: currentData.sunInterpretation,
              icon: Icons.wb_sunny_rounded,
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 20),

            // Rising Sign Card
            _buildSignDetailCard(
              title: AppTranslations.get('risingSign'),
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
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1)),
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

  Widget _buildPremiumHeader() {
    final isCompact = context.isCompactPhone;
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
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 20, vertical: 8),
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
              SizedBox(width: isCompact ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.get('astrologyAndDreams'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isCompact ? 18 : 20,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      AppTranslations.get('starAndDreamAnalysis'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
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

