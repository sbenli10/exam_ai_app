class LeaderboardEntry {
  const LeaderboardEntry({
    required this.id,
    required this.userId,
    required this.examId,
    required this.periodType,
    required this.periodStart,
    required this.periodEnd,
    required this.totalPoints,
    required this.totalNet,
    required this.solvedQuestionsCount,
    required this.correctCount,
    required this.wrongCount,
    required this.blankCount,
    required this.mockCount,
    required this.rankPosition,
    required this.email,
  });

  final String id;
  final String userId;
  final String examId;
  final String periodType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int totalPoints;
  final double totalNet;
  final int solvedQuestionsCount;
  final int correctCount;
  final int wrongCount;
  final int blankCount;
  final int mockCount;
  final int? rankPosition;
  final String? email;

  factory LeaderboardEntry.fromMap(Map<String, dynamic> map) {
    return LeaderboardEntry(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      examId: map['exam_id'] as String,
      periodType: map['period_type'] as String? ?? '',
      periodStart: DateTime.parse(map['period_start'] as String),
      periodEnd: DateTime.parse(map['period_end'] as String),
      totalPoints: (map['total_points'] as num?)?.toInt() ?? 0,
      totalNet: (map['total_net'] as num?)?.toDouble() ?? 0,
      solvedQuestionsCount: (map['solved_questions_count'] as num?)?.toInt() ?? 0,
      correctCount: (map['correct_count'] as num?)?.toInt() ?? 0,
      wrongCount: (map['wrong_count'] as num?)?.toInt() ?? 0,
      blankCount: (map['blank_count'] as num?)?.toInt() ?? 0,
      mockCount: (map['mock_count'] as num?)?.toInt() ?? 0,
      rankPosition: (map['rank_position'] as num?)?.toInt(),
      email: map['email'] as String?,
    );
  }
}
