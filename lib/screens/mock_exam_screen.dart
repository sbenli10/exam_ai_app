import 'package:flutter/material.dart';

import '../models/exam_type.dart';
import '../models/question.dart';
import '../services/ai_analysis_service.dart';
import '../services/exam_catalog_service.dart';
import '../services/question_service.dart';

class MockExamScreen extends StatefulWidget {
  const MockExamScreen({
    super.key,
    required this.examType,
    this.subjectId,
    this.topicId,
    this.subjectName,
    this.topicName,
    this.questionCount = 12,
    this.titleOverride,
    this.mockTypeOverride,
  });

  final ExamType examType;
  final String? subjectId;
  final String? topicId;
  final String? subjectName;
  final String? topicName;
  final int questionCount;
  final String? titleOverride;
  final String? mockTypeOverride;

  @override
  State<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends State<MockExamScreen> {
  final ExamCatalogService _examCatalogService = ExamCatalogService();
  final QuestionService _questionService = QuestionService();

  String? _examId;
  List<Question> _questions = const [];
  final Map<int, String> _selectedAnswers = {};
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCompleted = false;
  String? _errorMessage;
  late DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _loadMock();
  }

  Future<void> _loadMock() async {
    setState(() {
      _isLoading = true;
      _isCompleted = false;
      _errorMessage = null;
      _currentIndex = 0;
      _startedAt = DateTime.now();
      _selectedAnswers.clear();
    });

    try {
      final examId = await _examCatalogService.resolveExamIdByTitle(widget.examType.title);
      if (examId == null) {
        setState(() {
          _errorMessage = 'Deneme oluşturulurken sınav kaydı bulunamadı.';
          _isLoading = false;
        });
        return;
      }

      final questions = await _questionService.fetchQuestions(
        examId: examId,
        subjectId: widget.subjectId,
        topicId: widget.topicId,
        limit: widget.questionCount,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _examId = examId;
        _questions = questions;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Deneme soruları yüklenemedi.';
        _isLoading = false;
      });
    }
  }

  Future<void> _finishMock() async {
    if (_examId == null || _questions.isEmpty || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);

    final correctCount = _questions.asMap().entries.where((entry) {
      return _selectedAnswers[entry.key] == entry.value.correctAnswer;
    }).length;
    final blankCount = _questions.length - _selectedAnswers.length;
    final wrongCount = _questions.length - correctCount - blankCount;

    try {
      final mockAttemptId = await _questionService.saveMockAttempt(
        examId: _examId!,
        title: _mockTitle(),
        mockType: widget.mockTypeOverride ??
            (widget.topicId != null
                ? 'branch'
                : widget.subjectId != null
                    ? 'branch'
                    : widget.questionCount >= 40
                        ? 'full'
                        : 'mini'),
        questionCount: _questions.length,
        correctCount: correctCount,
        wrongCount: wrongCount,
        blankCount: blankCount,
        durationSeconds: DateTime.now().difference(_startedAt).inSeconds,
        subjectId: widget.subjectId,
        topicId: widget.topicId,
        startedAt: _startedAt,
        completedAt: DateTime.now(),
      );

      // Bulk insert per-question results into mock_attempt_questions.
      if (mockAttemptId != null) {
        await _questionService.saveMockAttemptQuestions(
          mockAttemptId: mockAttemptId,
          questions: _questions,
          selectedAnswers: _selectedAnswers,
        );

        // Trigger AI analysis stub (no-op while feature flag is disabled).
        final aiService = AiAnalysisService();
        await aiService.analyzeMock(mockAttemptId: mockAttemptId);
        await aiService.generateDailyPlanAfterMock(
          examId: _examId!,
          mockAttemptId: mockAttemptId,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _isCompleted = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deneme sonucu kaydedilemedi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _questions.isEmpty ? 0.0 : (_currentIndex + 1) / _questions.length;
    final question = _questions.isEmpty || _isCompleted ? null : _questions[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(_mockTitle()),
      ),
      body: SafeArea(
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
            _MockHero(
              examType: widget.examType.title,
              subjectName: widget.subjectName,
              topicName: widget.topicName,
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              const _MockStateCard(
                title: 'Deneme kuruluyor',
                message: 'Sana uygun soru seti hazırlanıyor.',
              )
            else if (_errorMessage != null)
              _MockActionCard(
                title: 'Deneme başlatılamadı',
                message: _errorMessage!,
                actionLabel: 'Tekrar dene',
                onTap: _loadMock,
              )
            else if (_questions.isEmpty)
              _MockActionCard(
                title: 'Yeterli soru bulunamadı',
                message: 'Bu deneme için önce soru havuzunun dolması gerekiyor.',
                actionLabel: 'Yenile',
                onTap: _loadMock,
              )
            else if (_isCompleted)
              _MockSummaryCard(
                questions: _questions,
                selectedAnswers: _selectedAnswers,
                onRetry: _loadMock,
              )
            else ...[
              _MockProgressCard(
                currentIndex: _currentIndex,
                total: _questions.length,
                progress: progress,
                answeredCount: _selectedAnswers.length,
              ),
              const SizedBox(height: 18),
              _MockQuestionCard(
                question: question!,
                selectedAnswer: _selectedAnswers[_currentIndex],
                onSelect: (value) {
                  setState(() => _selectedAnswers[_currentIndex] = value);
                },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _currentIndex == 0
                          ? null
                          : () => setState(() => _currentIndex -= 1),
                      child: const Text('Önceki'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _currentIndex == _questions.length - 1
                          ? _finishMock
                          : () => setState(() => _currentIndex += 1),
                      child: Text(
                        _currentIndex == _questions.length - 1
                            ? (_isSaving ? 'Kaydediliyor...' : 'Denemeyi Bitir')
                            : 'Sonraki',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }

  String _mockTitle() {
    if (widget.titleOverride != null && widget.titleOverride!.trim().isNotEmpty) {
      return widget.titleOverride!.trim();
    }
    if (widget.topicName != null) {
      return '${widget.topicName} Denemesi';
    }
    if (widget.subjectName != null) {
      return '${widget.subjectName} Mini Denemesi';
    }
    return '${widget.examType.title} Mini Deneme';
  }
}

class _MockHero extends StatelessWidget {
  const _MockHero({
    required this.examType,
    this.subjectName,
    this.topicName,
  });

  final String examType;
  final String? subjectName;
  final String? topicName;

  @override
  Widget build(BuildContext context) {
    return _MockSurface(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF101828), Color(0xFF163B63), Color(0xFF1F7A72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Odak deneme modu',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '$examType kısa deneme',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            topicName != null
                ? '$subjectName > $topicName odağında kısa ve net bir deneme seti hazır.'
                : 'Süre baskısı olmadan ritim, dikkat ve net dengesini görmen için sade bir oturum.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockProgressCard extends StatelessWidget {
  const _MockProgressCard({
    required this.currentIndex,
    required this.total,
    required this.progress,
    required this.answeredCount,
  });

  final int currentIndex;
  final int total;
  final double progress;
  final int answeredCount;

  @override
  Widget build(BuildContext context) {
    return _MockSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Soru ${currentIndex + 1} / $total',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '$answeredCount cevaplandı',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF475569),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1D4ED8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockQuestionCard extends StatelessWidget {
  const _MockQuestionCard({
    required this.question,
    required this.selectedAnswer,
    required this.onSelect,
  });

  final Question question;
  final String? selectedAnswer;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _MockSurface(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.questionText,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.4,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 18),
          ...question.options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onSelect(option.optionKey),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selectedAnswer == option.optionKey
                        ? const Color(0xFFEEF2FF)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selectedAnswer == option.optionKey
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: selectedAnswer == option.optionKey
                              ? const Color(0xFF4F46E5)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          option.optionKey,
                          style: TextStyle(
                            color: selectedAnswer == option.optionKey
                                ? Colors.white
                                : const Color(0xFF334155),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option.optionText,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.45,
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockSummaryCard extends StatelessWidget {
  const _MockSummaryCard({
    required this.questions,
    required this.selectedAnswers,
    required this.onRetry,
  });

  final List<Question> questions;
  final Map<int, String> selectedAnswers;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final correctCount = questions.asMap().entries.where((entry) {
      return selectedAnswers[entry.key] == entry.value.correctAnswer;
    }).length;
    final blankCount = questions.length - selectedAnswers.length;
    final wrongCount = questions.length - correctCount - blankCount;
    final net = correctCount - (wrongCount / 4);

    return _MockSurface(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deneme tamamlandı',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Bu oturum leaderboard ve ilerleme kartlarına yansıtıldı. Şimdi eksiklerini güçlendirecek yeni bir set açabilirsin.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _SummaryBox(label: 'Doğru', value: '$correctCount', color: const Color(0xFF16A34A))),
              const SizedBox(width: 10),
              Expanded(child: _SummaryBox(label: 'Yanlış', value: '$wrongCount', color: const Color(0xFFDC2626))),
              const SizedBox(width: 10),
              Expanded(child: _SummaryBox(label: 'Boş', value: '$blankCount', color: const Color(0xFF64748B))),
              const SizedBox(width: 10),
              Expanded(child: _SummaryBox(label: 'Net', value: net.toStringAsFixed(2), color: const Color(0xFF4F46E5))),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => onRetry(),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: const Text('Yeni deneme yükle'),
          ),
        ],
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockStateCard extends StatelessWidget {
  const _MockStateCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _MockSurface(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockActionCard extends StatelessWidget {
  const _MockActionCard({
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
    return _MockSurface(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => onTap(),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _MockSurface extends StatelessWidget {
  const _MockSurface({
    required this.child,
    this.padding,
    this.decoration,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BoxDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: decoration ??
          BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.88)),
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
