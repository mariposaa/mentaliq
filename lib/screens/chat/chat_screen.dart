import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_theme.dart';
import '../../config/app_constants.dart';
import '../../services/gemini_service.dart';
import '../../services/token_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../../l10n/app_translations.dart';
import '../../config/responsive.dart';

import 'package:audioplayers/audioplayers.dart';
import '../../widgets/compassionate_background.dart';

class ChatScreen extends StatefulWidget {
  final String category;
  final String? customSystemPrompt;

  const ChatScreen({super.key, required this.category, this.customSystemPrompt});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  int _tokenBalance = 100;
  
  // Atmosphere & Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  AtmosphereType _currentAtmosphere = AtmosphereType.none;
  bool _isMusicPlaying = false;
  String? _currentTrack;
  double _volume = 0.5;

  // Speech to Text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _speechText = '';
  final TextEditingController _memoryController = TextEditingController();
  List<_CompassionMemory> _compassionMemories = [];
  String _selectedMood = 'uzgun';
  static const String _compassionMemoriesKey = 'compassion_memories_v1';
  static const int _memorySaveTokenCost = 5;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _initSpeech();
    if (widget.category == 'duygusal_destek') {
      _loadCompassionMemories();
    }
  }

  void _initSpeech() async {
    try {
      await _speech.initialize();
    } catch (e) {
      debugPrint('Speech init error: $e');
    }
  }

  void _listenToController(
    TextEditingController controller, {
    bool autoSendOnDone = false,
  }) async {
    if (!_isListening) {
      final status = await Permission.microphone.request();
      if (status.isDenied) return;

      bool available = await _speech.initialize(
        onStatus: (val) {
          debugPrint('onStatus: $val');
          if (val == 'notListening' || val == 'done') {
            if (mounted && _isListening) {
              setState(() => _isListening = false);
              if (autoSendOnDone && controller.text.isNotEmpty) {
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
              controller.text = val.recognizedWords;
            }
          }),
        );
      }
    } else {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  void _listenForChat() {
    _listenToController(_messageController, autoSendOnDone: true);
  }

  void _listenForMemory() {
    _listenToController(_memoryController);
  }

  Future<void> _initializeChat() async {
    // Start Gemini session
    GeminiService.startChatSession(
      widget.category,
      customSystemPrompt: widget.customSystemPrompt,
    );
    
    // Load token balance
    final balance = await TokenService.getBalance();
    setState(() => _tokenBalance = balance);

    // Add welcome message
    final welcomeMessage = _getWelcomeMessage();
    setState(() {
      _messages.add(_ChatMessage(content: welcomeMessage, isUser: false));
    });
  }

  String _getWelcomeMessage() {
    final name = AppConstants.categoryNames[widget.category] ?? widget.category;
    
    if (widget.category == 'duygusal_destek') {
       return '${AppTranslations.get('welcomeGreeting')}\n\n${AppTranslations.format('welcomeMessage', [name])}\n\n${AppTranslations.get('securityNoteTitle')}\n${AppTranslations.get('securityNoteMessage')}\n\n${AppTranslations.get('securityNoteQuestion')}';
    }

    return '${AppTranslations.get('welcomeGreeting')}\n\n${AppTranslations.format('welcomeGeneral', [name])}\n\n${AppTranslations.get('whatToShare')}';
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Check tokens
    final hasTokens = await TokenService.hasEnoughTokens();
    if (!hasTokens) {
      _showInsufficientTokensDialog();
      return;
    }

    _messageController.clear();

    setState(() {
      _messages.add(_ChatMessage(content: message, isUser: true));
      _isLoading = true;
    });

    _scrollToBottom();

    // Use tokens
    await TokenService.useTokensForMessage();
    final newBalance = await TokenService.getBalance();
    setState(() => _tokenBalance = newBalance);

    // Get AI response
    final response = await GeminiService.sendMessage(message);

    setState(() {
      _isLoading = false;
      _messages.add(_ChatMessage(content: response, isUser: false));
    });

    _scrollToBottom();
  }

  Future<void> _loadCompassionMemories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_compassionMemoriesKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = json.decode(raw) as List<dynamic>;
      setState(() {
        _compassionMemories = decoded
            .whereType<Map>()
            .map((item) => _CompassionMemory.fromJson(Map<String, dynamic>.from(item)))
            .toList()
            .reversed
            .toList();
      });
    } catch (_) {
      setState(() => _compassionMemories = []);
    }
  }

  Future<void> _saveCompassionMemories() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(
      _compassionMemories.reversed.map((item) => item.toJson()).toList(),
    );
    await prefs.setString(_compassionMemoriesKey, encoded);
  }

  Future<void> _saveMemoryEntry() async {
    final content = _memoryController.text.trim();
    if (content.isEmpty) return;

    final hasTokens = await TokenService.useTokensForTest(_memorySaveTokenCost);
    if (!hasTokens) {
      _showInsufficientTokensDialog();
      return;
    }

    final now = DateTime.now();
    final shortNote = content.replaceAll(RegExp(r'\s+'), ' ');
    final note = shortNote.length > 70 ? '${shortNote.substring(0, 70)}...' : shortNote;

    setState(() {
      _compassionMemories.insert(
        0,
        _CompassionMemory(
          mood: _selectedMood,
          note: note,
          content: content,
          createdAt: now,
        ),
      );
      _memoryController.clear();
    });

    await _saveCompassionMemories();
    final newBalance = await TokenService.getBalance();
    if (mounted) {
      setState(() => _tokenBalance = newBalance);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Anı kaydedildi (-5 elmas).')),
    );
  }


  void _showInsufficientTokensDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.warmCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        title: Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(AppTranslations.get('insufficientTokens')),
          ],
        ),
        content: Text(
          '${AppTranslations.get('insufficientTokensMessage')}\n\n${AppTranslations.get('currentLabel')} $_tokenBalance\n${AppTranslations.get('requiredLabel')} ${TokenService.messageTokenCost}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppTranslations.get('ok'), style: TextStyle(color: AppTheme.sageGreen)),
          ),
        ],
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
    _memoryController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    GeminiService.clearSession();
    super.dispose();
  }

  Future<void> _playTrack(String trackName, AtmosphereType type) async {
    try {
      if (_currentTrack == trackName && _isMusicPlaying) {
        await _audioPlayer.pause();
        setState(() => _isMusicPlaying = false);
      } else {
        await _audioPlayer.setSource(AssetSource('sounds/$trackName'));
        await _audioPlayer.setVolume(_volume);
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.resume();
        setState(() {
          _isMusicPlaying = true;
          _currentTrack = trackName;
          _currentAtmosphere = type;
        });
      }
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  void _showAtmospherePanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.warmCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.get('therapyAtmosphere'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.forestCharcoal),
            ),
            const SizedBox(height: 20),
            
            // Tracks
            _buildAtmosphereOption(
              AppTranslations.get('rainSound'), 
              'rain-and-thunder-176105.mp3', 
              AtmosphereType.rain, 
              Icons.water_drop_outlined,
              Colors.blueGrey
            ),
            _buildAtmosphereOption(
              AppTranslations.get('forestSound'), 
              'night-forest-soundscape-158701.mp3', 
              AtmosphereType.fireflies, 
              Icons.forest_outlined,
              Colors.green
            ),
            _buildAtmosphereOption(
              AppTranslations.get('oceanSound'), 
              'soothing-ocean-waves-372489.mp3', 
              AtmosphereType.breath, 
              Icons.waves_rounded,
              Colors.blueAccent
            ),
            _buildAtmosphereOption(
              AppTranslations.get('melancholicPiano'), 
              'dark-crime-piano-drama-449252.mp3', 
              AtmosphereType.deep, 
              Icons.piano_rounded,
              Colors.deepPurple
            ),

            if (_isMusicPlaying) ...[
              const SizedBox(height: 30),
              Row(
                children: [
                  const Icon(Icons.volume_down_rounded, size: 20, color: AppTheme.mutedSage),
                  Expanded(
                    child: Slider(
                      value: _volume,
                      activeColor: AppTheme.sageGreen,
                      inactiveColor: AppTheme.softBorder,
                      onChanged: (val) {
                        setState(() => _volume = val);
                        _audioPlayer.setVolume(val);
                      },
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded, size: 20, color: AppTheme.mutedSage),
                ],
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAtmosphereOption(String title, String file, AtmosphereType type, IconData icon, Color color) {
    final isSelected = _currentTrack == file && _isMusicPlaying;
    
    return ListTile(
      onTap: () {
        _playTrack(file, type);
        Navigator.pop(context);
      },
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isSelected ? Icons.pause_rounded : Icons.play_arrow_rounded, 
          color: isSelected ? Colors.white : color
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: AppTheme.forestCharcoal
        ),
      ),
      trailing: isSelected 
        ? Icon(icon, color: color) 
        : Icon(icon, color: AppTheme.mutedSage.withOpacity(0.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompactPhone;
    final categoryName = AppConstants.categoryNames[widget.category] ?? widget.category;
    final categoryIcon = AppConstants.categoryIcons[widget.category] ?? '🌿';
    
    // Check if this is the Compassionate Zone
    final isCompassionateZone = widget.category == 'duygusal_destek';

    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      body: CompassionateBackground(
        type: isCompassionateZone ? _currentAtmosphere : AtmosphereType.none,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 4 : 8,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  // Transparent header if background is active
                  color: (isCompassionateZone && _currentAtmosphere != AtmosphereType.none) 
                      ? Colors.transparent 
                      : AppTheme.sandBeige,
                  border: Border(bottom: BorderSide(color: AppTheme.softBorder)),
                ),
                child: Row(
                  children: [
                    IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                        onPressed: () => Navigator.pop(context),
                        color: (_currentAtmosphere != AtmosphereType.none && isCompassionateZone) 
                            ? Colors.white 
                            : AppTheme.forestCharcoal,
                      ),
                    Container(
                      width: isCompact ? 36 : 40,
                      height: isCompact ? 36 : 40,
                      decoration: BoxDecoration(
                        color: AppTheme.sageGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(categoryIcon, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                    SizedBox(width: isCompact ? 8 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoryName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isCompact ? 15 : null,
                                  color: (_currentAtmosphere != AtmosphereType.none && isCompassionateZone) 
                                      ? Colors.white 
                                      : AppTheme.forestCharcoal,
                                ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _isLoading ? AppTheme.terracotta : AppTheme.sageGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isLoading ? AppTranslations.get('thinking') : AppTranslations.get('listeningStatus'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: (_currentAtmosphere != AtmosphereType.none && isCompassionateZone) 
                                          ? Colors.white70 
                                          : AppTheme.mutedSage,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Atmosphere Toggle Button (Only for Compassionate Zone)
                    if (isCompassionateZone)
                      GestureDetector(
                        onTap: _showAtmospherePanel,
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 8 : 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _isMusicPlaying 
                                ? AppTheme.terracotta 
                                : AppTheme.sageGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                               color: _isMusicPlaying ? Colors.transparent : AppTheme.sageGreen.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isMusicPlaying ? AppTranslations.get('atmosphereOn') : AppTranslations.get('changeAtmosphere'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: isCompact ? 10 : 11,
                                  fontWeight: FontWeight.w600,
                                  color: _isMusicPlaying ? Colors.white : AppTheme.sageGreen,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                _isMusicPlaying ? Icons.music_note_rounded : Icons.spa_outlined,
                                size: 16,
                                color: _isMusicPlaying ? Colors.white : AppTheme.sageGreen,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Token indicator
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 8 : 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.sageGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            '$_tokenBalance',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.sageGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            if (isCompassionateZone) ...[
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  decoration: BoxDecoration(
                    color: AppTheme.warmCream,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.softBorder),
                  ),
                  child: DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          labelColor: AppTheme.sageGreen,
                          unselectedLabelColor: AppTheme.mutedSage,
                          indicatorColor: AppTheme.sageGreen,
                          tabs: const [
                            Tab(text: 'İçini Dök'),
                            Tab(text: 'Anı Yaz'),
                            Tab(text: 'Anılar'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildChatTab(),
                              _buildMemoryComposerTab(),
                              _buildMemoriesTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              _buildMessagesList(),
              _buildChatInput(),
            ],
          ],
        ),
      ),
    ),
  );
}

  Widget _buildChatTab() {
    return Column(
      children: [
        _buildMessagesList(),
        _buildChatInput(),
      ],
    );
  }

  Widget _buildMessagesList() {
    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: _messages.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (_isLoading && index == _messages.length) {
            return _buildTypingIndicator();
          }
          return _buildMessageBubble(_messages[index]);
        },
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: AppTheme.warmCream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: Theme.of(context).textTheme.bodyLarge,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: AppTranslations.get('whatAreYouThinking'),
                hintStyle: TextStyle(color: AppTheme.mutedSage),
                filled: true,
                fillColor: AppTheme.sandBeige,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _listenForChat,
            child: Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: _isListening ? AppTheme.terracotta : AppTheme.sageGreen.withOpacity(0.12),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isListening ? AppTheme.terracotta : AppTheme.sageGreen).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                color: _isListening ? Colors.white : AppTheme.sageGreen,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: AppTheme.terracotta,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.terracotta.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryComposerTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        children: [
          TextField(
            controller: _memoryController,
            maxLines: 7,
            decoration: InputDecoration(
              hintText: 'Anını yaz veya mikrofonla konuş...',
              filled: true,
              fillColor: AppTheme.sandBeige,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _moodOptions.map((mood) {
                      final selected = mood['id'] == _selectedMood;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${mood['emoji']} ${mood['label']}'),
                          selected: selected,
                          onSelected: (_) => setState(() => _selectedMood = mood['id']!),
                          selectedColor: AppTheme.sageGreen.withOpacity(0.2),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _listenForMemory,
                  icon: Icon(_isListening ? Icons.stop_rounded : Icons.mic_rounded),
                  label: Text(_isListening ? 'Durdur' : 'Sesle Yaz'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveMemoryEntry,
                  icon: const Icon(Icons.bookmark_add_rounded),
                  label: const Text('Anıyı Kaydet'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemoriesTab() {
    if (_compassionMemories.isEmpty) {
      return const Center(
        child: Text('Henüz kayıtlı anı yok.'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width <= 360 ? 1 : 2;
        return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: width <= 390 ? 0.9 : 0.95,
      ),
      itemCount: _compassionMemories.length,
      itemBuilder: (context, index) {
        final item = _compassionMemories[index];
        return GestureDetector(
          onTap: () => _showMemoryDetails(item),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warmCream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.softBorder),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SvgPicture.asset(
                      _moodCatAsset(item.mood),
                      width: width <= 390 ? 100 : 120,
                      height: width <= 390 ? 100 : 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Text(
                  _formatDateTime(item.createdAt),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.forestCharcoal,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
      },
    );
  }

  static const List<Map<String, String>> _moodOptions = [
    {'id': 'uzgun', 'label': 'Üzgün', 'emoji': '😿'},
    {'id': 'neseli', 'label': 'Neşeli', 'emoji': '😺'},
    {'id': 'kaygili', 'label': 'Kaygılı', 'emoji': '😾'},
    {'id': 'sakin', 'label': 'Sakin', 'emoji': '😸'},
  ];

  String _moodLabel(String moodId) {
    final mood = _moodOptions.firstWhere(
      (item) => item['id'] == moodId,
      orElse: () => _moodOptions.first,
    );
    return mood['label']!;
  }

  String _moodCatAsset(String moodId) {
    switch (moodId) {
      case 'uzgun':
        return 'assets/images/cats/uzgun.svg';
      case 'neseli':
        return 'assets/images/cats/neseli.svg';
      case 'kaygili':
        return 'assets/images/cats/kaygili.svg';
      case 'sakin':
        return 'assets/images/cats/sakin.svg';
      default:
        return 'assets/images/cats/sakin.svg';
    }
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  void _showMemoryDetails(_CompassionMemory item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.warmCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        title: Text('${_moodLabel(item.mood)} • ${_formatDateTime(item.createdAt)}'),
        content: SingleChildScrollView(
          child: Text(
            item.content,
            style: const TextStyle(
              color: AppTheme.forestCharcoal,
              height: 1.4,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.sageGreen.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🌿', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: message.isUser ? AppTheme.sageGreen : AppTheme.warmCream,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(message.isUser ? 20 : 6),
                  bottomRight: Radius.circular(message.isUser ? 6 : 20),
                ),
                boxShadow: message.isUser ? null : AppTheme.cardShadow,
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: message.isUser ? Colors.white : AppTheme.forestCharcoal,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (message.isUser) const SizedBox(width: 42),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.sageGreen.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🌿', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.warmCream,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.sageGreen.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String content;
  final bool isUser;

  _ChatMessage({required this.content, required this.isUser});
}

class _CompassionMemory {
  final String mood;
  final String note;
  final String content;
  final DateTime createdAt;

  const _CompassionMemory({
    required this.mood,
    required this.note,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'mood': mood,
      'note': note,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory _CompassionMemory.fromJson(Map<String, dynamic> json) {
    return _CompassionMemory(
      mood: (json['mood'] ?? 'uzgun').toString(),
      note: (json['note'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}
