import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_theme.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_translations.dart';
import '../../services/silent_flirt_chat_service.dart';

class SilentFlirtChatScreen extends StatefulWidget {
  const SilentFlirtChatScreen({super.key, required this.chatId});

  final String chatId;

  @override
  State<SilentFlirtChatScreen> createState() => _SilentFlirtChatScreenState();
}

class _SilentFlirtChatScreenState extends State<SilentFlirtChatScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(bool blocked) async {
    final text = _controller.text.trim();
    if (text.isEmpty || blocked) return;
    await SilentFlirtChatService.sendMessage(chatId: widget.chatId, text: text);
    _controller.clear();
  }

  Future<void> _toggleBlock(bool blocked) async {
    await SilentFlirtChatService.setBlocked(
      chatId: widget.chatId,
      blocked: !blocked,
    );
  }

  Future<void> _report() async {
    final reasonController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppTranslations.get('silentFlirtReport')),
        content: TextField(
          controller: reasonController,
          maxLength: 160,
          decoration: InputDecoration(
            hintText: AppTranslations.get('silentFlirtReportHint'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppTranslations.get('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              await SilentFlirtChatService.reportChat(
                chatId: widget.chatId,
                reason: reason,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppTranslations.get('silentFlirtReportSaved'))),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.terracotta),
            child: Text(AppTranslations.get('send')),
          ),
        ],
      ),
    );
    reasonController.dispose();
  }

  Future<void> _closeChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppTranslations.get('silentFlirtCloseChat')),
        content: Text(AppTranslations.get('silentFlirtCloseChatConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppTranslations.get('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppTranslations.get('close'),
              style: const TextStyle(color: AppTheme.terracotta),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await SilentFlirtChatService.closeChat(widget.chatId);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SilentFlirtChatSummary?>(
      stream: SilentFlirtChatService.watchChat(widget.chatId),
      builder: (context, chatSnap) {
        final chat = chatSnap.data;
        if (chat == null) {
          return Scaffold(
            appBar: AppBar(title: Text(AppTranslations.get('silentFlirtLocalChats'))),
            body: Center(child: Text(AppTranslations.get('silentFlirtChatNotFound'))),
          );
        }
        final me = AuthService.userId;
        final partnerId = chat.participants.firstWhere(
          (p) => p != me,
          orElse: () => '',
        );
        final partnerNick = chat.participantNicks[partnerId] ?? 'User';
        final blocked = me != null && chat.blockedBy.contains(me);

        return Scaffold(
          backgroundColor: AppTheme.sandBeige,
          appBar: AppBar(
            backgroundColor: AppTheme.sandBeige,
            title: Text('@$partnerNick'),
            actions: [
              IconButton(
                tooltip: AppTranslations.get('silentFlirtBlock'),
                icon: Icon(blocked ? Icons.lock_open : Icons.block),
                onPressed: () => _toggleBlock(blocked),
              ),
              IconButton(
                tooltip: AppTranslations.get('silentFlirtReport'),
                icon: const Icon(Icons.flag_outlined),
                onPressed: _report,
              ),
              IconButton(
                tooltip: AppTranslations.get('silentFlirtCloseChat'),
                icon: const Icon(Icons.close_rounded),
                onPressed: _closeChat,
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<SilentFlirtChatMessage>>(
                  stream: SilentFlirtChatService.watchMessages(widget.chatId),
                  builder: (context, msgSnap) {
                    final messages = msgSnap.data ?? [];
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final m = messages[i];
                        final mine = me != null && m.senderId == me;
                        final bg = mine
                            ? AppTheme.terracotta.withOpacity(0.15)
                            : AppTheme.warmCream;
                        final align =
                            mine ? Alignment.centerRight : Alignment.centerLeft;
                        return Align(
                          alignment: align,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.softBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.text,
                                  style: const TextStyle(
                                    color: AppTheme.forestCharcoal,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('HH:mm')
                                      .format(m.createdAt ?? DateTime.now()),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.mutedSage,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  8 + MediaQuery.of(context).padding.bottom,
                ),
                color: AppTheme.warmCream,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !blocked,
                        decoration: InputDecoration(
                          hintText: blocked
                              ? AppTranslations.get('silentFlirtBlockedInfo')
                              : AppTranslations.get('messageInputHint'),
                          filled: true,
                          fillColor: AppTheme.sandBeige,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _send(blocked),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: blocked ? null : () => _send(blocked),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.terracotta,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
