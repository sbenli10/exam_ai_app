class Question {
  const Question({
    required this.id,
    required this.examId,
    required this.subjectId,
    required this.topicId,
    required this.questionText,
    required this.correctAnswer,
    required this.difficulty,
    required this.imageUrl,
    required this.explanation,
    required this.options,
  });

  final String id;
  final String? examId;
  final String? subjectId;
  final String? topicId;
  final String questionText;
  final String? correctAnswer;
  final String? difficulty;
  final String? imageUrl;
  final String? explanation;
  final List<QuestionOption> options;

  factory Question.fromMap(Map<String, dynamic> map) {
    final nestedOptions = map['question_options'];
    final options = <QuestionOption>[];

    if (nestedOptions is List) {
      for (final option in nestedOptions) {
        if (option is Map<String, dynamic>) {
          options.add(QuestionOption.fromMap(option));
        } else if (option is Map) {
          options.add(
            QuestionOption.fromMap(Map<String, dynamic>.from(option)),
          );
        }
      }
    }

    if (options.isEmpty) {
      const keys = ['A', 'B', 'C', 'D', 'E'];
      final fieldMap = {
        'A': map['option_a'],
        'B': map['option_b'],
        'C': map['option_c'],
        'D': map['option_d'],
        'E': map['option_e'],
      };

      for (final key in keys) {
        final value = fieldMap[key];
        if (value is String && value.isNotEmpty) {
          options.add(QuestionOption(optionKey: key, optionText: value));
        }
      }
    }

    return Question(
      id: map['id'] as String,
      examId: map['exam_id'] as String?,
      subjectId: map['subject_id'] as String?,
      topicId: map['topic_id'] as String?,
      questionText: map['question_text'] as String? ?? '',
      correctAnswer: map['correct_answer'] as String?,
      difficulty: map['difficulty'] as String?,
      imageUrl: map['image_url'] as String?,
      explanation: map['explanation'] as String?,
      options: options,
    );
  }
}

class QuestionOption {
  const QuestionOption({
    required this.optionKey,
    required this.optionText,
  });

  final String optionKey;
  final String optionText;

  factory QuestionOption.fromMap(Map<String, dynamic> map) {
    return QuestionOption(
      optionKey: map['option_key'] as String? ?? '',
      optionText: map['option_text'] as String? ?? '',
    );
  }
}
