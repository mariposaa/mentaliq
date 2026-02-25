import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
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
        throw FirebaseAuthException(code: 'invalid-input', message: 'Email ve şifre boş olamaz.');
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
      setState(() => _error = 'Beklenmeyen bir hata oluştu.');
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
      setState(() => _error = 'Google ile giriş yapılamadı.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Şifre sıfırlama için email gir.');
      return;
    }
    try {
      await AuthService.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifre sıfırlama bağlantısı gönderildi.')),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mapAuthError(e));
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email formatı geçersiz.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email veya şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu email zaten kayıtlı.';
      case 'weak-password':
        return 'Şifre en az 6 karakter olmalı.';
      case 'account-exists-with-different-credential':
        return 'Bu email farklı giriş yöntemi ile kayıtlı.';
      default:
        return e.message ?? 'Kimlik doğrulama hatası.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sandBeige,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Hesabını Güvenceye Al'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                AuthService.isAnonymous
                    ? 'Şu an misafir oturumundasın. Hesap oluşturursan verilerini kalıcı hale getirirsin.'
                    : 'Hesabın bağlı. Buradan farklı yöntemle tekrar giriş yapabilirsin.',
                style: const TextStyle(color: Colors.black87, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            if (_isRegisterMode) ...[
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'İsim (opsiyonel)'),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Şifre'),
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
                  : Text(_isRegisterMode ? 'Email ile Kayıt Ol' : 'Email ile Giriş Yap'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleGoogle,
              icon: const Icon(Icons.login_rounded),
              label: const Text('Google ile Devam Et'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _handleResetPassword,
                child: const Text('Şifremi unuttum'),
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
                    ? 'Zaten hesabın var mı? Giriş yap'
                    : 'Hesabın yok mu? Kayıt ol',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
