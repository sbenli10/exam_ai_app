class Profile {
  const Profile({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.email,
    required this.examType,
    required this.targetScore,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String nickname;
  final String email;
  final String examType;
  final int? targetScore;
  final DateTime createdAt;

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      nickname: map['nickname'] as String? ?? '',
      email: map['email'] as String,
      examType: map['exam_type'] as String? ?? '',
      targetScore: map['target_score'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'nickname': nickname,
      'email': email,
      'exam_type': examType,
      'target_score': targetScore,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
