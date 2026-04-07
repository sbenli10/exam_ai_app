import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main() async {
  final env = await _loadEnv('.env');
  final config = _RunnerConfig.fromEnv(env);
  final runner = QuestionGenerationJobRunner(config);

  await runner.run();
}

class QuestionGenerationJobRunner {
  QuestionGenerationJobRunner(this.config);

  final _RunnerConfig config;
  static const _maxRequestAttempts = 3;

  Future<void> run() async {
    final jobs = await _fetchPendingJobs();
    if (jobs.isEmpty) {
      stdout.writeln('No pending question generation jobs found.');
      return;
    }

    for (final job in jobs) {
      await _processJob(job);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPendingJobs() async {
    final uri = config.restUri(
      '/question_generation_jobs'
      '?select=id,exam_id,subject_id,topic_id,section_name,difficulty,question_style,'
      'target_count,batch_size,generated_count,inserted_count,duplicate_count,failed_count,'
      'status,prompt_version,notes,'
      'subjects(name),topics(name),exams(name)'
      '&status=eq.pending'
      '&order=created_at.asc',
    );

    final response = await _requestWithRetry(
      () => http.get(uri, headers: config.supabaseHeaders),
    );
    _ensureSuccess(response, 'Failed to fetch generation jobs');

    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> _processJob(Map<String, dynamic> job) async {
    final jobId = job['id'] as String;
    stdout.writeln('Processing job: $jobId');

    await _updateJob(jobId, {
      'status': 'running',
      'started_at': DateTime.now().toIso8601String(),
      'last_error': null,
    });

    try {
      final targetCount = (job['target_count'] as num).toInt();
      final batchSize = (job['batch_size'] as num).toInt();
      final generatedCount = (job['generated_count'] as num?)?.toInt() ?? 0;
      final remaining = targetCount - generatedCount;

      if (remaining <= 0) {
        await _updateJob(jobId, {
          'status': 'completed',
          'completed_at': DateTime.now().toIso8601String(),
        });
        return;
      }

      final requestedCount = remaining < batchSize ? remaining : batchSize;
      final prompt = _buildPrompt(job, requestedCount);
      final generatedQuestions = await _generateQuestions(prompt);

      var insertedCount = 0;
      var duplicateCount = 0;
      var failedCount = 0;

      for (final question in generatedQuestions) {
        final normalizedStem = _normalizeStem(question.questionText);
        final exists = await _questionExists(normalizedStem, job['topic_id'] as String);

        if (exists) {
          duplicateCount += 1;
          continue;
        }

        try {
          await _insertQuestion(job, question, normalizedStem);
          insertedCount += 1;
        } catch (_) {
          failedCount += 1;
        }
      }

      final totalGenerated = generatedCount + generatedQuestions.length;
      final totalInserted = ((job['inserted_count'] as num?)?.toInt() ?? 0) + insertedCount;
      final totalDuplicates = ((job['duplicate_count'] as num?)?.toInt() ?? 0) + duplicateCount;
      final totalFailed = ((job['failed_count'] as num?)?.toInt() ?? 0) + failedCount;

      await _updateJob(jobId, {
        'generated_count': totalGenerated,
        'inserted_count': totalInserted,
        'duplicate_count': totalDuplicates,
        'failed_count': totalFailed,
        'status': totalGenerated >= targetCount ? 'completed' : 'pending',
        'completed_at': totalGenerated >= targetCount ? DateTime.now().toIso8601String() : null,
      });
    } catch (error) {
      await _updateJob(jobId, {
        'status': 'failed',
        'last_error': error.toString(),
        'completed_at': DateTime.now().toIso8601String(),
      });
    }
  }

  String _buildPrompt(Map<String, dynamic> job, int requestedCount) {
    final examName = (job['exams'] as Map<String, dynamic>)['name'] as String? ?? '';
    final subjectName = (job['subjects'] as Map<String, dynamic>)['name'] as String? ?? '';
    final topicName = (job['topics'] as Map<String, dynamic>)['name'] as String? ?? '';
    final sectionName = job['section_name'] as String? ?? '';
    final difficulty = job['difficulty'] as String? ?? 'medium';
    final questionStyle = job['question_style'] as String? ?? 'standard';

    return '''
Sen Turkiye'deki ogrenciler icin ozgun sinav sorulari ureten uzman bir ogretmensin.

Sinav: $examName
Bolum: $sectionName
Ders: $subjectName
Konu: $topicName
Zorluk: $difficulty
Soru Stili: $questionStyle

Birbirinden farkli $requestedCount adet coktan secmeli soru uret.
Her soru 5 secenekli olsun: A, B, C, D, E.
Tek bir dogru cevap olsun.
Sorular tamamen ozgun olsun.
Bilinen cikmis sorulari kopyalama veya yakin turevlerini verme.
Sorular Turkce olsun.
Mufredata uygun olsun.

Yaniti sadece JSON array olarak ver:
[
  {
    "question_text": "...",
    "option_a": "...",
    "option_b": "...",
    "option_c": "...",
    "option_d": "...",
    "option_e": "...",
    "correct_answer": "A",
    "difficulty": "$difficulty"
  }
]
''';
  }

  Future<List<_GeneratedQuestion>> _generateQuestions(String prompt) async {
    final uri = Uri.parse(
      '${config.googleApiBaseUrl}/models/${config.googleModel}:generateContent?key=${config.googleApiKey}',
    );

    final response = await _requestWithRetry(
      () => http.post(
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
      ),
    );

    _ensureSuccess(response, 'Gemini generation failed');

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    final text = _extractText(candidates);

    if (text == null || text.trim().isEmpty) {
      throw StateError('Gemini returned empty content.');
    }

    final normalized = text.trim();
    final start = normalized.indexOf('[');
    final end = normalized.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) {
      throw StateError('Gemini did not return a valid JSON array.');
    }

    final payload = normalized.substring(start, end + 1);
    final items = _decodeQuestionArray(payload);

    return items
        .map((item) => _GeneratedQuestion.fromMap(Map<String, dynamic>.from(item as Map)))
        .where((question) => question.isValid)
        .toList();
  }

  List<dynamic> _decodeQuestionArray(String payload) {
    try {
      return jsonDecode(payload) as List<dynamic>;
    } on FormatException {
      final sanitizedPayload = _sanitizeJsonPayload(payload);
      return jsonDecode(sanitizedPayload) as List<dynamic>;
    }
  }

  String _sanitizeJsonPayload(String payload) {
    final buffer = StringBuffer();
    for (var index = 0; index < payload.length; index += 1) {
      final char = payload[index];
      if (char != r'\') {
        buffer.write(char);
        continue;
      }

      if (index + 1 >= payload.length) {
        buffer.write(r'\\');
        continue;
      }

      final next = payload[index + 1];
      const validEscapes = {'"', r'\', '/', 'b', 'f', 'n', 'r', 't', 'u'};
      if (validEscapes.contains(next)) {
        buffer.write(char);
        continue;
      }

      // Gemini bazen JSON icinde \alpha gibi gecersiz kacislar donduruyor.
      // Bu durumda ters slash'i kacislayip metni oldugu gibi koruyoruz.
      buffer.write(r'\\');
    }

    return buffer.toString();
  }

  Future<bool> _questionExists(String normalizedStem, String topicId) async {
    final uri = config.restUri(
      '/questions?select=id&topic_id=eq.$topicId&normalized_stem=eq.${Uri.encodeComponent(normalizedStem)}&limit=1',
    );

    final response = await _requestWithRetry(
      () => http.get(uri, headers: config.supabaseHeaders),
    );
    _ensureSuccess(response, 'Failed to check duplicate question');

    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.isNotEmpty;
  }

  Future<void> _insertQuestion(
    Map<String, dynamic> job,
    _GeneratedQuestion question,
    String normalizedStem,
  ) async {
    final insertUri = config.restUri('/questions');
    final insertResponse = await _requestWithRetry(
      () => http.post(
        insertUri,
        headers: config.supabaseHeadersReturning,
        body: jsonEncode({
          'exam_id': job['exam_id'],
          'subject_id': job['subject_id'],
          'topic_id': job['topic_id'],
          'question_text': question.questionText,
          'option_a': question.optionA,
          'option_b': question.optionB,
          'option_c': question.optionC,
          'option_d': question.optionD,
          'option_e': question.optionE,
          'correct_answer': question.correctAnswer,
          'difficulty': question.difficulty,
          'normalized_stem': normalizedStem,
        }),
      ),
    );

    _ensureSuccess(insertResponse, 'Failed to insert question');

    final insertedRows = jsonDecode(insertResponse.body) as List<dynamic>;
    final insertedQuestion = Map<String, dynamic>.from(insertedRows.first as Map);
    final questionId = insertedQuestion['id'] as String;

    final optionsUri = config.restUri('/question_options');
    final optionsResponse = await _requestWithRetry(
      () => http.post(
        optionsUri,
        headers: config.supabaseHeaders,
        body: jsonEncode([
          {'question_id': questionId, 'option_key': 'A', 'option_text': question.optionA},
          {'question_id': questionId, 'option_key': 'B', 'option_text': question.optionB},
          {'question_id': questionId, 'option_key': 'C', 'option_text': question.optionC},
          {'question_id': questionId, 'option_key': 'D', 'option_text': question.optionD},
          {'question_id': questionId, 'option_key': 'E', 'option_text': question.optionE},
        ]),
      ),
    );

    _ensureSuccess(optionsResponse, 'Failed to insert question options');
  }

  Future<void> _updateJob(String jobId, Map<String, dynamic> payload) async {
    final uri = config.restUri('/question_generation_jobs?id=eq.$jobId');
    final response = await _requestWithRetry(
      () => http.patch(
        uri,
        headers: config.supabaseHeaders,
        body: jsonEncode(payload),
      ),
    );

    _ensureSuccess(response, 'Failed to update job');
  }

  Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() request,
  ) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxRequestAttempts; attempt += 1) {
      try {
        return await request();
      } on SocketException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      }

      if (attempt < _maxRequestAttempts) {
        final delay = Duration(seconds: attempt * 2);
        stderr.writeln(
          'Ag hatasi, ${delay.inSeconds} sn sonra tekrar denenecek '
          '($attempt/$_maxRequestAttempts).',
        );
        await Future<void>.delayed(delay);
      }
    }

