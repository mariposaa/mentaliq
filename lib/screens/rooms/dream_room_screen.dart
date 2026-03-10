import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../config/responsive.dart';
import '../../l10n/app_translations.dart';
import '../../models/dream_model.dart';
import '../../services/ad_service.dart';
import '../../services/dream_service.dart';
import '../../services/token_service.dart';

/// Standalone dream analysis screen (no astrology content).
class DreamRoomScreen extends StatefulWidget {
  const DreamRoomScreen({super.key});

  @override
  State<DreamRoomScreen> createState() => _DreamRoomScreenState();
}

class _DreamRoomScreenState extends State<DreamRoomScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isDreamAnalyzing = false;
  String _dreamText = '';
  double _confidence = 1.0;
  DreamData? _dreamData;
  int _activeAnalysisTab = 0;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadLatestDream();
  }

  Future<void> _loadLatestDream() async {
    final latest = await DreamService.getLatestDream();
    if (!mounted) return;
    if (latest != null) {
      setState(() => _dreamData = latest);
    }
  }

  Future<void> _initSpeech() async {
    try {
      await _speech.initialize();
    } catch (e) {
      debugPrint('Speech init error: $e');
    }
  }

  Future<void> _listen() async {
    if (!_isListening) {
      final status = await Permission.microphone.request();
      if (status.isDenied) return;

      final available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'notListening' || val == 'done') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
              if (_dreamText.isNotEmpty) {
                Future.delayed(const Duration(milliseconds: 500), _runDreamAnalysis);
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
      if (_dreamText.isNotEmpty) {
        _runDreamAnalysis();
      }
    }
  }

  Future<void> _runDreamAnalysis() async {
    if (_dreamText.isEmpty) return;

    final hasEnough = await TokenService.hasEnoughTokensForDream();
    if (!hasEnough) {
      _showTokenError();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppTranslations.get('cosmicDreamAnalysis'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          AppTranslations.get('dreamAnalysisConfirm'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppTranslations.get('cancel'),
              style: const TextStyle(color: Colors.white38),
            ),
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
      final used = await TokenService.useTokensForDream();
      if (!used) {
        setState(() => _isDreamAnalyzing = false);
        return;
      }

      final result = await DreamService.analyzeTextDream(_dreamText);
      if (result != null) {
        await DreamService.saveDreamResult(result);
        if (!mounted) return;
        setState(() => _dreamData = result);
      } else {
        throw Exception('Dream analysis failed');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.get('errorDreamAnalysis'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isDreamAnalyzing = false);
    }
  }

  void _showTokenError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3F),
        title: Text(
          AppTranslations.get('insufficientTokens'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          AppTranslations.get('dreamInsufficientTokens'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppTranslations.get('cancel'),
              style: const TextStyle(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isDreamAnalyzing = true);
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
                _runDreamAnalysis();
              } else {
                setState(() => _isDreamAnalyzing = false);
              }
            },
            child: Text(
              AppTranslations.get('watchAdTokens'),
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ),
        ],
      ),
    );
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
              _buildHeader(),
              Expanded(
                child: _isDreamAnalyzing
                    ? _buildAnalyzingState()
                    : (_dreamData != null ? _buildDreamResultView() : _buildDreamInputView()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isCompact = context.isCompactPhone;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 20, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 6),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.purpleAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('🌙', style: TextStyle(fontSize: 22))),
          ),
          SizedBox(width: isCompact ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTranslations.get('dreamInterpretation'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isCompact ? 18 : 20,
                    color: Colors.white,
                  ),
                ),
                Text(
                  AppTranslations.get('dreamInterpretationTitle'),
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
        ],
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.cyanAccent),
          const SizedBox(height: 20),
          Text(
            AppTranslations.get('dreamAnalyzing'),
            style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            AppTranslations.get('geminiListeningDream'),
            style: const TextStyle(color: Colors.white30, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildDreamInputView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppTranslations.get('dreamInterpretationTitle'),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              letterSpacing: 4,
              fontWeight: FontWeight.bold,
            ),
          ),
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
              _isListening
                  ? (_dreamText.isEmpty ? AppTranslations.get('listening') : _dreamText)
                  : AppTranslations.get('tapToTellDream'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isListening ? Colors.cyanAccent : Colors.white60,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                fontStyle: _isListening ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          if (_isListening && _dreamText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'conf: ${(_confidence * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white30, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDreamResultView() {
    final isCompact = context.isCompactPhone;
    final data = _dreamData!;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? 14 : 20),
      child: Column(
        children: [
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
                    'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=800&q=80',
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
          Text(
            data.dreamTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 24 : 28,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.transcription,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildAnalysisTabItem(0, '🧠 ${AppTranslations.get('subconscious')}', Colors.purpleAccent),
              const SizedBox(width: 12),
              _buildAnalysisTabItem(1, '📜 ${AppTranslations.get('interpretation')}', Colors.amberAccent),
            ],
          ),
          const SizedBox(height: 16),
          _DreamGlassCard(
            padding: const EdgeInsets.all(20),
            child: Text(
              _activeAnalysisTab == 0 ? data.modernAnalysis : data.classicTabir,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.6),
            ),
          ),
          const SizedBox(height: 30),
          TextButton(
            onPressed: () => setState(() => _dreamData = null),
            child: Text(
              AppTranslations.get('newDream'),
              style: const TextStyle(color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisTabItem(int index, String label, Color color) {
    final active = _activeAnalysisTab == index;
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
}

class _DreamGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _DreamGlassCard({required this.child, this.padding});

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
