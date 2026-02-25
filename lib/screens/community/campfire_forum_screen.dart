import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/forum_service.dart';
import 'campfire_age_gate.dart';
import 'campfire_tabs_screen.dart';

/// Kamp Ateşi - 18+ giriş kontrolü; içerik dili UserDNA'dan.
class CampfireForumScreen extends StatefulWidget {
  const CampfireForumScreen({super.key});

  @override
  State<CampfireForumScreen> createState() => _CampfireForumScreenState();
}

class _CampfireForumScreenState extends State<CampfireForumScreen> {
  bool _loading = true;
  bool _ageConfirmed = false;

  @override
  void initState() {
    super.initState();
    _checkAge();
  }

  Future<void> _checkAge() async {
    final ok = await ForumService.isCampfireAgeConfirmed();
    if (mounted) setState(() => _ageConfirmed = ok);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.sandBeige,
        body: const Center(child: CircularProgressIndicator(color: AppTheme.terracotta)),
      );
    }
    if (!_ageConfirmed) {
      return CampfireAgeGate(onConfirmed: () => setState(() => _ageConfirmed = true));
    }
    return const CampfireTabsScreen();
  }
}
