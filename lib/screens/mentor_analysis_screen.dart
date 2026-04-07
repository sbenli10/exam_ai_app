import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/exam_type.dart';
import '../models/mentor_insight.dart';
import '../models/topic_attempt_stat.dart';

class MentorAnalysisScreen extends StatelessWidget {
  const MentorAnalysisScreen({
    super.key,
    required this.examType,
    required this.nickname,
    required this.insight,
    required this.topicStats,
    required this.topicNamesById,
    required this.weeklySolvedCounts,
    required this.todayPoints,
    required this.streak,
  });

  final ExamType examType;
  final String nickname;
  final MentorInsight insight;
  final List<TopicAttemptStat> topicStats;
  final Map<String, String> topicNamesById;
  final List<int> weeklySolvedCounts;
  final int todayPoints;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final sortedStats = [...topicStats]
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
    final weakStats = sortedStats.take(4).toList();
    final maxWeekly = weeklySolvedCounts.isEmpty
        ? 1
        : weeklySolvedCounts.reduce((a, b) => a > b ? a : b).clamp(1, 9999);
    const labels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cts', 'Paz'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Mentör Analizi'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$nickname için ${examType.title} mentör raporu',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    insight.recommendation,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.92),
                          height: 1.55,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Bugünkü puan',
                    value: '+$todayPoints',
                    color: const Color(0xFFDBEAFE),
                    textColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Seri',
                    value: '$streak gün',
                    color: const Color(0xFFFEF3C7),
                    textColor: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x100F172A),
                    blurRadius: 28,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zayıf Alanlar',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (weakStats.isEmpty)
                    Text(
                      'Henüz yeterli soru çözüm verisi yok. Birkaç oturum daha tamamladığında burada daha güçlü öneriler göreceksin.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF475569),
                            height: 1.5,
                          ),
                    )
                  else
                    ...weakStats.map((stat) {
                      final topicName =
                          topicNamesById[stat.topicId] ?? 'Konu';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                topicName,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Doğru ${stat.correctCount} • Yanlış ${stat.wrongCount} • Boş ${stat.blankCount}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xFF64748B),
                                    ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 10,
                                  value: stat.accuracy.clamp(0.0, 1.0),
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    stat.accuracy >= 0.7
                                        ? const Color(0xFF16A34A)
                                        : stat.accuracy >= 0.4
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x100F172A),
                    blurRadius: 28,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Son 7 Gün Çözüm Ritmi',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 170,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (index) {
                        final value = weeklySolvedCounts[index];
                        final ratio = value / maxWeekly;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: index == 6 ? 0 : 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '$value',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  height: 108 * ratio.clamp(0.08, 1.0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF93C5FD),
                                        Color(0xFF2563EB),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(labels[index]),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });

  final String label;
  final String value;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
          ),
        ],
      ),
    );
  }
}
