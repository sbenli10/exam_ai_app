import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/exam_type.dart';
import '../models/leaderboard_entry.dart';
import '../models/mentor_insight.dart';
import '../models/profile.dart';
import '../models/study_topic.dart';
import '../models/topic_attempt_stat.dart';
import '../services/auth_service.dart';
import '../services/exam_catalog_service.dart';
import '../services/leaderboard_service.dart';
import '../services/mentor_service.dart';
import '../services/profile_service.dart';
import '../services/question_service.dart';
import 'ai_solver_screen.dart';
import 'full_tyt_exam_screen.dart';
import 'mentor_analysis_screen.dart';
import 'mock_exam_screen.dart';
import 'profile_screen.dart';
import 'question_solver_screen.dart';
import 'topics_screen.dart';

class ExamDashboardScreen extends StatefulWidget {
  const ExamDashboardScreen({
    super.key,
    required this.examType,
  });

  final ExamType examType;

  @override
  State<ExamDashboardScreen> createState() => _ExamDashboardScreenState();
}

class _ExamDashboardScreenState extends State<ExamDashboardScreen> {
  final AuthService _authService = AuthService();
  final ExamCatalogService _examCatalogService = ExamCatalogService();
  final QuestionService _questionService = QuestionService();
  final LeaderboardService _leaderboardService = LeaderboardService();
  final ProfileService _profileService = ProfileService();
  final MentorService _mentorService = MentorService();

  late Future<_DashboardData?> _dashboardFuture;

  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  Future<_DashboardData?> _loadDashboard() async {
    final examId = await _examCatalogService.resolveExamIdByTitle(widget.examType.title);
    if (examId == null) return null;

    final profile = await _safeLoad<Profile?>(() => _profileService.getProfile(), null);

    final myEntry = await _safeLoad<LeaderboardEntry?>(
          () => _leaderboardService.fetchMyLeaderboardEntry(
        examId: examId,
        periodType: 'weekly',
      ),
      null,
    );

    final latestMock = await _safeLoad<Map<String, dynamic>?>(
          () => _questionService.fetchLatestMockAttempt(examId: examId),
      null,
    );

    final recentAttempts = await _safeLoad<List<Map<String, dynamic>>>(
          () => _questionService.fetchRecentMockAttempts(examId: examId),
      <Map<String, dynamic>>[],
    );

    final solvedToday = await _safeLoad<int>(
          () => _questionService.fetchTodaySolvedQuestionCount(examId: examId),
      0,
    );

    final streak = await _safeLoad<int>(
          () => _questionService.fetchStudyStreak(examId: examId),
      0,
    );

    final miniMockDone = await _safeLoad<bool>(
          () => _questionService.fetchTodayMiniMockCompleted(examId: examId),
      false,
    );

    final todayPoints = await _safeLoad<int>(
          () => _questionService.fetchTodayPoints(examId: examId),
      0,
    );

    final topicStats = await _safeLoad<List<TopicAttemptStat>>(
          () => _questionService.fetchTopicAttemptStats(examId: examId),
      <TopicAttemptStat>[],
    );

    final weeklySolvedCounts = await _safeLoad<List<int>>(
          () => _questionService.fetchWeeklySolvedCounts(examId: examId),
      List<int>.filled(7, 0),
    );

    final subjects = await _safeLoad<List<StudySubject>>(
          () => _examCatalogService.fetchSubjects(examId),
      <StudySubject>[],
    );

    final topicIds = <String>[];
    final topicSnapshots = <_TopicSnapshot>[];

    for (final subject in subjects) {
      final topics = await _safeLoad<List<StudyTopic>>(
            () => _examCatalogService.fetchTopics(subject.id),
        <StudyTopic>[],
      );

      for (final topic in topics) {
        topicIds.add(topic.id);
        topicSnapshots.add(
          _TopicSnapshot(
            subjectId: subject.id,
            subjectName: subject.name,
            topicId: topic.id,
            topicName: topic.name,
            priority: topic.priority ?? 99,
          ),
        );
      }
    }

    final questionCounts = await _safeLoad<Map<String, int>>(
          () => _questionService.fetchQuestionCountsByTopicIds(topicIds),
      <String, int>{},
    );

    final availableTopics = topicSnapshots
        .map((topic) => topic.copyWith(questionCount: questionCounts[topic.topicId] ?? 0))
        .where((topic) => topic.questionCount > 0)
        .toList()
      ..sort((a, b) {
        final p = a.priority.compareTo(b.priority);
        if (p != 0) return p;
        return b.questionCount.compareTo(a.questionCount);
      });

    final topicNamesById = <String, String>{
      for (final topic in topicSnapshots) topic.topicId: topic.topicName,
    };

    final mentorInsight = await _mentorService.getOrCreateInsight(
      examTitle: widget.examType.title,
      nickname: _nickname(profile),
      todayPoints: todayPoints,
      weeklyPoints: myEntry?.totalPoints ?? 0,
      weeklyNet: myEntry?.totalNet ?? 0,
      streak: streak,
      topicStats: topicStats,
      topicNamesById: topicNamesById,
    );

    return _DashboardData(
      examId: examId,
      profile: profile,
      myEntry: myEntry,
      latestMock: latestMock,
      recentAttempts: recentAttempts,
      solvedToday: solvedToday,
      streak: streak,
      miniMockDone: miniMockDone,
      todayPoints: todayPoints,
      mentorInsight: mentorInsight,
      weeklySolvedCounts: weeklySolvedCounts,
      topicStats: topicStats,
      topicNamesById: topicNamesById,
      recommendedTopic: _recommendedTopic(availableTopics, mentorInsight.weakTopics),
    );
  }

