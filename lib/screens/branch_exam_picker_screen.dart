import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/exam_type.dart';
import '../models/study_topic.dart';
import '../services/exam_catalog_service.dart';
import '../services/question_service.dart';
import 'mock_exam_screen.dart';

class BranchExamPickerScreen extends StatefulWidget {
  const BranchExamPickerScreen({
    super.key,
    required this.examType,
  });

  final ExamType examType;

  @override
  State<BranchExamPickerScreen> createState() => _BranchExamPickerScreenState();
}

class _BranchExamPickerScreenState extends State<BranchExamPickerScreen> {
  final ExamCatalogService _catalogService = ExamCatalogService();
  final QuestionService _questionService = QuestionService();

  bool _isLoading = true;
  String? _error;
  List<StudySubject> _subjects = const [];
  Map<String, int> _counts = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final examId = await _catalogService.resolveExamIdByTitle(widget.examType.title);
      if (examId == null) {
        setState(() {
          _error = 'Sınav kaydı bulunamadı.';
          _isLoading = false;
        });
        return;
      }

      final subjects = await _catalogService.fetchSubjects(examId);
      final enriched = <StudySubject>[];
      final topicIds = <String>[];
      for (final subject in subjects) {
        final topics = await _catalogService.fetchTopics(subject.id);
        topicIds.addAll(topics.map((topic) => topic.id));
        enriched.add(subject.copyWith(topics: topics));
      }

      final counts = await _questionService.fetchQuestionCountsByTopicIds(topicIds);

      if (!mounted) return;
      setState(() {
        _subjects = enriched;
        _counts = counts;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Branş denemeleri yüklenemedi.';
        _isLoading = false;
      });
    }
  }

  int _subjectQuestionCount(StudySubject subject) {
    var total = 0;
    for (final topic in subject.topics) {
      total += _counts[topic.id] ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Branş Denemesi'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              const _BranchHeroCard(),
              const SizedBox(height: 18),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Center(child: Text(_error!))
              else
                ..._subjects.map((subject) {
                  final total = _subjectQuestionCount(subject);
                  if (total == 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BranchRow(
                      title: subject.name,
                      subtitle: '$total onaylı soru ile branş denemesi',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MockExamScreen(
                              examType: widget.examType,
                              subjectId: subject.id,
                              subjectName: subject.name,
                              questionCount: 15,
                              mockTypeOverride: 'branch',
                              titleOverride: '${subject.name} Branş Denemesi',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchHeroCard extends StatelessWidget {
  const _BranchHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bir dersi baştan sona yokla',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Branş denemesi ile tek bir dersteki genel ritmini, hata yoğunluğunu ve net potansiyelini daha net gör.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF475569),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _BranchRow extends StatelessWidget {
  const _BranchRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x100F172A),
              blurRadius: 28,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.square_list_fill,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
