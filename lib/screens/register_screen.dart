import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/auth_gate.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nicknameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedExamType = 'YKS';

  static const List<String> _examTypes = ['YKS', 'LGS', 'KPSS', 'ALES'];

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final horizontal = size.width < 360 ? 16.0 : 22.0;
    final cardWidth = size.width < 420 ? size.width - horizontal * 2 : 388.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFF), Color(0xFFF6F3FF)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 260,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFE9D5FF).withOpacity(0.95),
                      const Color(0xFFE9D5FF).withOpacity(0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 24),
                child: Column(
                  children: [
                    const _TopHeader(),
                    const SizedBox(height: 18),
                    _GlassCard(
                      width: cardWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Kayıt Ol',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Kullanıcı adını oluştur, sınavını seç ve sana özel çalışma alanını hazırlayalım.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF64748B),
                                  height: 1.5,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 14),
                          const _SecurityCard(),
                          const SizedBox(height: 14),
                          _SoftField(
                            focusNode: _nicknameFocus,
                            controller: _nicknameController,
                            hint: 'Kullanıcı adı',
                            icon: Icons.alternate_email_rounded,
                          ),
                          const SizedBox(height: 12),
                          _SoftField(
                            focusNode: _emailFocus,
                            controller: _emailController,
                            hint: 'E-posta adresi',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _SoftField(
                            focusNode: _passwordFocus,
                            controller: _passwordController,
                            hint: 'Şifre',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            trailing: IconButton(
                              splashRadius: 18,
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 18,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SoftField(
                            focusNode: _confirmPasswordFocus,
                            controller: _confirmPasswordController,
                            hint: 'Şifreyi tekrar yaz',
                            icon: Icons.verified_user_outlined,
                            obscureText: _obscureConfirmPassword,
                            trailing: IconButton(
                              splashRadius: 18,
                              onPressed: () {
                                setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                              },
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 18,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _ExamDropdown(
                            value: _selectedExamType,
                            items: _examTypes,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedExamType = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          _PrimaryAction(
                            label: _loading ? 'Hesap hazırlanıyor...' : 'Hesap Oluştur',
                            loading: _loading,
                            onTap: _loading ? null : _handleRegister,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: Divider(color: const Color(0xFF0F172A).withOpacity(0.10))),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'veya',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: const Color(0xFF0F172A).withOpacity(0.10))),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Zaten hesabın var mı? ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              GestureDetector(
                                onTap: _loading ? null : () => Navigator.of(context).pop(),
                                child: const Text(
                                  'Giriş Yap',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF6D28D9),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    final nickname = _nicknameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final nicknameError = _validateNickname(nickname);
    if (nicknameError != null) {
      _showMessage(nicknameError, isError: true);
      _nicknameFocus.requestFocus();
      return;
    }

    final emailError = _validateEmail(email);
    if (emailError != null) {
      _showMessage(emailError, isError: true);
      _emailFocus.requestFocus();
      return;
    }

    final passwordError = _validatePassword(password);
    if (passwordError != null) {
      _showMessage(passwordError, isError: true);
      _passwordFocus.requestFocus();
      return;
    }

    if (confirmPassword.isEmpty) {
      _showMessage('Şifreyi tekrar yazmadan kaydı tamamlayamazsın.', isError: true);
      _confirmPasswordFocus.requestFocus();
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Yazdığın iki şifre birbiriyle eşleşmiyor.', isError: true);
      _confirmPasswordFocus.requestFocus();
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await _authService.signUp(
        email,
        password,
        nickname: nickname,
        examType: _selectedExamType,
      );

      if (!mounted) return;

      final shouldVerifyEmail = response.session == null;
      _showMessage(
        shouldVerifyEmail
            ? 'Hesabın oluşturuldu. E-posta doğrulamasını tamamladıktan sonra giriş yapabilirsin.'
            : 'Hesabın hazır. Sana özel çalışma alanın açılıyor.',
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyRegisterError(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String? _validateNickname(String value) {
    if (value.isEmpty) return 'Kullanıcı adı zorunlu. Girişte bu adı kullanacaksın.';
    if (value.contains('@')) return 'Kullanıcı adında @ işareti kullanma. Bu alan e-posta değil.';
    if (value.contains(' ')) return 'Kullanıcı adında boşluk kullanma. Daha sade bir ad seç.';
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(value)) {
      return 'Kullanıcı adı yalnızca harf, rakam, alt çizgi ve nokta içerebilir.';
    }
    if (value.length < 3) return 'Kullanıcı adı en az 3 karakter olmalı.';
    if (value.length > 20) return 'Kullanıcı adı en fazla 20 karakter olabilir.';
    return null;
  }

  String? _validateEmail(String value) {
    if (value.isEmpty) return 'E-posta adresi olmadan hesabını oluşturamam.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return 'Geçerli bir e-posta adresi yazmalısın.';
    }
    return null;
  }

  String? _validatePassword(String value) {
    if (value.isEmpty) return 'Şifre alanı boş bırakılamaz.';
    if (value.length < 8) return 'Şifren en az 8 karakter olmalı.';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Şifrene en az 1 büyük harf eklemen güvenliği artırır.';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Şifrende en az 1 küçük harf bulunmalı.';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Şifrene en az 1 rakam eklemelisin.';
    return null;
  }

  String _friendlyRegisterError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('user already registered') || raw.contains('already registered')) {
      return 'Bu e-posta adresiyle daha önce hesap açılmış görünüyor. Giriş yapmayı deneyebilirsin.';
    }
    if (raw.contains('duplicate') && raw.contains('nickname')) {
      return 'Bu kullanıcı adı zaten alınmış olabilir. Farklı bir kullanıcı adı dene.';
    }
    if (raw.contains('invalid email')) {
      return 'E-posta adresi geçersiz görünüyor. Yazımı kontrol et.';
    }
    if (raw.contains('password')) {
      return 'Şifre güvenlik kurallarına uymuyor. Daha güçlü bir şifre oluşturmayı dene.';
    }
    if (raw.contains('network') || raw.contains('socket') || raw.contains('host lookup')) {
      return 'İnternet bağlantısında bir sorun var gibi görünüyor. Bağlantını kontrol edip tekrar dene.';
    }
    return 'Kayıt sırasında bir sorun oluştu. Bilgilerini kontrol edip tekrar dene.';
  }

  void _showMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: isError ? const Color(0xFFBE123C) : const Color(0xFF166534),
        content: Text(message),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFF6D28D9), size: 24),
            SizedBox(width: 8),
            Icon(Icons.auto_awesome_rounded, color: Color(0xFF4F46E5), size: 20),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'WELCOME',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
                color: const Color(0xFF0F172A),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Create your study account',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
              ),
        ),
      ],
    );
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.74),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_moon_outlined, color: Color(0xFF6D28D9), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Kullanıcı adın girişte kullanılacak. Şifren güvenli şekilde korunur ve sana özel sınav alanı açılır.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: width),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.72),
                    Colors.white.withOpacity(0.54),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.75)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F0F172A),
                    blurRadius: 48,
                    offset: Offset(0, 22),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftField extends StatelessWidget {
  const _SoftField({
    required this.focusNode,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.trailing,
  });

  final FocusNode focusNode;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.88),
            blurRadius: 14,
            offset: const Offset(-6, -6),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(8, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF475569)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              focusNode: focusNode,
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscureText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ExamDropdown extends StatelessWidget {
  const _ExamDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(18),
        decoration: const InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(Icons.school_outlined),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.28),
              blurRadius: 26,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumWavePainter extends CustomPainter {
  _PremiumWavePainter({
    required this.base,
    required this.glow1,
    required this.glow2,
  });

  final Color base;
  final Color glow1;
  final Color glow2;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          base.withOpacity(0.95),
          base.withOpacity(0.58),
          Colors.white.withOpacity(0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height * 0.65)
      ..cubicTo(size.width * 0.18, size.height * 0.52, size.width * 0.34, size.height * 0.78,
          size.width * 0.52, size.height * 0.64)
      ..cubicTo(size.width * 0.68, size.height * 0.52, size.width * 0.82, size.height * 0.80,
          size.width, size.height * 0.62)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.12),
      120,
      Paint()..color = glow1.withOpacity(0.18),
    );
    canvas.drawCircle(
      Offset(size.width * 0.76, size.height * 0.16),
      140,
      Paint()..color = glow2.withOpacity(0.14),
    );
  }

  @override
  bool shouldRepaint(covariant _PremiumWavePainter oldDelegate) {
    return oldDelegate.base != base || oldDelegate.glow1 != glow1 || oldDelegate.glow2 != glow2;
  }
}

class _BottomWavePainter extends CustomPainter {
  _BottomWavePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..cubicTo(size.width * 0.22, size.height * 0.35, size.width * 0.45, size.height * 0.75,
          size.width * 0.68, size.height * 0.58)
      ..cubicTo(size.width * 0.82, size.height * 0.48, size.width * 0.92, size.height * 0.72,
          size.width, size.height * 0.62)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BottomWavePainter oldDelegate) => oldDelegate.color != color;
}

class _TechLinesPainter extends CustomPainter {
  _TechLinesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 56) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + 18, size.height);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TechLinesPainter oldDelegate) => oldDelegate.color != color;
}
