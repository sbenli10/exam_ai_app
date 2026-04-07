import 'package:flutter/material.dart';

class AuthScreenShell extends StatefulWidget {
  const AuthScreenShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  State<AuthScreenShell> createState() => _AuthScreenShellState();
}

class _AuthScreenShellState extends State<AuthScreenShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _heroFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.62, curve: Curves.easeOutCubic),
      ),
    );
    _cardFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.24, 1.0, curve: Curves.easeOutCubic),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.20, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isIOS = platform == TargetPlatform.iOS;
    final topPadding = isIOS ? 20.0 : 14.0;
    final horizontalPadding = isIOS ? 22.0 : 18.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Stack(
        children: [
          const _HeroBackground(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                topPadding,
                horizontalPadding,
                28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 80,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeTransition(
                      opacity: _heroFade,
                      child: SlideTransition(
                        position: _heroSlide,
                        child: _HeroSection(
                          title: widget.title,
                          subtitle: widget.subtitle,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FadeTransition(
                      opacity: _cardFade,
                      child: SlideTransition(
                        position: _cardSlide,
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBackground extends StatelessWidget {
  const _HeroBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: const Color(0xFFF5F6FA)),
        ),
        Positioned(
          top: -110,
          left: -40,
          right: -40,
          child: Container(
            height: 432,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D3A8C), Color(0xFF5A6BFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(56),
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -50,
          child: Container(
            width: 220,
            height: 220,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x66B9C5FF), Color(0x002D3A8C)],
              ),
            ),
          ),
        ),
        Positioned(
          top: 88,
          left: -70,
          child: Transform.rotate(
            angle: -0.35,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(52),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final displaySize = width < 370 ? 34.0 : 40.0;
    final subtitleSize = width < 370 ? 16.0 : 18.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: displaySize,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 270,
          child: Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: subtitleSize,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _InfoChip(icon: Icons.auto_awesome_rounded, label: 'AI planlar'),
            _InfoChip(icon: Icons.analytics_rounded, label: 'Net analizi'),
            _InfoChip(icon: Icons.school_rounded, label: 'YKS LGS KPSS ALES'),
          ],
        ),
        const SizedBox(height: 18),
        const _PremiumIllustration(),
      ],
    );
  }
}

class _PremiumIllustration extends StatelessWidget {
  const _PremiumIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 208,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 10,
            right: 10,
            top: 30,
            child: Container(
              height: 108,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
            ),
          ),
          Positioned(
            left: 28,
            right: 28,
            top: 12,
            child: Container(
              height: 132,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(38),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 8,
            child: Center(
              child: Container(
                width: 150,
                height: 172,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(38),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF8FAFF), Color(0xFFE2E8FF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 16,
                        right: 16,
                        top: 16,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4054C8), Color(0xFF6E7CFF)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.psychology_alt_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        top: 76,
                        child: Column(
                          children: const [
                            _StatLine(widthFactor: 1),
                            SizedBox(height: 9),
                            _StatLine(widthFactor: 0.82),
                            SizedBox(height: 9),
                            _StatLine(widthFactor: 0.58),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            _MetricDot(color: Color(0xFF34D399)),
                            _MetricDot(color: Color(0xFFFFC857)),
                            _MetricDot(color: Color(0xFF60A5FA)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 18,
            top: 54,
            child: _OrbitBadge(
              icon: Icons.edit_note_rounded,
              color: Color(0xFFFF8A65),
            ),
          ),
          const Positioned(
            right: 22,
            top: 42,
            child: _OrbitBadge(
              icon: Icons.menu_book_rounded,
              color: Color(0xFF38BDF8),
            ),
          ),
          const Positioned(
            left: 42,
            bottom: 34,
            child: _OrbitBadge(
              icon: Icons.bolt_rounded,
              color: Color(0xFFFBBF24),
            ),
          ),
          const Positioned(
            right: 46,
            bottom: 28,
            child: _OrbitBadge(
              icon: Icons.workspace_premium_rounded,
              color: Color(0xFF34D399),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: const Text(
                  'Ak\u0131ll\u0131 \u00e7al\u0131\u015fma plan\u0131, soru analizi ve AI destek',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitBadge extends StatelessWidget {
  const _OrbitBadge({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({
    required this.widthFactor,
  });

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: const Color(0xFFC7D2FE),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _MetricDot extends StatelessWidget {
  const _MetricDot({
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
