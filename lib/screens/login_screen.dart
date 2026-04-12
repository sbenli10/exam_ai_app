import 'dart:ui';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'register_screen.dart';

class PremiumLoginScreen extends StatefulWidget {
  const PremiumLoginScreen({super.key});

  @override
  State<PremiumLoginScreen> createState() => _PremiumLoginScreenState();
}

class _PremiumLoginScreenState extends State<PremiumLoginScreen> {
  final _authService = AuthService();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  final emailFocus = FocusNode();
  final passFocus = FocusNode();

  bool obscure = true;
  bool loading = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    emailFocus.dispose();
    passFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final safeTop = mq.padding.top;

    // Palette
    const lilac = Color(0xFFE9D5FF);
    const deepViolet = Color(0xFF6D28D9);
    const violet = Color(0xFF7C3AED);
    const indigo = Color(0xFF4F46E5);
    const bgTop = Color(0xFFF8FAFF);
    const bgBottom = Color(0xFFF6F3FF);

    final bgGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [bgTop, bgBottom],
    );

    final horizontal = size.width < 360 ? 16.0 : 22.0;
    final cardWidth = size.width < 420 ? size.width - horizontal * 2 : 388.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: bgGradient),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _TechLinesPainter(
                    color: const Color(0xFF111827).withOpacity(0.035),
                  ),
                ),
              ),
            ),

            // Top wave
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SizedBox(
                height: (size.height * 0.40).clamp(260.0, 390.0),
                child: CustomPaint(
                  painter: _PremiumWavePainter(
                    base: lilac,
                    glow1: violet,
                    glow2: indigo,
                  ),
                ),
              ),
            ),

            // Bottom soft wave shadow
            Positioned(
              left: 0,
              right: 0,
              bottom: -20,
              child: IgnorePointer(
                child: SizedBox(
                  height: 240,
                  child: CustomPaint(
                    painter: _BottomWavePainter(
                      color: deepViolet.withOpacity(0.07),
                    ),
                  ),
                ),
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 22),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: size.height - safeTop - 10),
                  child: Column(
                    children: [
                      const SizedBox(height: 14),

                      _WelcomeHeader(
                        title: "WELCOME",
                        subtitle: "Sign in to continue",
                        accent: deepViolet,
                      ),

                      const SizedBox(height: 18),

                      _GlassCard(
                        width: cardWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              "Giriş Yap",
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 14),

                            _NeumorphicField(
                              focusNode: emailFocus,
                              controller: emailCtrl,
                              hint: "Kullanıcı adı",
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.text,
                              glowColor: violet.withOpacity(0.28),
                            ),

                            const SizedBox(height: 12),

                            _NeumorphicField(
                              focusNode: passFocus,
                              controller: passCtrl,
                              hint: "Şifre",
                              icon: Icons.lock_outline_rounded,
                              obscureText: obscure,
                              glowColor: violet.withOpacity(0.28),
                              trailing: IconButton(
                                splashRadius: 18,
                                onPressed: () => setState(() => obscure = !obscure),
                                icon: Icon(
                                  obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  size: 18,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            Align(
                              alignment: Alignment.centerRight,
                              child: _LinkButton(
                                label: "Şifremi unuttum",
                                onTap: loading ? null : _handleResetPassword,
                                color: deepViolet,
                              ),
                            ),

                            const SizedBox(height: 10),

                            _BounceButton(
                              onTap: loading ? null : _handleLogin,
                              child: _PremiumCTA(
                                label: loading ? "Giriş yapılıyor..." : "Giriş Yap",
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                glowColor: violet.withOpacity(0.32),
                                loading: loading,
                              ),
                            ),

                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    thickness: 1,
                                    color: const Color(0xFF0F172A).withOpacity(0.10),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    "veya",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    thickness: 1,
                                    color: const Color(0xFF0F172A).withOpacity(0.10),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _SocialIconButton(
                                  onTap: loading
                                      ? null
                                      : () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => const RegisterScreen(),
                                            ),
                                          );
                                        },
                                  child: const _GoogleGLogo(size: 22),
                                ),
                                const SizedBox(width: 12),
                                _SocialIconButton(
                                  onTap: loading ? null : () {},
                                  child: const Icon(Icons.apple, size: 22, color: Color(0xFF111827)),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Hesabın yok mu? ",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: loading
                                      ? null
                                      : () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => const RegisterScreen(),
                                            ),
                                          );
                                        },
                                  child: Text(
                                    "Kayıt ol",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: deepViolet,
                                      decoration: TextDecoration.underline,
                                      decorationColor: deepViolet.withOpacity(0.45),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    final identifier = emailCtrl.text.trim();
    final password = passCtrl.text;

    if (identifier.isEmpty) {
      _showMessage('Kullanıcı adını yazmadan giriş yapamazsın.', isError: true);
      emailFocus.requestFocus();
      return;
    }

    if (password.length < 6) {
      _showMessage('Şifren en az 6 karakter olmalı.', isError: true);
      passFocus.requestFocus();
      return;
    }

    setState(() => loading = true);
    try {
      await _authService.signInWithIdentifier(identifier, password);
      if (!mounted) return;
      _showMessage('Giriş başarılı. Panelin hazırlanıyor.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyAuthError(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _handleResetPassword() async {
    final identifier = emailCtrl.text.trim();
    if (identifier.isEmpty) {
      _showMessage('Şifreni yenilemek için önce kullanıcı adını yaz.', isError: true);
      emailFocus.requestFocus();
      return;
    }

    setState(() => loading = true);
    try {
      await _authService.resetPasswordForIdentifier(identifier);
      if (!mounted) return;
      _showMessage('Şifre yenileme bağlantısı gönderildi. Gelen kutunu ve spam klasörünü kontrol et.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyAuthError(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String _friendlyAuthError(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('invalid login credentials') || raw.contains('invalid_credentials')) {
      return 'Kullanıcı adı ya da şifre yanlış görünüyor. Bilgilerini kontrol edip tekrar dene.';
    }
    if (raw.contains('email not confirmed') || raw.contains('email_not_confirmed')) {
      return 'E-posta doğrulaması tamamlanmamış. Önce e-postandaki doğrulama bağlantısını açman gerekiyor.';
    }
    if (raw.contains('kullanıcı adına ait hesap bulunamadı')) {
      return 'Bu kullanıcı adına ait bir hesap bulamadım. Yazımı kontrol edip tekrar dene.';
    }
    if (raw.contains('giriş için e-posta değil')) {
      return 'Bu ekranda e-posta ile değil, kayıt olurken belirlediğin kullanıcı adıyla giriş yapmalısın.';
    }
    if (raw.contains('too many requests')) {
      return 'Kısa sürede çok fazla deneme yapıldı. Birkaç dakika bekleyip tekrar dene.';
    }
    if (raw.contains('network') || raw.contains('socket') || raw.contains('host lookup')) {
      return 'İnternet bağlantısında bir sorun var gibi görünüyor. Bağlantını kontrol edip tekrar dene.';
    }
    return 'Giriş sırasında bir sorun oluştu. Lütfen tekrar dene.';
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

/// -------------------------------
/// Small premium link button (TR)
/// -------------------------------
class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.label,
    required this.onTap,
    required this.color,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color.withOpacity(0.35), width: 1.2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
              color: color,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// WELCOME header (minimal vector cats + premium typography)
/// ------------------------------------------------------------
class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _CatGlyph(),
            SizedBox(width: 10),
            _CatGlyph(flipped: true),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: t.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: t.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 74,
          height: 5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: [
                accent.withOpacity(0.15),
                accent.withOpacity(0.78),
                accent.withOpacity(0.15),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CatGlyph extends StatelessWidget {
  const _CatGlyph({this.flipped = false});
  final bool flipped;

  @override
  Widget build(BuildContext context) {
    final icon = CustomPaint(
      size: const Size(28, 22),
      painter: _CatGlyphPainter(color: const Color(0xFF111827).withOpacity(0.85)),
    );

    if (!flipped) return icon;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scale(-1.0, 1.0),
      child: icon,
    );
  }
}

class _CatGlyphPainter extends CustomPainter {
  _CatGlyphPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()..color = color.withOpacity(0.09);

    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(w * 0.18, h * 0.62);
    path.quadraticBezierTo(w * 0.16, h * 0.30, w * 0.28, h * 0.20);
    path.quadraticBezierTo(w * 0.33, h * 0.12, w * 0.38, h * 0.26);
    path.quadraticBezierTo(w * 0.50, h * 0.12, w * 0.62, h * 0.26);
    path.quadraticBezierTo(w * 0.67, h * 0.12, w * 0.72, h * 0.20);
    path.quadraticBezierTo(w * 0.84, h * 0.30, w * 0.82, h * 0.62);
    path.quadraticBezierTo(w * 0.80, h * 0.88, w * 0.50, h * 0.90);
    path.quadraticBezierTo(w * 0.20, h * 0.88, w * 0.18, h * 0.62);
    path.close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, p);

    final eye = Paint()..color = color.withOpacity(0.85);
    canvas.drawCircle(Offset(w * 0.40, h * 0.60), 1.4, eye);
    canvas.drawCircle(Offset(w * 0.60, h * 0.60), 1.4, eye);
  }

  @override
  bool shouldRepaint(covariant _CatGlyphPainter oldDelegate) => oldDelegate.color != color;
}

/// ------------------------------------------------------------
/// Glass Card (BackdropFilter) â€” more premium
/// ------------------------------------------------------------
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, required this.width});
  final Widget child;
  final double width;

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
                // double glass feel
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.72),
                    Colors.white.withOpacity(0.54),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.75), width: 1),
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

