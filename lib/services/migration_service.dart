import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:waypoint/models/plan_model.dart';
import 'package:waypoint/models/plan_meta_model.dart';
import 'package:waypoint/models/plan_version_model.dart';
import 'package:waypoint/models/day_itinerary_model.dart';
import 'package:waypoint/services/plan_service.dart';

/// Service to migrate legacy flat documents to subcollection architecture
/// 
/// Run this once to migrate existing data, then the app will use the new structure
/// for all new data while maintaining backwards compatibility for reading old data.
class MigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PlanService _planService = PlanService();

  /// Check if a plan has been migrated to subcollections
  Future<bool> isPlanMigrated(String planId) async {
    try {
      final versionsSnap = await _firestore
          .collection('plans')
          .doc(planId)
          .collection('versions')
          .limit(1)
          .get();
      return versionsSnap.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking migration status: $e');
      return false;
    }
  }

  /// Migrate a single plan from flat document to subcollections
  Future<MigrationResult> migratePlan(String planId) async {
    try {
      // Check if already migrated
      if (await isPlanMigrated(planId)) {
        return MigrationResult(
          planId: planId,
          success: true,
          message: 'Already migrated',
          versionsCreated: 0,
          daysCreated: 0,
        );
      }

      // Load legacy plan
      final planDoc = await _firestore.collection('plans').doc(planId).get();
      if (!planDoc.exists) {
        return MigrationResult(
          planId: planId,
          success: false,
          message: 'Plan not found',
          versionsCreated: 0,
          daysCreated: 0,
        );
      }

      final plan = Plan.fromJson(planDoc.data()!);
      
      // Create subcollection documents using batch writes
      final batch = _firestore.batch();
      var versionsCreated = 0;
      var daysCreated = 0;

      // Migrate activity category values at plan level
      await _migrateActivityCategory(planId, batch);

      // Create version documents and day documents
      for (final version in plan.versions) {
        final versionDoc = PlanVersionDoc.fromPlanVersion(version, planId);
        final versionRef = _firestore
            .collection('plans')
            .doc(planId)
            .collection('versions')
            .doc(version.id);
        batch.set(versionRef, versionDoc.toJson());
        versionsCreated++;

        for (final day in version.days) {
          final dayDoc = DayItineraryDoc.fromDayItinerary(day, planId, version.id);
          final dayRef = versionRef.collection('days').doc(dayDoc.id);
          batch.set(dayRef, dayDoc.toJson());
          daysCreated++;
        }
      }

      await batch.commit();

      return MigrationResult(
        planId: planId,
        success: true,
        message: 'Migration completed',
        versionsCreated: versionsCreated,
        daysCreated: daysCreated,
      );
    } catch (e) {
      debugPrint('Error migrating plan $planId: $e');
      return MigrationResult(
        planId: planId,
        success: false,
        message: 'Error: $e',
        versionsCreated: 0,
        daysCreated: 0,
      );
    }
  }

  /// Migrate activity category and experience level values
  Future<void> _migrateActivityCategory(String planId, WriteBatch batch) async {
    final planRef = _firestore.collection('plans').doc(planId);
    final planDoc = await planRef.get();
    if (!planDoc.exists) return;

    final data = planDoc.data()!;
    final updates = <String, dynamic>{};

    // Migrate activity_category
    final activityCategory = data['activity_category'] as String?;
    if (activityCategory != null) {
      String? newValue;
      switch (activityCategory) {
        case 'hikingTrekking':
        case 'hiking_trekking':
          newValue = 'hiking';
          break;
        case 'winterSports':
        case 'winter_sports':
          newValue = 'skis';
          break;
        case 'regionalTours':
        case 'regional_tours':
          newValue = 'tours';
          break;
        case 'cityTrips':
        case 'city_trips':
          newValue = 'cityTrips';
          break;
        case 'cycling':
          newValue = 'cycling';
          break;
        case 'climbing':
          newValue = 'climbing';
          break;
        // Old values to remove
        case 'paddling':
        case 'trailRunning':
        case 'trail_running':
        case 'overlanding':
        case 'horsebackTrekking':
        case 'horseback_trekking':
          newValue = null; // Remove deprecated values
          break;
        default:
          newValue = activityCategory; // Keep if already migrated
      }
      
      if (newValue != activityCategory) {
        updates['activity_category'] = newValue;
      }
    }

    if (updates.isNotEmpty) {
      batch.update(planRef, updates);
    }
  }

  /// Migrate experience level values across all versions
  Future<void> migrateExperienceLevels() async {
    try {
      final plansSnap = await _firestore.collection('plans').get();
      
      for (final planDoc in plansSnap.docs) {
        final versionsSnap = await _firestore
            .collection('plans')
            .doc(planDoc.id)
            .collection('versions')
            .get();

        final batch = _firestore.batch();
        var updateCount = 0;

        for (final versionDoc in versionsSnap.docs) {
          final data = versionDoc.data();
          final experienceLevel = data['experience_level'] as String?;
          
          if (experienceLevel != null) {
            String? newValue;
            switch (experienceLevel) {
              case 'easy':
                newValue = 'beginner';
                break;
              case 'moderate':
                newValue = 'intermediate';
                break;
              case 'hard':
                newValue = 'expert';
                break;
              case 'expert':
                newValue = 'expert';
                break;
              default:
                newValue = experienceLevel; // Keep if already migrated
            }
            
            if (newValue != experienceLevel) {
              batch.update(versionDoc.reference, {'experience_level': newValue});
              updateCount++;
            }
          }

          // Remove accommodation_style field
          if (data.containsKey('accommodation_style')) {
            batch.update(versionDoc.reference, {'accommodation_style': FieldValue.delete()});
            updateCount++;
          }
        }

        if (updateCount > 0) {
          await batch.commit();
          debugPrint('Migrated $updateCount fields in plan ${planDoc.id}');
        }
      }
      
      debugPrint('Experience level migration completed');
    } catch (e) {
      debugPrint('Error migrating experience levels: $e');
    }
  }

  /// Migrate all plans in the database
  Future<List<MigrationResult>> migrateAllPlans({
    int batchSize = 10,
    void Function(int current, int total)? onProgress,
  }) async {
    try {
      // Get all plan IDs
      final plansSnap = await _firestore.collection('plans').get();
      final planIds = plansSnap.docs.map((d) => d.id).toList();
      
      final results = <MigrationResult>[];
      
      for (var i = 0; i < planIds.length; i++) {
        final result = await migratePlan(planIds[i]);
        results.add(result);
        
        if (onProgress != null) {
          onProgress(i + 1, planIds.length);
        }
        
        // Small delay between batches to avoid overwhelming Firestore
        if ((i + 1) % batchSize == 0) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      return results;
    } catch (e) {
      debugPrint('Error migrating all plans: $e');
      return [];
    }
  }

  /// Verify migration integrity for a plan
  Future<MigrationVerification> verifyMigration(String planId) async {
    try {
      // Load legacy data
      final planDoc = await _firestore.collection('plans').doc(planId).get();
      if (!planDoc.exists) {
        return MigrationVerification(
          planId: planId,
          isValid: false,
          issues: ['Plan document not found'],
        );
      }

      final legacyPlan = Plan.fromJson(planDoc.data()!);
      final issues = <String>[];

      // Check if subcollections exist
      final versionsSnap = await _firestore
          .collection('plans')
          .doc(planId)
          .collection('versions')
          .get();

      if (versionsSnap.docs.isEmpty) {
        return MigrationVerification(
          planId: planId,
          isValid: false,
          issues: ['No versions found in subcollection - not migrated'],
        );
      }

      // Verify version count matches
      if (versionsSnap.docs.length != legacyPlan.versions.length) {
        issues.add(
          'Version count mismatch: legacy=${legacyPlan.versions.length}, '
          'subcollection=${versionsSnap.docs.length}',
        );
      }

      // Verify each version's days
      for (final versionDoc in versionsSnap.docs) {
        final versionData = PlanVersionDoc.fromJson(versionDoc.data());
        final legacyVersion = legacyPlan.versions.where((v) => v.id == versionData.id).firstOrNull;
        
        if (legacyVersion == null) {
          issues.add('Version ${versionData.id} not found in legacy data');
          continue;
        }

        final daysSnap = await _firestore
            .collection('plans')
            .doc(planId)
            .collection('versions')
            .doc(versionData.id)
            .collection('days')
            .get();

        if (daysSnap.docs.length != legacyVersion.days.length) {
          issues.add(
            'Day count mismatch for version ${versionData.id}: '
            'legacy=${legacyVersion.days.length}, subcollection=${daysSnap.docs.length}',
          );
        }
      }

      return MigrationVerification(
        planId: planId,
        isValid: issues.isEmpty,
        issues: issues,
      );
    } catch (e) {
      debugPrint('Error verifying migration for $planId: $e');
      return MigrationVerification(
        planId: planId,
        isValid: false,
        issues: ['Error during verification: $e'],
      );
    }
  }

  /// Get migration statistics
  Future<MigrationStats> getMigrationStats() async {
    try {
      final plansSnap = await _firestore.collection('plans').get();
      var migratedCount = 0;
      var notMigratedCount = 0;

      for (final doc in plansSnap.docs) {
        final isMigrated = await isPlanMigrated(doc.id);
        if (isMigrated) {
          migratedCount++;
        } else {
          notMigratedCount++;
        }
      }

      return MigrationStats(
        totalPlans: plansSnap.docs.length,
        migratedPlans: migratedCount,
        notMigratedPlans: notMigratedCount,
      );
    } catch (e) {
      debugPrint('Error getting migration stats: $e');
      return MigrationStats(totalPlans: 0, migratedPlans: 0, notMigratedPlans: 0);
    }
  }
}

/// Result of a single plan migration
class MigrationResult {
  final String planId;
  final bool success;
  final String message;
  final int versionsCreated;
  final int daysCreated;

  MigrationResult({
    required this.planId,
    required this.success,
    required this.message,
    required this.versionsCreated,
    required this.daysCreated,
  });

  @override
  String toString() => 'MigrationResult($planId: $message, '
      'versions=$versionsCreated, days=$daysCreated)';
}

/// Verification result for migration integrity
class MigrationVerification {
  final String planId;
  final bool isValid;
  final List<String> issues;

  MigrationVerification({
    required this.planId,
    required this.isValid,
    required this.issues,
  });
}

/// Overall migration statistics
class MigrationStats {
  final int totalPlans;
  final int migratedPlans;
  final int notMigratedPlans;

  MigrationStats({
    required this.totalPlans,
    required this.migratedPlans,
    required this.notMigratedPlans,
  });

  double get migrationProgress => totalPlans > 0 ? migratedPlans / totalPlans : 0;
}
