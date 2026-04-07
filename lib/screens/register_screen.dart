import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_screen_shell.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_gate.dart';
import '../widgets/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String _selectedExamType = 'YKS';

  static const _examTypes = ['YKS', 'LGS', 'KPSS', 'ALES'];

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenShell(
      title: 'Exam AI',
      subtitle: 'Hedefine ula\u015fmak i\u00e7in \u00e7al\u0131\u015fmaya ba\u015fla \ud83c\udfaf',
      child: AuthCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Hesap olu\u015ftur',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1F2937),
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Hedef s\u0131nav\u0131n\u0131 se\u00e7 ve \u00e7al\u0131\u015fmaya ba\u015fla.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B7280),
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F7FB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_graph_rounded,
                      color: Color(0xFF5A6BFF),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sana \u00f6zel \u00e7al\u0131\u015fma plan\u0131 ve analizler olu\u015ftural\u0131m.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AuthTextField(
                controller: _nicknameController,
                label: 'Kullanıcı adı',
                hintText: 'ornekogrenci',
                icon: Icons.alternate_email_rounded,
                validator: _validateNickname,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _emailController,
                label: 'Email adresi',
                hintText: 'ornek@mail.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _passwordController,
                label: '\u015eifre',
                hintText: 'En az 6 karakter',
                icon: Icons.lock_outline_rounded,
                obscureText: true,
                validator: _validatePassword,
              ),
              const SizedBox(height: 14),
              _SectionLabel(
                icon: Icons.school_rounded,
                title: 'S\u0131nav se\u00e7imi',
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedExamType,
                decoration: _dropdownDecoration(),
                items: _examTypes
                    .map(
                      (examType) => DropdownMenuItem<String>(
                        value: examType,
                        child: Text(examType),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedExamType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Hesap olu\u015ftur',
                onPressed: _handleRegister,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Zaten hesab\u0131n var m\u0131?',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text(
                      'Giri\u015f yap',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Kay\u0131t olduktan sonra AI destekli \u00e7al\u0131\u015fma deneyimin ba\u015flar.',
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

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      prefixIcon: const Icon(Icons.layers_outlined),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      hintText: 'S\u0131nav\u0131n\u0131 se\u00e7',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFF5A6BFF),
          width: 1.4,
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final nickname = _nicknameController.text.trim();
      final response = await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        nickname: nickname,
        examType: _selectedExamType,
      );

      if (!mounted) {
        return;
      }

      final shouldVerifyEmail = response.session == null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldVerifyEmail
                ? 'Hesap oluşturuldu. E-posta doğrulamasını tamamlayıp devam edebilirsin.'
                : 'Hesap hazır. Sana özel plan ekranı açılıyor.',
          ),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email zorunludur.';
    }
    if (!value.contains('@')) {
      return 'Ge\u00e7erli bir email girin.';
    }
    return null;
  }

  String? _validateNickname(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Kullanıcı adı zorunludur.';
    }
    if (value.trim().length < 3) {
      return 'Kullanıcı adı en az 3 karakter olmalı.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.length < 6) {
      return '\u015eifre en az 6 karakter olmal\u0131.';
    }
    return null;
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF5A6BFF)),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: const Color(0xFF374151),
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
