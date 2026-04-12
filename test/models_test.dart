import 'package:exam_ai_app/models/daily_task.dart';
import 'package:exam_ai_app/models/dashboard_summary.dart';
import 'package:exam_ai_app/models/mock_attempt_question.dart';
import 'package:exam_ai_app/models/dashboard_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailyTask', () {
    test('fromMap parses a complete map', () {
      final task = DailyTask.fromMap({
        'id': 'task-1',
        'user_id': 'user-1',
        'exam_id': 'exam-1',
        'task_type': 'solve_questions',
        'title': '10 soru çöz',
        'description': 'Bugün 10 soru çözmelisin',
        'status': 'completed',
        'points_reward': 25,
        'related_id': 'topic-1',
        'task_date': '2026-04-12',
      });

      expect(task.id, 'task-1');
      expect(task.userId, 'user-1');
      expect(task.examId, 'exam-1');
      expect(task.taskType, 'solve_questions');
      expect(task.title, '10 soru çöz');
      expect(task.description, 'Bugün 10 soru çözmelisin');
      expect(task.status, 'completed');
      expect(task.pointsReward, 25);
      expect(task.relatedId, 'topic-1');
      expect(task.isCompleted, isTrue);
      expect(task.isPending, isFalse);
    });

    test('fromMap handles missing/null fields gracefully', () {
      final task = DailyTask.fromMap(<String, dynamic>{});

      expect(task.id, '');
      expect(task.status, 'pending');
      expect(task.pointsReward, 0);
      expect(task.isCompleted, isFalse);
      expect(task.isPending, isTrue);
      expect(task.relatedId, isNull);
      expect(task.taskDate, isNull);
    });
  });

  group('DashboardSummary', () {
    test('fromRpcResponse parses full JSON', () {
      final summary = DashboardSummary.fromRpcResponse('exam-1', {
        'nickname': 'Ali',
        'exam_title': 'YKS',
        'solved_today': 15,
        'daily_goal': 80,
        'streak': 3,
        'today_points': 120,
        'weekly_points': 800,
        'weekly_net': 12.5,
        'accuracy': 0.78,
        'mini_mock_done': true,
        'weekly_solved_counts': [5, 10, 8, 12, 0, 0, 15],
        'recent_attempts': [
          {'title': 'Deneme 1', 'correct_count': 8, 'question_count': 12},
        ],
        'daily_tasks': [
          {
            'id': 't1',
            'user_id': 'u1',
            'exam_id': 'e1',
            'task_type': 'quiz',
            'title': 'Kısa test',
            'description': '',
            'status': 'pending',
            'points_reward': 10,
          },
        ],
        'weak_topics': ['Paragraf', 'Türev'],
        'mentor_recommendation': 'Paragraf çalış.',
      });

      expect(summary.examId, 'exam-1');
      expect(summary.nickname, 'Ali');
      expect(summary.solvedToday, 15);
      expect(summary.dailyGoal, 80);
      expect(summary.streak, 3);
      expect(summary.todayPoints, 120);
      expect(summary.accuracy, 0.78);
      expect(summary.miniMockDone, isTrue);
      expect(summary.weeklySolvedCounts.length, 7);
      expect(summary.recentAttempts.length, 1);
      expect(summary.dailyTasks.length, 1);
      expect(summary.dailyTasks.first.title, 'Kısa test');
      expect(summary.weakTopics, ['Paragraf', 'Türev']);
      expect(summary.mentorRecommendation, 'Paragraf çalış.');
      expect(summary.dailyProgress, closeTo(0.1875, 0.001));
    });

    test('fromRpcResponse handles empty map', () {
      final summary =
          DashboardSummary.fromRpcResponse('exam-2', <String, dynamic>{});

      expect(summary.examId, 'exam-2');
      expect(summary.nickname, '');
      expect(summary.solvedToday, 0);
      expect(summary.dailyGoal, 60);
      expect(summary.streak, 0);
      expect(summary.dailyTasks, isEmpty);
      expect(summary.weeklySolvedCounts.length, 7);
    });
  });

  group('MockAttemptQuestion', () {
    test('toMap and fromMap round-trip', () {
      const original = MockAttemptQuestion(
        mockAttemptId: 'mock-1',
        questionId: 'q-1',
        orderNo: 3,
        selectedAnswer: 'B',
        correctAnswer: 'B',
        isCorrect: true,
        isBlank: false,
      );

      final map = original.toMap();
      final restored = MockAttemptQuestion.fromMap(map);

      expect(restored.mockAttemptId, 'mock-1');
      expect(restored.questionId, 'q-1');
      expect(restored.orderNo, 3);
      expect(restored.selectedAnswer, 'B');
      expect(restored.correctAnswer, 'B');
      expect(restored.isCorrect, isTrue);
      expect(restored.isBlank, isFalse);
    });

    test('fromMap handles missing fields', () {
      final q = MockAttemptQuestion.fromMap(<String, dynamic>{});
      expect(q.mockAttemptId, '');
      expect(q.orderNo, 0);
      expect(q.selectedAnswer, isNull);
      expect(q.isCorrect, isFalse);
      expect(q.isBlank, isTrue);
    });
  });

  group('DashboardConfig', () {
    test('forExamTitle returns correct config for each exam', () {
      expect(DashboardConfig.forExamTitle('YKS').examType.title, 'YKS');
      expect(DashboardConfig.forExamTitle('LGS').examType.title, 'LGS');
      expect(DashboardConfig.forExamTitle('KPSS').examType.title, 'KPSS');
      expect(DashboardConfig.forExamTitle('ALES').examType.title, 'ALES');
      expect(DashboardConfig.forExamTitle('unknown').examType.title, 'YKS');
    });

    test('YKS config has TYT and AYT sections', () {
      final cfg = DashboardConfig.yks;
      expect(cfg.sections.length, 2);
      expect(cfg.sections[0].yksTrack, YksTrack.tyt);
      expect(cfg.sections[1].yksTrack, YksTrack.ayt);
    });

    test('allActions flattens section actions', () {
      final cfg = DashboardConfig.lgs;
      expect(cfg.allActions.length, 3);
    });
  });
}
