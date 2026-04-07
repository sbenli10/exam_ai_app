import 'package:flutter/material.dart';

import '../models/exam_type.dart';
import '../models/study_topic.dart';
import '../services/exam_catalog_service.dart';
import '../services/question_service.dart';
import 'mock_exam_screen.dart';
import 'question_solver_screen.dart';

class TopicsScreen extends StatefulWidget {
  const TopicsScreen({
    super.key,
    required this.examType,
    this.initialSubjectId,
    this.initialTopicId,
  });

  final ExamType examType;
  final String? initialSubjectId;
  final String? initialTopicId;

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  final ExamCatalogService _examCatalogService = ExamCatalogService();
  final QuestionService _questionService = QuestionService();

  bool _isLoading = true;
  String? _errorMessage;
  List<StudySubject> _subjects = const [];
  Map<String, int> _questionCounts = const {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final examId = await _examCatalogService.resolveExamIdByTitle(widget.examType.title);
      if (examId == null) {
        setState(() {
          _errorMessage = 'Bu sınav için veritabanı kaydı bulunamadı.';
          _isLoading = false;
        });
        return;
      }

      final subjects = await _examCatalogService.fetchSubjects(examId);
      final enriched = <StudySubject>[];
      final topicIds = <String>[];

      for (final subject in subjects) {
        final topics = await _examCatalogService.fetchTopics(subject.id);
        topicIds.addAll(topics.map((topic) => topic.id));
        enriched.add(subject.copyWith(topics: topics));
      }

      final counts = await _questionService.fetchQuestionCountsByTopicIds(topicIds);

      if (!mounted) {
        return;
      }

      setState(() {
        _subjects = enriched;
        _questionCounts = counts;
        _isLoading = false;
      });

      _openInitialTopicIfNeeded(enriched);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Konular yüklenirken bir hata oluştu.';
        _isLoading = false;
      });
    }
  }

  void _openTopic(BuildContext context, StudySubject subject, StudyTopic topic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionSolverScreen(
          examType: widget.examType,
          subjectId: subject.id,
          topicId: topic.id,
          subjectName: subject.name,
          topicName: topic.name,
        ),
      ),
    );
  }

  void _openInitialTopicIfNeeded(List<StudySubject> subjects) {
    final initialSubjectId = widget.initialSubjectId;
    final initialTopicId = widget.initialTopicId;
    if (initialSubjectId == null || initialTopicId == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      for (final subject in subjects) {
        if (subject.id != initialSubjectId) {
          continue;
        }

        for (final topic in subject.topics) {
          if (topic.id == initialTopicId) {
            _openTopic(context, subject, topic);
            return;
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('${widget.examType.title} Konuları'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF6F7FB), Color(0xFFF2F5FA), Color(0xFFEEF2F7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
            _TopicsHeroCard(examTitle: widget.examType.title),
            const SizedBox(height: 18),
            if (_isLoading)
              const _TopicsInfoCard(
                title: 'Konular yükleniyor',
                message: 'Ders ve konu verileri Supabase üzerinden çekiliyor.',
              )
            else if (_errorMessage != null)
              _TopicsActionCard(
                title: 'Veri alinamadi',
                message: _errorMessage!,
                actionLabel: 'Tekrar Dene',
                onTap: _loadData,
              )
            else if (_subjects.isEmpty)
              _TopicsActionCard(
                title: 'Ders bulunamadi',
                message: 'Bu sınav için önce exams, subjects ve topics tablolarını doldurman gerekiyor.',
                actionLabel: 'Yenile',
                onTap: _loadData,
              )
            else
              ..._subjects.map(
                (subject) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _SubjectSection(
                    subject: subject,
                    questionCounts: _questionCounts,
                    examType: widget.examType,
                    onOpenTopic: (topic) => _openTopic(context, subject, topic),
                    onStartMock: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MockExamScreen(
                            examType: widget.examType,
                            subjectId: subject.id,
                            subjectName: subject.name,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
          ),
        ),
      ),
    );
  }
}

class _TopicsHeroCard extends StatelessWidget {
  const _TopicsHeroCard({
    required this.examTitle,
  });

  final String examTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF101828), Color(0xFF163B63), Color(0xFF1F7A72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Konu seçimi',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.78),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '$examTitle odak alanları',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gereksiz kalabalığı kaldırdım. Önce konunu seç, sonra hızlı test ya da mini deneme ile ilerle.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.86),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _SubjectSection extends StatelessWidget {
  const _SubjectSection({
    required this.subject,
    required this.questionCounts,
    required this.examType,
    required this.onOpenTopic,
    required this.onStartMock,
  });

  final StudySubject subject;
  final Map<String, int> questionCounts;
  final ExamType examType;
  final ValueChanged<StudyTopic> onOpenTopic;
  final VoidCallback onStartMock;

  @override
  Widget build(BuildContext context) {
    return _TopicsSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subject.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF111827),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: onStartMock,
                icon: const Icon(Icons.timer_rounded),
                label: const Text('Mini deneme'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (subject.topics.isEmpty)
            Text(
              'Bu ders için konu kaydı bulunamadı.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
            )
          else
            ...subject.topics.map(
              (topic) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TopicTile(
                  topic: topic,
                  examType: examType,
                  subject: subject,
                  questionCount: questionCounts[topic.id] ?? 0,
                  onOpenTopic: () => onOpenTopic(topic),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({
    required this.topic,
    required this.examType,
    required this.subject,
    required this.questionCount,
    required this.onOpenTopic,
  });

  final StudyTopic topic;
  final ExamType examType;
  final StudySubject subject;
  final int questionCount;
  final VoidCallback onOpenTopic;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpenTopic,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE7ECF3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Color(0xFF4054C8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF111827),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _topicStatusLabel(questionCount),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF64748B),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF64748B),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      questionCount == 0
                          ? 'Bu konu için soru havuzu yakında hazır olacak'
                          : 'Konu testini aç, ritmini koru ve ilerlemeyi kaydet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  FilledButton(
                    onPressed: questionCount == 0 ? null : onOpenTopic,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3F51B5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Teste Gir'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _topicStatusLabel(int questionCount) {
  if (questionCount >= 40) {
    return 'Zengin soru havuzu';
  }
  if (questionCount >= 20) {
    return 'Hazır konu seti';
  }
  if (questionCount > 0) {
    return 'Açık mini set';
  }
  return 'Hazırlanıyor';
}

class _TopicsInfoCard extends StatelessWidget {
  const _TopicsInfoCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _TopicsSurface(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _TopicsActionCard extends StatelessWidget {
  const _TopicsActionCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return _TopicsSurface(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              onTap();
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _TopicsSurface extends StatelessWidget {
  const _TopicsSurface({
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.86)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.05),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}
