class GeneratedQuestion {
  const GeneratedQuestion({
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.optionE,
    required this.correctAnswer,
    required this.difficulty,
  });

  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String optionE;
  final String correctAnswer;
  final String difficulty;

  factory GeneratedQuestion.fromMap(Map<String, dynamic> map) {
    return GeneratedQuestion(
      questionText: map['question_text'] as String? ?? '',
      optionA: map['option_a'] as String? ?? '',
      optionB: map['option_b'] as String? ?? '',
      optionC: map['option_c'] as String? ?? '',
      optionD: map['option_d'] as String? ?? '',
      optionE: map['option_e'] as String? ?? '',
      correctAnswer: map['correct_answer'] as String? ?? '',
      difficulty: map['difficulty'] as String? ?? 'medium',
    );
  }

  Map<String, dynamic> toQuestionInsertMap({
    required String examId,
    required String subjectId,
    required String topicId,
  }) {
    return {
      'exam_id': examId,
      'subject_id': subjectId,
      'topic_id': topicId,
      'question_text': questionText,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'option_d': optionD,
      'option_e': optionE,
      'correct_answer': correctAnswer,
      'difficulty': difficulty,
    };
  }
}
