import 'package:flutter/material.dart';

import '../models/exam_type.dart';
import '../models/leaderboard_entry.dart';
import '../services/exam_catalog_service.dart';
import '../services/leaderboard_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    required this.examType,
  });

  final ExamType examType;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final ExamCatalogService _examCatalogService = ExamCatalogService();
  final LeaderboardService _leaderboardService = LeaderboardService();

  String _periodType = 'weekly';
  bool _isLoading = true;
  String? _errorMessage;
  String? _examId;
  List<LeaderboardEntry> _entries = const [];
  LeaderboardEntry? _myEntry;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final examId = await _examCatalogService.resolveExamIdByTitle(widget.examType.title);
      if (examId == null) {
        setState(() {
          _errorMessage = 'Bu sınav için leaderboard kaydı bulunamadı.';
          _isLoading = false;
        });
        return;
      }

      final entries = await _leaderboardService.fetchLeaderboard(
        examId: examId,
        periodType: _periodType,
        limit: 50,
      );
      final myEntry = await _leaderboardService.fetchMyLeaderboardEntry(
        examId: examId,
        periodType: _periodType,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _examId = examId;
        _entries = entries;
        _myEntry = myEntry;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Leaderboard yüklenirken bir hata oluştu.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text('${widget.examType.title} Leaderboard'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadLeaderboard,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _LeaderboardHero(examTitle: widget.examType.title),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              children: [
                _PeriodChip(
                  label: 'Haftalık',
                  selected: _periodType == 'weekly',
                  onTap: () {
                    setState(() {
                      _periodType = 'weekly';
                    });
                    _loadLeaderboard();
                  },
                ),
                _PeriodChip(
                  label: 'Aylık',
                  selected: _periodType == 'monthly',
                  onTap: () {
                    setState(() {
                      _periodType = 'monthly';
                    });
                    _loadLeaderboard();
                  },
                ),
                _PeriodChip(
                  label: 'Tüm Zamanlar',
                  selected: _periodType == 'all_time',
                  onTap: () {
                    setState(() {
                      _periodType = 'all_time';
                    });
                    _loadLeaderboard();
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_myEntry != null) ...[
              _MyRankCard(entry: _myEntry!),
              const SizedBox(height: 18),
            ],
            if (_isLoading)
              const _LeaderboardInfoCard(message: 'Sıralama yükleniyor...')
            else if (_errorMessage != null)
              _LeaderboardInfoCard(message: _errorMessage!)
            else if (_entries.isEmpty)
              const _LeaderboardInfoCard(
                message: 'Bu periyotta henüz leaderboard verisi oluşmamış.',
              )
            else ...[
              if (_examId != null)
                Text(
                  'exam_id: $_examId',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                ),
              const SizedBox(height: 10),
              ..._entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LeaderboardTile(entry: entry),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeaderboardHero extends StatelessWidget {
  const _LeaderboardHero({
    required this.examTitle,
  });

  final String examTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF2D3A8C), Color(0xFF5A6BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$examTitle Sıralama',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Puan, net ve çözülen soru performansına göre rakiplerini takip et.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.86),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFDBEAFE),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _MyRankCard extends StatelessWidget {
  const _MyRankCard({
    required this.entry,
  });

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _LeaderboardMetric(
              label: 'Sıralamam',
              value: '#${entry.rankPosition ?? '-'}',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _LeaderboardMetric(
              label: 'Toplam puan',
              value: '${entry.totalPoints}',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _LeaderboardMetric(
              label: 'Toplam net',
              value: entry.totalNet.toStringAsFixed(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardMetric extends StatelessWidget {
  const _LeaderboardMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF64748B),
              ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF111827),
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({
    required this.entry,
  });

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final displayName = entry.email == null || entry.email!.isEmpty
        ? 'Kullanıcı'
        : entry.email!.split('@').first;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                '#${entry.rankPosition ?? '-'}',
                style: const TextStyle(
                  color: Color(0xFF4054C8),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF111827),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.totalPoints} puan  •  ${entry.totalNet.toStringAsFixed(2)} net',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardInfoCard extends StatelessWidget {
  const _LeaderboardInfoCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
      ),
    );
  }
}
