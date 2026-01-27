import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/ad_service.dart';
import '../services/token_service.dart';

/// Campfire Token Dialog - Shows cost and watch ad option
/// Can be called from check-in or session entry
class CampfireTokenDialog {
  /// Show token dialog for campfire join (50 tokens)
  /// Returns true if user has enough tokens or watched ad
  static Future<bool> showJoinDialog(BuildContext context) async {
    return await _showDialog(
      context: context,
      cost: TokenService.campfireJoinCost,
      title: 'Kampa Katıl',
      description: 'Yeni bir gruba katılmak için 50 elmas gerekiyor.',
      icon: '🔥',
    );
  }

  /// Show token dialog for campfire session (20 tokens)
  /// Returns true if user has enough tokens or watched ad
  static Future<bool> showSessionDialog(BuildContext context, int sessionNumber) async {
    return await _showDialog(
      context: context,
      cost: TokenService.campfireSessionCost,
      title: '$sessionNumber. Oturum',
      description: 'Bu oturuma katılmak için 20 elmas gerekiyor.',
      icon: '🪵',
    );
  }

  static Future<bool> _showDialog({
    required BuildContext context,
    required int cost,
    required String title,
    required String description,
    required String icon,
  }) async {
    final currentBalance = await TokenService.getBalance();
    final hasEnough = currentBalance >= cost;

    // If has enough, just return true (will deduct later)
    if (hasEnough) return true;

    // Show dialog
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CampfireTokenDialogContent(
        currentBalance: currentBalance,
        cost: cost,
        title: title,
        description: description,
        icon: icon,
      ),
    );

    return result ?? false;
  }
}

class _CampfireTokenDialogContent extends StatefulWidget {
  final int currentBalance;
  final int cost;
  final String title;
  final String description;
  final String icon;

  const _CampfireTokenDialogContent({
    required this.currentBalance,
    required this.cost,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  State<_CampfireTokenDialogContent> createState() => _CampfireTokenDialogContentState();
}

class _CampfireTokenDialogContentState extends State<_CampfireTokenDialogContent> {
  bool _isWatchingAd = false;
  int _currentBalance = 0;

  @override
  void initState() {
    super.initState();
    _currentBalance = widget.currentBalance;
  }

  int get _needed => widget.cost - _currentBalance;
  bool get _hasEnough => _currentBalance >= widget.cost;

  Future<void> _watchAd() async {
    setState(() => _isWatchingAd = true);

    final success = await AdService.showRewardedAd();

    if (success) {
      await TokenService.addTokens(30);
      final newBalance = await TokenService.getBalance();

      if (mounted) {
        setState(() {
          _currentBalance = newBalance;
          _isWatchingAd = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Text('🎉 '),
                Text('30 elmas kazandın!'),
              ],
            ),
            backgroundColor: AppTheme.sageGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // If now has enough, close dialog with success
        if (_currentBalance >= widget.cost) {
          Navigator.of(context).pop(true);
        }
      }
    } else {
      setState(() => _isWatchingAd = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reklam yüklenemedi, biraz sonra tekrar dene'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppTheme.terracotta.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(widget.icon, style: const TextStyle(fontSize: 36)),
            ),
          ),

          const SizedBox(height: 20),

          // Title
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            widget.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 20),

          // Balance info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gerekli:',
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),
                    Text(
                      '💎 ${widget.cost}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mevcut:',
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),
                    Text(
                      '💎 $_currentBalance',
                      style: TextStyle(
                        color: _hasEnough ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (!_hasEnough) ...[
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Eksik:',
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                      Text(
                        '💎 $_needed',
                        style: TextStyle(
                          color: AppTheme.terracotta,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Watch Ad Button (if not enough)
          if (!_hasEnough) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isWatchingAd ? null : _watchAd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.terracotta,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: AppTheme.terracotta.withOpacity(0.5),
                ),
                child: _isWatchingAd
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_outline_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Reklam İzle (+30 💎)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Continue button (if has enough after watching ads)
          if (_hasEnough)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Devam Et',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),

          // Close button
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Vazgeç',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }
}