/// ------------------------------------------------------------
/// Neumorphic input with subtle glow on focus (tuned)
/// ------------------------------------------------------------
class _NeumorphicField extends StatefulWidget {
  const _NeumorphicField({
    required this.focusNode,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.trailing,
    required this.glowColor,
  });

  final FocusNode focusNode;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? trailing;
  final Color glowColor;

  @override
  State<_NeumorphicField> createState() => _NeumorphicFieldState();
}

class _NeumorphicFieldState extends State<_NeumorphicField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() => _focused = widget.focusNode.hasFocus);

  @override
  Widget build(BuildContext context) {
    final border = _focused ? widget.glowColor.withOpacity(0.42) : const Color(0xFFE2E8F0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
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
          if (_focused)
            BoxShadow(
              color: widget.glowColor,
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 18, color: const Color(0xFF475569)),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                focusNode: widget.focusNode,
                controller: widget.controller,
                keyboardType: widget.keyboardType,
                obscureText: widget.obscureText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// Premium CTA with sheen highlight
/// ------------------------------------------------------------
class _PremiumCTA extends StatelessWidget {
  const _PremiumCTA({
    required this.label,
    required this.gradient,
    required this.glowColor,
    required this.loading,
  });

  final String label;
  final Gradient gradient;
  final Color glowColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: glowColor,
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        // sheen
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.0),
                      Colors.white.withOpacity(0.18),
                      Colors.white.withOpacity(0.0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.25, 0.5, 0.75],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ------------------------------------------------------------
/// Bounce animation wrapper (press feedback)
/// ------------------------------------------------------------
class _BounceButton extends StatefulWidget {
  const _BounceButton({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_BounceButton> createState() => _BounceButtonState();
}

class _BounceButtonState extends State<_BounceButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 130));
    _scale = Tween<double>(begin: 1.0, end: 0.985).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _down() async {
    if (widget.onTap == null) return;
    await _c.forward();
  }

  Future<void> _up() async {
    if (widget.onTap == null) return;
    await _c.reverse();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _down(),
      onTapCancel: () => _c.reverse(),
      onTapUp: (_) => _up(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// ------------------------------------------------------------
/// Social icon buttons (compact, premium)
/// ------------------------------------------------------------
class _SocialIconButton extends StatelessWidget {
  const _SocialIconButton({
    required this.onTap,
    required this.child,
  });

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 56,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.86),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.07),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// Realistic Google "G" (vector-like via CustomPainter)
class _GoogleGLogo extends StatelessWidget {
  const _GoogleGLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 6,
      height: size + 6,
      child: CustomPaint(
        painter: _GoogleGPainter(),
      ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.18; // thickness
    final r = (s - stroke) / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: c, radius: r);

    final pBlue = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF4285F4);

    final pRed = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFEA4335);

    final pYellow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFBBC05);

    final pGreen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF34A853);

    // Google G arcs (approx angles)
    // angles in radians: startAngle, sweepAngle
    // red (top-left to top)
    canvas.drawArc(rect, _deg(-35), _deg(80), false, pRed);
    // yellow (top to bottom-left)
    canvas.drawArc(rect, _deg(45), _deg(90), false, pYellow);
    // green (bottom-left to bottom-right)
    canvas.drawArc(rect, _deg(135), _deg(90), false, pGreen);
    // blue (bottom-right to top-right)
    canvas.drawArc(rect, _deg(225), _deg(120), false, pBlue);

    // inner "G" bar (blue)
    final barP = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF4285F4);

    final barY = c.dy;
    canvas.drawLine(Offset(c.dx + r * 0.08, barY), Offset(c.dx + r * 0.85, barY), barP);
  }

  double _deg(double d) => d * 3.141592653589793 / 180.0;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ------------------------------------------------------------
