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

      // Plan metadata remains unchanged (no version_summaries needed)

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
