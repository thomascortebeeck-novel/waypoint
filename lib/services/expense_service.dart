import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:waypoint/models/expense_model.dart';

/// Service for trip expenses (Tricount-style) stored at trips/{tripId}/expenses/{expenseId}.
class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _tripsCollection = 'trips';
  static const String _expensesSubcollection = 'expenses';

  /// Stream all expenses for a trip, ordered by created_at descending.
  Stream<List<TripExpense>> streamExpenses(String tripId) {
    return _firestore
        .collection(_tripsCollection)
        .doc(tripId)
        .collection(_expensesSubcollection)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) => _docToExpense(d)).toList();
    }).handleError((e) {
      debugPrint('[ExpenseService] stream error: $e');
    });
  }

  TripExpense _docToExpense(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data()!;
    final withId = Map<String, dynamic>.from(data)..['id'] = d.id;
    return TripExpense.fromJson(withId);
  }

  Future<TripExpense?> getExpense(String tripId, String expenseId) async {
    try {
      final doc = await _firestore
          .collection(_tripsCollection)
          .doc(tripId)
          .collection(_expensesSubcollection)
          .doc(expenseId)
          .get();
      if (!doc.exists || doc.data() == null) return null;
      return _docToExpense(doc);
    } catch (e) {
      debugPrint('[ExpenseService] getExpense error: $e');
      return null;
    }
  }

  Future<String> createExpense(TripExpense expense) async {
    try {
      final ref = _firestore
          .collection(_tripsCollection)
          .doc(expense.tripId)
          .collection(_expensesSubcollection)
          .doc();
      final toSave = expense.copyWith(id: ref.id).toJson();
      await ref.set(toSave);
      return ref.id;
    } catch (e) {
      debugPrint('[ExpenseService] createExpense error: $e');
      rethrow;
    }
  }

  Future<void> updateExpense(TripExpense expense) async {
    try {
      await _firestore
          .collection(_tripsCollection)
          .doc(expense.tripId)
          .collection(_expensesSubcollection)
          .doc(expense.id)
          .update(expense.toJson());
    } catch (e) {
      debugPrint('[ExpenseService] updateExpense error: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(String tripId, String expenseId) async {
    try {
      await _firestore
          .collection(_tripsCollection)
          .doc(tripId)
          .collection(_expensesSubcollection)
          .doc(expenseId)
          .delete();
    } catch (e) {
      debugPrint('[ExpenseService] deleteExpense error: $e');
      rethrow;
    }
  }
}