/// Premium Wave Painters
/// ------------------------------------------------------------
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

    final bgPaint = Paint()
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
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.52,
        size.width * 0.34,
        size.height * 0.78,
        size.width * 0.52,
        size.height * 0.64,
      )
      ..cubicTo(
        size.width * 0.68,
        size.height * 0.52,
        size.width * 0.82,
        size.height * 0.80,
        size.width,
        size.height * 0.62,
      )
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, bgPaint);

    final highlight = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white.withOpacity(0.45), Colors.white.withOpacity(0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect)
      ..blendMode = BlendMode.screen;

    canvas.drawPath(path, highlight);

    _drawGlow(canvas, size, offset: Offset(size.width * 0.22, size.height * 0.12), color: glow1.withOpacity(0.22), r: 120);
    _drawGlow(canvas, size, offset: Offset(size.width * 0.76, size.height * 0.16), color: glow2.withOpacity(0.18), r: 140);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withOpacity(0.35);

    canvas.drawPath(path, stroke);
  }

  void _drawGlow(Canvas canvas, Size size, {required Offset offset, required Color color, required double r}) {
    final p = Paint()..color = color;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawCircle(offset, r, p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PremiumWavePainter oldDelegate) =>
      oldDelegate.base != base || oldDelegate.glow1 != glow1 || oldDelegate.glow2 != glow2;
}

class _BottomWavePainter extends CustomPainter {
  _BottomWavePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;

    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.35,
        size.width * 0.45,
        size.height * 0.75,
        size.width * 0.68,
        size.height * 0.58,
      )
      ..cubicTo(
        size.width * 0.82,
        size.height * 0.48,
        size.width * 0.92,
        size.height * 0.72,
        size.width,
        size.height * 0.62,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _BottomWavePainter oldDelegate) => oldDelegate.color != color;
}

class _TechLinesPainter extends CustomPainter {
  _TechLinesPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const step = 56.0;
    for (double x = 0; x < size.width; x += step) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + 18, size.height);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _TechLinesPainter oldDelegate) => oldDelegate.color != color;
}