  Future<T> _safeLoad<T>(Future<T> Function() loader, T fallback) async {
    try {
      return await loader();
    } catch (_) {
      return fallback;
    }
  }

  _TopicSnapshot? _recommendedTopic(List<_TopicSnapshot> availableTopics, List<String> weakTopics) {
    for (final weakTopic in weakTopics) {
      for (final topic in availableTopics) {
        if (topic.topicName == weakTopic) return topic;
      }
    }
    if (availableTopics.isEmpty) return null;
    return availableTopics.first;
  }

  String _nickname(Profile? profile) {
    if (profile != null && profile.nickname.trim().isNotEmpty) return profile.nickname.trim();
    final email = profile?.email ?? '';
    if (email.contains('@')) return email.split('@').first;
    return 'Öğrenci';
  }

  int _goal(Profile? profile) {
    final targetScore = profile?.targetScore ?? 380;
    if (targetScore >= 470) return 100;
    if (targetScore >= 430) return 80;
    return 60;
  }

  double _accuracy(_DashboardData data) {
    final entry = data.myEntry;
    if (entry == null || entry.solvedQuestionsCount == 0) return 0;
    return (entry.correctCount / entry.solvedQuestionsCount).clamp(0.0, 1.0);
  }

  String _mentorTitle(_DashboardData data) {
    final topic = data.recommendedTopic?.topicName;
    final subject = data.recommendedTopic?.subjectName;
    if (topic != null && subject != null) return 'Bugün $subject - $topic çalışmalısın';
    return 'Bugün eksik konularına kısa bir tekrar yap';
  }

