import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../../../config/app_theme.dart';
import '../../../services/gemini_service.dart';
import '../../../services/token_service.dart';
import '../../../services/ad_service.dart';
import '../../../services/user_dna_service.dart';
import 'package:permission_handler/permission_handler.dart';

class MindAtelierChatTab extends StatefulWidget {
  const MindAtelierChatTab({super.key});

  @override
  State<MindAtelierChatTab> createState() => _MindAtelierChatTabState();
}

class _MindAtelierChatTabState extends State<MindAtelierChatTab> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _text = '';
  double _confidence = 1.0;
  bool _isLoading = false;
  final List<_Message> _messages = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initSpeech();
    // İlk karşılama mesajı
    _messages.add(_Message(
      text: "Merhaba. Persona Psikoloji'ye hoş geldin. Burası senin güvenli alanın. Konuşmaya başlamak için mikrofona basabilirsin. Seni dinliyorum.",
      isUser: false,
    ));
  }

  void _initSpeech() async {
    try {
      await _speech.initialize();
    } catch (e) {
      debugPrint('Speech init error: $e');
    }
    if (mounted) setState(() {});
  }

  void _listen() async {
    if (!_isListening) {
      final status = await Permission.microphone.request();
      if (status.isDenied) return;

      bool available = await _speech.initialize(
        onStatus: (val) => debugPrint('onStatus: $val'),
        onError: (val) => debugPrint('onError: $val'),
      );
      if (available) {
        setState(() {
          _isListening = true;
          _text = '';
        });
        _speech.listen(
          localeId: 'tr_TR',
          onResult: (val) => setState(() {
            _text = val.recognizedWords;
            if (val.hasConfidenceRating && val.confidence > 0) {
              _confidence = val.confidence;
            }
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_text.isNotEmpty) {
        // Küçük bir gecikme ile son kelimelerin yakalanmasını sağla
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_text.isNotEmpty) {
            _sendMessage(_text);
          }
        });
      }
    }
  }

  Future<void> _sendMessage(String message) async {
    // Token Kontrolü (Sessizce)
    final hasTokens = await TokenService.hasEnoughTokens();
    if (!hasTokens) {
      if (mounted) {
        _showNoTokensDialog();
      }
      return;
    }

    // Token Düş (Sessizce)
    await TokenService.useTokensForMessage();

    setState(() {
      _messages.add(_Message(text: message, isUser: true));
      _isLoading = true;
      _text = '';
    });
    _scrollToBottom();

    try {
      // DNA Bağlamını Al
      final dnaContext = await UserDNAService.getDNAForAI();

      // Dünya Klasında Uzman Psikolog Personası
      final systemPrompt = """
      Sen 'Persona Psikoloji'nin baş rehberi, dünya klasında uzman bir Klinik Psikologsun. 
      Ekolün: Rogersyen (Kişi Odaklı), BDT (Bilişsel Davranışçı Terapi) ve Jungiyen Gölge Çalışması'nın sentezidir.
      
      $dnaContext

      MISYONUN:
      Kullanıcının yüzeydeki şikayetlerinin (öfke, stres vb.) altındaki derin duygusal kökleri bulmasına yardımcı olmak.
      
      REHBERLIK KURALLARI:
      1. AKTİF DİNLEME: Kullanıcının söylediğini kendi kelimelerinle özetle.
      2. DERİN SORULAR: 'Neden?' yerine 'Nasıl?' ve 'Bu duygu vücudunda nerede yankılanıyor?' gibi sorular sor.
      3. UYARI & FİKİR: Kullanıcı kendine zarar veren bir düşünce kalıbındaysa nazikçe uyar.
      4. EMPATİ: Samimi ama mesafeli bir profesyonellikle konuş.
      5. KISALIK: Yanıtların max 2-3 cümle olsun. 
      
      SES TONU: Anlayışlı, sakin, güven veren bir profesyonel gibi düşünerek yaz.
      """;

      final response = await GeminiService.generateResponse(
        message,
        'kendin_kesfet',
        customSystemPrompt: systemPrompt,
      );

      if (mounted) {
        setState(() {
          _messages.add(_Message(text: response, isUser: false));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showNoTokensDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.sandBeige,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.stars_rounded, color: AppTheme.terracotta),
            SizedBox(width: 10),
            Text('Tokenlerin Bitti', style: TextStyle(color: AppTheme.forestCharcoal)),
          ],
        ),
        content: const Text(
          'Zihin Atölyesi seansına devam etmek için bir reklam izleyerek 30 token kazanabilirsin.',
          style: TextStyle(color: AppTheme.forestCharcoal),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sonra', style: TextStyle(color: AppTheme.mutedSage)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await AdService.showRewardedAd();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.sageGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Reklam İzle (30 🪙)', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _analyzeSession() async {
    if (_messages.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analiz için biraz daha konuşmalıyız.')),
      );
      return;
    }

    final hasTokens = await TokenService.hasEnoughTokensForAnalysis();
    if (!hasTokens) {
      _showNoTokensDialog();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final conversation = _messages.map((m) => "${m.isUser ? 'Kullanıcı' : 'Psikolog'}: ${m.text}").join("\n");
      
      final analysisPrompt = """
      Aşağıdaki psikolojik seans konuşmasını analiz et ve kullanıcının karakter özelliklerini, değerlerini ve mbti tipini çıkar.
      Yanıtını SADECE aşağıdaki JSON formatında ver, başka hiçbir metin ekleme:
      {
        "user_dna": {
          "mbti": "...",
          "personality_traits": ["...", "..."],
          "core_values": ["...", "..."],
          "fears": ["...", "..."]
        }
      }
      
      Konuşma:
      $conversation
      """;

      final response = await GeminiService.generateResponse(analysisPrompt, 'genel');
      
      // JSON Parse
      final cleanJson = response.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> data = jsonDecode(cleanJson);
      
      final updates = UserDNAService.parseUpdatesFromJson(data);
      if (updates != null) {
        await UserDNAService.updateDNA(updates);
        await TokenService.useTokensForAnalysis();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Zihin DNA\'nız başarıyla güncellendi!'),
              backgroundColor: AppTheme.sageGreen,
            ),
          );
          setState(() {
            _messages.add(_Message(
              text: "Harika bir seanstı. Paylaştıkların sayesinde senin hakkında daha derin içgörülere sahip oldum. Zihin DNA tabinden güncel karakter haritana bakabilirsin.",
              isUser: false,
            ));
          });
        }
      }
    } catch (e) {
      debugPrint('Analysis error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Üst Bar: Analiz Butonu
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPrivacyBadge(),
              if (_messages.length >= 3)
                TextButton.icon(
                  onPressed: _isLoading ? null : _analyzeSession,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppTheme.sageGreen),
                  label: const Text(
                    'Analiz Et (15 🪙)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.sageGreen),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.sageGreen.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
            ],
          ),
        ),

        // Yazılı içerik alanı
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return _buildMessageBubble(msg);
            },
          ),
        ),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.sageGreen),
            ),
          ),

        // Ses Tanıma Görselleştirmesi
        if (_isListening)
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              _text.isEmpty ? "Dinliyorum..." : _text,
              style: TextStyle(
                color: AppTheme.forestCharcoal.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        // Alt Panel: Kontroller
        _buildControls(),
      ],
    );
  }

  Widget _buildPrivacyBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.sageGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.security_rounded, size: 12, color: AppTheme.sageGreen),
          SizedBox(width: 6),
          Text(
            'Güvenli Alan',
            style: TextStyle(fontSize: 10, color: AppTheme.forestCharcoal, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30, top: 10),
      child: Column(
        children: [
          GestureDetector(
            onTap: _listen,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: _isListening ? AppTheme.terracotta : AppTheme.sageGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isListening ? AppTheme.terracotta : AppTheme.sageGreen).withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: _isListening ? 5 : 0,
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isListening ? 'Bitirmek için Dokun' : 'Konuşmak için Bas',
            style: TextStyle(fontSize: 11, color: AppTheme.mutedSage),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_Message msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: msg.isUser ? AppTheme.sageGreen : AppTheme.warmCream,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 0),
            bottomRight: Radius.circular(msg.isUser ? 0 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: msg.isUser ? Colors.white : AppTheme.forestCharcoal,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isUser;
  _Message({required this.text, required this.isUser});
}
