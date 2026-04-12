class DailyTask {
  const DailyTask({
    required this.id,
    required this.userId,
    required this.examId,
    required this.taskType,
    required this.title,
    required this.description,
    required this.status,
    required this.pointsReward,
    this.relatedId,
    this.taskDate,
  });

  final String id;
  final String userId;
  final String examId;
  final String taskType;
  final String title;
  final String description;
  final String status;
  final int pointsReward;
  final String? relatedId;
  final DateTime? taskDate;

  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';

  factory DailyTask.fromMap(Map<String, dynamic> map) {
    return DailyTask(
      id: map['id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      examId: map['exam_id'] as String? ?? '',
      taskType: map['task_type'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      pointsReward: (map['points_reward'] as num?)?.toInt() ?? 0,
      relatedId: map['related_id'] as String?,
      taskDate: map['task_date'] != null
          ? DateTime.tryParse(map['task_date'] as String)
          : null,
    );
  }
}
