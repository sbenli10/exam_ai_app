class MockAttemptQuestion {
  const MockAttemptQuestion({
    required this.mockAttemptId,
    required this.questionId,
    required this.orderNo,
    this.selectedAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.isBlank,
  });

  final String mockAttemptId;
  final String questionId;
  final int orderNo;
  final String? selectedAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final bool isBlank;

  Map<String, dynamic> toMap() {
    return {
      'mock_attempt_id': mockAttemptId,
      'question_id': questionId,
      'order_no': orderNo,
      'selected_answer': selectedAnswer,
      'correct_answer': correctAnswer,
      'is_correct': isCorrect,
      'is_blank': isBlank,
    };
  }

  factory MockAttemptQuestion.fromMap(Map<String, dynamic> map) {
    return MockAttemptQuestion(
      mockAttemptId: map['mock_attempt_id'] as String? ?? '',
      questionId: map['question_id'] as String? ?? '',
      orderNo: (map['order_no'] as num?)?.toInt() ?? 0,
      selectedAnswer: map['selected_answer'] as String?,
      correctAnswer: map['correct_answer'] as String? ?? '',
      isCorrect: map['is_correct'] as bool? ?? false,
      isBlank: map['is_blank'] as bool? ?? true,
    );
  }
}
