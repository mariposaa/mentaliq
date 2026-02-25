import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/app_theme.dart';
import '../../services/auth_service.dart';
import '../community/campfire_post_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.userId;
    if (uid == null) {
      return Scaffold(
        backgroundColor: AppTheme.sandBeige,
        appBar: AppBar(backgroundColor: AppTheme.sandBeige, title: const Text('Bildirimler')),
        body: const Center(child: Text('Giriş gerekli')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      appBar: AppBar(
        backgroundColor: AppTheme.sandBeige,
        elevation: 0,
        title: const Text('Bildirimler', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.forestCharcoal)),
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
                  Icon(Icons.notifications_none_rounded, size: 64, color: AppTheme.mutedSage.withOpacity(0.6)),
                  const SizedBox(height: 12),
                  Text('Henüz bildirim yok', style: TextStyle(fontSize: 15, color: AppTheme.mutedSage)),
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
              final read = d['read'] as bool? ?? false;
              final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
              String title = 'Yeni bildirim';
              if (type == 'comment') title = 'Gönderine yorum yapıldı';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: read ? AppTheme.warmCream : AppTheme.terracotta.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: AppTheme.terracotta.withOpacity(0.2), child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.terracotta)),
                  title: Text(title, style: TextStyle(fontWeight: read ? FontWeight.normal : FontWeight.w600, fontSize: 14)),
                  subtitle: createdAt != null ? Text(_formatDate(createdAt), style: TextStyle(fontSize: 12, color: AppTheme.mutedSage)) : null,
                  onTap: () async {
                    if (postId.isNotEmpty) {
                      await AuthService.firestore.collection('users').doc(uid).collection('notifications').doc(docs[i].id).update({'read': true});
                      if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => CampfirePostDetailScreen(postId: postId)));
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
      return 'Bugün ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day}.${d.month}.${d.year}';
  }
}
