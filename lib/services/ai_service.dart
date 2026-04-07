import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/ai_solution.dart';
import '../models/generated_question.dart';

class AiService {
  AiService();

  static Never _missingEnv(String key) {
    throw StateError('$key .env dosyasında tanımlı değil.');
  }

  Future<AiSolution> analyzeQuestionImage({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    const prompt = '''
Bu bir sınav sorusudur. Fotoğraftaki soruyu analiz et.
Sorunun konusunu belirle.
Adım adım çözüm üret.
Çözümü öğrenci seviyesinde açıkla.

Yanıtı mutlaka Türkçe ve şu formatta ver:
KONU: ...
ADIMLAR:
1. ...
2. ...
3. ...
SONUC: ...
''';

    final apiKey = dotenv.env['GOOGLE_API_KEY'] ?? _missingEnv('GOOGLE_API_KEY');
    final model = dotenv.env['GOOGLE_MODEL'] ?? 'gemini-2.5-flash';
    final baseUrl = (dotenv.env['GOOGLE_API_BASE_URL'] ?? 'https://generativelanguage.googleapis.com/v1').trim();
    final uri = Uri.parse(
      '$baseUrl/models/$model:generateContent?key=$apiKey',
    );

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Encode(imageBytes),
                },
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Gemini API hatası: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    final text = _extractText(candidates)?.trim();

    if (text == null || text.isEmpty) {
      throw StateError('AI cevabı alınamadı. Lütfen tekrar deneyin.');
    }

    return _parseSolution(text);
  }

  Future<GeneratedQuestion> generateQuestion({
    required String examName,
    required String subjectName,
    required String topicName,
    String difficulty = 'medium',
  }) async {
    final prompt = '''
Sen Türkiye'deki öğrenciler için sınav sorusu üreten uzman bir öğretmensin.

Sınav: $examName
Ders: $subjectName
Konu: $topicName
Zorluk: $difficulty

Bir adet özgün çoktan seçmeli soru üret.
5 seçenek olsun: A, B, C, D, E.
Tek bir doğru cevap olsun.
Sorunun dili Türkçe olsun.
Müfredata uygun olsun.

Yanıtı sadece geçerli JSON olarak ver:
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
''';

    final text = await _generateText(prompt);
    final normalized = text.trim();
    final jsonStart = normalized.indexOf('{');
    final jsonEnd = normalized.lastIndexOf('}');

    if (jsonStart == -1 || jsonEnd == -1 || jsonEnd <= jsonStart) {
      throw StateError('AI geçerli soru JSON çıkarmadı.');
    }

    final payload = normalized.substring(jsonStart, jsonEnd + 1);
    final decoded = jsonDecode(payload) as Map<String, dynamic>;
    return GeneratedQuestion.fromMap(decoded);
  }

  Future<String> _generateText(String prompt) async {
    final apiKey = dotenv.env['GOOGLE_API_KEY'] ?? _missingEnv('GOOGLE_API_KEY');
    final model = dotenv.env['GOOGLE_MODEL'] ?? 'gemini-2.5-flash';
    final baseUrl = (dotenv.env['GOOGLE_API_BASE_URL'] ?? 'https://generativelanguage.googleapis.com/v1').trim();
    final uri = Uri.parse('$baseUrl/models/$model:generateContent?key=$apiKey');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
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
      throw StateError('Gemini API hatası: ${response.statusCode} ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    final text = _extractText(candidates)?.trim();

    if (text == null || text.isEmpty) {
      throw StateError('AI cevabı alınamadı. Lütfen tekrar deneyin.');
    }

    return text;
  }

  String? _extractText(List<dynamic>? candidates) {
    if (candidates == null || candidates.isEmpty) {
      return null;
    }

    final first = candidates.first as Map<String, dynamic>;
    final content = first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      return null;
    }

    final buffer = StringBuffer();
    for (final part in parts) {
      final map = part as Map<String, dynamic>;
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

  AiSolution _parseSolution(String text) {
    final topic = _extractSection(text, 'KONU:', ['ADIMLAR:', 'SONUC:', 'SONUÇ:']) ?? 'Konu tespit edilemedi';
    final stepsRaw = _extractSection(text, 'ADIMLAR:', ['SONUC:', 'SONUÇ:']) ?? text;
    final result = _extractSection(text, 'SONUC:', []) ??
        _extractSection(text, 'SONUÇ:', []) ??
        'Sonuç bulunamadı';

    final steps = stepsRaw
        .split(RegExp(r'\n+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.replaceFirst(RegExp(r'^[-•\d\.\)\s]+'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return AiSolution(
      topic: topic.trim(),
      steps: steps.isEmpty ? [stepsRaw.trim()] : steps,
      result: result.trim(),
      fullText: text,
    );
  }

  String? _extractSection(String text, String startToken, List<String> endTokens) {
    final startIndex = text.indexOf(startToken);
    if (startIndex == -1) {
      return null;
    }

    final contentStart = startIndex + startToken.length;
    var endIndex = text.length;
    for (final token in endTokens) {
      final tokenIndex = text.indexOf(token, contentStart);
      if (tokenIndex != -1 && tokenIndex < endIndex) {
        endIndex = tokenIndex;
      }
    }

    return text.substring(contentStart, endIndex).trim();
  }
}