    throw StateError('Istek tamamlanamadi: $lastError');
  }

  String _normalizeStem(String stem) {
    return stem
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9A-Z\s]'), '')
        .trim();
  }

  String? _extractText(List<dynamic>? candidates) {
    if (candidates == null || candidates.isEmpty) {
      return null;
    }

    final first = Map<String, dynamic>.from(candidates.first as Map);
    final content = first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null) {
      return null;
    }

    final buffer = StringBuffer();
    for (final part in parts) {
      final map = Map<String, dynamic>.from(part as Map);
      final text = map['text'] as String?;
      if (text != null && text.isNotEmpty) {
        if (buffer.isNotEmpty) {
          buffer.writeln();
        }
        buffer.write(text);
      }
    }

    return buffer.isEmpty ? null : buffer.toString();
  }

  void _ensureSuccess(http.Response response, String message) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('$message: ${response.statusCode} ${response.body}');
    }
  }
}

class _RunnerConfig {
  const _RunnerConfig({
    required this.supabaseUrl,
    required this.supabaseServiceRoleKey,
    required this.googleApiKey,
    required this.googleModel,
    required this.googleApiBaseUrl,
  });

  final String supabaseUrl;
  final String supabaseServiceRoleKey;
  final String googleApiKey;
  final String googleModel;
  final String googleApiBaseUrl;

