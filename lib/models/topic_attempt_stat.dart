class TopicAttemptStat {
  const TopicAttemptStat({
    required this.topicId,
    required this.correctCount,
    required this.wrongCount,
    required this.blankCount,
  });

  final String topicId;
  final int correctCount;
  final int wrongCount;
  final int blankCount;

  int get totalAttemptCount => correctCount + wrongCount + blankCount;

  double get accuracy {
    final effectiveTotal = correctCount + wrongCount;
    if (effectiveTotal == 0) {
      return 0;
    }
    return correctCount / effectiveTotal;
  }
}

