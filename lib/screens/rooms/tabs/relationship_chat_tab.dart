import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:image_picker/image_picker.dart';
import '../../../config/app_theme.dart';
import '../../../l10n/app_translations.dart';
import '../../../services/gemini_service.dart';
import '../../../services/token_service.dart';
import '../../../services/shadow_memory_service.dart';
import '../../../services/partner_service.dart';
import '../../../services/local_relationship_memory_service.dart';
import '../../../services/relationship_analysis_service.dart';

import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../../../widgets/token_dialog.dart';

/// İlişki Analizi Tab - WhatsApp-style chat with image analysis
class RelationshipChatTab extends StatefulWidget {
  const RelationshipChatTab({super.key});

  @override
  State<RelationshipChatTab> createState() => _RelationshipChatTabState();
}

class _RelationshipChatTabState extends State<RelationshipChatTab>
    with AutomaticKeepAliveClientMixin {
  
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _showAnalysisCard = true; // Show initial card
  int _tokenBalance = 100;
  LocalRelationshipOpeningInsight? _openingInsight;
  
  // Selected image
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  // Speech to Text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _speechText = '';
  bool _analysisReadyToastShown = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showPrivacyToast();
    });
  }

  void _initSpeech() async {
    try {
      await _speech.initialize();
    } catch (e) {
      debugPrint('Speech init error: $e');
    }
  }

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

  Future<void> _initializeChat() async {
    await GeminiService.startChatSession('iliskiler');
    final balance = await TokenService.getBalance();
    final partner = await PartnerService.getPrimaryPartner();
    final partnerKey = LocalRelationshipMemoryService.buildPartnerKey(partner);
    final insight = await LocalRelationshipMemoryService.getOpeningInsight(
      partnerKey: partnerKey,
    );

    setState(() {
      _tokenBalance = balance;
      _openingInsight = insight;
    });
  }

  /// Pick image from gallery
  Future<void> _pickImage() async {
    try {
      debugPrint('Attempting to pick image from gallery...');
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      debugPrint('Image picked: ${image?.path}');
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        debugPrint('Image bytes loaded: ${bytes.length} bytes');
        setState(() {
          _selectedImage = image;
          _selectedImageBytes = bytes;
        });
      } else {
        debugPrint('No image selected (user cancelled)');
      }
    } catch (e, stack) {
      debugPrint('Error picking image: $e');
      debugPrint('Stack: $stack');
      _showErrorSnackbar('${AppTranslations.get('errorImageSelection')} $e');
    }
  }

  /// Pick image from camera
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      _showErrorSnackbar(AppTranslations.get('errorPhotoTaken'));
    }
  }

  /// Analyze the selected WhatsApp screenshot
  Future<void> _analyzeScreenshot() async {
    if (_isLoading) return;
    if (_selectedImageBytes == null) return;

    // Check tokens
    final hasTokens = await TokenService.hasEnoughTokens();
    if (!hasTokens) {
      _showTokenDialog();
      return;
    }

    setState(() {
      _showAnalysisCard = false;
      _messages.add(_ChatMessage(
        content: AppTranslations.get('screenshotUploaded'),
        isUser: true,
        time: DateTime.now(),
        imageBytes: _selectedImageBytes,
      ));
      _isLoading = true;
    });

    _scrollToBottom();

    // Use tokens
    await TokenService.useTokensForMessage();
    final newBalance = await TokenService.getBalance();
    setState(() => _tokenBalance = newBalance);

    // Analyze with Gemini Vision
    try {
      final response = await GeminiService.analyzeImage(
        _selectedImageBytes!,
        '''Bu bir WhatsApp mesajlaşma ekran görüntüsü. Lütfen analiz et:
        
1. Mesajlaşmada neler konuşulmuş? Özet çıkar.
2. İletişim tonu nasıl? (pozitif, negatif, nötr)
3. Herhangi bir sorun veya gerginlik var mı?
4. Kullanıcıya pratik tavsiyeler ver.
5. TOKSİKLİK METRESİ: Bu konuşmanın toksiklik seviyesini 0 ile 100 arasında bir puan ver ve nedenini kısaca açıkla. (Örn: Toksiklik: 85/100 - Manipülatif dil kullanımı var).

Samimi ve destekleyici bir dil kullan. Türkçe yanıt ver.''',
      );

      setState(() {
        _isLoading = false;
        _selectedImage = null;
        _selectedImageBytes = null;
        _messages.add(_ChatMessage(
          content: response,
          isUser: false,
          time: DateTime.now(),
        ));
      });

      _scrollToBottom();
      _maybeShowAnalysisReadyToast();
    } catch (e) {
      debugPrint('Error analyzing image: $e');
      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(
          content: AppTranslations.get('errorImageAnalysis'),
          isUser: false,
          time: DateTime.now(),
        ));
      });
    }
  }

  Future<void> _runRedFlagScan() async {
    if (_isLoading) return;
    if (_selectedImageBytes == null) {
      _showErrorSnackbar('Önce bir ekran görüntüsü seçmelisin.');
      return;
    }

    final hasTokens = await TokenService.hasEnoughTokens();
    if (!hasTokens) {
      _showTokenDialog();
      return;
    }

    setState(() {
      _showAnalysisCard = false;
      _isLoading = true;
      _messages.add(_ChatMessage(
        content: 'Mikro Araç: Ekran Görüntüsünde Kırmızı Bayrak Tara',
        isUser: true,
        time: DateTime.now(),
        imageBytes: _selectedImageBytes,
      ));
    });
    _scrollToBottom();

    await TokenService.useTokensForMessage();
    final newBalance = await TokenService.getBalance();
    setState(() => _tokenBalance = newBalance);

    final response = await GeminiService.analyzeImage(
      _selectedImageBytes!,
      '''
Görev: Bu konuşma ekran görüntüsünde kırmızı bayrak taraması yap.
- Manipülasyon, gaslighting, pasif-agresiflik, küçümseme, suçlama, ghosting, love bombing belirtilerini ara.
- Varsa kısa kanıt cümlesiyle ismini koy. Yoksa "belirgin kırmızı bayrak yok" de.
- 0-100 arası toksisite puanı ver ve tek cümle gerekçe yaz.
- Yanıtı kısa tut: en fazla 6 cümle.

SADECE ŞU FORMATI DÖNDÜR:
1) Kırmızı Bayraklar: ...
2) Toksisite Puanı: X/100 - ...
3) Saygı Düzeyi: ...
4) Net Öneri: ...

Format dışına çıkma. Giriş cümlesi yazma.
''',
    );
    final normalized = _ensureRedFlagFormat(response);

    setState(() {
      _isLoading = false;
      _messages.add(_ChatMessage(
        content: normalized.content,
        isUser: false,
        time: DateTime.now(),
        autoFormatCorrected: normalized.corrected,
      ));
    });
    _scrollToBottom();
    _maybeShowAnalysisReadyToast();
  }

  Future<void> _runReplySuggestion() async {
    if (_isLoading) return;
    final draft = _messageController.text.trim();
    if (draft.isEmpty) {
      _showErrorSnackbar('Önce mesaj kutusuna karşı tarafın mesajını veya durumu yaz.');
      return;
    }

    final hasTokens = await TokenService.hasEnoughTokens();
    if (!hasTokens) {
      _showTokenDialog();
      return;
    }

    _messageController.clear();
    setState(() {
      _showAnalysisCard = false;
      _isLoading = true;
      _messages.add(_ChatMessage(
        content: 'Mikro Araç: Bu Mesaja Ne Cevap Yazmalıyım?\n\n$draft',
        isUser: true,
        time: DateTime.now(),
      ));
    });
    _scrollToBottom();

    await TokenService.useTokensForMessage();
    final newBalance = await TokenService.getBalance();
    setState(() => _tokenBalance = newBalance);

    final response = await GeminiService.sendMessage('''
Araç modu: "Bu Mesaja Ne Cevap Yazmalıyım?"
Kullanıcıdan gelen içerik:
$draft

İstenen çıktı:
- 3 kısa yanıt önerisi ver: (1) nazik, (2) net, (3) sınır koyan.
- Her öneri en fazla 1-2 cümle olsun.
- Metafor kullanma, gereksiz açıklama yapma.

SADECE ŞU FORMATI DÖNDÜR:
1) Nazik: ...
2) Net: ...
3) Sınır Koyan: ...

Format dışına çıkma. Ek açıklama yazma.
''');
    final normalized = _ensureReplyFormat(response);

    setState(() {
      _isLoading = false;
      _messages.add(_ChatMessage(
        content: normalized.content,
        isUser: false,
        time: DateTime.now(),
        autoFormatCorrected: normalized.corrected,
      ));
    });
    _scrollToBottom();
    _maybeShowAnalysisReadyToast();
  }

  Future<void> _runGaslightingTest() async {
    if (_isLoading) return;
    final draft = _messageController.text.trim();
    if (_selectedImageBytes == null && draft.isEmpty) {
      _showErrorSnackbar('Test için ya mesaj metni yaz ya da ekran görüntüsü seç.');
      return;
    }

    final hasTokens = await TokenService.hasEnoughTokens();
    if (!hasTokens) {
      _showTokenDialog();
      return;
    }

    setState(() {
      _showAnalysisCard = false;
      _isLoading = true;
      _messages.add(_ChatMessage(
        content: 'Mikro Araç: Manipülasyon (Gaslighting) Testi',
        isUser: true,
        time: DateTime.now(),
        imageBytes: _selectedImageBytes,
      ));
    });
    _scrollToBottom();

    await TokenService.useTokensForMessage();
    final newBalance = await TokenService.getBalance();
    setState(() => _tokenBalance = newBalance);

    String response;
    if (_selectedImageBytes != null) {
      response = await GeminiService.analyzeImage(
        _selectedImageBytes!,
        '''
Görev: Gaslighting/manipülasyon testi yap.
- Sonuç formatı:
1) Sonuç: Var / Şüpheli / Yok
2) Kanıt: En fazla 3 kısa madde
3) Risk puanı: 0-100 + tek cümle gerekçe
4) Kullanıcının atacağı 1 somut adım
- Yanıt kısa olsun, en fazla 6 cümle.

Sadece bu formatı döndür. Ek giriş cümlesi yazma.
''',
      );
    } else {
      response = await GeminiService.sendMessage('''
Araç modu: Manipülasyon (Gaslighting) Testi
Metin:
$draft

Sonuç formatı:
1) Sonuç: Var / Şüpheli / Yok
2) Kanıt: En fazla 3 kısa madde
3) Risk puanı: 0-100 + tek cümle gerekçe
4) Kullanıcının atacağı 1 somut adım
Kısa ve net yaz.

Sadece bu formatı döndür. Ek açıklama yazma.
''');
    }
    final normalized = _ensureGaslightingFormat(response);

    setState(() {
      _isLoading = false;
      _messages.add(_ChatMessage(
        content: normalized.content,
        isUser: false,
        time: DateTime.now(),
        autoFormatCorrected: normalized.corrected,
      ));
    });
    _scrollToBottom();
    _maybeShowAnalysisReadyToast();
  }

  void _sendMessage() async {
    if (_isLoading) return;
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final hasTokens = await TokenService.hasEnoughTokens();
    if (!hasTokens) {
      _showTokenDialog();
      return;
    }

    _messageController.clear();
    
    setState(() {
      _showAnalysisCard = false;
      _messages.add(_ChatMessage(content: message, isUser: true, time: DateTime.now()));
      _isLoading = true;
    });

    _scrollToBottom();

    await TokenService.useTokensForMessage();
    final newBalance = await TokenService.getBalance();
    setState(() => _tokenBalance = newBalance);

    final response = await GeminiService.sendMessage(message);

    setState(() {
      _isLoading = false;
      _messages.add(_ChatMessage(
        content: response,
        isUser: false,
        time: DateTime.now(),
      ));
    });

    _scrollToBottom();
    
    // Background: Analyze message for partner updates (Gölge Hafıza)
    ShadowMemoryService.analyzeAndUpdate(message);
    _maybeShowAnalysisReadyToast();
  }


  Future<void> _showTokenDialog() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        backgroundColor: AppTheme.terracotta,
        content: const Text(
          'Elmas yetersiz. Reklam izleyerek +30 elmas kazanabilirsin.',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );

    final gotTokens = await TokenDialog.show(context);
    if (gotTokens && mounted) {
      final newBalance = await TokenService.getBalance();
      setState(() => _tokenBalance = newBalance);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showPrivacyToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        backgroundColor: AppTheme.forestCharcoal,
        content: const Text(
          'Gizlilik Notu: Bu ekrandaki kişisel durum notları sadece telefonunda tutulur, sunucuya kaydedilmez.',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _maybeShowAnalysisReadyToast() async {
    if (!mounted || _analysisReadyToastShown) return;
    final readiness = await RelationshipAnalysisService.getReadinessStatus();
    if (!mounted || !readiness.isReady) return;

    _analysisReadyToastShown = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.sageGreen,
        duration: const Duration(seconds: 4),
        content: const Text(
          'Yeterli konuşma verisi birikti. "Analiz Tavsiyeler" sekmesinden derin raporu başlatabilirsin.',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    GeminiService.clearSession();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFE8DDD5),
            ),
            child: _showAnalysisCard && _messages.isEmpty
                ? _buildAnalysisCard()
                : _buildChatList(),
          ),
        ),
        _buildMicroToolsBar(),
        if (_selectedImageBytes != null) _buildImagePreview(),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildMicroToolsBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4F1),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildMicroToolChip(
                  icon: Icons.flag_circle_outlined,
                  label: 'Kırmızı Bayrak Tara',
                  onTap: _isLoading ? null : _runRedFlagScan,
                ),
                const SizedBox(width: 8),
                _buildMicroToolChip(
                  icon: Icons.reply_rounded,
                  label: 'Bu Mesaja Ne Yazayım?',
                  onTap: _isLoading ? null : _runReplySuggestion,
                ),
                const SizedBox(width: 8),
                _buildMicroToolChip(
                  icon: Icons.psychology_alt_outlined,
                  label: 'Gaslighting Testi',
                  onTap: _isLoading ? null : _runGaslightingTest,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.warmCream,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.softBorder),
            ),
            child: Text(
              'Bilgilendirme: Sonuçlar destek amaçlıdır, kesin tanı değildir. '
              'Mikro araçlar kısa cevap üretir; ekran görüntüsü yüklersen analiz daha isabetli olur.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.forestCharcoal.withOpacity(0.8),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicroToolChip({
    required IconData icon,
    required String label,
    required Future<void> Function()? onTap,
  }) {
    return InkWell(
      onTap: onTap == null ? null : () => onTap(),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade300 : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: onTap == null ? Colors.grey.shade400 : AppTheme.softBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.sageGreen),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.forestCharcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _NormalizedResult _ensureReplyFormat(String raw) {
    final text = raw.trim();
    if (text.contains('1)') && text.contains('2)') && text.contains('3)')) {
      return _NormalizedResult(content: text, corrected: false);
    }

    final first = _firstSentence(text);
    final safeFirst = first.isEmpty ? 'Bunu sakin ve net bir dille konuşmak istiyorum.' : first;
    return _NormalizedResult(
      content: '''
1) Nazik: $safeFirst
2) Net: Şu an netlik istiyorum; ne düşündüğünü açık söyler misin?
3) Sınır Koyan: Bu dil devam ederse konuşmayı durduracağım, saygılı iletişimde kalalım.
'''.trim(),
      corrected: true,
    );
  }

  _NormalizedResult _ensureGaslightingFormat(String raw) {
    final text = raw.trim();
    if (text.contains('1)') &&
        text.contains('2)') &&
        text.contains('3)') &&
        text.contains('4)')) {
      return _NormalizedResult(content: text, corrected: false);
    }

    final lower = text.toLowerCase();
    String result = 'Şüpheli';
    if (lower.contains('var')) result = 'Var';
    if (lower.contains('yok')) result = 'Yok';

    return _NormalizedResult(
      content: '''
1) Sonuç: $result
2) Kanıt:
- İfadede gerçekliği küçümseme/inkar tonu var.
- Duyguyu değersizleştiren dil riski görünüyor.
- Bağlam eksik; kesin yargı için daha fazla örnek gerekir.
3) Risk puanı: 55/100 - Dil manipülasyona işaret ediyor ama ek mesajlarla doğrulanmalı.
4) Kullanıcının atacağı 1 somut adım: Somut cümle iste: "Hangi davranışı kastettiğini net örnekle açıklar mısın?"
'''.trim(),
      corrected: true,
    );
  }

  _NormalizedResult _ensureRedFlagFormat(String raw) {
    final text = raw.trim();
    if (text.contains('1)') &&
        text.contains('2)') &&
        text.contains('3)') &&
        text.contains('4)')) {
      return _NormalizedResult(content: text, corrected: false);
    }

    final scoreMatch = RegExp(r'(\d{1,3})\s*/?\s*100').firstMatch(text);
    final score = scoreMatch?.group(1) ?? '50';

    return _NormalizedResult(
      content: '''
1) Kırmızı Bayraklar: Tutarsız iletişim, duygusal geri çekilme ve belirsizlik riski.
2) Toksisite Puanı: $score/100 - İletişim dengesi zayıf ve güven hissi düşüyor.
3) Saygı Düzeyi: Saygı kısmen korunuyor ama netlik ve süreklilik yetersiz.
4) Net Öneri: 24 saat içinde tek net mesaj at; cevap yine belirsizse teması azalt ve sınır koy.
'''.trim(),
      corrected: true,
    );
  }

  String _firstSentence(String text) {
    if (text.isEmpty) return '';
    final parts = text.split(RegExp(r'(?<=[.!?])\s+'));
    if (parts.isEmpty) return '';
    return parts.first.trim();
  }

  /// Initial analysis card - shown before any messages
  Widget _buildAnalysisCard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // Main Analysis Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF25D366), // WhatsApp green
                        const Color(0xFF128C7E),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF25D366).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('📱', style: TextStyle(fontSize: 36)),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Text(
                  AppTranslations.get('whatsappAnalysis'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.forestCharcoal,
                      ),
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  AppTranslations.get('whatsappAnalysisDesc'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.mutedSage,
                        height: 1.5,
                      ),
                ),

                if (_openingInsight != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.sageGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.sageGreen.withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: AppTheme.sageGreen, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Kişisel Durum Notu',
                              style: TextStyle(
                                color: AppTheme.forestCharcoal,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Son durum: ${_openingInsight!.lastState}',
                          style: TextStyle(
                            color: AppTheme.forestCharcoal.withOpacity(0.9),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Değişim: ${_openingInsight!.changeNote}',
                          style: TextStyle(
                            color: AppTheme.forestCharcoal.withOpacity(0.85),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bugün odak: ${_openingInsight!.todayFocus}',
                          style: TextStyle(
                            color: AppTheme.forestCharcoal.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 28),
                
                // Upload buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildUploadButton(
                        icon: Icons.photo_library_rounded,
                        label: AppTranslations.get('gallery'),
                        onTap: _pickImage,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildUploadButton(
                        icon: Icons.camera_alt_rounded,
                        label: AppTranslations.get('camera'),
                        onTap: _pickImageFromCamera,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Info text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.warmCream,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, 
                    color: AppTheme.sageGreen, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppTranslations.get('imagePrivacyNote'),
                    style: TextStyle(
                      color: AppTheme.forestCharcoal.withOpacity(0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Alternative text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.sageGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              AppTranslations.get('chatAlternative'),
              style: TextStyle(
                color: AppTheme.forestCharcoal,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.sageGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.sageGreen.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.sageGreen, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.sageGreen,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoading && index == _messages.length) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade200,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _selectedImageBytes!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTranslations.get('screenshotSelected'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.forestCharcoal,
                  ),
                ),
                Text(
                  AppTranslations.get('analyzeSendHint'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.mutedSage,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppTheme.mutedSage),
            onPressed: () => setState(() {
              _selectedImage = null;
              _selectedImageBytes = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.isUser;
    final timeStr = '${message.time.hour.toString().padLeft(2, '0')}:${message.time.minute.toString().padLeft(2, '0')}';
    
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 0,
        right: isUser ? 0 : 60,
        bottom: 8,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser ? const Color(0xFFDCF8C6) : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Show image if present
              if (message.imageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    message.imageBytes!,
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                message.content,
                style: TextStyle(
                  color: AppTheme.forestCharcoal,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (kDebugMode && message.autoFormatCorrected && !isUser) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'AUTO-FIX',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    timeStr,
                    style: TextStyle(color: AppTheme.mutedSage, fontSize: 11),
                  ),
                  if (isUser) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.done_all_rounded, size: 14, color: AppTheme.sageGreen),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(right: 60, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppTranslations.get('analyzingStatus'), style: TextStyle(color: AppTheme.mutedSage, fontSize: 13)),
              const SizedBox(width: 8),
              SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppTheme.sageGreen),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          // Camera button - opens bottom sheet
          GestureDetector(
            onTap: _showImagePickerSheet,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.sageGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.sageGreen.withOpacity(0.3)),
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                color: AppTheme.sageGreen,
                size: 24,
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Text input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(fontSize: 15),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: AppTranslations.get('messageInputHint'),
                  hintStyle: TextStyle(color: AppTheme.mutedSage),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) {
                  if (_isLoading) return;
                  _selectedImageBytes != null ? _analyzeScreenshot() : _sendMessage();
                },
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Mic Button
          GestureDetector(
            onTap: _listen,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isListening ? AppTheme.terracotta : AppTheme.sageGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (_isListening ? AppTheme.terracotta : AppTheme.sageGreen).withOpacity(0.3)),
              ),
              child: Icon(
                _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                color: _isListening ? Colors.white : AppTheme.sageGreen,
                size: 24,
              ),
            ),
          ),

          const SizedBox(width: 8),
          
          // Send button
          GestureDetector(
            onTap: _isLoading
                ? null
                : (_selectedImageBytes != null ? _analyzeScreenshot : _sendMessage),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.sageGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _selectedImageBytes != null ? Icons.search_rounded : Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Title
                Text(
                  AppTranslations.get('sendConversation'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.forestCharcoal,
                      ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                // Privacy message
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.sageGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, color: AppTheme.sageGreen, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppTranslations.get('privacySafe'),
                          style: TextStyle(
                            color: AppTheme.sageGreen,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Gallery option
                _buildPickerOption(
                  icon: Icons.photo_library_rounded,
                  title: AppTranslations.get('selectFromGallery'),
                  subtitle: AppTranslations.get('selectSavedScreenshots'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Camera option
                _buildPickerOption(
                  icon: Icons.camera_alt_rounded,
                  title: AppTranslations.get('takePhoto'),
                  subtitle: AppTranslations.get('takeScreenshotNow'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.sandBeige,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.sageGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.sageGreen, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.forestCharcoal,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.mutedSage,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.mutedSage, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String content;
  final bool isUser;
  final DateTime time;
  final Uint8List? imageBytes;
  final bool autoFormatCorrected;

  _ChatMessage({
    required this.content,
    required this.isUser,
    required this.time,
    this.imageBytes,
    this.autoFormatCorrected = false,
  });
}

class _NormalizedResult {
  final String content;
  final bool corrected;

  const _NormalizedResult({
    required this.content,
    required this.corrected,
  });
}
