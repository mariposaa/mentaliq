import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_locale.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_translations.dart';
import '../../models/forum_post.dart';
import '../../models/forum_comment.dart';
import '../../services/forum_service.dart';
import '../../services/auth_service.dart';
import '../../services/admin_role_service.dart';
import 'forum_post_image.dart';

class CampfirePostDetailScreen extends StatefulWidget {
  const CampfirePostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  State<CampfirePostDetailScreen> createState() => _CampfirePostDetailScreenState();
}

class _CampfirePostDetailScreenState extends State<CampfirePostDetailScreen> {
  final _commentController = TextEditingController();
  ForumPost? _post;
  String? _translatedText;
  bool _isTranslating = false;
  bool _canModerateForum = false;

  @override
  void initState() {
    super.initState();
    _loadPost();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final canModerate = await AdminRoleService.hasPermission(
      AdminPermission.moderateForum,
    );
    if (!mounted) return;
    setState(() => _canModerateForum = canModerate);
  }

  Future<void> _loadPost() async {
    final p = await ForumService.getPost(widget.postId);
    if (mounted) {
      setState(() => _post = p);
      if (p != null) _loadTranslation(p);
    }
  }

  Future<void> _loadTranslation(ForumPost post) async {
    final targetLang = AppLocale.currentLanguageCode;
    
    if (post.language == targetLang) {
      if (mounted) setState(() => _translatedText = post.text);
      return;
    }
    
    if (post.translations.containsKey(targetLang)) {
      if (mounted) setState(() => _translatedText = post.translations[targetLang]);
      return;
    }
    
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
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_post == null) {
      return Scaffold(
        backgroundColor: AppTheme.sandBeige,
        appBar: AppBar(backgroundColor: AppTheme.sandBeige, title: Text(AppTranslations.get('post'))),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.terracotta)),
      );
    }
    final post = _post!;
    final isMine = post.authorId == AuthService.userId;
    final canDeletePost = isMine || _canModerateForum;

    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      appBar: AppBar(
        backgroundColor: AppTheme.sandBeige,
        elevation: 0,
        title: Text(AppTranslations.get('post'), style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.forestCharcoal)),
        actions: canDeletePost
            ? [
                if (isMine)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.forestCharcoal),
                    onPressed: () => _showEditPost(context, post),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.terracotta),
                  onPressed: () => _confirmDeletePost(context, post),
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PostHeader(post: post),
                  if (post.imageUrl != null) ...[
                    const SizedBox(height: 12),
                    ForumPostImage(
                      imageUrl: post.imageUrl!,
                      maxHeight: AppTheme.forumDetailImageMaxHeight,
                      borderRadius: 12,
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_isTranslating)
                    Row(
                      children: [
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.terracotta)),
                        const SizedBox(width: 8),
                        Text(AppTranslations.get('translating'), style: TextStyle(fontSize: 14, color: AppTheme.mutedSage, fontStyle: FontStyle.italic)),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_translatedText ?? post.text, style: const TextStyle(fontSize: 15, color: AppTheme.forestCharcoal)),
                        if (post.language != AppLocale.currentLanguageCode) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.translate, size: 12, color: AppTheme.mutedSage),
                              const SizedBox(width: 4),
                              Text(AppTranslations.format('originalLanguage', [post.language.toUpperCase()]), style: TextStyle(fontSize: 11, color: AppTheme.mutedSage)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 16),
                  // Destek butonu (büyük)
                  _DetailSupportButton(post: post, onUpdate: _loadPost),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(AppTranslations.format('commentsTitle', ['${post.commentCount}']), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.forestCharcoal, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  StreamBuilder<List<ForumComment>>(
                    stream: ForumService.watchComments(widget.postId),
                    builder: (context, snap) {
                      final comments = snap.data ?? [];
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final c = comments[i];
                          final isMyComment = c.authorId == AuthService.userId;
                          return _CommentTile(
                            comment: c,
                            postId: widget.postId,
                            isMine: isMyComment,
                            canModerate: _canModerateForum,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          _BuildCommentField(postId: widget.postId, controller: _commentController),
        ],
      ),
    );
  }

  void _showEditPost(BuildContext context, ForumPost post) {
    final textController = TextEditingController(text: post.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.warmCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppTranslations.get('editPost'), style: Theme.of(ctx).textTheme.titleMedium?.copyWith(color: AppTheme.forestCharcoal)),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: AppTranslations.get('text'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppTheme.sandBeige,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await ForumService.updatePost(widget.postId, text: textController.text.trim());
                  if (context.mounted) Navigator.pop(ctx);
                  _loadPost();
                },
                style: FilledButton.styleFrom(backgroundColor: AppTheme.terracotta),
                child: Text(AppTranslations.get('save')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeletePost(BuildContext context, ForumPost post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppTranslations.get('deletePost')),
        content: Text(AppTranslations.get('deletePostConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppTranslations.get('cancel'))),
          TextButton(
            onPressed: () async {
              await ForumService.deletePost(post.id);
              if (context.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(AppTranslations.get('delete'), style: const TextStyle(color: AppTheme.terracotta)),
          ),
        ],
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.post});

  final ForumPost post;

  @override
  Widget build(BuildContext context) {
    final typeColor = AppTheme.postTypeColor(post.postType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tür etiketi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppTheme.postTypeEmoji(post.postType), style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(AppTheme.postTypeLabel(post.postType), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: typeColor)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            CircleAvatar(radius: 22, backgroundColor: typeColor.withOpacity(0.2), child: Text(post.displayAuthorName[0].toUpperCase(), style: TextStyle(color: typeColor, fontWeight: FontWeight.w700, fontSize: 18))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.displayAuthorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppTheme.forestCharcoal)),
                  Text(DateFormat('d MMM yyyy · HH:mm', 'tr').format(post.createdAt), style: TextStyle(fontSize: 12, color: AppTheme.mutedSage)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.postId,
    required this.isMine,
    required this.canModerate,
  });

  final ForumComment comment;
  final String postId;
  final bool isMine;
  final bool canModerate;

  @override
  Widget build(BuildContext context) {
    final canDelete = isMine || canModerate;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.sandBeige, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(comment.authorName ?? AppTranslations.get('user'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.forestCharcoal)),
              const SizedBox(width: 8),
              Text(DateFormat('d MMM · HH:mm', 'tr').format(comment.createdAt), style: TextStyle(fontSize: 11, color: AppTheme.mutedSage)),
              if (canDelete) ...[
                const Spacer(),
                if (isMine)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.mutedSage),
                    onPressed: () => _showEditComment(context),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.terracotta),
                  onPressed: () => _confirmDeleteComment(context),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(comment.text, style: const TextStyle(fontSize: 14, color: AppTheme.forestCharcoal)),
        ],
      ),
    );
  }

  void _showEditComment(BuildContext context) {
    final controller = TextEditingController(text: comment.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.warmCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppTranslations.get('editComment'), style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.forestCharcoal)),
              const SizedBox(height: 12),
              TextField(controller: controller, maxLines: 3, decoration: InputDecoration(hintText: AppTranslations.get('comment'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: AppTheme.sandBeige)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await ForumService.updateComment(postId, comment.id, controller.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(backgroundColor: AppTheme.terracotta),
                child: Text(AppTranslations.get('save')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteComment(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppTranslations.get('deleteComment')),
        content: Text(AppTranslations.get('deleteCommentConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppTranslations.get('cancel'))),
          TextButton(
            onPressed: () async {
              await ForumService.deleteComment(postId, comment.id);
              if (context.mounted) Navigator.pop(ctx);
            },
            child: Text(AppTranslations.get('delete'), style: const TextStyle(color: AppTheme.terracotta)),
          ),
        ],
      ),
    );
  }
}

class _BuildCommentField extends StatelessWidget {
  const _BuildCommentField({required this.postId, required this.controller});

  final String postId;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      color: AppTheme.warmCream,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: AppTranslations.get('writeComment'),
                filled: true,
                fillColor: AppTheme.sandBeige,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _send(context),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () => _send(context),
            icon: const Icon(Icons.send_rounded, size: 20),
            style: IconButton.styleFrom(backgroundColor: AppTheme.terracotta, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _send(BuildContext context) {
    final t = controller.text.trim();
    if (t.isEmpty) return;
    ForumService.addComment(postId, t);
    controller.clear();
  }
}

class _DetailSupportButton extends StatefulWidget {
  const _DetailSupportButton({required this.post, required this.onUpdate});
  
  final ForumPost post;
  final VoidCallback onUpdate;

  @override
  State<_DetailSupportButton> createState() => _DetailSupportButtonState();
}

class _DetailSupportButtonState extends State<_DetailSupportButton> {
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
  void didUpdateWidget(covariant _DetailSupportButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _isSupported = widget.post.isSupportedBy(AuthService.userId);
    _count = widget.post.supportCount;
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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _isSupported ? AppTheme.terracotta.withOpacity(0.15) : AppTheme.warmCream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isSupported ? AppTheme.terracotta : AppTheme.softBorder,
            width: _isSupported ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🫂', style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSupported ? AppTranslations.get('supporting') : AppTranslations.get('iSupportYou'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _isSupported ? AppTheme.terracotta : AppTheme.forestCharcoal,
                  ),
                ),
                Text(
                  AppTranslations.format('supportCount', ['$_count']),
                  style: TextStyle(fontSize: 12, color: AppTheme.mutedSage),
                ),
              ],
            ),
            if (_loading) ...[
              const SizedBox(width: 12),
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.terracotta)),
            ],
          ],
        ),
      ),
    );
  }
}