  Future<void> _refreshDashboard() async {
    setState(() => _dashboardFuture = _loadDashboard());
    await _dashboardFuture;
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _openRecommended(_DashboardData data) {
    final recommended = data.recommendedTopic;
    if (recommended == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => QuestionSolverScreen(examType: widget.examType)));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionSolverScreen(
          examType: widget.examType,
          subjectId: recommended.subjectId,
          topicId: recommended.topicId,
          subjectName: recommended.subjectName,
          topicName: recommended.topicName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _DashTokens.of(context);

    return Scaffold(
      backgroundColor: t.bgBase,
      body: FutureBuilder<_DashboardData?>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: FilledButton(
                onPressed: _refreshDashboard,
                child: const Text('Dashboard yüklenemedi'),
              ),
            );
          }

          // Sekmelerin bazıları data kullanıyor (Analiz gibi)
          final tabPages = <Widget>[
            _PanelTab(
              examTitle: widget.examType.title,
              nickname: _nickname(data.profile),
              streak: data.streak,
              goal: _goal(data.profile),
              solvedToday: data.solvedToday,
              miniMockDone: data.miniMockDone,
              accuracy: _accuracy(data),
              weeklySolvedCounts: data.weeklySolvedCounts,
              mentorTitle: _mentorTitle(data),
              mentorMessage: data.mentorInsight.recommendation,
              onLogout: () async {
                await _authService.signOut();
              },
              onOpenProfile: _openProfile,
              onRefresh: _refreshDashboard,
              onOpenRecommended: () => _openRecommended(data),
              onQuickSolve: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiQuestionSolverScreen()),
              ),
              onTopicTest: () => setState(() => _selectedTabIndex = 1),
              onMiniMock: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MockExamScreen(examType: widget.examType, questionCount: 12)),
              ),
              recentAttemptItems: _recentAttemptItems(data),
            ),
            TopicsScreen(examType: widget.examType),
            FullTytExamScreen(examType: widget.examType),
            MentorAnalysisScreen(
              examType: widget.examType,
              nickname: _nickname(data.profile),
              insight: data.mentorInsight,
              topicStats: data.topicStats,
              topicNamesById: data.topicNamesById,
              weeklySolvedCounts: data.weeklySolvedCounts,
              todayPoints: data.todayPoints,
              streak: data.streak,
            ),
            const ProfileScreen(embedded: true),
          ];

          return DecoratedBox(
            decoration: BoxDecoration(gradient: t.bgGradient),
            child: SafeArea(
              child: Stack(
                children: [
                  _PremiumGlowHeader(tokens: t),
                  RefreshIndicator(
                    onRefresh: _refreshDashboard,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: _GlassSurface(
                            radius: t.rXL,
                            blur: 14,
                            color: t.glassBase,
                            borderColor: t.glassBorder,
                            shadowColor: t.shadowStrong,
                            child: Column(
                              children: [
                                Expanded(
                                  child: IndexedStack(
                                    index: _selectedTabIndex,
                                    children: tabPages,
                                  ),
                                ),
                                _BottomTabBar(
                                  selectedIndex: _selectedTabIndex,
                                  onTap: (i) => setState(() => _selectedTabIndex = i),
                                  tokens: t,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<_AttemptViewModel> _recentAttemptItems(_DashboardData data) {
    final attempts = data.recentAttempts.take(2).map((item) {
      return _AttemptViewModel(
        title: (item['title'] as String?)?.trim().isNotEmpty == true ? item['title'] as String : 'Son Deneme',
        correct: (item['correct_count'] as num?)?.toInt() ?? 0,
        total: (item['question_count'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    if (attempts.isNotEmpty) return attempts;

    final latest = data.latestMock;
    if (latest != null) {
      return [
        _AttemptViewModel(
          title: (latest['title'] as String?) ?? 'Son Deneme',
          correct: (latest['correct_count'] as num?)?.toInt() ?? 0,
          total: (latest['question_count'] as num?)?.toInt() ?? 0,
        ),
      ];
    }

    return const [_AttemptViewModel(title: 'Henüz deneme yok', correct: 0, total: 0)];
  }
}

/// --------------------
/// TOKENS (Light/Dark)
/// --------------------
class _DashTokens {
  _DashTokens._(this.brightness);

  final Brightness brightness;
  bool get isDark => brightness == Brightness.dark;

  static _DashTokens of(BuildContext context) => _DashTokens._(Theme.of(context).brightness);

  // Layout
  final double rXL = 32;
  final double rL = 24;
  final double rM = 18;

  // Background
  Color get bgBase => isDark ? const Color(0xFF0B1220) : const Color(0xFFF4F8FF);

  Gradient get bgGradient => isDark
      ? const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B1220), Color(0xFF0F172A), Color(0xFF0B1220)],
  )
      : const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF7FAFF), Color(0xFFF9FAFC), Color(0xFFF2F6FB)],
  );

  // Text
  Color get textStrong => isDark ? const Color(0xFFE5E7EB) : const Color(0xFF0F172A);
  Color get text => isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
  Color get textSubtle => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get textMute => isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  // Borders
  Color get borderSoft => isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

  // Glass
  Color get glassBase => isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.62);
  Color get glassBorder => isDark ? Colors.white.withOpacity(0.10) : borderSoft.withOpacity(0.75);

  // Shadows
  Color get shadowStrong => isDark ? const Color(0xAA000000) : const Color(0x160F172A);
  Color get shadowSoft => isDark ? const Color(0x66000000) : const Color(0x120F172A);

  // Accents
  final Color success = const Color(0xFF22C55E);
  final Color blue = const Color(0xFF2563EB);

  // Tints
  Color get tintBlue => isDark ? const Color(0xFF0B254A) : const Color(0xFFE0ECFF);
  Color get tintGreen => isDark ? const Color(0xFF0B2A1E) : const Color(0xFFE7F8EE);
  Color get tintAmber => isDark ? const Color(0xFF2A1B0B) : const Color(0xFFFFF2E2);

  // Surfaces
  Color get cardBg => isDark ? const Color(0xFF0F172A).withOpacity(0.60) : Colors.white.withOpacity(0.72);
  Color get chipBg => isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
}

/// --------------------
/// Premium header (Glow)
/// --------------------
class _PremiumGlowHeader extends StatelessWidget {
  const _PremiumGlowHeader({required this.tokens});
  final _DashTokens tokens;

  @override
  Widget build(BuildContext context) {
    // Light modeda glow daha soft; dark modeda daha “neon”
    final green = tokens.isDark ? const Color(0xFF22C55E).withOpacity(0.18) : const Color(0xFF22C55E).withOpacity(0.12);
    final blue = tokens.isDark ? const Color(0xFF60A5FA).withOpacity(0.20) : const Color(0xFF60A5FA).withOpacity(0.12);
    final purple = tokens.isDark ? const Color(0xFF9333EA).withOpacity(0.12) : const Color(0xFF9333EA).withOpacity(0.08);

    final baseGradient = tokens.isDark
        ? const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.topRight,
      colors: [Color(0xFF0B1220), Color(0xFF111827), Color(0xFF1F2937)],
    )
        : const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.topRight,
      colors: [Color(0xFFF3F7FF), Color(0xFFF7FAFF), Color(0xFFF2F6FF)],
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Container(
              height: 320,
              decoration: BoxDecoration(gradient: baseGradient),
            ),
            Positioned(left: -60, top: -40, child: _GlowBlob(color: green, size: 220)),
            Positioned(right: -70, top: 10, child: _GlowBlob(color: blue, size: 240)),
            Positioned(right: 30, top: 140, child: _GlowBlob(color: purple, size: 180)),
          ],
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// --------------------
/// Glass container
/// --------------------
class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.child,
    required this.radius,
    required this.blur,
    required this.color,
    required this.borderColor,
    required this.shadowColor,
  });

  final Widget child;
  final double radius;
  final double blur;
  final Color color;
  final Color borderColor;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 52,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: child,
        ),
      ),
    );
  }
}

