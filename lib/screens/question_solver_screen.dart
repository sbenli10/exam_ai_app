import 'package:flutter/material.dart';

import '../models/exam_type.dart';
import '../models/question.dart';
import '../services/exam_catalog_service.dart';
import '../services/question_service.dart';

class QuestionSolverScreen extends StatefulWidget {
  const QuestionSolverScreen({
    super.key,
    required this.examType,
    this.subjectId,
    this.topicId,
    this.subjectName,
    this.topicName,
  });

  final ExamType examType;
  final String? subjectId;
  final String? topicId;
  final String? subjectName;
  final String? topicName;

  @override
  State<QuestionSolverScreen> createState() => _QuestionSolverScreenState();
}

class _QuestionSolverScreenState extends State<QuestionSolverScreen> {
  final ExamCatalogService _examCatalogService = ExamCatalogService();
  final QuestionService _questionService = QuestionService();

  String? _examId;
  List<Question> _questions = const [];
  final List<bool> _answerResults = [];
  int _currentIndex = 0;
  String? _selectedAnswer;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isSubmitted = false;
  bool _isSetCompleted = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSubmitted = false;
      _isSetCompleted = false;
      _selectedAnswer = null;
      _currentIndex = 0;
    });

    try {
      final examId = await _examCatalogService.resolveExamIdByTitle(widget.examType.title);
      if (examId == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _errorMessage = 'Bu sınav için veritabanı kaydı bulunamadı.';
          _isLoading = false;
        });
        return;
      }

      final questions = await _questionService.fetchQuestions(
        examId: examId,
        subjectId: widget.subjectId,
        topicId: widget.topicId,
        limit: 8,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _examId = examId;
        _questions = questions;
        _answerResults
          ..clear()
          ..addAll(List<bool>.filled(questions.length, false));
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Sorular yüklenirken bir hata oluştu.';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitAnswer() async {
    if (_selectedAnswer == null || _isSubmitting || _questions.isEmpty) {
      return;
    }

    final question = _questions[_currentIndex];
    final isCorrect = question.correctAnswer == _selectedAnswer;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _questionService.saveQuestionAttempt(
        questionId: question.id,
        selectedAnswer: _selectedAnswer,
        isCorrect: isCorrect,
        usedAiHelp: false,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
        _answerResults[_currentIndex] = isCorrect;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cevap kaydedilemedi. Lütfen tekrar dene.'),
        ),
      );
    }
  }

  void _nextQuestion() {
    if (_currentIndex >= _questions.length - 1) {
      setState(() {
        _isSetCompleted = true;
      });
      return;
    }

    setState(() {
      _currentIndex += 1;
      _selectedAnswer = null;
      _isSubmitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions.isEmpty || _isSetCompleted ? null : _questions[_currentIndex];
    final progress = _questions.isEmpty ? 0.0 : (_currentIndex + 1) / _questions.length;
    final correctCount = _answerResults.where((value) => value).length;
    final wrongCount = _isSetCompleted ? _questions.length - correctCount : _currentIndex + (_isSubmitted && !_answerResults[_currentIndex] ? 1 : 0) - correctCount;
    final net = correctCount - (wrongCount / 4);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('${widget.examType.title} Soru Çöz'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadQuestions,
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
              _HeaderCard(
                examTitle: widget.examType.title,
                examId: _examId,
                subjectName: widget.subjectName,
                topicName: widget.topicName,
              ),
              const SizedBox(height: 18),
              if (widget.subjectName != null && widget.topicName != null) ...[
                _TopicPathCard(
                  subjectName: widget.subjectName!,
                  topicName: widget.topicName!,
                ),
                const SizedBox(height: 18),
              ],
              if (_isLoading)
                const _LoadingCard()
              else if (_errorMessage != null)
                _InfoCard(
                  icon: Icons.error_outline_rounded,
            title: 'Veri alınamadı',
                  message: _errorMessage!,
                  actionLabel: 'Tekrar Dene',
                  onTap: _loadQuestions,
                )
              else if (question == null)
                _isSetCompleted
                    ? _TopicSummaryCard(
                        correctCount: correctCount,
                        wrongCount: wrongCount,
                        net: net,
                        answeredCount: _questions.length,
                        suggestedAction: _suggestedAction(correctCount, wrongCount, net),
                        onReload: _loadQuestions,
                      )
                    : (widget.topicId != null && widget.subjectId != null)
                        ? _TopicSummaryCard(
                            correctCount: 0,
                            wrongCount: 0,
                            net: 0,
                            emptyMode: true,
                            onReload: _loadQuestions,
                          )
                        : _InfoCard(
                            icon: Icons.inbox_outlined,
                            title: 'Soru bulunamadı',
                            message: 'Bu sınav için henüz hazır soru bulunamadı. Daha sonra tekrar kontrol et veya başka bir konu seç.',
                            actionLabel: 'Yenile',
                            onTap: _loadQuestions,
                          )
              else ...[
                _ProgressCard(
                  currentQuestion: _currentIndex + 1,
                  totalQuestions: _questions.length,
                  progress: progress,
                ),
                const SizedBox(height: 18),
                _QuestionCard(
                  question: question,
                  selectedAnswer: _selectedAnswer,
                  isSubmitted: _isSubmitted,
                  onOptionSelected: (value) {
                    if (_isSubmitted) {
                      return;
                    }

                    setState(() {
                      _selectedAnswer = value;
                    });
                  },
                ),
                const SizedBox(height: 18),
                if (_isSubmitted)
                  const _SubmissionInfoCard(),
                const SizedBox(height: 18),
                if (!_isSubmitted)
                  FilledButton(
                    onPressed: _selectedAnswer == null || _isSubmitting ? null : _submitAnswer,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3F51B5),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(_isSubmitting ? 'Kaydediliyor...' : 'Cevabı Gönder'),
                  )
                else
                  FilledButton(
                    onPressed: _nextQuestion,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3F51B5),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      _currentIndex == _questions.length - 1
                          ? 'Test Özetine Geç'
                          : 'Sonraki Soru',
                    ),
                  ),
              ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _suggestedAction(int correctCount, int wrongCount, double net) {
    if (correctCount == 0 && wrongCount == 0) {
      return 'Bu konuda soru havuzu oluştukça yeniden kontrol et. Bu arada benzer konularda ritmi koru.';
    }
    if (net >= 6) {
      return 'Bu konu güçlü görünüyor. Zorluğu bir tık artırıp mini denemeyle hız kazanabilirsin.';
    }
    if (wrongCount >= correctCount) {
      return 'Bu konuda önce kısa tekrar, sonra 8 soruluk yeni set daha doğru olacak. Hata tipi bilgi eksiği gibi görünüyor.';
    }
    return 'Performans dengeli. Yarın aynı konudan hızlı bir tekrar seti açarsan netini sabitleyebilirsin.';
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.examTitle,
    required this.examId,
    required this.subjectName,
    required this.topicName,
  });

  final String examTitle;
  final String? examId;
  final String? subjectName;
  final String? topicName;

  @override
  Widget build(BuildContext context) {
    return _SolverSurface(
      width: double.infinity,
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
              'Canlı soru akışı',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$examTitle odak testi',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            topicName == null
                ? 'Bugün sadece tek şeye odaklan: doğru ritimle çözmek. Her cevap ilerlemene işlenir.'
                : '$subjectName > $topicName konusu için odak soru seti hazır.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.84),
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            examId == null ? 'Soru havuzu bağlanıyor' : 'Hazır soru havuzu aktif',
            style: const TextStyle(
              color: Color(0xFFDDE7FF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicPathCard extends StatelessWidget {
  const _TopicPathCard({
    required this.subjectName,
    required this.topicName,
  });

  final String subjectName;
  final String topicName;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _TopicChip(label: subjectName),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
        _TopicChip(label: topicName, highlighted: true),
      ],
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.label,
    this.highlighted = false,
  });

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFEEF2FF) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted ? const Color(0xFF4338CA) : const Color(0xFF334155),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.currentQuestion,
    required this.totalQuestions,
    required this.progress,
  });

  final int currentQuestion;
  final int totalQuestions;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return _SolverSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Soru $currentQuestion / $totalQuestions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF111827),
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                '%${(progress * 100).round()}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF4054C8),
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5A6BFF)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.selectedAnswer,
    required this.isSubmitted,
    required this.onOptionSelected,
  });

  final Question question;
  final String? selectedAnswer;
  final bool isSubmitted;
  final ValueChanged<String> onOptionSelected;

  @override
  Widget build(BuildContext context) {
    return _SolverSurface(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (question.difficulty != null && question.difficulty!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Zorluk: ${question.difficulty}',
                style: const TextStyle(
                  color: Color(0xFF4338CA),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            question.questionText,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 18),
          for (final option in question.options) ...[
            _OptionTile(
              option: option,
              selectedAnswer: selectedAnswer,
              correctAnswer: isSubmitted ? question.correctAnswer : null,
              isSubmitted: isSubmitted,
              onTap: () => onOptionSelected(option.optionKey),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.isSubmitted,
    required this.onTap,
  });

  final QuestionOption option;
  final String? selectedAnswer;
  final String? correctAnswer;
  final bool isSubmitted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedAnswer == option.optionKey;
    final isCorrect = correctAnswer == option.optionKey;
    final isWrongSelected = isSubmitted && isSelected && !isCorrect;

    Color borderColor = const Color(0xFFE2E8F0);
    Color backgroundColor = Colors.white;

    if (isCorrect) {
      borderColor = const Color(0xFF10B981);
      backgroundColor = const Color(0xFFECFDF5);
    } else if (isWrongSelected) {
      borderColor = const Color(0xFFEF4444);
      backgroundColor = const Color(0xFFFEF2F2);
    } else if (isSelected) {
      borderColor = const Color(0xFF5A6BFF);
      backgroundColor = const Color(0xFFEEF2FF);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: isSubmitted ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: borderColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  option.optionKey,
                  style: TextStyle(
                    color: borderColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.optionText,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF111827),
                      height: 1.45,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionInfoCard extends StatelessWidget {
  const _SubmissionInfoCard();

  @override
  Widget build(BuildContext context) {
    return _SolverSurface(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FB),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE6F2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: Color(0xFF4338CA)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cevabın kaydedildi. Doğru cevap ve detaylı özet test sonunda gösterilecek.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF312E81),
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return _SolverSurface(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 36, color: const Color(0xFF5A6BFF)),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF111827),
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
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: () {
              onTap();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF3F51B5),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return _SolverSurface(
      padding: const EdgeInsets.all(28),
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Soru seti yükleniyor...'),
        ],
      ),
    );
  }
}

