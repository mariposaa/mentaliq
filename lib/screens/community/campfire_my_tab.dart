import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../l10n/app_translations.dart';
import '../../models/forum_post.dart';
import '../../services/forum_service.dart';
import 'campfire_post_detail_screen.dart';
import 'forum_post_image.dart';

class CampfireMyTab extends StatefulWidget {
  const CampfireMyTab({super.key});

  @override
  State<CampfireMyTab> createState() => _CampfireMyTabState();
}

class _CampfireMyTabState extends State<CampfireMyTab> {
  List<ForumPost> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final list = await ForumService.getMyPosts();
    if (!mounted) return;
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() => _list = list);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompactPhone;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.terracotta));
    }
    if (_list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note_rounded, size: 56, color: AppTheme.terracotta.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(AppTranslations.get('noMyPosts'), style: TextStyle(fontSize: 15, color: AppTheme.mutedSage)),
            const SizedBox(height: 4),
            Text(AppTranslations.get('postFirstFromShare'), style: TextStyle(fontSize: 13, color: AppTheme.mutedSage)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.terracotta,
      child: ListView.builder(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        itemCount: _list.length,
        itemBuilder: (_, i) {
          final p = _list[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
            clipBehavior: Clip.antiAlias,
            color: AppTheme.warmCream,
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CampfirePostDetailScreen(postId: p.id))).then((_) => _load()),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: Padding(
                padding: EdgeInsets.all(isCompact ? 12 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Tür etiketi
                        Expanded(
                          child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.postTypeColor(p.postType).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(AppTheme.postTypeEmoji(p.postType), style: const TextStyle(fontSize: 11)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  AppTheme.postTypeLabel(p.postType),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.postTypeColor(p.postType)),
                                ),
                              ),
                            ],
                          ),
                        )),
                        const SizedBox(width: 8),
                        Text(DateFormat('d MMM · HH:mm', 'tr').format(p.createdAt), style: TextStyle(fontSize: 12, color: AppTheme.mutedSage)),
                      ],
                    ),
                    if (p.imageUrl != null) ...[
                      const SizedBox(height: 8),
                      ForumPostImage(
                        imageUrl: p.imageUrl!,
                        maxHeight: AppTheme.forumMyCardImageHeight,
                        borderRadius: 8,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      p.text,
                      style: TextStyle(
                        fontSize: isCompact ? 13 : 14,
                        color: AppTheme.forestCharcoal,
                      ),
                      maxLines: isCompact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

}
