import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/daily_task.dart';
import '../models/dashboard_config.dart';
import '../models/dashboard_summary.dart';
import '../models/exam_type.dart';
import '../models/mentor_insight.dart';
import '../services/dashboard_service.dart';
import '../services/exam_catalog_service.dart';
import 'full_tyt_exam_screen.dart';
import 'mentor_analysis_screen.dart';
import 'mock_exam_screen.dart';
import 'question_solver_screen.dart';
import 'topic_exam_picker_screen.dart';
import 'topics_screen.dart';

/// A config-driven dashboard shared by all exam types.
///
/// Subclasses (YksDashboardScreen, LgsDashboardScreen, …) only need to provide
/// the [DashboardConfig] – all UI and data logic lives here.
class BaseDashboardScreen extends StatefulWidget {
  const BaseDashboardScreen({
    super.key,
    required this.config,
  });

  final DashboardConfig config;

  @override
  State<BaseDashboardScreen> createState() => _BaseDashboardScreenState();
}

class _BaseDashboardScreenState extends State<BaseDashboardScreen> {
  final DashboardService _dashboardService = DashboardService();
  final ExamCatalogService _examCatalogService = ExamCatalogService();

  late Future<DashboardSummary?> _summaryFuture;
  String? _examId;

  ExamType get _examType => widget.config.examType;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
  }

  Future<DashboardSummary?> _loadSummary() async {
    final examId =
        await _examCatalogService.resolveExamIdByTitle(_examType.title);
    if (examId == null) return null;

    _examId = examId;

    // Seed today's daily tasks (no-op if already done).
    await _dashboardService.generateDailyTasks(examId: examId);

    // Fetch full summary via single RPC.
    return _dashboardService.getDashboardSummary(examId: examId);
  }

  Future<void> _refreshSummary() async {
    setState(() {
      _summaryFuture = _loadSummary();
    });
    await _summaryFuture;
  }

  Future<void> _onCompleteTask(DailyTask task) async {
    final success =
        await _dashboardService.completeDailyTask(taskId: task.id);
    if (success) {
      _refreshSummary();
    }
  }

  // ──────────────── navigation helpers ────────────────

  void _navigateForAction(DashboardActionTile tile) {
    switch (tile.routeId) {
      case 'quick_solve':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuestionSolverScreen(examType: _examType),
          ),
        );
        break;
      case 'topic_test':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TopicExamPickerScreen(examType: _examType),
          ),
        );
        break;
      case 'mini_mock':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MockExamScreen(
              examType: _examType,
              questionCount: 12,
            ),
          ),
        );
        break;
      case 'full_tyt':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullTytExamScreen(examType: _examType),
          ),
        );
        break;
      case 'ayt_placeholder':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AYT bölümü yakında eklenecek.')),
        );
        break;
      default:
        break;
    }
  }

  void _onBottomTap(int index, DashboardSummary summary) {
    switch (index) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TopicsScreen(examType: _examType),
          ),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullTytExamScreen(examType: _examType),
          ),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MentorAnalysisScreen(
              examType: _examType,
              nickname: summary.nickname.isNotEmpty
                  ? summary.nickname
                  : 'Öğrenci',
              insight: MentorInsight(
                recommendation: summary.mentorRecommendation,
                weakTopics: summary.weakTopics,
                createdAt: DateTime.now(),
              ),
              topicStats: const [],
              topicNamesById: const {},
              weeklySolvedCounts: summary.weeklySolvedCounts,
              todayPoints: summary.todayPoints,
              streak: summary.streak,
            ),
          ),
        );
        break;
    }
  }

  // ──────────────── build ────────────────

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final gradient = widget.config.themeGradient;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: FutureBuilder<DashboardSummary?>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final summary = snapshot.data;
          if (summary == null) {
            return Center(
              child: FilledButton(
                onPressed: _refreshSummary,
                child: const Text('Dashboard yüklenemedi'),
              ),
            );
          }

          final nickname = summary.nickname.isNotEmpty
              ? summary.nickname
              : 'Öğrenci';
          final progress = summary.dailyProgress;

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF6FAFF),
                  Color(0xFFF8FAFC),
                  Color(0xFFF2F6FB),
                ],
              ),
            ),
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: _refreshSummary,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.88),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x120F172A),
                              blurRadius: 42,
                              offset: Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 16, 16, 18),
                                children: [
                                  _BrandCard(
                                    examTitle: _examType.title,
                                    gradient: gradient,
                                  ),
                                  const SizedBox(height: 12),
                                  _WelcomeCard(
                                    nickname: nickname,
                                    examTitle: _examType.title,
                                    streak: summary.streak,
                                  ),
                                  const SizedBox(height: 12),
                                  _GoalPanel(
                                    textTheme: textTheme,
                                    solvedToday: summary.solvedToday,
                                    dailyGoal: summary.dailyGoal,
                                    progress: progress,
                                    miniMockDone: summary.miniMockDone,
                                  ),
                                  const SizedBox(height: 12),

                                  // ── AI Mentor ──
                                  if (summary
                                      .mentorRecommendation.isNotEmpty)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _AiMentorPanel(
                                        title: summary.weakTopics.isNotEmpty
                                            ? 'Bugün ${summary.weakTopics.first} çalışmalısın'
                                            : 'Bugün eksik konularına kısa bir tekrar yap',
                                        message: summary
                                            .mentorRecommendation,
                                        gradient: gradient,
                                        onTap: () => _navigateForAction(
                                          const DashboardActionTile(
                                            icon:
                                                CupertinoIcons.bolt_fill,
                                            title: '',
                                            subtitle: '',
                                            tint: Colors.transparent,
                                            routeId: 'quick_solve',
                                          ),
                                        ),
                                      ),
                                    ),

                                  // ── Bugünün Görevleri ──
                                  if (summary.dailyTasks.isNotEmpty)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _DailyTasksPanel(
                                        tasks: summary.dailyTasks,
                                        onComplete: _onCompleteTask,
                                      ),
                                    ),

                                  // ── Action tiles from config ──
                                  SizedBox(
                                    height: 132,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: _buildActionTiles(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // ── Weekly progress ──
                                  _PanelCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Haftalık ilerleme',
                                                style: textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                  fontWeight:
                                                      FontWeight.w900,
                                                  color: const Color(
                                                      0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '${(summary.accuracy * 100).round()}%',
                                                  style: textTheme
                                                      .titleLarge
                                                      ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w900,
                                                    color: const Color(
                                                        0xFF0F172A),
                                                  ),
                                                ),
                                                Text(
                                                  'doğruluk',
                                                  style: textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                    color: const Color(
                                                        0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        _WeeklyBars(
                                            values: summary
                                                .weeklySolvedCounts),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // ── Recent attempts ──
                                  _PanelCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Son denemeler',
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color:
                                                const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ..._recentAttemptItems(summary)
                                            .map(
                                          (attempt) => Padding(
                                            padding:
                                                const EdgeInsets.only(
                                                    bottom: 12),
                                            child: _RecentAttemptRow(
                                                attempt: attempt),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _BottomTabBar(
                              labels: widget.config.bottomLabels,
                              onTap: (index) =>
                                  _onBottomTap(index, summary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildActionTiles() {
    // For YKS, only show TYT actions for now (AYT placeholder is separate).
    final actions = widget.config.sections
        .where((s) =>
            s.yksTrack == null || s.yksTrack == YksTrack.tyt)
        .expand((s) => s.actions)
        .toList();

    final tiles = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      if (i > 0) tiles.add(const SizedBox(width: 12));
      final action = actions[i];
      tiles.add(
        _ActionTile(
          icon: action.icon,
          title: action.title,
          subtitle: action.subtitle,
          tint: action.tint,
          onTap: () => _navigateForAction(action),
        ),
      );
    }
    return tiles;
  }

  List<_AttemptViewModel> _recentAttemptItems(DashboardSummary summary) {
    final attempts = summary.recentAttempts.take(2).map((item) {
      return _AttemptViewModel(
        title: (item['title'] as String?)?.trim().isNotEmpty == true
            ? item['title'] as String
            : 'Son Deneme',
        correct: (item['correct_count'] as num?)?.toInt() ?? 0,
        total: (item['question_count'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    if (attempts.isNotEmpty) return attempts;

    return const [
      _AttemptViewModel(title: 'Henüz deneme yok', correct: 0, total: 0),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  Private widgets (shared by all exam dashboard variants)
// ═══════════════════════════════════════════════════════════════════════

class _BrandCard extends StatelessWidget {
  const _BrandCard({required this.examTitle, required this.gradient});

  final String examTitle;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'ExamAPP-AI',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E3A5F),
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(width: 4),
          const Icon(
            CupertinoIcons.sparkles,
            size: 18,
            color: Color(0xFF3B82F6),
          ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.nickname,
    required this.examTitle,
    required this.streak,
  });

  final String nickname;
  final String examTitle;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      CupertinoIcons.flame_fill,
                      size: 44,
                      color: Color(0xFFF97316),
                    ),
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${streak > 0 ? streak : 0}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  streak > 0 ? '$streak Günlük Seri' : 'Seriyi başlat',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Merhaba, $nickname',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$examTitle çalışma alanın hazır',
                        style: textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x120F172A),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    CupertinoIcons.bell_fill,
                    color: Color(0xFF0F172A),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFF60A5FA),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    nickname.isNotEmpty ? nickname[0].toUpperCase() : 'Ö',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalPanel extends StatelessWidget {
  const _GoalPanel({
    required this.textTheme,
    required this.solvedToday,
    required this.dailyGoal,
    required this.progress,
    required this.miniMockDone,
  });

  final TextTheme textTheme;
  final int solvedToday;
  final int dailyGoal;
  final double progress;
  final bool miniMockDone;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bugünkü hedef',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF334155),
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(
                  text: '$solvedToday',
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(text: ' / $dailyGoal soru tamamlandı'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _GoalProgressBar(value: progress),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                miniMockDone
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                size: 18,
                color: miniMockDone
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  miniMockDone
                      ? 'Mini denemeyi bugün tamamladın'
                      : 'Mini deneme seni bekliyor',
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bugünün Görevleri ──

class _DailyTasksPanel extends StatelessWidget {
  const _DailyTasksPanel({
    required this.tasks,
    required this.onComplete,
  });

  final List<DailyTask> tasks;
  final Future<void> Function(DailyTask) onComplete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.checkmark_seal_fill,
                size: 20,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Text(
                'Bugünün Görevleri',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DailyTaskRow(task: task, onComplete: onComplete),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyTaskRow extends StatelessWidget {
  const _DailyTaskRow({
    required this.task,
    required this.onComplete,
  });

  final DailyTask task;
  final Future<void> Function(DailyTask) onComplete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final done = task.isCompleted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFFECFDF5)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            done
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.circle,
            size: 22,
            color: done
                ? const Color(0xFF16A34A)
                : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                    decoration:
                        done ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (task.description.isNotEmpty)
                  Text(
                    task.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+${task.pointsReward}',
              style: textTheme.labelSmall?.copyWith(
                color: const Color(0xFF2563EB),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (!done) ...[
            const SizedBox(width: 6),
            SizedBox(
              height: 32,
              child: FilledButton(
                onPressed: () => onComplete(task),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  backgroundColor: const Color(0xFF16A34A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Tamamla',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared UI widgets ──

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GoalProgressBar extends StatelessWidget {
  const _GoalProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: constraints.maxWidth * value,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4ADE80), Color(0xFF22C55E)],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AiMentorPanel extends StatelessWidget {
  const _AiMentorPanel({
    required this.title,
    required this.message,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String message;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.1),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(1.2),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          color: Colors.white.withOpacity(0.12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(CupertinoIcons.sparkles,
                      size: 14, color: Colors.white),
                ),
                const SizedBox(width: 6),
                Text(
                  'AI Mentor önerisi',
                  style: textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.94),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4ADE80),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Hemen Başla'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D0F172A),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final max =
        values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b).clamp(1, 999);
    const labels = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];

    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final value = index < values.length ? values[index] : 0;
          final ratio = max == 0 ? 0.0 : value / max;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == 6 ? 0 : 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Container(
                            height: 84,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          Container(
                            height:
                                value == 0 ? 12 : 84 * ratio.clamp(0.12, 1.0),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFF86B8FF),
                                  Color(0xFF3B82F6),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value.toString(),
                    style:
                        Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                            ),
                  ),
                  Text(
                    labels[index],
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                            ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _RecentAttemptRow extends StatelessWidget {
  const _RecentAttemptRow({required this.attempt});

  final _AttemptViewModel attempt;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trailing =
        attempt.total > 0 ? '${attempt.correct}/${attempt.total}' : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              CupertinoIcons.book_fill,
              size: 16,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attempt.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  attempt.total > 0 ? 'Doğru cevap' : 'Henüz kayıt yok',
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Text(
            trailing,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomTabBar extends StatelessWidget {
  const _BottomTabBar({
    required this.labels,
    required this.onTap,
  });

  final List<String> labels;
  final ValueChanged<int> onTap;

  static const _icons = [
    CupertinoIcons.house_fill,
    CupertinoIcons.book_fill,
    CupertinoIcons.doc_text_fill,
    CupertinoIcons.chart_bar_alt_fill,
    CupertinoIcons.person_crop_circle,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(labels.length.clamp(0, _icons.length), (i) {
          return _BottomItem(
            icon: _icons[i],
            label: labels[i],
            active: i == 0,
            onTap: () => onTap(i),
          );
        }),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF2563EB) : const Color(0xFF475569);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _AttemptViewModel {
  const _AttemptViewModel({
    required this.title,
    required this.correct,
    required this.total,
  });

  final String title;
  final int correct;
  final int total;
}