class _SolverSurface extends StatelessWidget {
  const _SolverSurface({
    required this.child,
    this.padding,
    this.width,
    this.decoration,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final BoxDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
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

class _TopicSummaryCard extends StatelessWidget {
  const _TopicSummaryCard({
    required this.correctCount,
    required this.wrongCount,
    required this.net,
    this.answeredCount = 0,
    this.suggestedAction = '',
    required this.onReload,
    this.emptyMode = false,
  });

  final int correctCount;
  final int wrongCount;
  final double net;
  final int answeredCount;
  final String suggestedAction;
  final Future<void> Function() onReload;
  final bool emptyMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            emptyMode ? 'Bu Konuda Henüz Soru Yok' : 'Konu Özetin',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            emptyMode
                ? 'Bu topic için henüz yeterli hazır soru bulunmuyor. Kısa bir süre sonra tekrar kontrol edebilirsin.'
                : 'Bu set tamamlandı. Şimdi performansını görüp aynı konudan yeni bir set çözmeye devam edebilirsin.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 18),
          if (!emptyMode) ...[
            Row(
              children: [
                Expanded(child: _SummaryMetric(label: 'Doğru', value: '$correctCount', color: const Color(0xFF059669))),
                const SizedBox(width: 12),
                Expanded(child: _SummaryMetric(label: 'Yanlış', value: '$wrongCount', color: const Color(0xFFDC2626))),
                const SizedBox(width: 12),
                Expanded(child: _SummaryMetric(label: 'Net', value: net.toStringAsFixed(2), color: const Color(0xFF4338CA))),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set analizi',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$answeredCount soruluk bu sette önerilen sonraki adım:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    suggestedAction,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          OutlinedButton(
            onPressed: () => onReload(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF3F51B5),
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(emptyMode ? 'Tekrar Kontrol Et' : 'Aynı Konudan Yeni Set Yükle'),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}
