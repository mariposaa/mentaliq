import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../l10n/app_translations.dart';
import '../../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isRegisterMode = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleEmailFlow() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text.trim();
      if (email.isEmpty || password.isEmpty) {
        throw FirebaseAuthException(code: 'invalid-input', message: AppTranslations.get('emailPasswordEmpty'));
      }

      if (_isRegisterMode) {
        await AuthService.registerWithEmail(
          email: email,
          password: password,
          displayName: _nameCtrl.text.trim(),
        );
      } else {
        await AuthService.signInWithEmail(email: email, password: password);
      }

      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mapAuthError(e));
    } catch (_) {
      setState(() => _error = AppTranslations.get('unexpectedError'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService.signInWithGoogle();
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mapAuthError(e));
    } catch (_) {
      setState(() => _error = AppTranslations.get('googleSignInFailed'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = AppTranslations.get('passwordResetEmail'));
      return;
    }
    try {
      await AuthService.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.get('passwordResetSent'))),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mapAuthError(e));
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return AppTranslations.get('invalidEmail');
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return AppTranslations.get('wrongCredentials');
      case 'email-already-in-use':
        return AppTranslations.get('emailInUse');
      case 'weak-password':
        return AppTranslations.get('weakPassword');
      case 'account-exists-with-different-credential':
        return AppTranslations.get('differentSignInMethod');
      default:
        return e.message ?? AppTranslations.get('authError');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompactPhone;
    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(AppTranslations.get('secureYourAccount')),
      ),
      body: SingleChildScrollView(
        padding: context.insetsAll(isCompact ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.all(isCompact ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                AuthService.isAnonymous
                    ? AppTranslations.get('guestSessionInfo')
                    : AppTranslations.get('accountLinkedInfo'),
                style: TextStyle(
                  color: Colors.black87,
                  height: 1.4,
                  fontSize: isCompact ? 13 : 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isRegisterMode) ...[
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: AppTranslations.get('nameOptional')),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: AppTranslations.get('email')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: InputDecoration(labelText: AppTranslations.get('password')),
            ),
            const SizedBox(height: 14),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleEmailFlow,
              child: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isRegisterMode ? AppTranslations.get('emailSignUp') : AppTranslations.get('emailSignIn')),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleGoogle,
              icon: const Icon(Icons.login_rounded),
              label: Text(AppTranslations.get('continueWithGoogle')),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _handleResetPassword,
                child: Text(AppTranslations.get('forgotPassword')),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                        _error = null;
                        _isRegisterMode = !_isRegisterMode;
                      }),
              child: Text(
                _isRegisterMode
                    ? AppTranslations.get('alreadyHaveAccount')
                    : AppTranslations.get('dontHaveAccount'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
