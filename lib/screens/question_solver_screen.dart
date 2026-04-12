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
  final List<bool> _answerResults = <bool>[];
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
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isSubmitted = false;
      _isSetCompleted = false;
      _selectedAnswer = null;
      _currentIndex = 0;
    });

    try {
      final examId = await _examCatalogService.resolveExamIdByTitle(
        widget.examType.title,
      );

      if (examId == null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Bu sınav için uygun soru havuzu bağlantısı kurulamadı.';
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

      if (!mounted) return;

      setState(() {
        _examId = examId;
        _questions = questions;
        _answerResults
          ..clear()
          ..addAll(List<bool>.filled(questions.length, false));
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Sorular yüklenirken bir sorun oluştu. Lütfen yeniden dene.';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitAnswer() async {
    if (_selectedAnswer == null || _isSubmitting || _questions.isEmpty) return;

    final question = _questions[_currentIndex];
    final isCorrect = question.correctAnswer == _selectedAnswer;

    setState(() => _isSubmitting = true);

    try {
      await _questionService.saveQuestionAttempt(
        questionId: question.id,
        selectedAnswer: _selectedAnswer,
        isCorrect: isCorrect,
        usedAiHelp: false,
      );

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
        _answerResults[_currentIndex] = isCorrect;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cevap kaydedilemedi. İnternetini kontrol edip tekrar dene.'),
        ),
      );
    }
  }

  void _nextQuestion() {
    if (_currentIndex >= _questions.length - 1) {
      setState(() => _isSetCompleted = true);
      return;
    }

    setState(() {
      _currentIndex += 1;
      _selectedAnswer = null;
      _isSubmitted = false;
    });
  }

  String _suggestedAction(int correctCount, int wrongCount, double net) {
    if (correctCount == 0 && wrongCount == 0) {
      return 'Bu konu için yeni sorular geldikçe tekrar kontrol et. Şimdilik benzer bir başlık ile ritmini koruyabilirsin.';
    }
    if (net >= 6) {
      return 'Bu konu sende oturmaya başlamış. İstersen mini denemeye geçip hızını ve dikkatini birlikte test edebilirsin.';
    }
    if (wrongCount >= correctCount) {
      return 'Önce kısa bir konu tekrarı, ardından aynı başlıktan yeni bir 8 soruluk set açmak en verimli adım olur.';
    }
    return 'Fena gitmiyorsun. Yarın aynı konuda kısa bir tekrar turu açarsan performansın daha dengeli hale gelir.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _SolverPalette.of(context);
    final question =
        _questions.isEmpty || _isSetCompleted ? null : _questions[_currentIndex];
    final progress =
        _questions.isEmpty ? 0.0 : (_currentIndex + 1) / _questions.length;
    final correctCount = _answerResults.where((value) => value).length;
    final wrongCount = _isSetCompleted
        ? _questions.length - correctCount
        : _currentIndex +
                (_isSubmitted && !_answerResults[_currentIndex] ? 1 : 0) -
                correctCount;
    final net = correctCount - (wrongCount / 4);
    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width < 360 ? 14.0 : 18.0;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '${widget.examType.title} Soru Çöz',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: colors.textStrong,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadQuestions,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: colors.backgroundGradient),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                28,
              ),
              children: [
                _SolverHeroCard(
                  examTitle: widget.examType.title,
                  examReady: _examId != null,
                  subjectName: widget.subjectName,
                  topicName: widget.topicName,
                ),
                const SizedBox(height: 12),
                if (widget.subjectName != null && widget.topicName != null) ...[
                  _TopicTrail(
                    subjectName: widget.subjectName!,
                    topicName: widget.topicName!,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_isLoading)
                  const _LoadingCard()
                else if (_errorMessage != null)
                  _InfoCard(
                    icon: Icons.error_outline_rounded,
                    title: 'Sorulara şu an ulaşılamıyor',
                    message: _errorMessage!,
                    actionLabel: 'Tekrar dene',
                    onTap: _loadQuestions,
                  )
                else if (question == null)
                  _TopicSummaryCard(
                    correctCount: correctCount,
                    wrongCount: wrongCount,
                    net: net,
                    answeredCount: _questions.length,
                    suggestedAction: _suggestedAction(
                      correctCount,
                      wrongCount,
                      net,
                    ),
                    onReload: _loadQuestions,
                    emptyMode: !_isSetCompleted,
                  )
                else ...[
                  _ProgressCard(
                    currentQuestion: _currentIndex + 1,
                    totalQuestions: _questions.length,
                    progress: progress,
                  ),
                  const SizedBox(height: 12),
                  _QuestionCard(
                    question: question,
                    selectedAnswer: _selectedAnswer,
                    isSubmitted: _isSubmitted,
                    onOptionSelected: (value) {
                      if (_isSubmitted) return;
                      setState(() => _selectedAnswer = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_isSubmitted) ...[
                    _ResultBanner(
                      isCorrect: _answerResults[_currentIndex],
                      correctAnswer: question.correctAnswer,
                    ),
                    const SizedBox(height: 12),
                    if ((question.explanation ?? '').trim().isNotEmpty)
                      _ExplanationCard(explanation: question.explanation!.trim()),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: !_isSubmitted
                        ? (_selectedAnswer == null || _isSubmitting
                            ? null
                            : _submitAnswer)
                        : _nextQuestion,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_isSubmitted && _isSubmitting) ...[
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ] else ...[
                          Icon(
                            _isSubmitted
                                ? Icons.arrow_forward_rounded
                                : Icons.send_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          !_isSubmitted
                              ? (_isSubmitting
                                  ? 'Cevabın kaydediliyor...'
                                  : 'Cevabı Gönder')
                              : (_currentIndex == _questions.length - 1
                                  ? 'Set özetine geç'
                                  : 'Sonraki soruya geç'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
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
}

class _SolverPalette {
  _SolverPalette._();

  static _SolverPalette of(BuildContext context) => _SolverPalette._();

  final Color background = const Color(0xFFF6F8FC);
  final Color surface = Colors.white;
  final Color surfaceMuted = const Color(0xFFF8FAFF);
  final Color border = const Color(0xFFE4EAF3);
  final Color textStrong = const Color(0xFF111827);
  final Color text = const Color(0xFF475569);
  final Color textMuted = const Color(0xFF64748B);
  final Color primary = const Color(0xFF3B82F6);
  final Color success = const Color(0xFF16A34A);
  final Color danger = const Color(0xFFDC2626);

  Gradient get backgroundGradient => const LinearGradient(
        colors: [Color(0xFFF7F9FD), Color(0xFFF2F6FC), Color(0xFFF7F9FD)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  List<BoxShadow> get shadow => const [
        BoxShadow(
          color: Color(0x100F172A),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ];
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.decoration,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BoxDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final colors = _SolverPalette.of(context);
    return Container(
      padding: padding,
      decoration: decoration ??
          BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border),
            boxShadow: colors.shadow,
          ),
      child: child,
    );
  }
}

class _SolverHeroCard extends StatelessWidget {
  const _SolverHeroCard({
    required this.examTitle,
    required this.examReady,
    this.subjectName,
    this.topicName,
  });

  final String examTitle;
  final bool examReady;
  final String? subjectName;
  final String? topicName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _CardShell(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF182236), Color(0xFF214A80), Color(0xFF157A78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Canlı soru akışı',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '$examTitle odak testi',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subjectName != null && topicName != null
                ? '$subjectName > $topicName konusu için odak soru setin hazır. Sakin ilerle, her soruda biraz daha güçlen.'
                : 'Hazır soru havuzu aktif. Bugün kısa bir odak turu ile ritmini yakalayabilirsin.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withOpacity(0.90),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(
                examReady ? Icons.verified_rounded : Icons.cloud_sync_rounded,
                color: Colors.white.withOpacity(0.92),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                examReady ? 'Hazır soru havuzu aktif' : 'Soru havuzu hazırlanıyor',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.92),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopicTrail extends StatelessWidget {
  const _TopicTrail({
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
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _TrailChip(label: subjectName),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
        _TrailChip(label: topicName, highlighted: true),
      ],
    );
  }
}
class _TrailChip extends StatelessWidget {
  const _TrailChip({
    required this.label,
    this.highlighted = false,
  });

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = _SolverPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted
            ? colors.primary.withOpacity(0.10)
            : colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? colors.primary.withOpacity(0.26)
              : colors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted ? colors.primary : colors.textStrong,
          fontWeight: FontWeight.w800,
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
    final colors = _SolverPalette.of(context);
    final theme = Theme.of(context);

    return _CardShell(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Soru $currentQuestion / $totalQuestions',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '%${(progress * 100).round()}',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Küçük adımlarla gidiyoruz. Her doğru cevap seni bir adım daha öne taşıyor.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: const Color(0xFFE9EEF7),
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
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
    final colors = _SolverPalette.of(context);
    final theme = Theme.of(context);

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Badge(
            label: 'Zorluk: ${_difficultyLabel(question.difficulty)}',
            foreground: colors.primary,
            background: colors.primary.withOpacity(0.10),
            border: colors.primary.withOpacity(0.20),
          ),
          const SizedBox(height: 18),
          Text(
            question.questionText,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colors.textStrong,
              fontWeight: FontWeight.w900,
              height: 1.42,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 18),
          ...question.options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OptionTile(
                option: option,
                selectedAnswer: selectedAnswer,
                correctAnswer: isSubmitted ? question.correctAnswer : null,
                isSubmitted: isSubmitted,
                onTap: () => onOptionSelected(option.optionKey),
              ),
            ),
          ),
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
    final colors = _SolverPalette.of(context);
    final isSelected = selectedAnswer == option.optionKey;
    final isCorrect = correctAnswer == option.optionKey;
    final isWrongSelected = isSubmitted && isSelected && !isCorrect;

    var borderColor = colors.border;
    var backgroundColor = colors.surfaceMuted;
    var accent = colors.primary;
    IconData? trailingIcon;
    String? stateText;

    if (isCorrect) {
      borderColor = colors.success;
      backgroundColor = colors.success.withOpacity(0.10);
      accent = colors.success;
      trailingIcon = Icons.check_circle_rounded;
      stateText = 'Doğru';
    } else if (isWrongSelected) {
      borderColor = colors.danger;
      backgroundColor = colors.danger.withOpacity(0.08);
      accent = colors.danger;
      trailingIcon = Icons.cancel_rounded;
      stateText = 'Yanlış';
    } else if (isSelected) {
      borderColor = colors.primary;
      backgroundColor = colors.primary.withOpacity(0.08);
      accent = colors.primary;
      stateText = 'Seçildi';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSubmitted ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  option.optionKey,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.optionText,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.textStrong,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                ),
              ),
              if (stateText != null) ...[
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        stateText,
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(height: 8),
                      Icon(trailingIcon, color: accent, size: 22),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.isCorrect,
    required this.correctAnswer,
  });

  final bool isCorrect;
  final String? correctAnswer;

  @override
  Widget build(BuildContext context) {
    final colors = _SolverPalette.of(context);
    final accent = isCorrect ? colors.success : colors.danger;
    final bg = isCorrect
        ? colors.success.withOpacity(0.10)
        : colors.danger.withOpacity(0.08);

    return _CardShell(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withOpacity(0.26)),
      ),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.emoji_events_rounded : Icons.lightbulb_rounded,
            color: accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isCorrect
                  ? 'Harika, bu soruyu doğru çözdün.'
                  : 'Bu soruda doğru cevap ${correctAnswer ?? '-'} idi. Kısa çözüm notuna göz atıp devam edebilirsin.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.explanation});

  final String explanation;

  @override
  Widget build(BuildContext context) {
    final colors = _SolverPalette.of(context);

    return _CardShell(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Kısa çözüm notu',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textStrong,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            explanation,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.text,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
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
    final colors = _SolverPalette.of(context);

    return _CardShell(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(icon, size: 38, color: colors.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => onTap(),
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary.withOpacity(0.10),
              foregroundColor: colors.primary,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
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
    final colors = _SolverPalette.of(context);

    return _CardShell(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CircularProgressIndicator(color: colors.primary),
          const SizedBox(height: 14),
          Text(
            'Soru seti hazırlanıyor...',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Birazdan ilk sorunu göreceksin. Bu kısa bekleyişten sonra odak başlıyor.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
          ),
        ],
      ),
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
    final colors = _SolverPalette.of(context);

    return _CardShell(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            emptyMode ? 'Bu konuda henüz hazır soru yok' : 'Set tamamlandı',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            emptyMode
                ? 'Bu başlık için yeni sorular eklendikçe burada görünecek. Şimdilik yakın bir konu ile devam edebilirsin.'
                : 'Güzel iş çıkardın. Şimdi sonucu hızlıca görüp istersen yeni bir set ile devam edebilirsin.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
          ),
          if (!emptyMode) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Doğru',
                    value: '$correctCount',
                    color: colors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Yanlış',
                    value: '$wrongCount',
                    color: colors.danger,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Net',
                    value: net.toStringAsFixed(2),
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mentör yorumu',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.textStrong,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$answeredCount soruluk bu setten sonra öneri:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    suggestedAction,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                        ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.tonal(
            onPressed: () => onReload(),
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary.withOpacity(0.10),
              foregroundColor: colors.primary,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              emptyMode ? 'Tekrar kontrol et' : 'Yeni set aç',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
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

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _difficultyLabel(String? difficulty) {
  switch ((difficulty ?? '').trim().toLowerCase()) {
    case 'easy':
      return 'Kolay';
    case 'medium':
      return 'Orta';
    case 'hard':
      return 'Zor';
    default:
      if (difficulty == null || difficulty.trim().isEmpty) {
        return 'Standart';
      }
      return difficulty;
  }
}
