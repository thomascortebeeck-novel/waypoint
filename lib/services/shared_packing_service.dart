import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:waypoint/models/shared_packing_item_model.dart';

/// Shared packing subcollection: trips/{tripId}/shared_packing.
/// One doc per item; only trip members (and owner) should modify (enforce in rules).
class SharedPackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _sharedPackingRef(String tripId) =>
      _firestore.collection('trips').doc(tripId).collection('shared_packing');

  /// Add a shared item. Returns the new doc id.
  Future<String> addSharedItem({
    required String tripId,
    required String label,
    required String userId,
  }) async {
    final ref = _sharedPackingRef(tripId).doc();
    final item = SharedPackingItem(
      id: ref.id,
      label: label.trim(),
      addedBy: userId,
      checked: false,
      createdAt: DateTime.now(),
    );
    await ref.set(item.toJson());
    return ref.id;
  }

  /// Toggle checked state.
  Future<void> toggleSharedItem({
    required String tripId,
    required String itemId,
    required bool checked,
  }) async {
    await _sharedPackingRef(tripId).doc(itemId).update({'checked': checked});
  }

  /// Remove a shared item.
  Future<void> removeSharedItem({
    required String tripId,
    required String itemId,
  }) async {
    await _sharedPackingRef(tripId).doc(itemId).delete();
  }

  /// Stream all shared packing items for the trip (ordered by created_at).
  Stream<List<SharedPackingItem>> streamSharedPackingItems(String tripId) {
    return _sharedPackingRef(tripId)
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SharedPackingItem.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }
}
