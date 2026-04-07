import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/exam_type.dart';
import '../models/question.dart';
import '../services/question_service.dart';

class WrongQuestionsReviewScreen extends StatefulWidget {
  const WrongQuestionsReviewScreen({
    super.key,
    required this.examType,
    required this.examId,
  });

  final ExamType examType;
  final String examId;

  @override
  State<WrongQuestionsReviewScreen> createState() =>
      _WrongQuestionsReviewScreenState();
}

class _WrongQuestionsReviewScreenState extends State<WrongQuestionsReviewScreen> {
  final QuestionService _questionService = QuestionService();

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

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
      final items = await _questionService.fetchWrongQuestionReviews(
        examId: widget.examId,
        limit: 20,
      );

      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Yanlış sorular yüklenemedi.';
        _isLoading = false;
      });
    }
  }

  String _buildSolutionText(Question question) {
    final answerKey = question.correctAnswer ?? '-';
    QuestionOption? answerOption;
    for (final option in question.options) {
      if (option.optionKey == answerKey) {
        answerOption = option;
        break;
      }
    }

    if (question.explanation != null && question.explanation!.trim().isNotEmpty) {
      return question.explanation!.trim();
    }

    if (answerOption != null) {
      return 'Bu soruda doğru yaklaşım, kökte istenen bilgiyi seçeneklerle tek tek karşılaştırmaktır. Doğru cevap $answerKey şıkkıdır çünkü en uygun seçenek "${answerOption.optionText}" olarak görünmektedir.';
    }

    return 'Bu soruda doğru yaklaşım, kökte istenen bilgi veya işlemi seçeneklerle dikkatli biçimde karşılaştırmaktır. Doğru cevap $answerKey şıkkıdır.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Yanlış Sorularım'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _WrongHeroCard(examTitle: widget.examType.title),
              const SizedBox(height: 18),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Center(child: Text(_error!))
              else if (_items.isEmpty)
                const _EmptyWrongCard()
              else
                ..._items.map((item) {
                  final question = Question.fromMap(
                    Map<String, dynamic>.from(item['question'] as Map),
                  );
                  final selectedAnswer = item['selected_answer'] as String?;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _WrongQuestionCard(
                      question: question,
                      selectedAnswer: selectedAnswer,
                      solutionText: _buildSolutionText(question),
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

class _WrongHeroCard extends StatelessWidget {
  const _WrongHeroCard({
    required this.examTitle,
  });

  final String examTitle;

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
            '$examTitle yanlış analiz alanı',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Burada yanlış yaptığın soruları çözüm mantığıyla tekrar görebilir, hangi seçenekte koptuğunu daha net anlayabilirsin.',
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

class _EmptyWrongCard extends StatelessWidget {
  const _EmptyWrongCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.check_mark_circled_solid,
            color: Color(0xFF16A34A),
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            'İncelenecek yanlış soru yok',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Soru çözdükçe burada yanlış yaptığın sorular ve çözüm notları görünür.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF64748B),
                ),
          ),
        ],
      ),
    );
  }
}

class _WrongQuestionCard extends StatelessWidget {
  const _WrongQuestionCard({
    required this.question,
    required this.selectedAnswer,
    required this.solutionText,
  });

  final Question question;
  final String? selectedAnswer;
  final String solutionText;

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Yanlış',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFB91C1C),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Doğru: ${question.correctAnswer ?? '-'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF15803D),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            question.questionText,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          ...question.options.map((option) {
            final isCorrect = option.optionKey == question.correctAnswer;
            final isSelected = option.optionKey == selectedAnswer;
            final background = isCorrect
                ? const Color(0xFFECFDF5)
                : isSelected
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFF8FAFC);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isCorrect
                        ? const Color(0xFF86EFAC)
                        : isSelected
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? const Color(0xFF16A34A)
                            : isSelected
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF0F172A),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        option.optionKey,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option.optionText,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text(
            'Çözüm Notu',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            solutionText,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF475569),
                  height: 1.55,
                ),
          ),
        ],
      ),
    );
  }
}
