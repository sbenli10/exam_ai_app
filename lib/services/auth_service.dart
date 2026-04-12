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

  Future<AuthResponse> signInWithIdentifier(
    String identifier,
    String password,
  ) async {
    final resolvedEmail = await _resolveEmailForIdentifier(identifier);
    return _client.auth.signInWithPassword(
      email: resolvedEmail,
      password: password,
    );
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  Future<void> resetPasswordForIdentifier(String identifier) async {
    final resolvedEmail = await _resolveEmailForIdentifier(identifier);
    await _client.auth.resetPasswordForEmail(resolvedEmail);
  }

  User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  Future<Profile?> getProfile() {
    return _profileService.getProfile();
  }

  Future<String> _resolveEmailForIdentifier(String identifier) async {
    final normalized = identifier.trim();
    if (normalized.isEmpty) {
      throw const AuthException('Kullanıcı adı boş olamaz.');
    }

    if (normalized.contains('@')) {
      throw const AuthException(
        'Giriş için e-posta değil, kayıt olurken yazdığın kullanıcı adını kullanmalısın.',
      );
    }

    final dynamic result = await _client.rpc(
      'resolve_login_email',
      params: {'p_nickname': normalized},
    );

    final email = _extractEmail(result);
    if (email == null || email.trim().isEmpty) {
      throw const AuthException('Bu kullanıcı adına ait hesap bulunamadı.');
    }

    return email.trim();
  }

  String? _extractEmail(dynamic result) {
    if (result is String) {
      return result;
    }

    if (result is Map<String, dynamic>) {
      return result['email'] as String?;
    }

    if (result is List && result.isNotEmpty) {
      final first = result.first;
      if (first is String) {
        return first;
      }
      if (first is Map<String, dynamic>) {
        return first['email'] as String?;
      }
    }

    return null;
  }
}
