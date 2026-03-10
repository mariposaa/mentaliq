import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_locale.dart';
import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../l10n/app_translations.dart';
import '../../models/forum_post.dart';
import '../../services/auth_service.dart';
import '../../services/forum_service.dart';
import 'campfire_post_detail_screen.dart';
import 'forum_post_image.dart';

class CampfireFeedTab extends StatelessWidget {
  const CampfireFeedTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompactPhone;
    return StreamBuilder<List<ForumPost>>(
      stream: ForumService.watchFeedPosts(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.terracotta));
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_fire_department_rounded, size: 56, color: AppTheme.terracotta.withOpacity(0.5)),
                const SizedBox(height: 12),
                Text(AppTranslations.get('noPostsYet'), style: TextStyle(fontSize: 15, color: AppTheme.mutedSage)),
                const SizedBox(height: 4),
                Text(AppTranslations.get('makeFirstPost'), style: TextStyle(fontSize: 13, color: AppTheme.mutedSage)),
              ],
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width <= 340 ? 1 : (width <= 430 ? 2 : 3);
            final itemWidth =
                (width - 24 - ((crossAxisCount - 1) * 8)) / crossAxisCount;
            final aspectRatio = itemWidth <= 150 ? 0.54 : (isCompact ? 0.6 : 0.64);
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 10,
                childAspectRatio: aspectRatio,
              ),
              itemCount: list.length,
              itemBuilder: (_, index) {
                final post = list[index];
                return _PostCard(
                  post: post,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CampfirePostDetailScreen(postId: post.id),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _PostCard extends StatefulWidget {
  const _PostCard({required this.post, required this.onTap});

  final ForumPost post;
  final VoidCallback onTap;

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  String? _translatedText;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    _loadTranslation();
  }

  @override
  void didUpdateWidget(covariant _PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _translatedText = null;
      _loadTranslation();
    }
  }

  Future<void> _loadTranslation() async {
    final targetLang = AppLocale.currentLanguageCode;
    final post = widget.post;
    
    // Orijinal dil aynıysa çeviri gerekmez
    if (post.language == targetLang) {
      if (mounted) setState(() => _translatedText = post.text);
      return;
    }
    
    // Cache'de varsa direkt kullan
    if (post.translations.containsKey(targetLang)) {
      if (mounted) setState(() => _translatedText = post.translations[targetLang]);
      return;
    }
    
    // Çeviri gerekiyor
    if (mounted) setState(() => _isTranslating = true);
    
    final translated = await ForumService.translatePost(post, targetLang);
    
    if (mounted) {
      setState(() {
        _translatedText = translated;
        _isTranslating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final displayText = _translatedText ?? post.text;
    final userLang = AppLocale.currentLanguageCode;
    final needsTranslation = post.language != userLang;
    
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: AppTheme.warmCream,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Tür etiketi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.postTypeColor(post.postType).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppTheme.postTypeEmoji(post.postType), style: const TextStyle(fontSize: 10)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        AppTheme.postTypeLabel(post.postType),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppTheme.postTypeColor(post.postType)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  CircleAvatar(radius: 12, backgroundColor: AppTheme.postTypeColor(post.postType).withOpacity(0.2), child: Text(post.displayAuthorName[0].toUpperCase(), style: TextStyle(color: AppTheme.postTypeColor(post.postType), fontWeight: FontWeight.w600, fontSize: 10))),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(post.displayAuthorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: AppTheme.forestCharcoal), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(DateFormat('d MMM · HH:mm', 'tr').format(post.createdAt), style: TextStyle(fontSize: 9, color: AppTheme.mutedSage)),
                      ],
                    ),
                  ),
                  // Çevrildi göstergesi
                  if (needsTranslation && !_isTranslating) 
                    Tooltip(
                      message: AppTranslations.format('translatedTooltip', [post.language.toUpperCase()]),
                      child: Icon(Icons.translate, size: 10, color: AppTheme.mutedSage.withOpacity(0.7)),
                    ),
                ],
              ),
              if (post.imageUrl != null) ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: ForumPostImage(
                    imageUrl: post.imageUrl!,
                    maxHeight: 150,
                    borderRadius: 8,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              if (_isTranslating)
                Row(
                  children: [
                    SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.mutedSage)),
                    const SizedBox(width: 6),
                    Text(AppTranslations.get('translating'), style: TextStyle(fontSize: 11, color: AppTheme.mutedSage, fontStyle: FontStyle.italic)),
                  ],
                )
              else
                Text(displayText, style: const TextStyle(fontSize: 12, color: AppTheme.forestCharcoal), maxLines: 2, overflow: TextOverflow.ellipsis),
              // Yorum ve Destek sayıları
              const SizedBox(height: 8),
              Row(
                children: [
                  // Destek butonu
                  _SupportButton(post: post),
                  const SizedBox(width: 12),
                  // Yorum sayısı
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 12, color: AppTheme.mutedSage),
                      const SizedBox(width: 3),
                      Text('${post.commentCount}', style: TextStyle(fontSize: 10, color: AppTheme.mutedSage)),
                    ],
                  ),
                ],
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportButton extends StatefulWidget {
  const _SupportButton({required this.post});
  
  final ForumPost post;

  @override
  State<_SupportButton> createState() => _SupportButtonState();
}

class _SupportButtonState extends State<_SupportButton> {
  late bool _isSupported;
  late int _count;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _isSupported = widget.post.isSupportedBy(AuthService.userId);
    _count = widget.post.supportCount;
  }

  @override
  void didUpdateWidget(covariant _SupportButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _isSupported = widget.post.isSupportedBy(AuthService.userId);
      _count = widget.post.supportCount;
    }
  }

  Future<void> _toggle() async {
    if (_loading) return;
    setState(() => _loading = true);
    
    final newState = await ForumService.toggleSupport(widget.post.id);
    
    if (mounted) {
      setState(() {
        _isSupported = newState;
        _count = newState ? _count + 1 : _count - 1;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _isSupported ? AppTheme.terracotta.withOpacity(0.15) : AppTheme.softBorder.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🫂', style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text(
              '$_count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _isSupported ? AppTheme.terracotta : AppTheme.forestCharcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
