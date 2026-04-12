import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/exam_type.dart';
import '../models/study_topic.dart';
import '../services/exam_catalog_service.dart';
import '../services/question_service.dart';
import 'mock_exam_screen.dart';
import 'question_solver_screen.dart';

class TopicsScreen extends StatefulWidget {
  const TopicsScreen({
    super.key,
    required this.examType,
    this.initialSubjectId,
    this.initialTopicId,
  });

  final ExamType examType;
  final String? initialSubjectId;
  final String? initialTopicId;

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

enum _TopicsSegment { suggested, ready, preparing, all }

class _TopicsScreenState extends State<TopicsScreen> {
  final ExamCatalogService _examCatalogService = ExamCatalogService();
  final QuestionService _questionService = QuestionService();

  bool _isLoading = true;
  String? _errorMessage;

  List<StudySubject> _subjects = const [];
  Map<String, int> _questionCounts = const {};

  // UI State (local only)
  String? _selectedSubjectId;
  _TopicsSegment _segment = _TopicsSegment.ready; // more practical default
  String _query = '';

  // Avoid rebuilding controllers in build
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final examId = await _examCatalogService.resolveExamIdByTitle(widget.examType.title);
      if (examId == null) {
        setState(() {
          _errorMessage = 'Bu sınav için içerik henüz hazır değil.';
          _isLoading = false;
        });
        return;
      }

      final subjects = await _examCatalogSubjects(examId);

      final counts = await _questionService.fetchQuestionCountsByTopicIds(
        subjects.expand((s) => s.topics.map((t) => t.id)).toList(),
      );

      if (!mounted) return;

      setState(() {
        _subjects = subjects;
        _questionCounts = counts;
        _isLoading = false;

        _selectedSubjectId = widget.initialSubjectId ?? (subjects.isNotEmpty ? subjects.first.id : null);
      });

