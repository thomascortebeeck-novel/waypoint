import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus { pending, processing, completed, failed }

/// Represents a purchase order for a plan
/// Note: Purchasing a plan gives access to ALL versions of that plan
class OrderModel {
  final String id;
  final String planId;
  final String buyerId;
  final String sellerId;
  final double amount;
  final OrderStatus status;
  final String? transactionId;
  final String? idempotencyKey;
  final String? stripePaymentIntentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderModel({
    required this.id,
    required this.planId,
    required this.buyerId,
    required this.sellerId,
    required this.amount,
    required this.status,
    this.transactionId,
    this.idempotencyKey,
    this.stripePaymentIntentId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      planId: json['plan_id'] as String,
      buyerId: json['buyer_id'] as String,
      sellerId: json['seller_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: OrderStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OrderStatus.pending,
      ),
      transactionId: json['transaction_id'] as String?,
      idempotencyKey: json['idempotency_key'] as String?,
      stripePaymentIntentId: json['stripe_payment_intent_id'] as String?,
      createdAt: (json['created_at'] as Timestamp).toDate(),
      updatedAt: (json['updated_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plan_id': planId,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'amount': amount,
      'status': status.name,
      'transaction_id': transactionId,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (stripePaymentIntentId != null) 'stripe_payment_intent_id': stripePaymentIntentId,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  OrderModel copyWith({
    String? id,
    String? planId,
    String? buyerId,
    String? sellerId,
    double? amount,
    OrderStatus? status,
    String? transactionId,
    String? idempotencyKey,
    String? stripePaymentIntentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      buyerId: buyerId ?? this.buyerId,
      sellerId: sellerId ?? this.sellerId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      transactionId: transactionId ?? this.transactionId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      stripePaymentIntentId: stripePaymentIntentId ?? this.stripePaymentIntentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Generate a unique order ID
  static String generateOrderId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch.toString().substring(10);
    return 'WP-$timestamp-$random';
  }
}

/// Represents a user's favorite plan
class FavoriteModel {
  final String planId;
  final DateTime savedAt;
  final String? note;

  FavoriteModel({
    required this.planId,
    required this.savedAt,
    this.note,
  });

  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    return FavoriteModel(
      planId: json['plan_id'] as String,
      savedAt: (json['saved_at'] as Timestamp).toDate(),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan_id': planId,
      'saved_at': Timestamp.fromDate(savedAt),
      if (note != null) 'note': note,
    };
  }
}

/// Represents proof of purchase for a plan
/// Note: Purchase grants access to ALL versions of the plan
class PurchasedPlanModel {
  final String planId;
  final String orderId;
  final DateTime purchasedAt;

  PurchasedPlanModel({
    required this.planId,
    required this.orderId,
    required this.purchasedAt,
  });

  factory PurchasedPlanModel.fromJson(Map<String, dynamic> json) {
    return PurchasedPlanModel(
      planId: json['plan_id'] as String,
      orderId: json['order_id'] as String,
      purchasedAt: (json['purchased_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan_id': planId,
      'order_id': orderId,
      'purchased_at': Timestamp.fromDate(purchasedAt),
    };
  }
}
