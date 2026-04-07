import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exam_type.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';
import '../screens/exam_dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<String?> _ensureProfile(
    ProfileService profileService,
    User user,
  ) async {
    final existingProfile = await profileService.getProfile(userId: user.id);
    if (existingProfile != null) {
      return existingProfile.examType;
    }

    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final examType = metadata['exam_type'] as String?;
    final nickname = metadata['nickname'] as String?;
    if (examType == null || nickname == null) {
      return null;
    }

    await profileService.createProfile(
      userId: user.id,
      nickname: nickname,
      email: user.email ?? '',
      examType: examType,
      targetScore: metadata['target_score'] as int?,
    );
    return examType;
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final profileService = ProfileService(client: client);

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;

        if (snapshot.connectionState == ConnectionState.waiting && session == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (session != null) {
          return FutureBuilder<String?>(
            future: _ensureProfile(profileService, session.user),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final examTypeTitle = profileSnapshot.data;
              if (examTypeTitle == null || examTypeTitle.isEmpty) {
                return _MissingProfileScreen(
                  onSignOut: () => client.auth.signOut(),
                );
              }

              final examType = ExamType.fromTitle(examTypeTitle);
              return FutureBuilder<Profile?>(
                future: profileService.getProfile(userId: session.user.id),
                builder: (context, resolvedProfileSnapshot) {
                  if (resolvedProfileSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final resolvedProfile = resolvedProfileSnapshot.data;
                  if (resolvedProfile == null || resolvedProfile.targetScore == null) {
                    return OnboardingScreen(
                      user: session.user,
                      initialExamType: examTypeTitle,
                    );
                  }

                  return ExamDashboardScreen(
                    examType: examType,
                  );
                },
              );
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}

class _MissingProfileScreen extends StatelessWidget {
  const _MissingProfileScreen({
    required this.onSignOut,
  });

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_circle_outlined,
                size: 54,
                color: Color(0xFF5A6BFF),
              ),
              const SizedBox(height: 16),
              Text(
                'Profil bilgisi bulunamadi.',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Lütfen tekrar giriş yaparak kayıt akışını tamamla.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                    ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onSignOut,
                child: const Text('Çıkış yap'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
