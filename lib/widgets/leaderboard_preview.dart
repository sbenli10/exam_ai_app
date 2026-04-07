import 'package:flutter/material.dart';

class LeaderboardPreviewEntry {
  const LeaderboardPreviewEntry({
    required this.name,
    required this.points,
    this.isCurrentUser = false,
  });

  final String name;
  final int points;
  final bool isCurrentUser;
}

class LeaderboardPreviewCard extends StatelessWidget {
  const LeaderboardPreviewCard({
    super.key,
    required this.entries,
    required this.onTap,
  });

  final List<LeaderboardPreviewEntry> entries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bugünün Liderleri',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              ...entries.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LeaderboardRow(
                    rank: index + 1,
                    entry: item,
                  ),
                );
              }),
              const SizedBox(height: 8),
              Text(
                'Tüm sıralamayı gör',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF4F46E5),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.entry,
  });

  final int rank;
  final LeaderboardPreviewEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: entry.isCurrentUser ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: entry.isCurrentUser ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Text(
            '$rank',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: entry.isCurrentUser ? const Color(0xFF4338CA) : const Color(0xFF111827),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              entry.isCurrentUser ? '${entry.name} - Sen' : entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF111827),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '${entry.points}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
