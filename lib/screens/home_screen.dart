import 'package:flutter/material.dart';

import '../models/exam_type.dart';
import '../services/auth_service.dart';
import '../services/exam_catalog_service.dart';
import 'ai_solver_screen.dart';
import 'exam_dashboard_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final _examCatalogService = ExamCatalogService();
  static final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final examTypes = _examCatalogService.getExamTypes();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DashboardHeader(
                    onLogout: () async {
                      await _authService.signOut();
                    },
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(
                    title: 'H\u0131zl\u0131 Eri\u015fim',
                    subtitle: 'Bug\u00fcnk\u00fc \u00e7al\u0131\u015fma ak\u0131\u015f\u0131na tek dokunu\u015fla gir.',
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 156,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        QuickActionCard(
                          icon: Icons.camera_alt_rounded,
                          title: 'Soru \u00c7\u00f6z',
                          subtitle: 'AI ile \u00e7\u00f6z\u00fcm analizi al',
                          gradient: const [Color(0xFF4054C8), Color(0xFF6D7CFF)],
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AiQuestionSolverScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 14),
                        QuickActionCard(
                          icon: Icons.bar_chart_rounded,
                          title: 'Performans',
                          subtitle: 'Netlerini ve geli\u015fimini g\u00f6r',
                          gradient: const [Color(0xFF0F766E), Color(0xFF34D399)],
                          onTap: () => _showComingSoon(context, 'Performans Analizi'),
                        ),
                        const SizedBox(width: 14),
                        QuickActionCard(
                          icon: Icons.calendar_month_rounded,
                          title: 'G\u00fcnl\u00fck Plan',
                          subtitle: 'Bug\u00fcn\u00fcn \u00e7al\u0131\u015fma d\u00fczeni haz\u0131r',
                          gradient: const [Color(0xFFF59E0B), Color(0xFFF97316)],
                          onTap: () => _showComingSoon(context, 'G\u00fcnl\u00fck \u00c7al\u0131\u015fma Plan\u0131'),
                        ),
                        const SizedBox(width: 14),
                        QuickActionCard(
                          icon: Icons.psychology_alt_rounded,
                          title: 'AI Tavsiyesi',
                          subtitle: 'Eksiklerine g\u00f6re \u00f6neri al',
                          gradient: const [Color(0xFF7C3AED), Color(0xFFA78BFA)],
                          onTap: () => _showComingSoon(context, 'AI Tavsiyeleri'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle(
                    title: 'S\u0131nav\u0131n\u0131 Se\u00e7',
                    subtitle: 'Haz\u0131rlanmak istedi\u011fin s\u0131nav i\u00e7in ki\u015fiselle\u015ftirilmi\u015f ak\u0131\u015f\u0131 a\u00e7.',
                  ),
                  const SizedBox(height: 14),
                  ...examTypes.map(
                    (examType) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ExamCard(
                        examType: examType,
                        onTap: () => _openDashboard(context, examType),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const ProgressCard(),
                  const SizedBox(height: 16),
                  const _AiSuggestionCard(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDashboard(BuildContext context, ExamType examType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamDashboardScreen(examType: examType),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName \u00e7ok yak\u0131nda eklenecek.'),
      ),
    );
  }
}

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.onLogout,
  });

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D3A8C), Color(0xFF5A6BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D3A8C).withOpacity(0.20),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'AI Study Companion',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              _HeaderIconButton(
                icon: Icons.notifications_none_rounded,
                onTap: () async {},
              ),
              const SizedBox(width: 10),
              _HeaderIconButton(
                icon: Icons.logout_rounded,
                onTap: onLogout,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Exam AI',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bug\u00fcn hedefin i\u00e7in \u00e7al\u0131\u015fmaya ba\u015fla \ud83c\udfaf',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withOpacity(0.92),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 22),
          const _HeaderIllustration(),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _HeaderIllustration extends StatelessWidget {
  const _HeaderIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 142,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            right: 8,
            bottom: 10,
            child: Container(
              height: 82,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Center(
              child: Container(
                width: 126,
                height: 126,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE0E7FF), Color(0xFFF8FAFF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 14,
                        right: 14,
                        top: 14,
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF5A6BFF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.psychology_alt_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 16,
                        right: 16,
                        bottom: 18,
                        child: Column(
                          children: [
                            _MiniProgressLine(widthFactor: 1),
                            SizedBox(height: 8),
                            _MiniProgressLine(widthFactor: 0.76),
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
            left: 20,
            top: 18,
            child: _OrbitTile(
              icon: Icons.edit_note_rounded,
              color: Color(0xFFFF8A65),
            ),
          ),
          const Positioned(
            right: 18,
            top: 28,
            child: _OrbitTile(
              icon: Icons.menu_book_rounded,
              color: Color(0xFF38BDF8),
            ),
          ),
          const Positioned(
            left: 44,
            bottom: 4,
            child: _OrbitTile(
              icon: Icons.emoji_events_rounded,
              color: Color(0xFFFBBF24),
            ),
          ),
          const Positioned(
            right: 42,
            bottom: 0,
            child: _OrbitTile(
              icon: Icons.auto_graph_rounded,
              color: Color(0xFF34D399),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitTile extends StatelessWidget {
  const _OrbitTile({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _MiniProgressLine extends StatelessWidget {
  const _MiniProgressLine({
    required this.widthFactor,
  });

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 7,
        decoration: BoxDecoration(
          color: const Color(0xFFB9C5FF),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          width: 164,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withOpacity(0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.88),
                      height: 1.45,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExamCard extends StatelessWidget {
  const ExamCard({
    super.key,
    required this.examType,
    required this.onTap,
  });

  final ExamType examType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accentColor = _accentFor(examType.title);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.school_rounded, color: accentColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      examType.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF111827),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      examType.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF64748B),
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentFor(String title) {
    switch (title) {
      case 'YKS':
        return const Color(0xFF4054C8);
      case 'LGS':
        return const Color(0xFF0F766E);
      case 'KPSS':
        return const Color(0xFFF59E0B);
      case 'ALES':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF4054C8);
    }
  }
}

class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    const progress = 0.62;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: '\u00c7al\u0131\u015fma \u0130lerlemen',
            subtitle: 'Bug\u00fcnk\u00fc performans\u0131n seni hedefe yakla\u015ft\u0131r\u0131yor.',
            compact: true,
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(
                child: _MetricBox(
                  label: '\u00c7\u00f6z\u00fclen soru',
                  value: '25',
                  color: Color(0xFF4054C8),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _MetricBox(
                  label: 'Tamamlanan plan',
                  value: '%62',
                  color: Color(0xFF34D399),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5A6BFF)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Bug\u00fcn 25 soru \u00e7\u00f6zd\u00fcn \ud83d\ude80',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _AiSuggestionCard extends StatelessWidget {
  const _AiSuggestionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Tavsiyesi',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Matematikte fonksiyonlar konusuna tekrar etmeni \u00f6neriyorum. Son \u00e7\u00f6z\u00fcmlerinde bu ba\u015fl\u0131kta hata oran\u0131 artt\u0131.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.88),
                  height: 1.55,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF111827),
                fontWeight: FontWeight.w800,
              ),
        ),
        SizedBox(height: compact ? 6 : 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF64748B),
                height: 1.45,
              ),
        ),
      ],
    );
  }
}
