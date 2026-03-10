import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/responsive.dart';
import '../../services/addiction_service.dart';
import '../../l10n/app_translations.dart';

class GamblingSOSScreen extends StatefulWidget {
  const GamblingSOSScreen({super.key});

  @override
  State<GamblingSOSScreen> createState() => _GamblingSOSScreenState();
}

class _GamblingSOSScreenState extends State<GamblingSOSScreen> {
  int _secondsRemaining = 15 * 60; // 15 Minutes
  Timer? _timer;
  List<String> _realityChecks = [];
  int _currentCheckIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _loadRealityChecks();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
          
          // Switch reality check every 3 minutes
          if (_secondsRemaining % 180 == 0 && _realityChecks.isNotEmpty) {
             _currentCheckIndex = (_currentCheckIndex + 1) % _realityChecks.length;
          }
        });
      } else {
        _timer?.cancel();
        // Time is up - maybe show safe exit or summary
      }
    });
  }

  Future<void> _loadRealityChecks() async {
    final checks = await AddictionService.triggerEmergency('gambling');
    if (mounted) {
      setState(() {
        _realityChecks = checks ?? [
          AppTranslations.get('realityCheck1'),
          AppTranslations.get('realityCheck2'),
          AppTranslations.get('realityCheck3'),
        ];
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timerString {
    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompactPhone;
    // Compatibility fallback: old gamblingDNA photo model was removed.
    const photoUrl = '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. VISUAL SHOCK LAYER (Background Photo with BW Filter)
          if (photoUrl.isNotEmpty)
            ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.grey,
                BlendMode.saturation,
              ), // Black & white filter
              child: Opacity(
                opacity: 0.4,
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[900]),
                ),
              ),
            )
          else
            Container(color: Colors.grey[900]), // Fallback background

          // 2. CONTENT LAYER
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(isCompact ? 16 : 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Timer Box
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 20 : 30,
                      vertical: isCompact ? 12 : 15,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.redAccent, width: 2),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black.withOpacity(0.7),
                    ),
                    child: Text(
                      _timerString,
                      style: const TextStyle(
                        fontFamily: 'Courier', // Monospace for countdown feel
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                  SizedBox(height: isCompact ? 20 : 40),
                  
                  // Reality Checks & Chat Interface
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(isCompact ? 14 : 20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              itemCount: _realityChecks.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Text(
                                    _realityChecks[index],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isCompact ? 16 : 18,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (_isLoading) 
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Action Buttons
                  Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: 14,
                    runSpacing: 10,
                    children: [
                      _buildActionButton(
                        icon: Icons.call,
                        label: AppTranslations.get('call'),
                        onTap: () {
                          // Implement call functionality
                        },
                      ),
                       _buildActionButton(
                        icon: Icons.chat_bubble_outline,
                        label: AppTranslations.get('talkToGemini'),
                        onTap: () {
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text(AppTranslations.get('emergencyChatStarting')))
                           );
                           // In a real app, this would open a full chat mode
                           // For now, we simulate a new strong message arriving
                           setState(() {
                             _isLoading = true;
                           });
                           Future.delayed(const Duration(seconds: 2), () {
                             if (mounted) {
                               setState(() {
                                 _realityChecks.add(AppTranslations.get('slowDownObjects'));
                                 _isLoading = false;
                               });
                             }
                           });
                        },
                      ),
                      _buildActionButton(
                        icon: Icons.exit_to_app,
                        label: AppTranslations.get('crisisPassed'),
                        onTap: () {
                           Navigator.of(context).pop();
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text(AppTranslations.get('wonBattle')))
                           );
                        },
                        isPrimary: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap, bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 100,
        child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPrimary ? Colors.green : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
        ),
      ),
    );
  }
}
