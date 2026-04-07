import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class ProfileService {
  ProfileService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> createProfile({
    required String userId,
    required String nickname,
    required String email,
    required String examType,
    int? targetScore,
  }) async {
    await _client.from('profiles').upsert({
      'user_id': userId,
      'nickname': nickname,
      'email': email,
      'exam_type': examType,
      'target_score': targetScore,
    }, onConflict: 'user_id');
  }

  Future<Profile?> getProfile({String? userId}) async {
    final resolvedUserId = userId ?? _client.auth.currentUser?.id;
    if (resolvedUserId == null) {
      return null;
    }

    final data = await _client
        .from('profiles')
        .select()
        .eq('user_id', resolvedUserId)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return Profile.fromMap(data);
  }

  Future<Profile> updateProfile({
    required String userId,
    String? nickname,
    String? email,
    String? examType,
    int? targetScore,
  }) async {
    final payload = <String, dynamic>{};
    if (nickname != null) {
      payload['nickname'] = nickname;
    }
    if (email != null) {
      payload['email'] = email;
    }
    if (examType != null) {
      payload['exam_type'] = examType;
    }
    if (targetScore != null) {
      payload['target_score'] = targetScore;
    }

    final data = await _client
        .from('profiles')
        .update(payload)
        .eq('user_id', userId)
        .select()
        .single();

    return Profile.fromMap(data);
  }
}
