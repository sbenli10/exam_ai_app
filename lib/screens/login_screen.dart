import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_screen_shell.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/primary_button.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenShell(
      title: 'Exam AI',
      subtitle:
          'Daha sakin, daha düzenli ve daha akıllı bir çalışma alanına giriş yap',
      child: AuthCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tekrar hoş geldin',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1F2937),
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bugünkü hedeflerine dönmek için hesabına giriş yap. Birkaç saniye içinde hazırsın.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B7280),
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 22),
              _WelcomePanel(),
              const SizedBox(height: 18),
              if (_statusMessage != null) ...[
                _StatusBanner(
                  message: _statusMessage!,
                  isError: _statusIsError,
                ),
                const SizedBox(height: 16),
              ],
              AuthTextField(
                controller: _emailController,
                label: 'E-posta adresin',
                hintText: 'ornek@mail.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _passwordController,
                label: 'Şifren',
                hintText: 'En az 6 karakter',
                icon: Icons.lock_outline_rounded,
                obscureText: true,
                validator: _validatePassword,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _handleForgotPassword,
                  child: const Text(
                    'Şifreni mi unuttun?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              PrimaryButton(
                label: 'Çalışmaya Başla',
                onPressed: _handleLogin,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Henüz hesabın yok mu?',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                  ),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                    child: const Text(
                      'Kayıt ol',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Giriş yaptıktan sonra kişiselleştirilmiş planın ve bugünkü hedeflerin açılır.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF94A3B8),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      _showStatus(
        'Devam etmeden önce e-posta ve şifre alanlarını kontrol et.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showStatus(
        _friendlyAuthError(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    final emailError = _validateEmail(email);
    if (emailError != null) {
      _showStatus(
        'Şifre yenileme bağlantısı gönderebilmem için önce geçerli bir e-posta yazman gerekiyor.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      await _authService.resetPassword(email);
      if (!mounted) {
        return;
      }
      _showStatus(
        'Şifre yenileme bağlantısını e-posta adresine gönderdim. Gelen kutunu ve spam klasörünü kontrol et.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showStatus(
        _friendlyResetError(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'E-posta alanı boş bırakılamaz.';
    }

    final email = value.trim();
    if (!email.contains('@') || !email.contains('.')) {
      return 'Geçerli görünen bir e-posta adresi yaz.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Şifre alanı boş bırakılamaz.';
    }
    if (value.length < 6) {
      return 'Şifre en az 6 karakter olmalı.';
    }
    return null;
  }

  void _showStatus(String message, {bool isError = false}) {
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  String _friendlyAuthError(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('invalid login credentials') ||
        raw.contains('invalid_credentials')) {
      return 'E-posta veya şifre eşleşmedi. Yazdıklarını kontrol edip tekrar dene.';
    }
    if (raw.contains('email not confirmed') ||
        raw.contains('email_not_confirmed')) {
      return 'Hesabın hazır görünüyor ama e-posta doğrulaması tamamlanmamış. E-postandaki bağlantıya tıklayıp tekrar giriş yap.';
    }
    if (raw.contains('too many requests')) {
      return 'Kısa sürede çok fazla deneme yapıldı. Birkaç dakika bekleyip yeniden deneyebilirsin.';
    }
    if (raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('failed host lookup')) {
      return 'İnternet bağlantısında bir sorun görünüyor. Bağlantını kontrol edip tekrar dene.';
    }

    return 'Giriş sırasında beklenmeyen bir sorun oluştu. Birkaç saniye sonra tekrar dene.';
  }

  String _friendlyResetError(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('too many requests')) {
      return 'Kısa sürede çok fazla şifre yenileme isteği gönderildi. Birkaç dakika sonra tekrar dene.';
    }
    if (raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('failed host lookup')) {
      return 'Bağlantı sorunu nedeniyle e-posta gönderilemedi. İnternetini kontrol edip tekrar dene.';
    }

    return 'Şifre yenileme bağlantısı gönderilirken bir sorun oluştu. Birazdan tekrar deneyebilirsin.';
  }
}

class _WelcomePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF6F7FF), Color(0xFFF3FAF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EBF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFF4F46E5),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bugünkü çalışma alanın hazır',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Giriş yaptığında günlük hedefin, soru akışın ve eksik konu önerilerin seni bekliyor.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF475569),
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniInfoChip(label: 'Günlük hedef'),
              _MiniInfoChip(label: 'Net analizi'),
              _MiniInfoChip(label: 'AI koç'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        isError ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4);
    final borderColor =
        isError ? const Color(0xFFFDA4AF) : const Color(0xFF86EFAC);
    final iconColor =
        isError ? const Color(0xFFBE123C) : const Color(0xFF15803D);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.info_outline_rounded : Icons.check_circle_rounded,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF334155),
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  const _MiniInfoChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