      _openInitialTopicIfNeeded(subjects);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Konuları şu an yükleyemedim. Tekrar deneyelim.';
        _isLoading = false;
      });
    }
  }

  Future<List<StudySubject>> _examCatalogSubjects(String examId) async {
    final subjects = await _examCatalogService.fetchSubjects(examId);
    final enriched = <StudySubject>[];

    for (final subject in subjects) {
      final topics = await _examCatalogService.fetchTopics(subject.id);
      enriched.add(subject.copyWith(topics: topics));
    }

    return enriched;
  }

  void _openTopic(BuildContext context, StudySubject subject, StudyTopic topic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionSolverScreen(
          examType: widget.examType,
          subjectId: subject.id,
          topicId: topic.id,
          subjectName: subject.name,
          topicName: topic.name,
        ),
      ),
    );
  }

  void _openInitialTopicIfNeeded(List<StudySubject> subjects) {
    final initialSubjectId = widget.initialSubjectId;
    final initialTopicId = widget.initialTopicId;
    if (initialSubjectId == null || initialTopicId == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      for (final subject in subjects) {
        if (subject.id != initialSubjectId) continue;
        for (final topic in subject.topics) {
          if (topic.id == initialTopicId) {
            setState(() => _selectedSubjectId = subject.id);
            _openTopic(context, subject, topic);
            return;
          }
        }
      }
    });
  }

  StudySubject? get _selectedSubject {
    final id = _selectedSubjectId;
    if (id == null) return null;
    for (final s in _subjects) {
      if (s.id == id) return s;
    }
    return _subjects.isNotEmpty ? _subjects.first : null;
  }

  int _countForTopic(String topicId) => _questionCounts[topicId] ?? 0;

  List<StudyTopic> _suggestedTopics(StudySubject subject) {
    // UI-only heuristic: top 2 by question count
    final sorted = [...subject.topics]..sort((a, b) => _countForTopic(b.id).compareTo(_countForTopic(a.id)));
    return sorted.take(2).where((t) => _countForTopic(t.id) > 0).toList();
  }

  List<StudyTopic> _filteredTopics(StudySubject subject) {
    final q = _query.trim().toLowerCase();
    Iterable<StudyTopic> list = subject.topics;

    switch (_segment) {
      case _TopicsSegment.suggested:
        final suggestedIds = _suggestedTopics(subject).map((t) => t.id).toSet();
        list = list.where((t) => suggestedIds.contains(t.id));
        break;
      case _TopicsSegment.ready:
        list = list.where((t) => _countForTopic(t.id) > 0);
        break;
      case _TopicsSegment.preparing:
        list = list.where((t) => _countForTopic(t.id) == 0);
        break;
      case _TopicsSegment.all:
        break;
    }

    if (q.isNotEmpty) {
      list = list.where((t) => t.name.toLowerCase().contains(q));
    }

    return list.toList();
  }

  void _selectSubject(String id) {
    setState(() {
      _selectedSubjectId = id;
      _segment = _TopicsSegment.ready;
      _query = '';
      _searchController.clear();
    });
  }

  void _setQuery(String v) {
    setState(() => _query = v);
  }

  void _clearQuery() {
    setState(() {
      _query = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _TopicsTokens.of(context);

    final w = MediaQuery.of(context).size.width;
    final hPad = w < 360 ? 14.0 : 18.0;

    final selected = _selectedSubject;
    final filteredTopics = (selected == null) ? const <StudyTopic>[] : _filteredTopics(selected);

    // Design goal: NOT crowded.
    // Keep: Hero + Subject chips + Segment filter + Search + Clean topic list.
    // Remove: 3 dashboard mini cards + heavy sub-cards + extra shadows.
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('${widget.examType.title} Konuları'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: t.bgGradient),
          child: ListView(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 28),
            children: [
              _HeroCard(examTitle: widget.examType.title),
              const SizedBox(height: 12),

              if (_isLoading)
                const _InfoCard(
                  title: 'Konular hazırlanıyor',
                  message: 'Birazdan içerik burada olacak.',
                  variant: _InfoVariant.loading,
                )
              else if (_errorMessage != null)
                _InfoCard(
                  title: 'Kısa bir sorun oldu',
                  message: _errorMessage!,
                  actionLabel: 'Tekrar dene',
                  onTap: _loadData,
                )
              else if (_subjects.isEmpty)
                  _InfoCard(
                    title: 'Henüz içerik yok',
                    message: 'Bu sınav için konu listesi yakında eklenecek.',
                    actionLabel: 'Yenile',
                    onTap: _loadData,
                  )
                else ...[
                    _SubjectsStrip(
                      subjects: _subjects,
                      selectedSubjectId: _selectedSubjectId,
                      onSelect: _selectSubject,
                    ),
                    const SizedBox(height: 10),

                    _SegmentedBar(
                      value: _segment,
                      onChanged: (v) => setState(() => _segment = v),
                    ),
                    const SizedBox(height: 10),

                    _SearchBar(
                      controller: _searchController,
                      hint: selected == null ? 'Konu ara' : '${selected.name} içinde ara',
                      onChanged: _setQuery,
                      onClear: _clearQuery,
                    ),
                    const SizedBox(height: 12),

                    if (selected == null)
                      _InfoCard(
                        title: 'Ders seçilemedi',
                        message: 'Üstten bir ders seçip devam edebilirsin.',
                        actionLabel: 'Yenile',
                        onTap: _loadData,
                      )
                    else
                      _SubjectHeaderRow(
                        subjectName: selected.name,
                        totalTopics: selected.topics.length,
                        readyTopics: selected.topics.where((x) => _countForTopic(x.id) > 0).length,
                        resultsCount: filteredTopics.length,
                        queryActive: _query.trim().isNotEmpty,
                        onStartMock: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MockExamScreen(
                                examType: widget.examType,
                                subjectId: selected.id,
                                subjectName: selected.name,
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 10),

                    if (selected != null) ...[
                      if (filteredTopics.isEmpty)
                        _EmptyState(query: _query, segment: _segment)
                      else
                        ...filteredTopics.map(
                              (topic) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TopicTileCompact(
                              topicName: topic.name,
                              questionCount: _countForTopic(topic.id),
                              onTap: () => _openTopic(context, selected, topic),
                            ),
                          ),
                        ),
                    ],
                  ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// TOKENS — exam-app clean system
/// ------------------------------------------------------------
class _TopicsTokens {
  _TopicsTokens._(this.brightness);

  final Brightness brightness;
  bool get isDark => brightness == Brightness.dark;

  static _TopicsTokens of(BuildContext context) => _TopicsTokens._(Theme.of(context).brightness);

  // Brand palette
  Color get brandA => const Color(0xFF2563EB); // electric blue
  Color get brandB => const Color(0xFF1E3A8A); // deep night blue
  Color get primary => const Color(0xFF3F51B5);
  Color get success => const Color(0xFF10B981);

  // Text
  Color get textStrong => isDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
  Color get text => isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
  Color get textSubtle => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  // Background
  Color get bg => isDark ? const Color(0xFF0B1220) : const Color(0xFFF7F8FF);

  Gradient get bgGradient => isDark
      ? const LinearGradient(
    colors: [Color(0xFF0B1220), Color(0xFF0F172A), Color(0xFF0B1220)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  )
      : const LinearGradient(
    colors: [
      Color(0xFFF7F8FF),
      Color(0xFFF2F6FF),
      Color(0xFFF1F5FF),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Surfaces
  Color get surface => isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFFFFFFF);
  Color get border => isDark ? Colors.white.withOpacity(0.14) : const Color(0xFFE6EAF2);

  // Minimal shadow
  Color get shadow => isDark ? const Color(0x24000000) : const Color(0x060F172A);
}

/// ------------------------------------------------------------
/// HERO — one strong element, rest stays minimal
/// ------------------------------------------------------------
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.examTitle});
  final String examTitle;

  @override
  Widget build(BuildContext context) {
    final t = _TopicsTokens.of(context);
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.brandB, const Color(0xFF163B63), t.brandA],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroPill(label: 'Pratik'),
          const SizedBox(height: 10),
          Text(
            '$examTitle konuları',
            style: tt.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Dersini seç, konunu bul ve teste gir. Hazır setlerle düzenli ilerle.',
            style: tt.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.90),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------
/// SUBJECTS STRIP — easy tapping + airy
/// ------------------------------------------------------------
class _SubjectsStrip extends StatelessWidget {
  const _SubjectsStrip({
    required this.subjects,
    required this.selectedSubjectId,
    required this.onSelect,
  });

  final List<StudySubject> subjects;
  final String? selectedSubjectId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = _TopicsTokens.of(context);

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: subjects.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = subjects[i];
          final selected = s.id == selectedSubjectId;

          return TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0, end: selected ? 1 : 0),
            builder: (context, v, _) {
              final bg = Color.lerp(t.surface, t.brandA.withOpacity(0.14), v)!;
              final br = Color.lerp(t.border, t.brandA.withOpacity(0.30), v)!;
              final fg = Color.lerp(t.textStrong, t.brandA, v)!;

              return GestureDetector(
                onTap: () => onSelect(s.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: br),
                    boxShadow: [
                      BoxShadow(
                        color: t.shadow,
                        blurRadius: 10,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: selected ? t.brandA : t.textSubtle.withOpacity(0.35),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        s.name,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// ------------------------------------------------------------
/// SEGMENTED BAR — big tap targets, simple labels
/// ------------------------------------------------------------
class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({required this.value, required this.onChanged});

  final _TopicsSegment value;
  final ValueChanged<_TopicsSegment> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = _TopicsTokens.of(context);

    Widget item(_TopicsSegment seg, String label, IconData icon) {
      final selected = seg == value;

      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(seg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? t.brandA.withOpacity(0.14) : t.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? t.brandA.withOpacity(0.25) : t.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: selected ? t.brandA : t.textSubtle),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? t.brandA : t.textSubtle,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          item(_TopicsSegment.ready, 'Hazır', Icons.check_circle_rounded),
          const SizedBox(width: 6),
          item(_TopicsSegment.suggested, 'Öneri', Icons.auto_awesome_rounded),
          const SizedBox(width: 6),
          item(_TopicsSegment.preparing, 'Yakında', Icons.hourglass_bottom_rounded),
          const SizedBox(width: 6),
          item(_TopicsSegment.all, 'Hepsi', Icons.grid_view_rounded),
        ],
      ),
    );
  }
}

/// ------------------------------------------------------------
/// SEARCH BAR — stable controller
/// ------------------------------------------------------------
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = _TopicsTokens.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: t.textSubtle),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: t.textSubtle, fontWeight: FontWeight.w600),
                border: InputBorder.none,
              ),
              style: TextStyle(color: t.textStrong, fontWeight: FontWeight.w700),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
              color: t.textSubtle,
              splashRadius: 18,
            ),
        ],
      ),
    );
  }
}

