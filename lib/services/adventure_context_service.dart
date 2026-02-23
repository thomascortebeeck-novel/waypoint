import 'package:cloud_functions/cloud_functions.dart';
import 'package:waypoint/models/adventure_context_model.dart';
import 'package:flutter/foundation.dart';

/// Service for generating AI-powered travel context (prepare info + local tips)
/// 
/// @deprecated This service is deprecated. AI generation features have been removed from the UI.
/// The service is kept for backward compatibility but should not be used in new code.
@Deprecated('AI generation features have been removed from the UI')
class AdventureContextService {
  static final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Generate travel context using AI based on adventure details
  /// 
  /// Returns a map with 'prepare' and 'local_tips' keys, or null on error
  /// 
  /// @deprecated This method is deprecated. AI generation features have been removed from the UI.
  @Deprecated('AI generation features have been removed from the UI')
  static Future<Map<String, dynamic>?> generateAdventureContext({
    required String location,
    required String title,
    required String description,
    required String activityType,
    required String accommodationType,
  }) async {
    try {
      debugPrint('[AdventureContextService] Generating context for: $title in $location');

      final result = await _functions.httpsCallable('generateAdventureContext').call({
        'location': location,
        'title': title,
        'description': description,
        'activity_type': activityType,
        'accommodation_type': accommodationType,
      });

      final data = result.data as Map<String, dynamic>?;

      if (data == null) {
        debugPrint('[AdventureContextService] No data returned from function');
        return null;
      }

      // Validate that we have the required keys
      if (!data.containsKey('prepare') || !data.containsKey('local_tips')) {
        debugPrint('[AdventureContextService] Missing required keys in response');
        return null;
      }

      debugPrint('[AdventureContextService] Successfully generated context');
      return data;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[AdventureContextService] Firebase function error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e, stack) {
      debugPrint('[AdventureContextService] Unexpected error: $e');
      debugPrint('[AdventureContextService] Stack: $stack');
      rethrow;
    }
  }
}

