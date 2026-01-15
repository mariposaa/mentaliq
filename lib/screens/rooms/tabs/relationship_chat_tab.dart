import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../../../config/app_theme.dart';
import '../../../services/gemini_service.dart';
import '../../../services/token_service.dart';
import '../../../services/shadow_memory_service.dart';

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
  
  // Selected image
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await GeminiService.startChatSession('iliskiler');
    final balance = await TokenService.getBalance();
    setState(() => _tokenBalance = balance);
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
      _showErrorSnackbar('Resim seçilemedi: $e');
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
      _showErrorSnackbar('Fotoğraf çekilemedi');
    }
  }

  /// Analyze the selected WhatsApp screenshot
  Future<void> _analyzeScreenshot() async {
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
        content: '📸 WhatsApp ekran görüntüsü yüklendi',
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
    } catch (e) {
      debugPrint('Error analyzing image: $e');
      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(
          content: 'Üzgünüm, resmi analiz ederken bir hata oluştu. Lütfen tekrar dene.',
          isUser: false,
          time: DateTime.now(),
        ));
      });
    }
  }

  void _sendMessage() async {
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
  }


  Future<void> _showTokenDialog() async {
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
        if (_selectedImageBytes != null) _buildImagePreview(),
        _buildInputArea(),
      ],
    );
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
                  'WhatsApp Mesaj Analizi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.forestCharcoal,
                      ),
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  'Yazışmalarının ekran görüntüsünü yükle,\nben analiz edip sana tavsiyeler vereyim.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.mutedSage,
                        height: 1.5,
                      ),
                ),
                
                const SizedBox(height: 28),
                
                // Upload buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildUploadButton(
                        icon: Icons.photo_library_rounded,
                        label: 'Galeri',
                        onTap: _pickImage,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildUploadButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'Kamera',
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
                    'Resimler yalnızca analiz için kullanılır ve saklanmaz.',
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
              '💬 veya mesaj yazarak sohbet edebilirsin',
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
                  'Ekran görüntüsü seçildi',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.forestCharcoal,
                  ),
                ),
                Text(
                  'Analiz etmek için gönder butonuna bas',
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
              Text('Analiz ediliyor', style: TextStyle(color: AppTheme.mutedSage, fontSize: 13)),
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
                  hintText: 'Mesaj yaz...',
                  hintStyle: TextStyle(color: AppTheme.mutedSage),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _selectedImageBytes != null ? _analyzeScreenshot() : _sendMessage(),
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Send button
          GestureDetector(
            onTap: _selectedImageBytes != null ? _analyzeScreenshot : _sendMessage,
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
                  'Analiz etmem için WhatsApp konuşmanı at',
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
                          'Resimler kesinlikle saklanmıyor, gizliliğin güvende.',
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
                  title: 'Galeriden Seç',
                  subtitle: 'Kayıtlı ekran görüntülerinden seç',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Camera option
                _buildPickerOption(
                  icon: Icons.camera_alt_rounded,
                  title: 'Fotoğraf Çek',
                  subtitle: 'Ekrandaki konuşmayı şimdi çek',
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

  _ChatMessage({
    required this.content,
    required this.isUser,
    required this.time,
    this.imageBytes,
  });
}
