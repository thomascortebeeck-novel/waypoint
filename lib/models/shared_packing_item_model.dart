import 'package:cloud_firestore/cloud_firestore.dart';

/// One shared packing item for a trip (subcollection trips/{tripId}/shared_packing).
class SharedPackingItem {
  final String id;
  final String label;
  final String addedBy;
  final bool checked;
  final DateTime createdAt;

  const SharedPackingItem({
    required this.id,
    required this.label,
    required this.addedBy,
    required this.checked,
    required this.createdAt,
  });

  factory SharedPackingItem.fromJson(Map<String, dynamic> json) => SharedPackingItem(
        id: json['id'] as String,
        label: json['label'] as String,
        addedBy: json['added_by'] as String,
        checked: json['checked'] as bool? ?? false,
        createdAt: (json['created_at'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'added_by': addedBy,
        'checked': checked,
        'created_at': Timestamp.fromDate(createdAt),
      };

  SharedPackingItem copyWith({
    String? id,
    String? label,
    String? addedBy,
    bool? checked,
    DateTime? createdAt,
  }) =>
      SharedPackingItem(
        id: id ?? this.id,
        label: label ?? this.label,
        addedBy: addedBy ?? this.addedBy,
        checked: checked ?? this.checked,
        createdAt: createdAt ?? this.createdAt,
      );
}