/// --------------------
/// PANEL TAB (Dashboard content)
/// --------------------
class _PanelTab extends StatelessWidget {
  const _PanelTab({
    required this.examTitle,
    required this.nickname,
    required this.streak,
    required this.goal,
    required this.solvedToday,
    required this.miniMockDone,
    required this.accuracy,
    required this.weeklySolvedCounts,
    required this.mentorTitle,
    required this.mentorMessage,
    required this.onLogout,
    required this.onOpenProfile,
    required this.onRefresh,
    required this.onOpenRecommended,
    required this.onQuickSolve,
    required this.onTopicTest,
    required this.onMiniMock,
    required this.recentAttemptItems,
  });

  final String examTitle;
  final String nickname;
  final int streak;
  final int goal;
  final int solvedToday;
  final bool miniMockDone;
  final double accuracy;
  final List<int> weeklySolvedCounts;
  final String mentorTitle;
  final String mentorMessage;

  final Future<void> Function() onLogout;
  final VoidCallback onOpenProfile;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenRecommended;

  final VoidCallback onQuickSolve;
  final VoidCallback onTopicTest;
  final VoidCallback onMiniMock;

  final List<_AttemptViewModel> recentAttemptItems;

  @override
  Widget build(BuildContext context) {
    final t = _DashTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    final progress = goal == 0 ? 0.0 : (solvedToday / goal).clamp(0.0, 1.0);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      children: [
        _BrandCard(examTitle: examTitle),
        const SizedBox(height: 12),
        _WelcomeCard(
          nickname: nickname,
          examTitle: examTitle,
          streak: streak,
          onLogout: onLogout,
          onOpenProfile: onOpenProfile,
        ),
        const SizedBox(height: 12),

        _PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bugünkü hedef',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: t.textStrong,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: textTheme.bodyLarge?.copyWith(
                    color: t.text,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                  children: [
                    TextSpan(
                      text: '$solvedToday',
                      style: TextStyle(color: t.success, fontWeight: FontWeight.w900),
                    ),
                    TextSpan(text: ' / $goal soru tamamlandı'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _GoalProgressBar(value: progress),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    miniMockDone ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
                    size: 18,
                    color: miniMockDone ? t.success : t.textMute,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      miniMockDone ? 'Mini denemeyi bugün tamamladın' : 'Mini deneme seni bekliyor',
                      style: textTheme.bodySmall?.copyWith(
                        color: t.textSubtle,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          tokens: t,
        ),

        const SizedBox(height: 12),
        _AiMentorPanel(
          title: mentorTitle,
          message: mentorMessage,
          onTap: onOpenRecommended,
          tokens: t,
        ),

        const SizedBox(height: 12),
        _AiSolveShortcutCard(
          onTap: onQuickSolve,
          tokens: t,
        ),

        const SizedBox(height: 12),
        SizedBox(
          height: 188,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _ActionTile(
                icon: CupertinoIcons.scope,
                title: 'Konu Testi',
                subtitle: 'Tek konu odaklı',
                tint: t.tintGreen,
                onTap: onTopicTest,
                tokens: t,
              ),
              const SizedBox(width: 12),
              _ActionTile(
                icon: CupertinoIcons.doc_text_search,
                title: 'Mini Deneme',
                subtitle: 'Hızlı ölçüm',
                tint: t.tintAmber,
                onTap: onMiniMock,
                tokens: t,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        _PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Haftalık ilerleme',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: t.textStrong,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(accuracy * 100).round()}%',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: t.textStrong,
                        ),
                      ),
                      Text(
                        'doğruluk',
                        style: textTheme.bodySmall?.copyWith(
                          color: t.textSubtle,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _WeeklyBars(values: weeklySolvedCounts, tokens: t),
            ],
          ),
          tokens: t,
        ),

        const SizedBox(height: 12),
        _PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Son denemeler',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: t.textStrong,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),
              ...recentAttemptItems.map(
                    (attempt) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RecentAttemptRow(attempt: attempt, tokens: t),
                ),
              ),
            ],
          ),
          tokens: t,
        ),
      ],
    );
  }
}

