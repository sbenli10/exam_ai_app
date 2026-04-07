import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mentor_insight.dart';
import '../models/topic_attempt_stat.dart';

class MentorService {
  MentorService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<MentorInsight?> fetchLatestInsight() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }

    try {
      final row = await _client
          .from('ai_analysis')
          .select('weak_topics, recommendation, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) {
        return null;
      }

      return MentorInsight.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  Future<MentorInsight> getOrCreateInsight({
    required String examTitle,
    required String nickname,
    required int todayPoints,
    required int weeklyPoints,
    required double weeklyNet,
    required int streak,
    required List<TopicAttemptStat> topicStats,
    required Map<String, String> topicNamesById,
  }) async {
    final latest = await fetchLatestInsight();
    final now = DateTime.now();
    if (latest != null && now.difference(latest.createdAt).inHours < 12) {
      return latest;
    }

    final weakTopics = topicStats
        .where((stat) => stat.totalAttemptCount >= 3)
        .toList()
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));

    final weakTopicNames = weakTopics
        .take(3)
        .map((stat) => topicNamesById[stat.topicId])
        .whereType<String>()
        .toList();

    final recommendation = await _generateRecommendation(
      examTitle: examTitle,
      nickname: nickname,
      todayPoints: todayPoints,
      weeklyPoints: weeklyPoints,
      weeklyNet: weeklyNet,
      streak: streak,
      weakTopics: weakTopicNames,
    );

    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await _client.from('ai_analysis').insert({
          'user_id': userId,
          'weak_topics': weakTopicNames,
          'recommendation': recommendation,
        });
      } catch (_) {
        // Dashboard should still render even if ai_analysis RLS is not ready.
      }
    }

    return MentorInsight(
      recommendation: recommendation,
      weakTopics: weakTopicNames,
      createdAt: now,
    );
  }

  Future<String> _generateRecommendation({
    required String examTitle,
    required String nickname,
    required int todayPoints,
    required int weeklyPoints,
    required double weeklyNet,
    required int streak,
    required List<String> weakTopics,
  }) async {
    final apiKey = dotenv.env['GOOGLE_API_KEY'];
    final model = dotenv.env['GOOGLE_MODEL'] ?? 'gemini-2.5-flash';
    final baseUrl = dotenv.env['GOOGLE_API_BASE_URL'] ?? 'https://generativelanguage.googleapis.com/v1';

    if (apiKey == null || apiKey.isEmpty) {
      return _fallbackRecommendation(weakTopics);
    }

    final uri = Uri.parse('$baseUrl/models/$model:generateContent?key=$apiKey');
    final prompt = '''
Sen Exam AI uygulamasında öğrenciye mentor olan bir koçsun.

Sınav: $examTitle
Öğrenci: $nickname
Bugünkü puan: $todayPoints
Haftalık puan: $weeklyPoints
Haftalık net: ${weeklyNet.toStringAsFixed(2)}
Seri: $streak gün
Zayıf konular: ${weakTopics.isEmpty ? 'Belirgin veri yok' : weakTopics.join(', ')}

Türkçe ve motive edici tek paragraf öner.
Öğrenciye bugün ne yapması gerektiğini somut şekilde söyle.
Maksimum 45 kelime kullan.
''';

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _fallbackRecommendation(weakTopics);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>?;
      final first = candidates == null || candidates.isEmpty
          ? null
          : Map<String, dynamic>.from(candidates.first as Map);
      final content = first?['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      final text = parts == null || parts.isEmpty
          ? null
          : Map<String, dynamic>.from(parts.first as Map)['text'] as String?;

      return (text == null || text.trim().isEmpty)
          ? _fallbackRecommendation(weakTopics)
          : text.trim();
    } catch (_) {
      return _fallbackRecommendation(weakTopics);
    }
  }

  String _fallbackRecommendation(List<String> weakTopics) {
    if (weakTopics.isEmpty) {
      return 'Bugün paragraf ve problemlerle ritmini koru, ardından mini denemeyle günü kapat. Seri korundukça puanın daha hızlı yükselecek.';
    }

    return '${weakTopics.first} konusunda tekrar yap, sonra hızlı bir mini test çöz. Bugün doğru soru sayını artırman haftalık puanını öne taşıyacak.';
  }
}
