/// Stub service for future AI analysis automation.
///
/// The methods in this class are placeholders that will call Edge Functions
/// like `analyze-mock` and `generate-daily-plan-after-mock` once they are
/// implemented on the backend.  All methods are no-ops until the feature flag
/// [kAiAnalysisEnabled] is set to `true`.
class AiAnalysisService {
  /// Feature flag – set to `true` once the Edge Functions are deployed.
  static const bool kAiAnalysisEnabled = false;

  /// Triggers the `analyze-mock` Edge Function for a given mock attempt.
  ///
  /// Returns `true` when the call succeeds (or when the feature is disabled,
  /// since there is nothing to do).
  Future<bool> analyzeMock({required String mockAttemptId}) async {
    if (!kAiAnalysisEnabled) return true;

    // TODO: call Supabase Edge Function `analyze-mock`
    // final response = await _client.functions.invoke(
    //   'analyze-mock',
    //   body: {'mock_attempt_id': mockAttemptId},
    // );
    // return response.status == 200;
    return true;
  }

  /// Triggers the `generate-daily-plan-after-mock` Edge Function.
  ///
  /// Returns `true` when the call succeeds (or when the feature is disabled).
  Future<bool> generateDailyPlanAfterMock({
    required String examId,
    required String mockAttemptId,
  }) async {
    if (!kAiAnalysisEnabled) return true;

    // TODO: call Supabase Edge Function `generate-daily-plan-after-mock`
    // final response = await _client.functions.invoke(
    //   'generate-daily-plan-after-mock',
    //   body: {
    //     'exam_id': examId,
    //     'mock_attempt_id': mockAttemptId,
    //   },
    // );
    // return response.status == 200;
    return true;
  }
}
