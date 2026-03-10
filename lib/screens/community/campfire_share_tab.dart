import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../l10n/app_translations.dart';
import '../../services/forum_service.dart';
import '../../widgets/responsive_card.dart';

const int _kMaxPostLength = 150;

class CampfireShareTab extends StatefulWidget {
  const CampfireShareTab({super.key});

  @override
  State<CampfireShareTab> createState() => _CampfireShareTabState();
}

class _CampfireShareTabState extends State<CampfireShareTab> {
  final _textController = TextEditingController();
  String _postType = 'confession';
  bool _isAnonymous = false;
  XFile? _pickedImage;
  bool _sending = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Widget _buildTypeButton(String type, String emoji, String label) {
    final isSelected = _postType == type;
    final color = AppTheme.postTypeColor(type);
    final maxWidth = (MediaQuery.sizeOf(context).width - 56) / 2;
    return SizedBox(
      width: maxWidth < 170 ? maxWidth : 170,
      child: GestureDetector(
        onTap: () => setState(() => _postType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : AppTheme.warmCream,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : AppTheme.softBorder, width: isSelected ? 2 : 1),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: isSelected ? color : AppTheme.mutedSage),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTypeDescription(String type) {
    switch (type) {
      case 'confession': return AppTranslations.get('confessionDesc');
      case 'photo_story': return AppTranslations.get('photoStoryDesc');
      case 'idea_question': return AppTranslations.get('ideaQuestionDesc');
      default: return '';
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (x != null && mounted) setState(() => _pickedImage = x);
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('enterText'))));
      return;
    }
    setState(() => _sending = true);
    try {
      Uint8List? imageBytes;
      if (_pickedImage != null) imageBytes = await _pickedImage!.readAsBytes();
      await ForumService.createPost(
        postType: _postType,
        text: text,
        isAnonymous: _isAnonymous,
        imageBytes: imageBytes,
      );
      if (mounted) {
        _textController.clear();
        setState(() => _pickedImage = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('shared'))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompactPhone;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppTranslations.get('postType'), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.forestCharcoal)),
          const SizedBox(height: 8),
          // Tür seçimi - 3 buton
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTypeButton('confession', '🤫', AppTranslations.get('confessionType')),
              _buildTypeButton('photo_story', '📸', AppTranslations.get('photoStoryType')),
              _buildTypeButton('idea_question', '💡', AppTranslations.get('ideaQuestionType')),
            ],
          ),
          const SizedBox(height: 12),
          // Seçili tür önizlemesi
          ResponsiveCard(
            padding: 12,
            color: AppTheme.postTypeColor(_postType).withOpacity(0.1),
            radius: 12,
            border: Border.all(
              color: AppTheme.postTypeColor(_postType).withOpacity(0.3),
            ),
            child: Row(
              children: [
                Text(AppTheme.postTypeEmoji(_postType), style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTheme.postTypeLabel(_postType),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.postTypeColor(_postType)),
                      ),
                      Text(
                        _getTypeDescription(_postType),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: AppTheme.mutedSage),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_postType == 'confession') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _isAnonymous,
                  onChanged: (v) => setState(() => _isAnonymous = v ?? false),
                  activeColor: AppTheme.terracotta,
                ),
                Text(AppTranslations.get('anonymousShare')),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text('Metin * (en fazla $_kMaxPostLength karakter)', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.forestCharcoal)),
          const SizedBox(height: 6),
          TextField(
            controller: _textController,
            maxLines: 4,
            maxLength: _kMaxPostLength,
            inputFormatters: [LengthLimitingTextInputFormatter(_kMaxPostLength)],
            decoration: InputDecoration(
              hintText: AppTranslations.get('shareInputHint'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppTheme.warmCream,
              counterStyle: TextStyle(fontSize: 11, color: AppTheme.mutedSage),
            ),
          ),
          const SizedBox(height: 16),
          Text(AppTranslations.get('imageOptional'), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.mutedSage)),
          const SizedBox(height: 6),
          if (_pickedImage != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: AppTheme.forumSharePreviewHeight,
                    width: double.infinity,
                    child: FutureBuilder<Uint8List>(
                      future: _pickedImage!.readAsBytes(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        return Image.memory(snapshot.data!, fit: BoxFit.contain);
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _pickedImage = null),
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(AppTranslations.get('addPhoto')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.mutedSage,
                side: BorderSide(color: AppTheme.softBorder),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _sending ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: AppTheme.terracotta, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _sending ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(AppTranslations.get('share')),
          ),
        ],
      ),
    );
  }
}