/// ------------------------------------------------------------
/// SUBJECT HEADER ROW — lightweight, not a big card
/// ------------------------------------------------------------
class _SubjectHeaderRow extends StatelessWidget {
  const _SubjectHeaderRow({
    required this.subjectName,
    required this.totalTopics,
    required this.readyTopics,
    required this.resultsCount,
    required this.queryActive,
    required this.onStartMock,
  });

  final String subjectName;
  final int totalTopics;
  final int readyTopics;
  final int resultsCount;
  final bool queryActive;
  final VoidCallback onStartMock;

  @override
  Widget build(BuildContext context) {
    final t = _TopicsTokens.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subjectName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: t.textStrong,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                queryActive ? '$resultsCount sonuç' : 'Hazır: $readyTopics • Toplam: $totalTopics',
                style: TextStyle(color: t.textSubtle, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        FilledButton.tonal(
          onPressed: onStartMock,
          style: FilledButton.styleFrom(
            backgroundColor: t.brandA.withOpacity(0.14),
            foregroundColor: t.brandA,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(t.isDark ? 0.08 : 0.90),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(t.isDark ? 0.10 : 0.70)),
                ),
                child: Icon(Icons.timer_rounded, size: 16, color: t.brandA),
              ),
              const SizedBox(width: 10),
              const Text('Mini'),
            ],
          ),
        ),
      ],
    );
  }
}

