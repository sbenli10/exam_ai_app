import 'package:flutter/material.dart';

import '../models/exam_type.dart';
import '../models/study_topic.dart';
import '../services/exam_catalog_service.dart';
import '../services/question_generation_service.dart';

class QuestionGenerationAdminScreen extends StatefulWidget {
  const QuestionGenerationAdminScreen({
    super.key,
    required this.examType,
  });

  final ExamType examType;

  @override
  State<QuestionGenerationAdminScreen> createState() =>
      _QuestionGenerationAdminScreenState();
}

class _QuestionGenerationAdminScreenState
    extends State<QuestionGenerationAdminScreen> {
  final ExamCatalogService _catalogService = ExamCatalogService();
  final QuestionGenerationService _generationService =
      QuestionGenerationService();
  final TextEditingController _measurementFocusController =
      TextEditingController();

  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isApproving = false;
  bool _isBulkRejecting = false;
  final Set<String> _busyQuestionIds = <String>{};
  final Set<String> _selectedQuestionIds = <String>{};
  String? _errorMessage;
  String? _successMessage;
  String? _examId;
  List<StudySubject> _subjects = const [];
  StudySubject? _selectedSubject;
  StudyTopic? _selectedTopic;
  String _difficulty = 'medium';
  String _questionStyle = 'standard';
  int _targetCount = 5;
  Map<String, dynamic>? _lastResult;

  static const _difficultyOptions = <String, String>{
    'easy': 'Kolay',
    'medium': 'Orta',
    'hard': 'Zor',
  };

  static const _styleOptions = <String, String>{
    'standard': 'Standart',
    'new_generation': 'Yeni nesil',
    'short_drill': 'Hızlı tekrar',
    'long_paragraph': 'Uzun paragraf',
    'table_interpretation': 'Tablo yorumlama',
    'graph_interpretation': 'Grafik yorumlama',
  };

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _measurementFocusController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final examId =
          await _catalogService.resolveExamIdByTitle(widget.examType.title);
      if (examId == null) {
        throw StateError('Sınav kaydı bulunamadı.');
      }

      final subjects = await _catalogService.fetchSubjects(examId);
      final enriched = <StudySubject>[];
      for (final subject in subjects) {
        final topics = await _catalogService.fetchTopics(subject.id);
        enriched.add(subject.copyWith(topics: topics));
      }

      if (!mounted) return;

      final initialSubject = enriched.isEmpty ? null : enriched.first;
      final initialTopic = initialSubject == null || initialSubject.topics.isEmpty
          ? null
          : initialSubject.topics.first;

      setState(() {
        _examId = examId;
        _subjects = enriched;
        _selectedSubject = initialSubject;
        _selectedTopic = initialTopic;
        _isLoading = false;
      });

      _applySuggestedMeasurementFocus();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  void _applySuggestedMeasurementFocus() {
    if (_measurementFocusController.text.trim().isNotEmpty) return;
    final subjectName = _selectedSubject?.name ?? 'ders';
    final topicName = _selectedTopic?.name ?? 'konu';
    _measurementFocusController.text =
        '$subjectName içinde $topicName konusundaki temel kazanımı, kavramsal anlayışı ve yorum becerisini ölç.';
  }

  List<Map<String, dynamic>> _currentGeneratedQuestions() {
    final raw = _lastResult?['inserted_questions'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<String> _allGeneratedQuestionIds() {
    return _currentGeneratedQuestions()
        .map((item) => item['id'])
        .whereType<String>()
        .toList();
  }

  void _setGeneratedQuestions(
    List<Map<String, dynamic>> questions, {
    Set<String>? selectedIds,
  }) {
    final current = Map<String, dynamic>.from(_lastResult ?? const {});
    current['inserted_questions'] = questions;
    current['inserted_count'] = questions.length;
    _lastResult = current;

    final validIds = questions.map((item) => item['id']).whereType<String>().toSet();
    _selectedQuestionIds
      ..clear()
      ..addAll((selectedIds ?? _selectedQuestionIds).where(validIds.contains));
  }

  Future<void> _generate() async {
    final focus = _measurementFocusController.text.trim();
    if (_examId == null || _selectedSubject == null || _selectedTopic == null) {
      setState(() {
        _errorMessage = 'Önce ders ve konu seçmelisin.';
        _successMessage = null;
      });
      return;
    }

    if (focus.isEmpty) {
      setState(() {
        _errorMessage =
            'Bu soruda neyi ölçmek istediğini yaz. Örneğin kazanım, beceri veya alt başlık belirtebilirsin.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _successMessage = null;
      _lastResult = null;
      _selectedQuestionIds.clear();
    });

    try {
      final result = await _generationService.generateQuestions(
        examId: _examId!,
        subjectId: _selectedSubject!.id,
        topicId: _selectedTopic!.id,
        difficulty: _difficulty,
        questionStyle: _questionStyle,
        measurementFocus: focus,
        targetCount: _targetCount,
        batchSize: _targetCount,
      );

      if (!mounted) return;

      final insertedQuestions = (result['inserted_questions'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          <Map<String, dynamic>>[];

      setState(() {
        _lastResult = result;
        _selectedQuestionIds
          ..clear()
          ..addAll(
            insertedQuestions.map((item) => item['id']).whereType<String>(),
          );
        _successMessage = insertedQuestions.isNotEmpty
            ? '${insertedQuestions.length} soru taslak olarak eklendi. Varsayılan olarak hepsi seçildi.'
            : 'Yeni soru eklenmedi. Tekrar eden veya geçersiz kayıtlar elenmiş olabilir.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _successMessage = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _approveSelectedQuestions() async {
    if (_selectedSubject == null || _selectedTopic == null) return;

    final selectedIds = _selectedQuestionIds.toList();
    if (selectedIds.isEmpty) {
      setState(() {
        _errorMessage = 'Onay vermek için önce en az bir soru seçmelisin.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isApproving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _generationService.approveQuestions(
        questionIds: selectedIds,
        subjectId: _selectedSubject!.id,
        topicId: _selectedTopic!.id,
      );

      if (!mounted) return;

      final remainingQuestions = _currentGeneratedQuestions()
          .where((item) => !selectedIds.contains(item['id']))
          .toList();

      setState(() {
        _setGeneratedQuestions(remainingQuestions, selectedIds: <String>{});
        _successMessage =
            '${selectedIds.length} seçili soru onaylandı ve öğrenci kullanımına açıldı.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isApproving = false);
      }
    }
  }

  Future<void> _rejectSelectedQuestions() async {
    final selectedIds = _selectedQuestionIds.toList();
    if (selectedIds.isEmpty) {
      setState(() {
        _errorMessage = 'Toplu reddetme için önce en az bir soru seçmelisin.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isBulkRejecting = true;
      _errorMessage = null;
      _successMessage = null;
      _busyQuestionIds.addAll(selectedIds);
    });

    try {
      for (final questionId in selectedIds) {
        await _generationService.deleteDraftQuestion(questionId);
      }

      if (!mounted) return;

      final remainingQuestions = _currentGeneratedQuestions()
          .where((item) => !selectedIds.contains(item['id']))
          .toList();

      setState(() {
        _setGeneratedQuestions(remainingQuestions, selectedIds: <String>{});
        _successMessage =
            '${selectedIds.length} seçili taslak soru reddedildi ve listeden kaldırıldı.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isBulkRejecting = false;
          _busyQuestionIds.removeAll(selectedIds);
        });
      }
    }
  }

  Future<void> _rejectQuestion(String questionId) async {
    setState(() {
      _busyQuestionIds.add(questionId);
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _generationService.deleteDraftQuestion(questionId);
      if (!mounted) return;

      final updatedQuestions = _currentGeneratedQuestions()
          .where((item) => item['id'] != questionId)
          .toList();

      setState(() {
        _setGeneratedQuestions(updatedQuestions);
        _successMessage = 'Taslak soru reddedildi ve listeden kaldırıldı.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busyQuestionIds.remove(questionId));
      }
    }
  }

  Future<void> _regenerateQuestion(String questionId) async {
    if (_examId == null || _selectedSubject == null || _selectedTopic == null) {
      setState(() {
        _errorMessage =
            'Yeniden üretmek için önce geçerli ders ve konu seçimi gerekli.';
      });
      return;
    }

    final focus = _measurementFocusController.text.trim();
    if (focus.isEmpty) {
      setState(() {
        _errorMessage =
            'Yeniden üretmeden önce ölçmek istediğin beceriyi yazmalısın.';
      });
      return;
    }

    final currentQuestions = _currentGeneratedQuestions();
    final replaceIndex =
        currentQuestions.indexWhere((item) => item['id'] == questionId);
    if (replaceIndex == -1) {
      setState(() => _errorMessage = 'Yeniden üretilecek soru bulunamadı.');
      return;
    }

    final wasSelected = _selectedQuestionIds.contains(questionId);

    setState(() {
      _busyQuestionIds.add(questionId);
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _generationService.deleteDraftQuestion(questionId);

      final regenerated = await _generationService.generateQuestions(
        examId: _examId!,
        subjectId: _selectedSubject!.id,
        topicId: _selectedTopic!.id,
        difficulty: _difficulty,
        questionStyle: _questionStyle,
        measurementFocus: focus,
        targetCount: 1,
        batchSize: 1,
      );

      if (!mounted) return;

      final newQuestions = (regenerated['inserted_questions'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          <Map<String, dynamic>>[];

      final updatedQuestions = List<Map<String, dynamic>>.from(currentQuestions)
        ..removeAt(replaceIndex);
      final updatedSelectedIds = Set<String>.from(_selectedQuestionIds)
        ..remove(questionId);

      if (newQuestions.isNotEmpty) {
        updatedQuestions.insert(replaceIndex, newQuestions.first);
        final newId = newQuestions.first['id'];
        if (wasSelected && newId is String) {
          updatedSelectedIds.add(newId);
        }
      }

      setState(() {
        _setGeneratedQuestions(updatedQuestions, selectedIds: updatedSelectedIds);
        _successMessage = newQuestions.isNotEmpty
            ? 'Soru aynı sırada yeniden üretildi.'
            : 'Yeni soru üretilemedi. Eski soru listeden kaldırıldı.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busyQuestionIds.remove(questionId));
      }
    }
  }

  void _toggleQuestionSelection(String questionId, bool selected) {
    setState(() {
      if (selected) {
        _selectedQuestionIds.add(questionId);
      } else {
        _selectedQuestionIds.remove(questionId);
      }
    });
  }

  void _selectAllQuestions() {
    setState(() {
      _selectedQuestionIds
        ..clear()
        ..addAll(_allGeneratedQuestionIds());
    });
  }

  void _clearSelection() {
    setState(_selectedQuestionIds.clear);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('AI Soru Üretim Paneli'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F7FB), Color(0xFFF2F5FA), Color(0xFFEEF2F7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadCatalog,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _AdminHero(examTitle: widget.examType.title),
              const SizedBox(height: 18),
              if (_isLoading)
                const _AdminSurface(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_errorMessage != null && _subjects.isEmpty)
                _AdminSurface(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Katalog yüklenemedi',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                _AdminSurface(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Üretim ayarları',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sorular önce taslak olarak üretilir. Öğrencilerin görmesi için branş öğretmeni onayı gerekir.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<StudySubject>(
                          value: _selectedSubject,
                          decoration: _inputDecoration('Ders seç'),
                          items: _subjects
                              .map(
                                (subject) => DropdownMenuItem(
                                  value: subject,
                                  child: Text(subject.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedSubject = value;
                              _selectedTopic =
                                  value == null || value.topics.isEmpty
                                      ? null
                                      : value.topics.first;
                            });
                            _measurementFocusController.clear();
                            _applySuggestedMeasurementFocus();
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<StudyTopic>(
                          value: _selectedTopic,
                          decoration: _inputDecoration('Konu seç'),
                          items: (_selectedSubject?.topics ??
                                  const <StudyTopic>[])
                              .map(
                                (topic) => DropdownMenuItem(
                                  value: topic,
                                  child: Text(topic.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => _selectedTopic = value);
                            _measurementFocusController.clear();
                            _applySuggestedMeasurementFocus();
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _measurementFocusController,
                          minLines: 3,
                          maxLines: 4,
                          decoration: _inputDecoration(
                            'Bu soruda neyi ölçmek istiyorsun?',
                          ).copyWith(
                            hintText:
                                'Örn: paragrafta ana düşünceyi bulma, işlem önceliğini doğru uygulama, grafik yorumlama, çıkarım yapma',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _difficulty,
                                decoration: _inputDecoration('Zorluk'),
                                items: _difficultyOptions.entries
                                    .map(
                                      (entry) => DropdownMenuItem(
                                        value: entry.key,
                                        child: Text(entry.value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _difficulty = value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _targetCount,
                                decoration: _inputDecoration('Adet'),
                                items: const [5, 10, 15, 20]
                                    .map(
                                      (count) => DropdownMenuItem(
                                        value: count,
                                        child: Text('$count soru'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _targetCount = value);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: _questionStyle,
                          decoration: _inputDecoration('Soru stili'),
                          items: _styleOptions.entries
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _questionStyle = value);
                            }
                          },
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _isGenerating ? null : _generate,
                          icon: _isGenerating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome_rounded),
                          label: Text(
                            _isGenerating
                                ? 'Sorular üretiliyor...'
                                : 'Gemini ile soru üret',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        if (_successMessage != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _successMessage!,
                            style: const TextStyle(
                              color: Color(0xFF166534),
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ],
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (_lastResult != null)
                  _ResultCard(
                    result: _lastResult!,
                    isApproving: _isApproving,
                    isBulkRejecting: _isBulkRejecting,
                    busyQuestionIds: _busyQuestionIds,
                    selectedQuestionIds: _selectedQuestionIds,
                    onApproveSelected: _approveSelectedQuestions,
                    onRejectSelected: _rejectSelectedQuestions,
                    onSelectAll: _selectAllQuestions,
                    onClearSelection: _clearSelection,
                    onRejectQuestion: _rejectQuestion,
                    onRegenerateQuestion: _regenerateQuestion,
                    onToggleSelection: _toggleQuestionSelection,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
      ),
    );
  }
}

class _AdminHero extends StatelessWidget {
  const _AdminHero({
    required this.examTitle,
  });

  final String examTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF101828), Color(0xFF163B63), Color(0xFF1F7A72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${examTitle} için AI soru üretimi',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sınava, derse, konuya ve ölçmek istediğin kazanıma göre özgün sorular üret. Taslakları seç, incele, reddet veya öğretmen onayıyla yayına al.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.88),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.isApproving,
    required this.isBulkRejecting,
    required this.busyQuestionIds,
    required this.selectedQuestionIds,
    required this.onApproveSelected,
    required this.onRejectSelected,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onRejectQuestion,
    required this.onRegenerateQuestion,
    required this.onToggleSelection,
  });

  final Map<String, dynamic> result;
  final bool isApproving;
  final bool isBulkRejecting;
  final Set<String> busyQuestionIds;
  final Set<String> selectedQuestionIds;
  final Future<void> Function() onApproveSelected;
  final Future<void> Function() onRejectSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final Future<void> Function(String questionId) onRejectQuestion;
  final Future<void> Function(String questionId) onRegenerateQuestion;
  final void Function(String questionId, bool selected) onToggleSelection;

  @override
  Widget build(BuildContext context) {
    final inserted = result['inserted_count'] ?? 0;
    final duplicate = result['duplicate_count'] ?? 0;
    final failed = result['failed_count'] ?? 0;
    final jobId = result['job_id'] ?? '-';
    final insertedQuestions =
        (result['inserted_questions'] as List?)
            ?.whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList() ??
        const <Map<String, dynamic>>[];

    return _AdminSurface(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Üretim sonucu',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'İş kimliği: $jobId',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Taslak soruları seçerek toplu onay verebilir, toplu reddedebilir veya tek tek yeniden üretebilirsin.',
              style: TextStyle(
                color: Color(0xFF475569),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ResultChip(label: 'Eklenen', value: '$inserted'),
                _ResultChip(label: 'Tekrar', value: '$duplicate'),
                _ResultChip(label: 'Başarısız', value: '$failed'),
                _ResultChip(
                  label: 'Seçili',
                  value: '${selectedQuestionIds.length}',
                ),
              ],
            ),
            if (insertedQuestions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Üretilen sorular önizlemesi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: insertedQuestions.isEmpty ? null : onSelectAll,
                    child: const Text('Tümünü seç'),
                  ),
                  TextButton(
                    onPressed:
                        selectedQuestionIds.isEmpty ? null : onClearSelection,
                    child: const Text('Temizle'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Aşağıdaki sorular taslak olarak eklendi. İstersen bazılarını seçip toplu işlem yapabilir, istersen kart bazında yönetebilirsin.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: selectedQuestionIds.isEmpty || isApproving
                          ? null
                          : onApproveSelected,
                      icon: isApproving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_rounded),
                      label: Text(
                        isApproving
                            ? 'Onaylanıyor...'
                            : 'Seçili soruları onayla',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF166534),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: selectedQuestionIds.isEmpty || isBulkRejecting
                          ? null
                          : onRejectSelected,
                      icon: isBulkRejecting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline_rounded),
                      label: Text(
                        isBulkRejecting
                            ? 'Reddediliyor...'
                            : 'Toplu reddet',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB91C1C),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...insertedQuestions.asMap().entries.map((entry) {
                final questionId = entry.value['id'] as String?;
                if (questionId == null) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GeneratedQuestionPreviewCard(
                    index: entry.key + 1,
                    question: entry.value,
                    isBusy: busyQuestionIds.contains(questionId),
                    isSelected: selectedQuestionIds.contains(questionId),
                    onToggleSelection: (value) =>
                        onToggleSelection(questionId, value),
                    onReject: () => onRejectQuestion(questionId),
                    onRegenerate: () => onRegenerateQuestion(questionId),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _GeneratedQuestionPreviewCard extends StatelessWidget {
  const _GeneratedQuestionPreviewCard({
    required this.index,
    required this.question,
    required this.isBusy,
    required this.isSelected,
    required this.onToggleSelection,
    required this.onReject,
    required this.onRegenerate,
  });

  final int index;
  final Map<String, dynamic> question;
  final bool isBusy;
  final bool isSelected;
  final ValueChanged<bool> onToggleSelection;
  final VoidCallback onReject;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final questionText = (question['question_text'] as String?)?.trim();
    final correctAnswer = (question['correct_answer'] as String?)?.trim();
    final difficulty = (question['difficulty'] as String?)?.trim();
    final options = <MapEntry<String, String>>[
      MapEntry('A', (question['option_a'] as String?)?.trim() ?? ''),
      MapEntry('B', (question['option_b'] as String?)?.trim() ?? ''),
      MapEntry('C', (question['option_c'] as String?)?.trim() ?? ''),
      MapEntry('D', (question['option_d'] as String?)?.trim() ?? ''),
      MapEntry('E', (question['option_e'] as String?)?.trim() ?? ''),
    ].where((entry) => entry.value.isNotEmpty).toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? const Color(0xFF7DD3FC) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: isSelected,
                onChanged:
                    isBusy ? null : (value) => onToggleSelection(value ?? false),
              ),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (difficulty != null && difficulty.isNotEmpty)
                      _PreviewBadge(
                        label: _difficultyLabel(difficulty),
                        color: const Color(0xFF1D4ED8),
                        background: const Color(0xFFDBEAFE),
                      ),
                    if (correctAnswer != null && correctAnswer.isNotEmpty)
                      _PreviewBadge(
                        label: 'Doğru cevap: $correctAnswer',
                        color: const Color(0xFF166534),
                        background: const Color(0xFFDCFCE7),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            questionText?.isNotEmpty == true
                ? questionText!
                : 'Soru metni alınamadı.',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...options.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _QuestionOptionTile(
                  optionKey: option.key,
                  optionText: option.value,
                  isCorrect: correctAnswer == option.key,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : onReject,
                  icon: const Icon(Icons.close_rounded),
                  label: Text(isBusy ? 'İşleniyor...' : 'Soruyu reddet'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isBusy ? null : onRegenerate,
                  icon: isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('Yeniden üret'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _difficultyLabel(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 'Kolay';
      case 'hard':
        return 'Zor';
      default:
        return 'Orta';
    }
  }
}

class _QuestionOptionTile extends StatelessWidget {
  const _QuestionOptionTile({
    required this.optionKey,
    required this.optionText,
    required this.isCorrect,
  });

  final String optionKey;
  final String optionText;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFECFDF3) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  isCorrect ? const Color(0xFF166534) : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              optionKey,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              optionText,
              style: TextStyle(
                color: const Color(0xFF0F172A),
                fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w500,
                height: 1.45,
              ),
            ),
          ),
          if (isCorrect) ...[
            const SizedBox(width: 10),
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 18,
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSurface extends StatelessWidget {
  const _AdminSurface({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.88)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.05),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}
