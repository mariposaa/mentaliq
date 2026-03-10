import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../l10n/app_translations.dart';
import '../../services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _launchURL(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppTranslations.get('error'))),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppTranslations.get('error'))),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.warmCream,
        title: Text(
          AppTranslations.get('deleteAccount'),
          style: const TextStyle(
            color: AppTheme.terracotta,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          AppTranslations.get('deleteAccountConfirm'),
          style: const TextStyle(color: AppTheme.forestCharcoal),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppTranslations.get('cancel'),
              style: const TextStyle(color: AppTheme.mutedSage),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              final success = await AuthService.deleteAccount();
              
              if (context.mounted) {
                if (success) {
                  // The user is deleted and signed out, auth state will change
                  // and they will be redirected by the auth listener in wrapper.
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppTranslations.get('error'))),
                  );
                }
              }
            },
            child: Text(
              AppTranslations.get('delete'),
              style: const TextStyle(
                color: AppTheme.terracotta,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      appBar: AppBar(
        backgroundColor: AppTheme.sandBeige,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppTheme.forestCharcoal),
        title: Text(
          AppTranslations.get('settings'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.forestCharcoal,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Legal Section
            Container(
              decoration: BoxDecoration(
                color: AppTheme.warmCream,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  _buildListTile(
                    context,
                    title: AppTranslations.get('privacyPolicy'),
                    icon: Icons.privacy_tip_outlined,
                    onTap: () => _launchURL(context, 'https://gezistory.com/gizlilik-politikasi'),
                  ),
                  const Divider(height: 1, color: AppTheme.softBorder),
                  _buildListTile(
                    context,
                    title: AppTranslations.get('termsOfService'),
                    icon: Icons.description_outlined,
                    onTap: () => _launchURL(context, 'https://gezistory.com/kullanim-kosullari'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Danger Zone Section
            Container(
              decoration: BoxDecoration(
                color: AppTheme.warmCream,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(color: AppTheme.terracotta.withOpacity(0.3)),
                boxShadow: AppTheme.cardShadow,
              ),
              child: _buildListTile(
                context,
                title: AppTranslations.get('deleteAccount'),
                icon: Icons.delete_forever_outlined,
                textColor: AppTheme.terracotta,
                iconColor: AppTheme.terracotta,
                onTap: () => _showDeleteConfirmation(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color textColor = AppTheme.forestCharcoal,
    Color iconColor = AppTheme.mutedSage,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.mutedSage),
      onTap: onTap,
    );
  }
}
