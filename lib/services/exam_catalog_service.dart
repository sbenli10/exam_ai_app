import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exam_type.dart';
import '../models/study_topic.dart';

class ExamCatalogService {
  ExamCatalogService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const Map<String, Map<String, List<String>>> _defaultCurriculum = {
    'YKS': {
      'Türkçe': ['Paragraf', 'Cümlede Anlam', 'Sözcükte Anlam'],
      'Matematik': ['Fonksiyonlar', 'Limit', 'Türev', 'Problemler'],
      'Fizik': ['Hareket', 'Kuvvet ve Enerji', 'Elektrik'],
      'Kimya': ['Mol', 'Kimyasal Tepkimeler', 'Çözeltiler'],
    },
    'LGS': {
      'Türkçe': ['Paragraf', 'Sözel Mantık', 'Fiilimsi'],
      'Matematik': ['Çarpanlar ve Katlar', 'Üslü İfadeler', 'Cebirsel İfadeler'],
      'Fen Bilimleri': ['Mevsimler ve İklim', 'DNA ve Genetik Kod', 'Basınç'],
      'İngilizce': ['Friendship', 'Teen Life', 'Cooking'],
    },
    'KPSS': {
      'Genel Yetenek': ['Türkçe', 'Matematik', 'Mantık'],
      'Genel Kültür': ['Tarih', 'Coğrafya', 'Vatandaşlık'],
      'Eğitim Bilimleri': ['Gelişim Psikolojisi', 'Ölçme ve Değerlendirme', 'Program Geliştirme'],
    },
    'ALES': {
      'Sayısal': ['Problemler', 'Temel Kavramlar', 'Grafik Yorumlama'],
      'Sözel': ['Paragraf', 'Anlam Bilgisi', 'Sözel Akıl Yürütme'],
      'Mantık': ['Şekil Mantığı', 'Tablo Yorumlama', 'Karşılaştırma'],
    },
  };

  List<ExamType> getExamTypes() {
    return ExamType.all;
  }

  Future<String?> resolveExamIdByTitle(String title) async {
    final existing = await _client
        .from('exams')
        .select('id')
        .eq('name', title)
        .maybeSingle();

    if (existing != null) {
      return existing['id'] as String?;
    }

    final inserted = await _client
        .from('exams')
        .insert({
          'name': title,
          'description': '$title sınavı için otomatik oluşturulan kayıt',
        })
        .select('id')
        .single();

    return inserted['id'] as String?;
  }

  Future<List<StudySubject>> fetchSubjects(String examId) async {
    var rows = await _client
        .from('subjects')
        .select()
        .eq('exam_id', examId)
        .order('name');

    if (rows.isEmpty) {
      await _seedDefaultCurriculumForExam(examId);
      rows = await _client
          .from('subjects')
          .select()
          .eq('exam_id', examId)
          .order('name');
    }

    return rows
        .map<StudySubject>((row) => StudySubject.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<StudyTopic>> fetchTopics(String subjectId) async {
    var rows = await _client
        .from('topics')
        .select()
        .eq('subject_id', subjectId)
        .order('name');

    if (rows.isEmpty) {
      await _seedMissingTopicsForSubject(subjectId);
      rows = await _client
          .from('topics')
          .select()
          .eq('subject_id', subjectId)
          .order('name');
    }

    return rows
        .map<StudyTopic>((row) => StudyTopic.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> _seedDefaultCurriculumForExam(String examId) async {
    final examRow = await _client
        .from('exams')
        .select('name')
        .eq('id', examId)
        .maybeSingle();

    final examName = examRow?['name'] as String?;
    final curriculum = _defaultCurriculum[examName];

    if (examName == null || curriculum == null) {
      return;
    }

    for (final entry in curriculum.entries) {
      final subjectData = await _client
          .from('subjects')
          .insert({
            'exam_id': examId,
            'name': entry.key,
          })
          .select('id')
          .single();

      final subjectId = subjectData['id'] as String;
      final topicRows = entry.value
          .map(
            (topicName) => {
              'subject_id': subjectId,
              'name': topicName,
            },
          )
          .toList();

      await _client.from('topics').insert(topicRows);
    }
  }

  Future<void> _seedMissingTopicsForSubject(String subjectId) async {
    final subjectRow = await _client
        .from('subjects')
        .select('name, exam_id')
        .eq('id', subjectId)
        .maybeSingle();

    if (subjectRow == null) {
      return;
    }

    final examId = subjectRow['exam_id'] as String?;
    final subjectName = subjectRow['name'] as String?;
    if (examId == null || subjectName == null) {
      return;
    }

    final examRow = await _client
        .from('exams')
        .select('name')
        .eq('id', examId)
        .maybeSingle();

    final examName = examRow?['name'] as String?;
    final curriculum = _defaultCurriculum[examName];
    final topicNames = curriculum?[subjectName];

    if (topicNames == null || topicNames.isEmpty) {
      return;
    }

    final topicRows = topicNames
        .map(
          (topicName) => {
            'subject_id': subjectId,
            'name': topicName,
          },
        )
        .toList();

    await _client.from('topics').insert(topicRows);
  }
}