/// ------------------------------------------------------------
/// TOPIC TILE (compact, easy tapping, exam-app feel)
/// ------------------------------------------------------------
class _TopicTileCompact extends StatelessWidget {
  const _TopicTileCompact({
    required this.topicName,
    required this.questionCount,
    required this.onTap,
  });

  final String topicName;
  final int questionCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = _TopicsTokens.of(context);
    final enabled = questionCount > 0;

    final status = enabled ? 'Hazır' : 'Yakında';
    final statusColor = enabled ? t.success : t.textSubtle;
    final statusBg = enabled ? t.success.withOpacity(0.10) : const Color(0xFFF1F5F9);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.border),
            boxShadow: [
              BoxShadow(
                color: t.shadow,
                blurRadius: 10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: t.brandA.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.brandA.withOpacity(0.18)),
                ),
                child: Icon(Icons.menu_book_rounded, color: t.brandA, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topicName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: t.textStrong,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: t.border.withOpacity(0.35)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (questionCount > 0)
                          Text(
                            '$questionCount soru',
                            style: TextStyle(color: t.textSubtle, fontWeight: FontWeight.w800),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: enabled ? onTap : null,
                style: FilledButton.styleFrom(
                  backgroundColor: t.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                child: const Text('Başla'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query, required this.segment});

  final String query;
  final _TopicsSegment segment;

  @override
  Widget build(BuildContext context) {
    final t = _TopicsTokens.of(context);

    final msg = query.trim().isNotEmpty
        ? 'Aramana uygun konu yok.'
        : switch (segment) {
      _TopicsSegment.ready => 'Bu derste henüz hazır set yok.',
      _TopicsSegment.suggested => 'Önerilen konu bulunamadı.',
      _TopicsSegment.preparing => 'Hazırlanan konu yok.',
      _TopicsSegment.all => 'Konu bulunamadı.',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined, color: t.textSubtle),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                color: t.textSubtle,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ------------------------------------------------------------
/// INFO CARD
/// ------------------------------------------------------------
enum _InfoVariant { normal, loading }

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onTap,
    this.variant = _InfoVariant.normal,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onTap;
  final _InfoVariant variant;

  @override
  Widget build(BuildContext context) {
    final t = _TopicsTokens.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          if (variant == _InfoVariant.loading) ...[
            CircularProgressIndicator(color: t.brandA),
          ] else ...[
            Icon(Icons.info_outline_rounded, color: t.brandA, size: 28),
          ],
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: t.textStrong,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: t.textSubtle,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionLabel != null && onTap != null) ...[
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: () => onTap!(),
              style: FilledButton.styleFrom(
                backgroundColor: t.brandA.withOpacity(0.12),
                foregroundColor: t.brandA,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}