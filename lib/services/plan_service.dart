import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:waypoint/models/plan_model.dart';

class PlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'plans';

  /// Get all published plans
  Future<List<Plan>> getAllPlans() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('is_published', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();
      
      return snapshot.docs
          .map((doc) => Plan.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting all plans: $e');
      return [];
    }
  }

  /// Get featured plans
  Future<List<Plan>> getFeaturedPlans() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('is_published', isEqualTo: true)
          .where('is_featured', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .limit(20)
          .get();
      
      return snapshot.docs
          .map((doc) => Plan.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting featured plans: $e');
      return [];
    }
  }

  /// Get discover plans (curated by admin)
  Future<List<Plan>> getDiscoverPlans() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('is_published', isEqualTo: true)
          .where('is_discover', isEqualTo: true)
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();
      return snapshot.docs.map((doc) => Plan.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting discover plans: $e');
      return [];
    }
  }

  /// Get plan by ID
  Future<Plan?> getPlanById(String planId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(planId).get();
      if (!doc.exists) return null;
      return Plan.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error getting plan: $e');
      return null;
    }
  }

  /// Get plans by creator
  Future<List<Plan>> getPlansByCreator(String creatorId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('creator_id', isEqualTo: creatorId)
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();
      
      return snapshot.docs
          .map((doc) => Plan.fromJson(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting plans by creator: $e');
      return [];
    }
  }

  /// Get plans by IDs (for purchased plans)
  Future<List<Plan>> getPlansByIds(List<String> planIds) async {
    if (planIds.isEmpty) return [];
    
    try {
      // Firestore 'in' queries support max 30 items
      final chunks = <List<String>>[];
      for (var i = 0; i < planIds.length; i += 30) {
        chunks.add(planIds.sublist(
          i, 
          i + 30 > planIds.length ? planIds.length : i + 30
        ));
      }

      final plans = <Plan>[];
      for (final chunk in chunks) {
        final snapshot = await _firestore
            .collection(_collection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        
        plans.addAll(
          snapshot.docs.map((doc) => Plan.fromJson(doc.data()))
        );
      }
      
      return plans;
    } catch (e) {
      debugPrint('Error getting plans by IDs: $e');
      return [];
    }
  }

  /// Create a new plan
  Future<String> createPlan(Plan plan) async {
    try {
      // Ensure the stored document ID matches the 'id' field
      final docRef = _firestore.collection(_collection).doc();
      final planWithId = plan.copyWith(id: docRef.id);
      await docRef.set(planWithId.toJson());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating plan: $e');
      rethrow;
    }
  }

  /// Update a plan
  Future<void> updatePlan(Plan plan) async {
    try {
      await _firestore.collection(_collection).doc(plan.id).update(
        plan.copyWith(updatedAt: DateTime.now()).toJson(),
      );
    } catch (e) {
      debugPrint('Error updating plan: $e');
      rethrow;
    }
  }

  /// Delete a plan
  Future<void> deletePlan(String planId) async {
    try {
      await _firestore.collection(_collection).doc(planId).delete();
    } catch (e) {
      debugPrint('Error deleting plan: $e');
      rethrow;
    }
  }

  /// Stream all published plans
  Stream<List<Plan>> streamAllPlans() {
    return _firestore
        .collection(_collection)
        .where('is_published', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => 
          snapshot.docs.map((doc) => Plan.fromJson(doc.data())).toList()
        );
  }

  /// Stream featured plans
  Stream<List<Plan>> streamFeaturedPlans() {
    return _firestore
        .collection(_collection)
        .where('is_featured', isEqualTo: true)
        .where('is_published', isEqualTo: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          // Sort in memory since we can't use orderBy without composite index
          final plans = snapshot.docs.map((doc) => Plan.fromJson(doc.data())).toList();
          plans.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return plans;
        });
  }

  /// Stream discover plans
  Stream<List<Plan>> streamDiscoverPlans() {
    return _firestore
        .collection(_collection)
        .where('is_discover', isEqualTo: true)
        .where('is_published', isEqualTo: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          // Sort in memory since we can't use orderBy without composite index
          final plans = snapshot.docs.map((doc) => Plan.fromJson(doc.data())).toList();
          plans.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return plans;
        });
  }

  /// Stream plans created by a specific user
  Stream<List<Plan>> streamPlansByCreator(String creatorId) {
    return _firestore
        .collection(_collection)
        .where('creator_id', isEqualTo: creatorId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Plan.fromJson(doc.data())).toList());
  }
}
