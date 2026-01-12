import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:waypoint/models/order_model.dart';

/// Service for managing orders and purchases
class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _ordersCollection = 'orders';

  /// Create a new order with pending status
  /// Note: Purchasing a plan grants access to ALL versions
  Future<OrderModel> createOrder({
    required String planId,
    required String buyerId,
    required String sellerId,
    required double amount,
  }) async {
    try {
      final orderId = OrderModel.generateOrderId();
      final now = DateTime.now();

      final order = OrderModel(
        id: orderId,
        planId: planId,
        buyerId: buyerId,
        sellerId: sellerId,
        amount: amount,
        status: OrderStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore.collection(_ordersCollection).doc(orderId).set(order.toJson());
      return order;
    } catch (e) {
      debugPrint('Error creating order: $e');
      rethrow;
    }
  }

  /// Update order status to processing
  Future<void> setOrderProcessing(String orderId) async {
    try {
      await _firestore.collection(_ordersCollection).doc(orderId).update({
        'status': OrderStatus.processing.name,
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating order to processing: $e');
      rethrow;
    }
  }

  /// Complete the order (simulated payment success)
  /// This updates the order, increments plan sales count, and adds to user's purchased plans
  Future<void> completeOrder(String orderId) async {
    try {
      final orderDoc = await _firestore.collection(_ordersCollection).doc(orderId).get();
      if (!orderDoc.exists) throw Exception('Order not found');

      final order = OrderModel.fromJson(orderDoc.data()!);
      final transactionId = 'TXN-${DateTime.now().millisecondsSinceEpoch}';

      await _firestore.runTransaction((transaction) async {
        final planRef = _firestore.collection('plans').doc(order.planId);
        final planDoc = await transaction.get(planRef);

        if (!planDoc.exists) throw Exception('Plan not found');

        final currentSalesCount = (planDoc.data()?['sales_count'] as num?)?.toInt() ?? 0;

        // Update order to completed
        transaction.update(_firestore.collection(_ordersCollection).doc(orderId), {
          'status': OrderStatus.completed.name,
          'transaction_id': transactionId,
          'updated_at': Timestamp.now(),
        });

        // Increment plan sales count
        transaction.update(planRef, {
          'sales_count': currentSalesCount + 1,
        });

        // Add to user's purchased plans subcollection
        // Note: Purchase grants access to ALL versions of the plan
        final purchasedPlan = PurchasedPlanModel(
          planId: order.planId,
          orderId: orderId,
          purchasedAt: DateTime.now(),
        );

        transaction.set(
          _firestore
              .collection('users')
              .doc(order.buyerId)
              .collection('purchasedPlans')
              .doc(order.planId),
          purchasedPlan.toJson(),
        );

        // Also add to the user's purchased_plan_ids array for backward compatibility
        transaction.update(_firestore.collection('users').doc(order.buyerId), {
          'purchased_plan_ids': FieldValue.arrayUnion([order.planId]),
          'updated_at': Timestamp.now(),
        });
      });
    } catch (e) {
      debugPrint('Error completing order: $e');
      rethrow;
    }
  }

  /// Fail the order
  Future<void> failOrder(String orderId) async {
    try {
      await _firestore.collection(_ordersCollection).doc(orderId).update({
        'status': OrderStatus.failed.name,
        'updated_at': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error failing order: $e');
      rethrow;
    }
  }

  /// Check if user has purchased a plan
  Future<bool> hasPurchased(String userId, String planId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('purchasedPlans')
          .doc(planId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking purchase: $e');
      return false;
    }
  }

  /// Stream purchase status for a plan
  Stream<bool> streamPurchaseStatus(String userId, String planId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('purchasedPlans')
        .doc(planId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Get order by ID
  Future<OrderModel?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore.collection(_ordersCollection).doc(orderId).get();
      if (!doc.exists) return null;
      return OrderModel.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error getting order: $e');
      return null;
    }
  }

  /// Get user's orders
  Future<List<OrderModel>> getUserOrders(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_ordersCollection)
          .where('buyer_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => OrderModel.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting user orders: $e');
      return [];
    }
  }
}
