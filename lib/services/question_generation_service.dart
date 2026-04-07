import 'package:supabase_flutter/supabase_flutter.dart';

class QuestionGenerationService {
  QuestionGenerationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> generateQuestions({
    required String examId,
    required String subjectId,
    required String topicId,
    required String difficulty,
    required String questionStyle,
    required String measurementFocus,
    required int targetCount,
    int batchSize = 10,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw StateError(
        'Soru üretmek için tekrar giriş yapman gerekiyor. Oturum bulunamadı.',
      );
    }

    await _client.auth.refreshSession();

    final response = await _client.functions.invoke(
      'generate-questions',
      body: {
        'exam_id': examId,
        'subject_id': subjectId,
        'topic_id': topicId,
        'difficulty': difficulty,
        'question_style': questionStyle,
        'measurement_focus': measurementFocus,
        'target_count': targetCount,
        'batch_size': batchSize,
      },
    );

    if (response.status < 200 || response.status >= 300) {
      final details = '${response.data}';
      if (response.status == 401 || details.contains('Invalid JWT')) {
        throw StateError(
          'Oturum doğrulaması başarısız oldu. Lütfen çıkış yapıp tekrar giriş yap ve yeniden dene.',
        );
      }
      throw StateError('Soru üretimi başarısız oldu: $details');
    }

    final data = response.data;
    if (data is! Map) {
      throw StateError('Fonksiyon beklenen veri formatını döndürmedi.');
    }

    return Map<String, dynamic>.from(data);
  }

  Future<void> approveQuestions({
    required List<String> questionIds,
    required String subjectId,
    required String topicId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError(
        'Onay işlemi için giriş yapmış bir kullanıcı gerekli.',
      );
    }

    await _client.auth.refreshSession();

    if (questionIds.isEmpty) {
      return;
    }

    await _client
        .from('questions')
        .update({
          'is_verified': true,
          'verified_by': userId,
          'verified_at': DateTime.now().toIso8601String(),
        })
        .inFilter('id', questionIds)
        .eq('subject_id', subjectId)
        .eq('topic_id', topicId);
  }

  Future<void> deleteDraftQuestion(String questionId) async {
    await _client.auth.refreshSession();
    await _client.from('question_options').delete().eq('question_id', questionId);
    await _client.from('questions').delete().eq('id', questionId);
  }
}
