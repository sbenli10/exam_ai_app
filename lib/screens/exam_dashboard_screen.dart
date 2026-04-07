import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/exam_type.dart';
import '../models/leaderboard_entry.dart';
import '../models/mentor_insight.dart';
import '../models/profile.dart';
import '../models/study_topic.dart';
import '../models/topic_attempt_stat.dart';
import '../services/exam_catalog_service.dart';
import '../services/leaderboard_service.dart';
import '../services/mentor_service.dart';
import '../services/profile_service.dart';
import '../services/question_service.dart';
import 'full_tyt_exam_screen.dart';
import 'mentor_analysis_screen.dart';
import 'mock_exam_screen.dart';
import 'question_solver_screen.dart';
import 'topic_exam_picker_screen.dart';
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
  final ExamCatalogService _examCatalogService = ExamCatalogService();
  final QuestionService _questionService = QuestionService();
  final LeaderboardService _leaderboardService = LeaderboardService();
  final ProfileService _profileService = ProfileService();
  final MentorService _mentorService = MentorService();

  late Future<_DashboardData?> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  Future<_DashboardData?> _loadDashboard() async {
    final examId = await _examCatalogService.resolveExamIdByTitle(
      widget.examType.title,
    );
    if (examId == null) {
      return null;
    }

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
        final priorityCompare = a.priority.compareTo(b.priority);
        if (priorityCompare != 0) {
          return priorityCompare;
        }
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

  _TopicSnapshot? _recommendedTopic(
    List<_TopicSnapshot> availableTopics,
    List<String> weakTopics,
  ) {
    for (final weakTopic in weakTopics) {
      for (final topic in availableTopics) {
        if (topic.topicName == weakTopic) {
          return topic;
        }
      }
    }
    if (availableTopics.isEmpty) {
      return null;
    }
    return availableTopics.first;
  }

  String _nickname(Profile? profile) {
    if (profile != null && profile.nickname.trim().isNotEmpty) {
      return profile.nickname.trim();
    }
    final email = profile?.email ?? '';
    if (email.contains('@')) {
      return email.split('@').first;
    }
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
    if (entry == null || entry.solvedQuestionsCount == 0) {
      return 0;
    }
    return (entry.correctCount / entry.solvedQuestionsCount).clamp(0.0, 1.0);
  }

  String _mentorTitle(_DashboardData data) {
    final topic = data.recommendedTopic?.topicName;
    final subject = data.recommendedTopic?.subjectName;
    if (topic != null && subject != null) {
      return 'Bugün $subject - $topic çalışmalısın';
    }
    return 'Bugün eksik konularına kısa bir tekrar yap';
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      _dashboardFuture = _loadDashboard();
    });
    await _dashboardFuture;
  }

  void _openRecommended(_DashboardData data) {
    final recommended = data.recommendedTopic;
    if (recommended == null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuestionSolverScreen(examType: widget.examType),
        ),
      );
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

  void _onBottomTap(int index, _DashboardData data) {
    switch (index) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TopicsScreen(examType: widget.examType),
          ),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullTytExamScreen(examType: widget.examType),
          ),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MentorAnalysisScreen(
              examType: widget.examType,
              nickname: _nickname(data.profile),
              insight: data.mentorInsight,
              topicStats: data.topicStats,
              topicNamesById: data.topicNamesById,
              weeklySolvedCounts: data.weeklySolvedCounts,
              todayPoints: data.todayPoints,
              streak: data.streak,
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: FutureBuilder<_DashboardData?>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              snapshot.data == null) {
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

          final nickname = _nickname(data.profile);
          final goal = _goal(data.profile);
          final progress = goal == 0
              ? 0.0
              : (data.solvedToday / goal).clamp(0.0, 1.0);
          final accuracy = _accuracy(data);

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
                onRefresh: _refreshDashboard,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                                children: [
                                  _BrandCard(examTitle: widget.examType.title),
                                  const SizedBox(height: 12),
                                  _WelcomeCard(
                                    nickname: nickname,
                                    examTitle: widget.examType.title,
                                    streak: data.streak,
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
                                                text: '${data.solvedToday}',
                                                style: const TextStyle(
                                                  color: Color(0xFF16A34A),
                                                  fontWeight: FontWeight.w900,
                                                ),
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
                                              data.miniMockDone
                                                  ? CupertinoIcons.check_mark_circled_solid
                                                  : CupertinoIcons.circle,
                                              size: 18,
                                              color: data.miniMockDone
                                                  ? const Color(0xFF16A34A)
                                                  : const Color(0xFF94A3B8),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                data.miniMockDone
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
                                  ),
                                  const SizedBox(height: 12),
                                  _AiMentorPanel(
                                    title: _mentorTitle(data),
                                    message: data.mentorInsight.recommendation,
                                    onTap: () => _openRecommended(data),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 132,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: [
                                        _ActionTile(
                                          icon: CupertinoIcons.bolt_fill,
                                          title: 'Hızlı Çöz',
                                          subtitle: 'Karışık sorular',
                                          tint: const Color(0xFFE0ECFF),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => QuestionSolverScreen(
                                                  examType: widget.examType,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        _ActionTile(
                                          icon: CupertinoIcons.scope,
                                          title: 'Konu Testi',
                                          subtitle: 'Tek konu odaklı',
                                          tint: const Color(0xFFE7F8EE),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => TopicExamPickerScreen(
                                                  examType: widget.examType,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        _ActionTile(
                                          icon: CupertinoIcons.doc_text_search,
                                          title: 'Mini Deneme',
                                          subtitle: 'Hızlı ölçüm',
                                          tint: const Color(0xFFFFF2E2),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => MockExamScreen(
                                                  examType: widget.examType,
                                                  questionCount: 12,
                                                ),
                                              ),
                                            );
                                          },
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
                                                  color: const Color(0xFF0F172A),
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
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                Text(
                                                  'doğruluk',
                                                  style: textTheme.bodySmall?.copyWith(
                                                    color: const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        _WeeklyBars(values: data.weeklySolvedCounts),
                                      ],
                                    ),
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
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ..._recentAttemptItems(data).map(
                                          (attempt) => Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: _RecentAttemptRow(attempt: attempt),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _BottomTabBar(
                              onTap: (index) => _onBottomTap(index, data),
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

  List<_AttemptViewModel> _recentAttemptItems(_DashboardData data) {
    final attempts = data.recentAttempts.take(2).map((item) {
      return _AttemptViewModel(
        title: (item['title'] as String?)?.trim().isNotEmpty == true
            ? item['title'] as String
            : 'Son Deneme',
        correct: (item['correct_count'] as num?)?.toInt() ?? 0,
        total: (item['question_count'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    if (attempts.isNotEmpty) {
      return attempts;
    }

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

    return const [
      _AttemptViewModel(title: 'Henüz deneme yok', correct: 0, total: 0),
    ];
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({
    required this.examTitle,
  });

  final String examTitle;

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
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
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

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.child,
  });

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
  const _GoalProgressBar({
    required this.value,
  });

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
    required this.onTap,
  });

  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A3B82F6),
            blurRadius: 28,
            offset: Offset(0, 12),
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
                  child: const Icon(CupertinoIcons.sparkles, size: 14, color: Colors.white),
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
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
  const _WeeklyBars({
    required this.values,
  });

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final max = values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b).clamp(1, 999);
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
                            height: value == 0 ? 12 : 84 * ratio.clamp(0.12, 1.0),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF86B8FF), Color(0xFF3B82F6)],
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
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    labels[index],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
  const _RecentAttemptRow({
    required this.attempt,
  });

  final _AttemptViewModel attempt;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trailing = attempt.total > 0 ? '${attempt.correct}/${attempt.total}' : '-';

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
    required this.onTap,
  });

  final ValueChanged<int> onTap;

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
        children: [
          _BottomItem(icon: CupertinoIcons.house_fill, label: 'Panel', active: true, onTap: () => onTap(0)),
          _BottomItem(icon: CupertinoIcons.book_fill, label: 'Pratik', onTap: () => onTap(1)),
          _BottomItem(icon: CupertinoIcons.doc_text_fill, label: 'Deneme', onTap: () => onTap(2)),
          _BottomItem(icon: CupertinoIcons.chart_bar_alt_fill, label: 'Analiz', onTap: () => onTap(3)),
          _BottomItem(icon: CupertinoIcons.person_crop_circle, label: 'Profil', onTap: () => onTap(4)),
        ],
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

  _TopicSnapshot copyWith({
    int? questionCount,
  }) {
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