  factory _RunnerConfig.fromEnv(Map<String, String> env) {
    String requireValue(String key) {
      final value = env[key];
      if (value == null || value.isEmpty) {
        throw StateError('$key is required for question generation job runner.');
      }
      return value;
    }

    return _RunnerConfig(
      supabaseUrl: requireValue('SUPABASE_URL'),
      supabaseServiceRoleKey: requireValue('SUPABASE_SERVICE_ROLE_KEY'),
      googleApiKey: requireValue('GOOGLE_API_KEY'),
      googleModel: env['GOOGLE_MODEL'] ?? 'gemini-2.5-flash',
      googleApiBaseUrl: env['GOOGLE_API_BASE_URL'] ?? 'https://generativelanguage.googleapis.com/v1',
    );
  }

  Uri restUri(String path) {
    return Uri.parse('$supabaseUrl/rest/v1$path');
  }

  Map<String, String> get supabaseHeaders => {
        'apikey': supabaseServiceRoleKey,
        'Authorization': 'Bearer $supabaseServiceRoleKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal',
      };

  Map<String, String> get supabaseHeadersReturning => {
        'apikey': supabaseServiceRoleKey,
        'Authorization': 'Bearer $supabaseServiceRoleKey',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };
}

class _GeneratedQuestion {
  const _GeneratedQuestion({
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.optionE,
    required this.correctAnswer,
    required this.difficulty,
  });

  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String optionE;
  final String correctAnswer;
  final String difficulty;

  bool get isValid {
    return questionText.isNotEmpty &&
        optionA.isNotEmpty &&
        optionB.isNotEmpty &&
        optionC.isNotEmpty &&
        optionD.isNotEmpty &&
        optionE.isNotEmpty &&
        ['A', 'B', 'C', 'D', 'E'].contains(correctAnswer);
  }

  factory _GeneratedQuestion.fromMap(Map<String, dynamic> map) {
    return _GeneratedQuestion(
      questionText: (map['question_text'] as String? ?? '').trim(),
      optionA: (map['option_a'] as String? ?? '').trim(),
      optionB: (map['option_b'] as String? ?? '').trim(),
      optionC: (map['option_c'] as String? ?? '').trim(),
      optionD: (map['option_d'] as String? ?? '').trim(),
      optionE: (map['option_e'] as String? ?? '').trim(),
      correctAnswer: (map['correct_answer'] as String? ?? '').trim(),
      difficulty: (map['difficulty'] as String? ?? 'medium').trim(),
    );
  }
}

Future<Map<String, String>> _loadEnv(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    return {};
  }

  final lines = await file.readAsLines();
  final env = <String, String>{};
  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#') || !line.contains('=')) {
      continue;
    }

    final index = line.indexOf('=');
    final key = line.substring(0, index).trim();
    final value = line.substring(index + 1).trim();
    env[key] = value;
  }

  return env;
}
