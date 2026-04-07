import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/exam_type.dart';
import '../models/study_topic.dart';
import '../services/exam_catalog_service.dart';
import '../services/question_service.dart';
import 'mock_exam_screen.dart';

class TopicExamPickerScreen extends StatefulWidget {
  const TopicExamPickerScreen({
    super.key,
    required this.examType,
  });

  final ExamType examType;

  @override
  State<TopicExamPickerScreen> createState() => _TopicExamPickerScreenState();
}

class _TopicExamPickerScreenState extends State<TopicExamPickerScreen> {
  final ExamCatalogService _catalogService = ExamCatalogService();
  final QuestionService _questionService = QuestionService();

  bool _isLoading = true;
  String? _error;
  List<StudySubject> _subjects = const [];
  Map<String, int> _questionCounts = const {};

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
        _questionCounts = counts;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Konu denemeleri yüklenemedi.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Konu Denemesi'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              const _PickerHeroCard(
                title: 'Tek konuya odaklan',
                subtitle:
                    'Her konu için kısa ama ölçücü bir deneme başlat ve eksiklerini daha net gör.',
              ),
              const SizedBox(height: 18),
              if (_isLoading)
                const _PickerStateCard(message: 'Konular hazırlanıyor...')
              else if (_error != null)
                _PickerErrorCard(message: _error!, onRetry: _load)
              else
                ..._subjects.map((subject) {
                  final topics = subject.topics
                      .where((topic) => (_questionCounts[topic.id] ?? 0) > 0)
                      .toList();
                  if (topics.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _PickerSection(
                      title: subject.name,
                      children: topics.map((topic) {
                        final count = _questionCounts[topic.id] ?? 0;
                        return _ActionRowCard(
                          title: topic.name,
                          subtitle: '$count onaylı soru ile konu denemesi',
                          icon: CupertinoIcons.scope,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MockExamScreen(
                                  examType: widget.examType,
                                  subjectId: subject.id,
                                  topicId: topic.id,
                                  subjectName: subject.name,
                                  topicName: topic.name,
                                  questionCount: 10,
                                  mockTypeOverride: 'mini',
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
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

class _PickerHeroCard extends StatelessWidget {
  const _PickerHeroCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

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
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
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

class _PickerStateCard extends StatelessWidget {
  const _PickerStateCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _PickerErrorCard extends StatelessWidget {
  const _PickerErrorCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }
}

class _PickerSection extends StatelessWidget {
  const _PickerSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ActionRowCard extends StatelessWidget {
  const _ActionRowCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
              const Icon(
                CupertinoIcons.chevron_right,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
