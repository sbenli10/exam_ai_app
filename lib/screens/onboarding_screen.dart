import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exam_type.dart';
import '../services/profile_service.dart';
import 'exam_dashboard_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.user,
    required this.initialExamType,
  });

  final User user;
  final String initialExamType;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final ProfileService _profileService = ProfileService();
  final TextEditingController _nicknameController = TextEditingController();
  bool _isSaving = false;
  double _targetScore = 420;
  String _selectedExamType = 'YKS';

  @override
  void initState() {
    super.initState();
    final metadata = widget.user.userMetadata ?? const <String, dynamic>{};
    _nicknameController.text =
        (metadata['nickname'] as String?)?.trim().isNotEmpty == true
            ? (metadata['nickname'] as String).trim()
            : _fallbackNickname(widget.user.email);
    _selectedExamType = widget.initialExamType.isEmpty ? 'YKS' : widget.initialExamType;
    final metadataTarget = metadata['target_score'];
    if (metadataTarget is num) {
      _targetScore = metadataTarget.toDouble().clamp(250.0, 560.0).toDouble();
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1D4ED8),
              Color(0xFF22C55E),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            children: [
              Text(
                'İlk planı birlikte kuralım',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Hedefini netleştir, sana göre deneme akışı ve tekrar önerileri oluşturalım.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.88),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seni nasıl çağıralım?',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nicknameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Öğrenci adı'),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Hazırlandığın sınav',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: ExamType.all
                          .map(
                            (examType) => ChoiceChip(
                              label: Text(examType.title),
                              selected: _selectedExamType == examType.title,
                              onSelected: (_) {
                                setState(() => _selectedExamType = examType.title);
                              },
                              labelStyle: TextStyle(
                                color: _selectedExamType == examType.title
                                    ? const Color(0xFF0F172A)
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              selectedColor: const Color(0xFFFDE68A),
                              backgroundColor: Colors.white.withOpacity(0.12),
                              side: BorderSide(color: Colors.white.withOpacity(0.18)),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hedef puanın',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_targetScore.round()} puan',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFFFDE68A),
                        inactiveTrackColor: Colors.white.withOpacity(0.18),
                        thumbColor: const Color(0xFFFDE68A),
                        overlayColor: const Color(0xFFFDE68A).withOpacity(0.2),
                      ),
                      child: Slider(
                        value: _targetScore,
                        min: 250,
                        max: 560,
                        divisions: 31,
                        label: _targetScore.round().toString(),
                        onChanged: (value) {
                          setState(() => _targetScore = value);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _goalNarrative(_targetScore.round()),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.88),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _OnboardingStatCard(
                      title: 'Günlük plan',
                      value: _dailyGoal(_targetScore.round()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OnboardingStatCard(
                      title: 'Deneme ritmi',
                      value: _mockRhythm(_targetScore.round()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _OnboardingTipCard(
                tips: [
                  'Önce soru ritmini kur, sonra deneme yoğunluğunu artır.',
                  'Yanlış yaptığın konular ertesi gün tekrar listene düşmeli.',
                  'Her hafta en az bir mini deneme ile netini sabitle.',
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _completeOnboarding,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFDE68A),
                  foregroundColor: const Color(0xFF0F172A),
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: Text(
                  _isSaving ? 'Plan kaydediliyor...' : 'Çalışma planımı oluştur',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFFDE68A)),
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı adı en az 3 karakter olmalı.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _profileService.updateProfile(
        userId: widget.user.id,
        nickname: nickname,
        email: widget.user.email ?? '',
        examType: _selectedExamType,
        targetScore: _targetScore.round(),
      );
    } catch (_) {
      await _profileService.createProfile(
        userId: widget.user.id,
        nickname: nickname,
        email: widget.user.email ?? '',
        examType: _selectedExamType,
        targetScore: _targetScore.round(),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ExamDashboardScreen(
          examType: ExamType.fromTitle(_selectedExamType),
        ),
      ),
      (route) => false,
    );
  }

  String _fallbackNickname(String? email) {
    if (email == null || !email.contains('@')) {
      return 'öğrenci';
    }
    return email.split('@').first;
  }

  String _goalNarrative(int targetScore) {
    if (targetScore >= 470) {
      return 'Yüksek hedef modundasın. Soru ritmi, tam deneme ve haftalık tekrar dengesini agresif kuruyoruz.';
    }
    if (targetScore >= 400) {
      return 'Sağlam ilerleme bandındasın. Konu eksiklerini toparlayıp haftalık mini denemelerle net sabitleyeceğiz.';
    }
    return 'Temel güçlendirme modundasın. Önce konu açıklarını kapatıp güvenli bir soru ritmi kuracağız.';
  }

  String _dailyGoal(int targetScore) {
    if (targetScore >= 470) {
      return '60 soru';
    }
    if (targetScore >= 400) {
      return '45 soru';
    }
    return '30 soru';
  }

  String _mockRhythm(int targetScore) {
    if (targetScore >= 470) {
      return 'Haftada 3';
    }
    if (targetScore >= 400) {
      return 'Haftada 2';
    }
    return 'Haftada 1';
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: child,
    );
  }
}

class _OnboardingStatCard extends StatelessWidget {
  const _OnboardingStatCard({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.82),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingTipCard extends StatelessWidget {
  const _OnboardingTipCard({
    required this.tips,
  });

  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Uygulama senin için ne yapacak?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF334155),
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
