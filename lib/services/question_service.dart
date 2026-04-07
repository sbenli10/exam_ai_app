import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/generated_question.dart';
import '../models/question.dart';
import '../models/topic_attempt_stat.dart';

class QuestionService {
  QuestionService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Question>> fetchQuestions({
    required String examId,
    String? subjectId,
    String? topicId,
    String? difficulty,
    int limit = 10,
  }) async {
    var query = _client.from('questions').select('''
          id,
          exam_id,
          subject_id,
          topic_id,
          question_text,
          option_a,
          option_b,
          option_c,
          option_d,
          option_e,
          correct_answer,
          difficulty,
          is_verified,
          image_url,
          question_options (
            option_key,
            option_text
          )
        ''').eq('exam_id', examId);
    query = query.eq('is_verified', true);

    if (subjectId != null && subjectId.isNotEmpty) {
      query = query.eq('subject_id', subjectId);
    }

    if (topicId != null && topicId.isNotEmpty) {
      query = query.eq('topic_id', topicId);
    }

    if (difficulty != null && difficulty.isNotEmpty) {
      query = query.eq('difficulty', difficulty);
    }

    final response = await query.limit(limit);

    return response
        .map<Question>((row) => Question.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<Question?> fetchQuestionById(String questionId) async {
    final data = await _client.from('questions').select('''
          id,
          exam_id,
          subject_id,
          topic_id,
          question_text,
          option_a,
          option_b,
          option_c,
          option_d,
          option_e,
          correct_answer,
          difficulty,
          is_verified,
          image_url,
          question_options (
            option_key,
            option_text
          )
        ''').eq('id', questionId).maybeSingle();
    if (data == null) {
      return null;
    }

    if (data['is_verified'] == false) {
      return null;
    }

    return Question.fromMap(data);
  }

  Future<Question?> fetchExistingQuestionForTopic({
    required String examId,
    required String subjectId,
    required String topicId,
  }) async {
    final data = await _client.from('questions').select('''
          id,
          exam_id,
          subject_id,
          topic_id,
          question_text,
          option_a,
          option_b,
          option_c,
          option_d,
          option_e,
          correct_answer,
          difficulty,
          is_verified,
          image_url,
          question_options (
            option_key,
            option_text
          )
        ''').eq('exam_id', examId).eq('subject_id', subjectId).eq('topic_id', topicId).eq('is_verified', true).limit(1).maybeSingle();

    if (data == null) {
      return null;
    }

    return Question.fromMap(data);
  }

  Future<Question> createGeneratedQuestion({
    required String examId,
    required String subjectId,
    required String topicId,
    required GeneratedQuestion generatedQuestion,
  }) async {
    final data = await _client
        .from('questions')
        .insert(
          generatedQuestion.toQuestionInsertMap(
            examId: examId,
            subjectId: subjectId,
            topicId: topicId,
          ),
        )
        .select('''
          id,
          exam_id,
          subject_id,
          topic_id,
          question_text,
          option_a,
          option_b,
          option_c,
          option_d,
          option_e,
          correct_answer,
          difficulty,
          image_url
        ''')
        .single();

    await _client.from('question_options').insert([
      {
        'question_id': data['id'],
        'option_key': 'A',
        'option_text': generatedQuestion.optionA,
      },
      {
        'question_id': data['id'],
        'option_key': 'B',
        'option_text': generatedQuestion.optionB,
      },
      {
        'question_id': data['id'],
        'option_key': 'C',
        'option_text': generatedQuestion.optionC,
      },
      {
        'question_id': data['id'],
        'option_key': 'D',
        'option_text': generatedQuestion.optionD,
      },
      {
        'question_id': data['id'],
        'option_key': 'E',
        'option_text': generatedQuestion.optionE,
      },
    ]);

    return Question.fromMap(data);
  }

  Future<Map<String, int>> fetchQuestionCountsByTopicIds(List<String> topicIds) async {
    if (topicIds.isEmpty) {
      return const {};
    }

    final rows = await _client
        .from('questions')
        .select('topic_id')
        .inFilter('topic_id', topicIds)
        .eq('is_verified', true);

    final counts = <String, int>{};
    for (final row in rows) {
      final item = Map<String, dynamic>.from(row);
      final topicId = item['topic_id'] as String?;
      if (topicId == null) {
        continue;
      }
      counts[topicId] = (counts[topicId] ?? 0) + 1;
    }

    return counts;
  }

  Future<int> fetchQuestionCountByExam(String examId) async {
    final rows = await _client
        .from('questions')
        .select('id')
        .eq('exam_id', examId)
        .eq('is_verified', true);

    return rows.length;
  }

  Future<void> saveQuestionAttempt({
    required String questionId,
    String? selectedAnswer,
    required bool isCorrect,
    bool isBlank = false,
    bool usedAiHelp = false,
    int timeSpentSeconds = 0,
    int attemptNo = 1,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('No authenticated user found.');
    }

    await _client.from('question_attempts').insert({
      'user_id': userId,
      'question_id': questionId,
      'selected_answer': selectedAnswer,
      'is_correct': isCorrect,
      'is_blank': isBlank,
      'used_ai_help': usedAiHelp,
      'time_spent_seconds': timeSpentSeconds,
      'attempt_no': attemptNo,
    });
  }

  Future<void> saveMockAttempt({
    required String examId,
    required String title,
    required String mockType,
    required int questionCount,
    required int correctCount,
    required int wrongCount,
    required int blankCount,
    int durationSeconds = 0,
    String? subjectId,
    String? topicId,
    DateTime? startedAt,
    DateTime? completedAt,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('No authenticated user found.');
    }

    await _client.from('mock_attempts').insert({
      'user_id': userId,
      'exam_id': examId,
      'subject_id': subjectId,
      'topic_id': topicId,
      'title': title,
      'mock_type': mockType,
      'question_count': questionCount,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'blank_count': blankCount,
      'duration_seconds': durationSeconds,
      'started_at': (startedAt ?? DateTime.now()).toIso8601String(),
      'completed_at': (completedAt ?? DateTime.now()).toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> fetchLatestMockAttempt({
    required String examId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('No authenticated user found.');
    }

    final data = await _client
        .from('mock_attempts')
        .select()
        .eq('user_id', userId)
        .eq('exam_id', examId)
        .order('completed_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return Map<String, dynamic>.from(data);
  }

  Future<int> fetchTodaySolvedQuestionCount({
    required String examId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('No authenticated user found.');
    }

    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).toIso8601String();

    final rows = await _client
        .from('question_attempts')
        .select('id')
        .eq('user_id', userId)
        .eq('exam_id', examId)
        .gte('created_at', start);

    return rows.length;
  }

  Future<int> fetchTodayPoints({
    required String examId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('No authenticated user found.');
    }

    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).toIso8601String();

    final questionRows = await _client
        .from('question_attempts')
        .select('points_awarded')
        .eq('user_id', userId)
        .eq('exam_id', examId)
        .gte('created_at', start);

    final mockRows = await _client
        .from('mock_attempts')
        .select('points_awarded')
        .eq('user_id', userId)
        .eq('exam_id', examId)
        .gte('created_at', start);

    var total = 0;
    for (final row in questionRows) {
      total += (Map<String, dynamic>.from(row)['points_awarded'] as num?)?.toInt() ?? 0;
    }
    for (final row in mockRows) {
      total += (Map<String, dynamic>.from(row)['points_awarded'] as num?)?.toInt() ?? 0;
    }

    return total;
  }

  Future<bool> fetchTodayMiniMockCompleted({
    required String examId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('No authenticated user found.');
    }

    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).toIso8601String();

    final rows = await _client
        .from('mock_attempts')
        .select('id')
        .eq('user_id', userId)
        .eq('exam_id', examId)
        .eq('mock_type', 'mini')
        .gte('created_at', start)
        .limit(1);

    return rows.isNotEmpty;
  }

  Future<int> fetchStudyStreak({
    required String examId,
    int dayLimit = 30,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('No authenticated user found.');
    }

    final startDate = DateTime.now().subtract(Duration(days: dayLimit));
    final start = DateTime(startDate.year, startDate.month, startDate.day).toIso8601String();

    final questionRows = await _client
        .from('question_attempts')
        .select('created_at')
        .eq('user_id', userId)
        .eq('exam_id', examId)
        .gte('created_at', start);

    final mockRows = await _client
        .from('mock_attempts')
        .select('created_at')
        .eq('user_id', userId)
        .eq('exam_id', examId)
        .gte('created_at', start);

    final activeDays = <String>{};
    for (final row in [...questionRows, ...mockRows]) {
      final createdAt = Map<String, dynamic>.from(row)['created_at'] as String?;
      if (createdAt == null) {
        continue;
      }
      activeDays.add(createdAt.split('T').first);
    }

    var streak = 0;
    var cursor = DateTime.now();
    while (true) {
      final key = DateTime(cursor.year, cursor.month, cursor.day).toIso8601String().split('T').first;
      if (!activeDays.contains(key)) {
        break;
      }
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  Future<List<TopicAttemptStat>> fetchTopicAttemptStats({
    required String examId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('No authenticated user found.');
    }

    final rows = await _client
        .from('question_attempts')
        .select('topic_id, is_correct, is_blank')
        .eq('user_id', userId)
        .eq('exam_id', examId);

    final stats = <String, Map<String, int>>{};
    for (final row in rows) {
      final item = Map<String, dynamic>.from(row);
      final topicId = item['topic_id'] as String?;
      if (topicId == null) {
        continue;
      }

      final current = stats.putIfAbsent(
        topicId,
        () => {
          'correct': 0,
          'wrong': 0,
          'blank': 0,
        },
      );

      final isBlank = item['is_blank'] as bool? ?? false;
      final isCorrect = item['is_correct'] as bool? ?? false;
      if (isBlank) {
        current['blank'] = (current['blank'] ?? 0) + 1;
      } else if (isCorrect) {
        current['correct'] = (current['correct'] ?? 0) + 1;
      } else {
        current['wrong'] = (current['wrong'] ?? 0) + 1;
      }
    }

    return stats.entries
        .map(
          (entry) => TopicAttemptStat(
            topicId: entry.key,
            correctCount: entry.value['correct'] ?? 0,
            wrongCount: entry.value['wrong'] ?? 0,
            blankCount: entry.value['blank'] ?? 0,
          ),
        )
        .toList();
  }

  Future<List<int>> fetchWeeklySolvedCounts({
    required String examId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('No authenticated user found.');
    }

    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day).subtract(
      const Duration(days: 6),
    );

    final rows = await _client
        .from('question_attempts')
        .select('created_at')
        .eq('user_id', userId)
        .eq('exam_id', examId)
        .gte('created_at', startDate.toIso8601String());

    final countsByDay = <String, int>{};
    for (final row in rows) {
      final createdAt = Map<String, dynamic>.from(row)['created_at'] as String?;
      if (createdAt == null || createdAt.length < 10) {
        continue;
      }
      final dayKey = createdAt.substring(0, 10);
      countsByDay[dayKey] = (countsByDay[dayKey] ?? 0) + 1;
    }

    return List<int>.generate(7, (index) {
      final day = startDate.add(Duration(days: index));
      final dayKey = DateTime(day.year, day.month, day.day)
          .toIso8601String()
          .substring(0, 10);
      return countsByDay[dayKey] ?? 0;
    });
  }

  Future<List<Map<String, dynamic>>> fetchRecentMockAttempts({
    required String examId,
    int limit = 3,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('No authenticated user found.');
    }

    final rows = await _client
        .from('mock_attempts')
        .select()
        .eq('user_id', userId)
        .eq('exam_id', examId)
        .order('completed_at', ascending: false)
        .limit(limit);

    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchWrongQuestionReviews({
    required String examId,
    int limit = 20,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('No authenticated user found.');
    }

    final rows = await _client
        .from('question_attempts')
        .select('''
          question_id,
          selected_answer,
          created_at,
          questions (
            id,
            exam_id,
            subject_id,
            topic_id,
            question_text,
            option_a,
            option_b,
            option_c,
            option_d,
            option_e,
            correct_answer,
            difficulty,
            image_url,
            question_options (
              option_key,
              option_text
            )
          )
        ''')
        .eq('user_id', userId)
        .eq('exam_id', examId)
        .eq('is_correct', false)
        .eq('is_blank', false)
        .order('created_at', ascending: false)
        .limit(limit);

    final uniqueByQuestionId = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final item = Map<String, dynamic>.from(row);
      final questionId = item['question_id'] as String?;
      if (questionId == null || uniqueByQuestionId.containsKey(questionId)) {
        continue;
      }

      final questionMapRaw = item['questions'];
      if (questionMapRaw is Map) {
        uniqueByQuestionId[questionId] = {
          'selected_answer': item['selected_answer'],
          'created_at': item['created_at'],
          'question': Map<String, dynamic>.from(questionMapRaw),
        };
      } else if (questionMapRaw is List && questionMapRaw.isNotEmpty) {
        final first = questionMapRaw.first;
        if (first is Map) {
          uniqueByQuestionId[questionId] = {
            'selected_answer': item['selected_answer'],
            'created_at': item['created_at'],
            'question': Map<String, dynamic>.from(first),
          };
        }
      }
    }

    return uniqueByQuestionId.values.toList();
  }
}
