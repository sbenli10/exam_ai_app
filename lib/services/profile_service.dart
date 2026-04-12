import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/avatar_config.dart';
import '../models/profile.dart';

class ProfileService {
  ProfileService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // ----------------------------
  // Profiles
  // ----------------------------
  Future<void> createProfile({
    required String userId,
    required String nickname,
    required String email,
    required String examType,
    int? targetScore,
  }) async {
    await _client.from('profiles').upsert(
      {
        'user_id': userId,
        'nickname': nickname,
        'email': email,
        'exam_type': examType,
        'target_score': targetScore,
      },
      onConflict: 'user_id',
    );
  }

  Future<Profile?> getProfile({String? userId}) async {
    final resolvedUserId = userId ?? _client.auth.currentUser?.id;
    if (resolvedUserId == null) return null;

    final data = await _client.from('profiles').select().eq('user_id', resolvedUserId).maybeSingle();
    if (data == null) return null;

    return Profile.fromMap(Map<String, dynamic>.from(data));
  }

  /// Updates the user's profile row (profiles.user_id = userId).
  ///
  /// - If [clearTargetScore] is true, it sets target_score = NULL (even if targetScore is null).
  /// - If [targetScore] is null and clearTargetScore is false, target_score is not changed.
  Future<Profile> updateProfile({
    required String userId,
    String? nickname,
    String? email,
    String? examType,
    int? targetScore,
    bool clearTargetScore = false,
  }) async {
    final payload = <String, dynamic>{};

    if (nickname != null) payload['nickname'] = nickname;
    if (email != null) payload['email'] = email;
    if (examType != null) payload['exam_type'] = examType;

    if (clearTargetScore) {
      payload['target_score'] = null;
    } else if (targetScore != null) {
      payload['target_score'] = targetScore;
    }

    // If nothing to update, return current profile (avoid empty update)
    if (payload.isEmpty) {
      final current = await getProfile(userId: userId);
      if (current == null) {
        throw StateError('Profile not found for user_id=$userId');
      }
      return current;
    }

    final data = await _client.from('profiles').update(payload).eq('user_id', userId).select().single();
    return Profile.fromMap(Map<String, dynamic>.from(data));
  }

  /// Calls RPC: is_nickname_available(p_nickname text) returns boolean
  Future<bool> isNicknameAvailable(String nickname) async {
    final result = await _client.rpc(
      'is_nickname_available',
      params: {'p_nickname': nickname.trim()},
    );

    // Supabase may return bool or 0/1 depending on SQL/function style
    if (result is bool) return result;
    if (result is num) return result != 0;

    // Fallback: try decode from map { "is_nickname_available": true } etc.
    if (result is Map) {
      final v = result.values.isNotEmpty ? result.values.first : null;
      if (v is bool) return v;
      if (v is num) return v != 0;
    }

    return false;
  }

  // ----------------------------
  // Profile photo (table: profile_photos)
  // ----------------------------
  Future<String?> getProfilePhotoUrl(String userId) async {
    final data = await _client
        .from('profile_photos')
        .select('photo_url')
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return null;
    return (data as Map<String, dynamic>)['photo_url'] as String?;
  }

  /// Upserts photo info into profile_photos table.
  /// - [photoUrl] is usually a public URL from Supabase Storage (public bucket) or a signed URL (private bucket).
  /// - [photoPath] is optional; store the storage object path if you want.
  Future<void> upsertProfilePhotoUrl(
      String userId,
      String photoUrl, {
        String? photoPath,
      }) async {
    await _client.from('profile_photos').upsert(
      {
        'user_id': userId,
        'photo_url': photoUrl,
        if (photoPath != null) 'photo_path': photoPath,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id',
    );
  }

  // ----------------------------
  // Avatar config (table: avatar_configs)
  // ----------------------------
  Future<void> upsertAvatarConfig(String userId, AvatarConfig config) async {
    await _client.from('avatar_configs').upsert(
      config.toJson(userId),
      onConflict: 'user_id',
    );
  }

  Future<AvatarConfig?> getAvatarConfig(String userId) async {
    final data = await _client.from('avatar_configs').select().eq('user_id', userId).maybeSingle();
    if (data == null) return null;

    return AvatarConfig.fromJson(Map<String, dynamic>.from(data as Map));
  }
}