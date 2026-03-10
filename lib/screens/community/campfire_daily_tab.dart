import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../l10n/app_translations.dart';
import '../../models/forum_post.dart';
import '../../models/forum_daily_question.dart';
import '../../services/forum_service.dart';
import '../../widgets/responsive_card.dart';
import 'campfire_post_detail_screen.dart';

class CampfireDailyTab extends StatefulWidget {
  const CampfireDailyTab({super.key});

  @override
  State<CampfireDailyTab> createState() => _CampfireDailyTabState();
}

class _CampfireDailyTabState extends State<CampfireDailyTab> {
  ForumDailyQuestion? _question;
  final _answerController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final q = await ForumService.getTodayDailyQuestion();
    if (mounted) setState(() => _question = q);
  }

  Future<void> _submitAnswer() async {
    final text = _answerController.text.trim();
    if (text.isEmpty || _question == null) return;
    setState(() => _sending = true);
    try {
      await ForumService.createPost(
        postType: 'daily_answer',
        text: text,
        isAnonymous: false,
        dailyQuestionId: _question!.id,
      );
      if (mounted) {
        _answerController.clear();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppTranslations.get('answerShared'))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppTranslations.get('error')} $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompactPhone;
    if (_question == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.help_outline_rounded, size: 56, color: AppTheme.terracotta.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(AppTranslations.get('noQuestionYet'), style: TextStyle(fontSize: 15, color: AppTheme.mutedSage)),
            const SizedBox(height: 4),
            Text(AppTranslations.get('areaWillBeFilled'), style: TextStyle(fontSize: 13, color: AppTheme.mutedSage)),
          ],
        ),
      );
    }
    final q = _question!;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveCard(
            padding: 16,
            color: AppTheme.terracotta.withOpacity(0.12),
            radius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('d MMM yyyy', 'tr').format(q.date), style: TextStyle(fontSize: 12, color: AppTheme.mutedSage)),
                const SizedBox(height: 8),
                Text(
                  q.text,
                  style: TextStyle(
                    fontSize: isCompact ? 15 : 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.forestCharcoal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(AppTranslations.get('writeAnswer'), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.forestCharcoal)),
          const SizedBox(height: 8),
          TextField(
            controller: _answerController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: AppTranslations.get('shareThoughts'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppTheme.warmCream,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _sending ? null : _submitAnswer,
            style: FilledButton.styleFrom(backgroundColor: AppTheme.terracotta),
            child: _sending ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(AppTranslations.get('send')),
          ),
          const SizedBox(height: 24),
          Text(AppTranslations.get('otherAnswers'), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.forestCharcoal)),
          const SizedBox(height: 8),
          StreamBuilder<List<ForumPost>>(
            stream: ForumService.watchDailyAnswers(q.id),
            builder: (context, snap) {
              final list = snap.data ?? [];
              if (list.isEmpty) return const SizedBox.shrink();
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final p = list[i];
                  return _AnswerCard(
                    post: p,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CampfirePostDetailScreen(postId: p.id))),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.post, required this.onTap});

  final ForumPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompactPhone;
    return Card(
      margin: const EdgeInsets.only(bottom: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppTheme.warmCream,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 14, backgroundColor: AppTheme.terracotta.withOpacity(0.2), child: Text(post.displayAuthorName[0].toUpperCase(), style: const TextStyle(fontSize: 12, color: AppTheme.terracotta, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      post.displayAuthorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isCompact ? 12 : 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.forestCharcoal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(DateFormat('HH:mm', 'tr').format(post.createdAt), style: TextStyle(fontSize: 11, color: AppTheme.mutedSage)),
                ],
              ),
              const SizedBox(height: 6),
              Text(post.text, style: const TextStyle(fontSize: 14, color: AppTheme.forestCharcoal), maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
