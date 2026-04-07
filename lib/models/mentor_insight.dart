class MentorInsight {
  const MentorInsight({
    required this.recommendation,
    required this.weakTopics,
    required this.createdAt,
  });

  final String recommendation;
  final List<String> weakTopics;
  final DateTime createdAt;

  factory MentorInsight.fromMap(Map<String, dynamic> map) {
    final weakTopicsRaw = map['weak_topics'];
    final weakTopics = <String>[];

    if (weakTopicsRaw is List) {
      for (final item in weakTopicsRaw) {
        if (item is String && item.isNotEmpty) {
          weakTopics.add(item);
        }
      }
    }

    return MentorInsight(
      recommendation: map['recommendation'] as String? ?? '',
      weakTopics: weakTopics,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

