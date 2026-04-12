import 'daily_task.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.examId,
    this.nickname = '',
    this.examTitle = '',
    this.solvedToday = 0,
    this.dailyGoal = 60,
    this.streak = 0,
    this.todayPoints = 0,
    this.weeklyPoints = 0,
    this.weeklyNet = 0.0,
    this.accuracy = 0.0,
    this.miniMockDone = false,
    this.weeklySolvedCounts = const [],
    this.recentAttempts = const [],
    this.dailyTasks = const [],
    this.weakTopics = const [],
    this.mentorRecommendation = '',
  });

  final String examId;
  final String nickname;
  final String examTitle;
  final int solvedToday;
  final int dailyGoal;
  final int streak;
  final int todayPoints;
  final int weeklyPoints;
  final double weeklyNet;
  final double accuracy;
  final bool miniMockDone;
  final List<int> weeklySolvedCounts;
  final List<Map<String, dynamic>> recentAttempts;
  final List<DailyTask> dailyTasks;
  final List<String> weakTopics;
  final String mentorRecommendation;

  double get dailyProgress =>
      dailyGoal == 0 ? 0.0 : (solvedToday / dailyGoal).clamp(0.0, 1.0);

  factory DashboardSummary.fromRpcResponse(
    String examId,
    Map<String, dynamic> map,
  ) {
    final tasksRaw = map['daily_tasks'];
    final dailyTasks = <DailyTask>[];
    if (tasksRaw is List) {
      for (final item in tasksRaw) {
        if (item is Map<String, dynamic>) {
          dailyTasks.add(DailyTask.fromMap(item));
        } else if (item is Map) {
          dailyTasks.add(DailyTask.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    final weeklyRaw = map['weekly_solved_counts'];
    final weeklySolvedCounts = <int>[];
    if (weeklyRaw is List) {
      for (final item in weeklyRaw) {
        weeklySolvedCounts.add((item as num?)?.toInt() ?? 0);
      }
    }
    if (weeklySolvedCounts.isEmpty) {
      weeklySolvedCounts.addAll(List<int>.filled(7, 0));
    }

    final recentRaw = map['recent_attempts'];
    final recentAttempts = <Map<String, dynamic>>[];
    if (recentRaw is List) {
      for (final item in recentRaw) {
        if (item is Map<String, dynamic>) {
          recentAttempts.add(item);
        } else if (item is Map) {
          recentAttempts.add(Map<String, dynamic>.from(item));
        }
      }
    }

    final weakTopicsRaw = map['weak_topics'];
    final weakTopics = <String>[];
    if (weakTopicsRaw is List) {
      for (final item in weakTopicsRaw) {
        if (item is String && item.isNotEmpty) {
          weakTopics.add(item);
        }
      }
    }

    return DashboardSummary(
      examId: examId,
      nickname: map['nickname'] as String? ?? '',
      examTitle: map['exam_title'] as String? ?? '',
      solvedToday: (map['solved_today'] as num?)?.toInt() ?? 0,
      dailyGoal: (map['daily_goal'] as num?)?.toInt() ?? 60,
      streak: (map['streak'] as num?)?.toInt() ?? 0,
      todayPoints: (map['today_points'] as num?)?.toInt() ?? 0,
      weeklyPoints: (map['weekly_points'] as num?)?.toInt() ?? 0,
      weeklyNet: (map['weekly_net'] as num?)?.toDouble() ?? 0.0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      miniMockDone: map['mini_mock_done'] as bool? ?? false,
      weeklySolvedCounts: weeklySolvedCounts,
      recentAttempts: recentAttempts,
      dailyTasks: dailyTasks,
      weakTopics: weakTopics,
      mentorRecommendation: map['mentor_recommendation'] as String? ?? '',
    );
  }
}
