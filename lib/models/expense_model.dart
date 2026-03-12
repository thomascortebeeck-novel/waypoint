import 'package:cloud_firestore/cloud_firestore.dart';

/// How the expense is split among participants.
enum ExpenseSplitType {
  equal,
  amounts,
  parts,
}

/// A single expense entry for a trip (Tricount-style).
class TripExpense {
  final String id;
  final String tripId;
  /// Display title (e.g. "Drinks", "Dinner").
  final String title;
  /// Total amount in the expense currency.
  final double amount;
  /// Currency code (e.g. "EUR", "USD").
  final String currencyCode;
  /// User ID of the person who paid.
  final String paidByUserId;
  /// Date of the expense (when it occurred).
  final DateTime date;
  final ExpenseSplitType splitType;
  /// User IDs included in the split (owner + members who are in this expense).
  final List<String> participantIds;
  /// For splitType == amounts: userId -> amount per person.
  final Map<String, double> splitAmounts;
  /// For splitType == parts: userId -> part multiplier (e.g. 1, 2 for "double share").
  final Map<String, int> splitParts;
  /// Optional emoji or icon key for display.
  final String? iconKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TripExpense({
    required this.id,
    required this.tripId,
    required this.title,
    required this.amount,
    required this.currencyCode,
    required this.paidByUserId,
    required this.date,
    required this.splitType,
    required this.participantIds,
    this.splitAmounts = const {},
    this.splitParts = const {},
    this.iconKey,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TripExpense.fromJson(Map<String, dynamic> json) {
    final splitTypeStr = json['split_type'] as String? ?? 'equal';
    final splitType = ExpenseSplitType.values.firstWhere(
      (e) => e.name == splitTypeStr,
      orElse: () => ExpenseSplitType.equal,
    );
    final amountsRaw = json['split_amounts'] as Map<String, dynamic>? ?? {};
    final partsRaw = json['split_parts'] as Map<String, dynamic>? ?? {};
    return TripExpense(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      title: json['title'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currencyCode: json['currency_code'] as String? ?? 'EUR',
      paidByUserId: json['paid_by_user_id'] as String? ?? '',
      date: (json['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      splitType: splitType,
      participantIds: List<String>.from(json['participant_ids'] ?? []),
      splitAmounts: amountsRaw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
      splitParts: partsRaw.map((k, v) => MapEntry(k.toString(), v is int ? v : (v as num).toInt())),
      iconKey: json['icon_key'] as String?,
      createdAt: (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'trip_id': tripId,
        'title': title,
        'amount': amount,
        'currency_code': currencyCode,
        'paid_by_user_id': paidByUserId,
        'date': Timestamp.fromDate(date),
        'split_type': splitType.name,
        'participant_ids': participantIds,
        if (splitAmounts.isNotEmpty) 'split_amounts': splitAmounts,
        if (splitParts.isNotEmpty) 'split_parts': splitParts,
        if (iconKey != null) 'icon_key': iconKey,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
      };

  TripExpense copyWith({
    String? id,
    String? tripId,
    String? title,
    double? amount,
    String? currencyCode,
    String? paidByUserId,
    DateTime? date,
    ExpenseSplitType? splitType,
    List<String>? participantIds,
    Map<String, double>? splitAmounts,
    Map<String, int>? splitParts,
    String? iconKey,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      TripExpense(
        id: id ?? this.id,
        tripId: tripId ?? this.tripId,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        currencyCode: currencyCode ?? this.currencyCode,
        paidByUserId: paidByUserId ?? this.paidByUserId,
        date: date ?? this.date,
        splitType: splitType ?? this.splitType,
        participantIds: participantIds ?? this.participantIds,
        splitAmounts: splitAmounts ?? this.splitAmounts,
        splitParts: splitParts ?? this.splitParts,
        iconKey: iconKey ?? this.iconKey,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
