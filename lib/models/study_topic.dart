class StudySubject {
  const StudySubject({
    required this.id,
    required this.examId,
    required this.name,
    this.sectionName,
    required this.topics,
  });

  final String id;
  final String examId;
  final String name;
  final String? sectionName;
  final List<StudyTopic> topics;

  factory StudySubject.fromMap(Map<String, dynamic> map) {
    return StudySubject(
      id: map['id'] as String,
      examId: map['exam_id'] as String,
      name: map['name'] as String? ?? '',
      sectionName: map['section_name'] as String?,
      topics: const [],
    );
  }

  StudySubject copyWith({
    List<StudyTopic>? topics,
  }) {
    return StudySubject(
      id: id,
      examId: examId,
      name: name,
      sectionName: sectionName,
      topics: topics ?? this.topics,
    );
  }
}

class StudyTopic {
  const StudyTopic({
    required this.id,
    required this.subjectId,
    required this.name,
    this.sectionName,
    this.priority,
    this.targetQuestionCount,
  });

  final String id;
  final String subjectId;
  final String name;
  final String? sectionName;
  final int? priority;
  final int? targetQuestionCount;

  factory StudyTopic.fromMap(Map<String, dynamic> map) {
    return StudyTopic(
      id: map['id'] as String,
      subjectId: map['subject_id'] as String,
      name: map['name'] as String? ?? '',
      sectionName: map['section_name'] as String?,
      priority: map['priority'] as int?,
      targetQuestionCount: map['target_question_count'] as int?,
    );
  }
}
