import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../l10n/app_translations.dart';
import '../services/ad_service.dart';
import '../services/token_service.dart';

/// Reusable Token Dialog - Shows friendly message and watch ad option
/// Can be called from anywhere in the app
class TokenDialog {
  /// Show token insufficient dialog with watch ad option
  /// Returns true if user watched ad and got tokens, false otherwise
  static Future<bool> show(BuildContext context) async {
    final currentBalance = await TokenService.getBalance();
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TokenDialogContent(currentBalance: currentBalance),
    );
    
    return result ?? false;
  }
}

class _TokenDialogContent extends StatefulWidget {
  final int currentBalance;
  
  const _TokenDialogContent({required this.currentBalance});

  @override
  State<_TokenDialogContent> createState() => _TokenDialogContentState();
}

class _TokenDialogContentState extends State<_TokenDialogContent> {
  bool _isWatchingAd = false;

  Future<void> _watchAd() async {
    setState(() => _isWatchingAd = true);
    
    // Show rewarded ad
    final success = await AdService.showRewardedAd();
    
    if (success) {
      await TokenService.addTokens(TokenService.adRewardTokens);
      
      if (mounted) {
        Navigator.of(context).pop(true);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:               Row(
              children: [
                const Text('🎉 '),
                Text(AppTranslations.get('tokensEarned')),
              ],
            ),
            backgroundColor: AppTheme.sageGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      setState(() => _isWatchingAd = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTranslations.get('adLoadFailed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.warmCream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji icon
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppTheme.sageGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('💫', style: TextStyle(fontSize: 36)),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Title
          Text(
            AppTranslations.get('tokensRunOut'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.forestCharcoal,
                ),
          ),
          
          const SizedBox(height: 12),
          
          // Friendly message
          Text(
            AppTranslations.get('tokensRunOutMsg'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.forestCharcoal.withOpacity(0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Current balance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.sandBeige,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              AppTranslations.format('currentTokens', ['${widget.currentBalance}']),
              style: TextStyle(
                color: AppTheme.mutedSage,
                fontSize: 13,
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Watch Ad Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isWatchingAd ? null : _watchAd,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.sageGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: AppTheme.sageGreen.withOpacity(0.5),
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
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_circle_outline_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(AppTranslations.get('watchAd'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Close button
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              AppTranslations.get('notNow'),
              style: TextStyle(color: AppTheme.mutedSage),
            ),
          ),
        ],
      ),
    );
  }
}
