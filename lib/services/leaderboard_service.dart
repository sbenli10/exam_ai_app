import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/leaderboard_entry.dart';

class LeaderboardService {
  LeaderboardService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<LeaderboardEntry>> fetchLeaderboard({
    required String examId,
    String periodType = 'weekly',
    DateTime? referenceDate,
    int limit = 50,
  }) async {
    final periodStart = _periodStart(periodType, referenceDate ?? DateTime.now());

    final response = await _client.from('leaderboard_stats').select('''
          id,
          user_id,
          exam_id,
          period_type,
          period_start,
          period_end,
          total_points,
          total_net,
          solved_questions_count,
          correct_count,
          wrong_count,
          blank_count,
          mock_count,
          rank_position
        ''').eq('exam_id', examId).eq('period_type', periodType).eq(
          'period_start',
          periodStart.toIso8601String().split('T').first,
        ).order('rank_position', ascending: true).limit(limit);

    final rows = response.map((row) => Map<String, dynamic>.from(row)).toList();
    final emailByUserId = await _profileEmailMap(
      rows.map((row) => row['user_id'] as String).toSet().toList(),
    );

    return rows.map<LeaderboardEntry>((row) {
      return LeaderboardEntry.fromMap({
        ...row,
        'email': emailByUserId[row['user_id'] as String],
      });
    }).toList();
  }

  Future<LeaderboardEntry?> fetchMyLeaderboardEntry({
    required String examId,
    String periodType = 'weekly',
    DateTime? referenceDate,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('No authenticated user found.');
    }

    final periodStart = _periodStart(periodType, referenceDate ?? DateTime.now());

    final data = await _client.from('leaderboard_stats').select('''
          id,
          user_id,
          exam_id,
          period_type,
          period_start,
          period_end,
          total_points,
          total_net,
          solved_questions_count,
          correct_count,
          wrong_count,
          blank_count,
          mock_count,
          rank_position
        ''').eq('exam_id', examId).eq('period_type', periodType).eq(
          'period_start',
          periodStart.toIso8601String().split('T').first,
        ).eq('user_id', userId).maybeSingle();

    if (data == null) {
      return null;
    }

    final emailByUserId = await _profileEmailMap([userId]);

    return LeaderboardEntry.fromMap({
      ...data,
      'email': emailByUserId[userId],
    });
  }

  DateTime _periodStart(String periodType, DateTime referenceDate) {
    final normalized = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);

    switch (periodType) {
      case 'weekly':
        final weekdayOffset = normalized.weekday - DateTime.monday;
        return normalized.subtract(Duration(days: weekdayOffset));
      case 'monthly':
        return DateTime(normalized.year, normalized.month, 1);
      case 'all_time':
        return DateTime(1970, 1, 1);
      default:
        throw ArgumentError('Unsupported period type: $periodType');
    }
  }

  Future<Map<String, String?>> _profileEmailMap(List<String> userIds) async {
    if (userIds.isEmpty) {
      return const {};
    }

    final rows = await _client
        .from('profiles')
        .select('user_id, email')
        .inFilter('user_id', userIds);

    final map = <String, String?>{};
    for (final row in rows) {
      final item = Map<String, dynamic>.from(row);
      map[item['user_id'] as String] = item['email'] as String?;
    }

    return map;
  }
}
