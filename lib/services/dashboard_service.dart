import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_summary.dart';

class DashboardService {
  DashboardService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Calls the `generate_daily_tasks_for_today` RPC to seed today's tasks.
  Future<void> generateDailyTasks({required String examId}) async {
    try {
      await _client.rpc('generate_daily_tasks_for_today', params: {
        'p_exam_id': examId,
      });
    } catch (_) {
      // Silently ignore if the RPC does not exist yet or returns an error.
      // The dashboard will still render without daily tasks.
    }
  }

  /// Calls the `get_dashboard_summary` RPC to fetch the full dashboard
  /// summary as a single JSON payload.
  Future<DashboardSummary> getDashboardSummary({
    required String examId,
  }) async {
    try {
      final response = await _client.rpc('get_dashboard_summary', params: {
        'p_exam_id': examId,
      });

      if (response is Map<String, dynamic>) {
        return DashboardSummary.fromRpcResponse(examId, response);
      }

      if (response is Map) {
        return DashboardSummary.fromRpcResponse(
          examId,
          Map<String, dynamic>.from(response),
        );
      }

      return DashboardSummary(examId: examId);
    } catch (_) {
      // If the RPC does not exist yet, return an empty summary.
      return DashboardSummary(examId: examId);
    }
  }

  /// Calls the `complete_daily_task` RPC to mark a task as completed and
  /// award points.
  Future<bool> completeDailyTask({required String taskId}) async {
    try {
      await _client.rpc('complete_daily_task', params: {
        'p_task_id': taskId,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