/// --------------------
/// Cards (Premium, light/dark)
/// --------------------
class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child, required this.tokens});
  final Widget child;
  final _DashTokens tokens;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.rL),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.cardBg,
            borderRadius: BorderRadius.circular(tokens.rL),
            border: Border.all(color: tokens.borderSoft.withOpacity(tokens.isDark ? 0.55 : 0.65)),
            boxShadow: [
              BoxShadow(
                color: tokens.shadowSoft,
                blurRadius: tokens.isDark ? 26 : 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({required this.examTitle});
  final String examTitle;

  @override
  Widget build(BuildContext context) {
    final t = _DashTokens.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: t.isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.74),
        borderRadius: BorderRadius.vertical(top: Radius.circular(t.rL)),
        border: Border(bottom: BorderSide(color: t.borderSoft.withOpacity(0.9))),
        boxShadow: [
          BoxShadow(
            color: t.shadowSoft,
            blurRadius: 16,
            offset: const Offset(0, 6),
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
              color: t.textStrong,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            CupertinoIcons.sparkles,
            size: 18,
            color: t.isDark ? const Color(0xFF93C5FD) : const Color(0xFF3B82F6),
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
    required this.onLogout,
    required this.onOpenProfile,
  });

  final String nickname;
  final String examTitle;
  final int streak;
  final Future<void> Function() onLogout;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final t = _DashTokens.of(context);
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
                    const Icon(CupertinoIcons.flame_fill, size: 44, color: Color(0xFFF97316)),
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(
                          '${streak > 0 ? streak : 0}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
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
                    color: t.textSubtle,
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
                          color: t.textStrong,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$examTitle çalışma alanın hazır',
                        style: textTheme.bodyMedium?.copyWith(
                          color: t.textSubtle,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => onLogout(),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: t.isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.92),
                      shape: BoxShape.circle,
                      border: Border.all(color: t.borderSoft.withOpacity(t.isDark ? 0.35 : 0.6)),
                      boxShadow: [
                        BoxShadow(color: t.shadowSoft, blurRadius: 18, offset: const Offset(0, 8)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(CupertinoIcons.square_arrow_right, color: t.textStrong, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onOpenProfile,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: t.isDark
                            ? const [Color(0xFF93C5FD), Color(0xFF2563EB)]
                            : const [Color(0xFF60A5FA), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: t.shadowSoft,
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      nickname.isNotEmpty ? nickname[0].toUpperCase() : 'Ö',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
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

/// --------------------
/// Progress + charts (premium)
/// --------------------
class _GoalProgressBar extends StatelessWidget {
  const _GoalProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final t = _DashTokens.of(context);
    final clamped = value.clamp(0.0, 1.0);

    return Container(
      height: 18,
      decoration: BoxDecoration(
        color: t.isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E7EB).withOpacity(0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.borderSoft.withOpacity(t.isDark ? 0.25 : 0.4)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              width: constraints.maxWidth * clamped,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF4ADE80), Color(0xFF22C55E)]),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(color: Color(0x2622C55E), blurRadius: 10, offset: Offset(0, 6)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars({required this.values, required this.tokens});
  final List<int> values;
  final _DashTokens tokens;

  @override
  Widget build(BuildContext context) {
    final maxVal = values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b).clamp(1, 999);
    const labels = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];

    return SizedBox(
      height: 144,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final v = index < values.length ? values[index] : 0;
          final ratio = v == 0 ? 0.0 : (v / maxVal);

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == 6 ? 0 : 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 18,
                        decoration: BoxDecoration(
                          color: tokens.isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            height: v == 0 ? 10 : 98 * ratio.clamp(0.12, 1.0),
                            width: 18,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: tokens.isDark
                                    ? const [Color(0xFF93C5FD), Color(0xFF3B82F6)]
                                    : const [Color(0xFF93C5FD), Color(0xFF2563EB)],
                              ),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: tokens.isDark ? const Color(0x332563EB) : const Color(0x1F2563EB),
                                  blurRadius: 10,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    v.toString(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    labels[index],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.textSubtle,
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

/// --------------------
/// Mentor + tiles + rows
/// --------------------
class _AiMentorPanel extends StatelessWidget {
  const _AiMentorPanel({
    required this.title,
    required this.message,
    required this.onTap,
    required this.tokens,
  });

  final String title;
  final String message;
  final VoidCallback onTap;
  final _DashTokens tokens;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final gradient = tokens.isDark
        ? const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF60A5FA)], begin: Alignment.topLeft, end: Alignment.bottomRight)
        : const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF60A5FA)], begin: Alignment.topLeft, end: Alignment.bottomRight);

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(tokens.rL),
        boxShadow: [
          BoxShadow(
            color: tokens.isDark ? const Color(0x331D4ED8) : const Color(0x1F3B82F6),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(1.2),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.rL - 1),
          color: Colors.white.withOpacity(tokens.isDark ? 0.06 : 0.10),
          border: Border.all(color: Colors.white.withOpacity(tokens.isDark ? 0.10 : 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(tokens.isDark ? 0.14 : 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(tokens.isDark ? 0.10 : 0.12)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(CupertinoIcons.sparkles, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Mentor önerisi',
                  style: textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.1,
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
                height: 1.15,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.94),
                fontWeight: FontWeight.w600,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

class _AiSolveShortcutCard extends StatelessWidget {
  const _AiSolveShortcutCard({
    required this.onTap,
    required this.tokens,
  });

  final VoidCallback onTap;
  final _DashTokens tokens;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: tokens.isDark
            ? const LinearGradient(
                colors: [Color(0xFF111827), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(tokens.rL),
        boxShadow: [
          BoxShadow(
            color: tokens.isDark
                ? const Color(0x33000000)
                : const Color(0x1F1D4ED8),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: const Icon(
              CupertinoIcons.camera_viewfinder,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fotoğraftan soru çözdür',
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sorunun fotoğrafını yükle, AI çözüm adımlarını anlaşılır biçimde anlatsın.',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.88),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1D4ED8),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Aç',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatefulWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.onTap,
    required this.tokens,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;
  final _DashTokens tokens;

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = widget.tokens;
    final iconGradient = tokens.isDark
        ? LinearGradient(
            colors: [
              Colors.white.withOpacity(0.14),
              Colors.white.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              Colors.white.withOpacity(0.98),
              widget.tint.withOpacity(0.45),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 152,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            gradient: tokens.isDark
                ? LinearGradient(
                    colors: [
                      Colors.white.withOpacity(_pressed ? 0.09 : 0.07),
                      Colors.white.withOpacity(_pressed ? 0.06 : 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.99),
                      widget.tint.withOpacity(_pressed ? 0.38 : 0.30),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(tokens.rL),
            border: Border.all(
              color: tokens.borderSoft.withOpacity(_pressed ? 0.95 : (tokens.isDark ? 0.55 : 0.70)),
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.shadowSoft,
                blurRadius: _pressed ? 18 : 26,
                offset: Offset(0, _pressed ? 8 : 14),
              ),
            ],
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(tokens.rL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: iconGradient,
                    border: Border.all(
                      color: tokens.isDark
                          ? Colors.white.withOpacity(0.10)
                          : Colors.white.withOpacity(0.90),
                    ),
                    boxShadow: _pressed
                        ? []
                        : [
                            BoxShadow(
                              color: widget.tint.withOpacity(tokens.isDark ? 0.10 : 0.16),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    widget.icon,
                    color: tokens.isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                    size: 22,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: tokens.textStrong,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: tokens.textSubtle,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: tokens.isDark
                        ? Colors.white.withOpacity(_pressed ? 0.12 : 0.08)
                        : Colors.white.withOpacity(_pressed ? 0.98 : 0.92),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: tokens.borderSoft.withOpacity(tokens.isDark ? 0.45 : 0.65),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Başlat',
                        style: textTheme.labelMedium?.copyWith(
                          color: tokens.isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        CupertinoIcons.arrow_right,
                        size: 14,
                        color: tokens.isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1D4ED8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentAttemptRow extends StatelessWidget {
  const _RecentAttemptRow({required this.attempt, required this.tokens});
  final _AttemptViewModel attempt;
  final _DashTokens tokens;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trailing = attempt.total > 0 ? '${attempt.correct}/${attempt.total}' : '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC).withOpacity(0.95),
        borderRadius: BorderRadius.circular(tokens.rM),
        border: Border.all(color: tokens.borderSoft.withOpacity(tokens.isDark ? 0.55 : 0.75)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: tokens.isDark
                    ? const [Color(0xFF0B254A), Color(0xFF111827)]
                    : const [Color(0xFFDBEAFE), Color(0xFFEFF6FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              CupertinoIcons.book_fill,
              size: 16,
              color: tokens.isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
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
                    fontWeight: FontWeight.w800,
                    color: tokens.textStrong,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  attempt.total > 0 ? 'Doğru cevap' : 'Henüz kayıt yok',
                  style: textTheme.bodySmall?.copyWith(
                    color: tokens.textSubtle,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            trailing,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: tokens.textStrong,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// --------------------
/// Bottom bar (real active state)
/// --------------------
class _BottomTabBar extends StatelessWidget {
  const _BottomTabBar({
    required this.onTap,
    required this.selectedIndex,
    required this.tokens,
  });

  final ValueChanged<int> onTap;
  final int selectedIndex;
  final _DashTokens tokens;

  @override
  Widget build(BuildContext context) {
    final items = const [
      (CupertinoIcons.house_fill, 'Panel'),
      (CupertinoIcons.book_fill, 'Pratik'),
      (CupertinoIcons.doc_text_fill, 'Deneme'),
      (CupertinoIcons.chart_bar_alt_fill, 'Analiz'),
      (CupertinoIcons.person_crop_circle, 'Profil'),
    ];

    final pillGradient = tokens.isDark
        ? const LinearGradient(colors: [Color(0xFF0B254A), Color(0xFF111827)], begin: Alignment.topLeft, end: Alignment.bottomRight)
        : const LinearGradient(colors: [Color(0xFFDBEAFE), Color(0xFFEFF6FF)], begin: Alignment.topLeft, end: Alignment.bottomRight);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(tokens.rL),
        border: Border.all(color: tokens.borderSoft.withOpacity(tokens.isDark ? 0.55 : 0.70)),
        boxShadow: [
          BoxShadow(color: tokens.shadowSoft, blurRadius: 26, offset: const Offset(0, 12)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final itemW = w / items.length;
          final pillW = itemW - 10;

          return Stack(
            alignment: Alignment.center,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: (itemW * selectedIndex) + 5,
                child: Container(
                  width: pillW,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: pillGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              Row(
                children: List.generate(items.length, (i) {
                  final it = items[i];
                  final active = i == selectedIndex;
                  return SizedBox(
                    width: itemW,
                    child: _BottomItem(
                      icon: it.$1,
                      label: it.$2,
                      active: active,
                      onTap: () => onTap(i),
                      tokens: tokens,
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.tokens,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final _DashTokens tokens;

  @override
  Widget build(BuildContext context) {
    final color = active ? (tokens.isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)) : tokens.textSubtle;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// --------------------
/// Data models (unchanged)
/// --------------------
class _DashboardData {
  const _DashboardData({
    required this.examId,
    required this.profile,
    required this.myEntry,
    required this.latestMock,
    required this.recentAttempts,
    required this.solvedToday,
    required this.streak,
    required this.miniMockDone,
    required this.todayPoints,
    required this.mentorInsight,
    required this.weeklySolvedCounts,
    required this.topicStats,
    required this.topicNamesById,
    required this.recommendedTopic,
  });

  final String examId;
  final Profile? profile;
  final LeaderboardEntry? myEntry;
  final Map<String, dynamic>? latestMock;
  final List<Map<String, dynamic>> recentAttempts;
  final int solvedToday;
  final int streak;
  final bool miniMockDone;
  final int todayPoints;
  final MentorInsight mentorInsight;
  final List<int> weeklySolvedCounts;
  final List<TopicAttemptStat> topicStats;
  final Map<String, String> topicNamesById;
  final _TopicSnapshot? recommendedTopic;
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

class _TopicSnapshot {
  const _TopicSnapshot({
    required this.subjectId,
    required this.subjectName,
    required this.topicId,
    required this.topicName,
    required this.priority,
    this.questionCount = 0,
  });

  final String subjectId;
  final String subjectName;
  final String topicId;
  final String topicName;
  final int priority;
  final int questionCount;

  _TopicSnapshot copyWith({int? questionCount}) {
    return _TopicSnapshot(
      subjectId: subjectId,
      subjectName: subjectName,
      topicId: topicId,
      topicName: topicName,
      priority: priority,
      questionCount: questionCount ?? this.questionCount,
    );
  }
}
