import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_translations.dart';
import '../../services/addiction_service.dart';
import '../../services/auth_service.dart';
import '../community/campfire_post_detail_screen.dart';
import '../modules/addiction_module_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.userId;
    if (uid == null) {
      return Scaffold(
        backgroundColor: AppTheme.sandBeige,
        appBar: AppBar(backgroundColor: AppTheme.sandBeige, title: Text(AppTranslations.get('notifications'))),
        body: Center(child: Text(AppTranslations.get('loginRequired'))),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      appBar: AppBar(
        backgroundColor: AppTheme.sandBeige,
        elevation: 0,
        title: Text(AppTranslations.get('notifications'), style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.forestCharcoal)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: AuthService.firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.terracotta));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 64, color: AppTheme.mutedSage.withValues(alpha: 0.6)),
                  const SizedBox(height: 12),
                  Text(AppTranslations.get('noNotifications'), style: const TextStyle(fontSize: 15, color: AppTheme.mutedSage)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>? ?? {};
              final type = d['type'] as String? ?? '';
              final postId = d['postId'] as String? ?? '';
              final addictionId = d['addictionId'] as String? ?? '';
              final rawTitle = d['title'] as String?;
              final rawMessage = d['message'] as String?;
              final read = d['read'] as bool? ?? false;
              final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
              String title = AppTranslations.get('newNotification');
              if (type == 'comment') title = AppTranslations.get('commentOnPost');
              if (type == 'addiction_checkin') title = rawTitle ?? 'Proactive Check-in';
              if (type == 'addiction_mandatory_checkin') {
                title = rawTitle ?? 'High Risk Check-in Required';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: read ? AppTheme.warmCream : AppTheme.terracotta.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: AppTheme.terracotta.withValues(alpha: 0.2), child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.terracotta)),
                  title: Text(title, style: TextStyle(fontWeight: read ? FontWeight.normal : FontWeight.w600, fontSize: 14)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (rawMessage != null && rawMessage.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(rawMessage, style: const TextStyle(fontSize: 12, color: AppTheme.mutedSage)),
                        ),
                      if (createdAt != null)
                        Text(_formatDate(createdAt), style: const TextStyle(fontSize: 12, color: AppTheme.mutedSage)),
                    ],
                  ),
                  onTap: () async {
                    await AuthService.firestore.collection('users').doc(uid).collection('notifications').doc(docs[i].id).update({'read': true});
                    if (postId.isNotEmpty) {
                      if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => CampfirePostDetailScreen(postId: postId)));
                      return;
                    }
                    if ((type == 'addiction_checkin' || type == 'addiction_mandatory_checkin') &&
                        context.mounted) {
                      if (addictionId.isNotEmpty) {
                        await AddictionService.ensureTrackingForId(addictionId);
                      }
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddictionModuleScreen(initialAddictionId: addictionId.isEmpty ? null : addictionId),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.day == now.day && d.month == now.month && d.year == now.year) {
      return '${AppTranslations.get('today')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day}.${d.month}.${d.year}';
  }
}
