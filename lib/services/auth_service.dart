import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import 'profile_service.dart';

class AuthService {
  AuthService({
    SupabaseClient? client,
    ProfileService? profileService,
  })  : _client = client ?? Supabase.instance.client,
        _profileService = profileService ?? ProfileService(client: client);

  final SupabaseClient _client;
  final ProfileService _profileService;

  Future<AuthResponse> signUp(
    String email,
    String password, {
    required String nickname,
    String? examType,
    int? targetScore,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'nickname': nickname,
        'exam_type': examType,
        'target_score': targetScore,
      },
    );

    return response;
  }

  Future<AuthResponse> signIn(String email, String password) {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  Future<Profile?> getProfile() {
    return _profileService.getProfile();
  }
}
