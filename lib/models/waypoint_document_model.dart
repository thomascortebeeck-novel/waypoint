import 'package:cloud_firestore/cloud_firestore.dart';

/// Document uploaded by trip owner/participant for a waypoint (e.g. booking confirmation).
/// Stored in: trips/{tripId}/waypoint_docs/{docId}
class WaypointDocument {
  final String id;
  final String tripId;
  final int dayNum;
  final String waypointId;
  final String downloadUrl;
  final String fileName;
  final DateTime uploadedAt;
  final String? uploadedBy;

  const WaypointDocument({
    required this.id,
    required this.tripId,
    required this.dayNum,
    required this.waypointId,
    required this.downloadUrl,
    required this.fileName,
    required this.uploadedAt,
    this.uploadedBy,
  });

  factory WaypointDocument.fromJson(Map<String, dynamic> json, String docId, String tripId) {
    final uploadedAt = json['uploaded_at'];
    return WaypointDocument(
      id: docId,
      tripId: tripId,
      dayNum: json['day_num'] as int,
      waypointId: json['waypoint_id'] as String,
      downloadUrl: json['download_url'] as String,
      fileName: json['file_name'] as String? ?? 'document',
      uploadedAt: uploadedAt is Timestamp
          ? (uploadedAt as Timestamp).toDate()
          : DateTime.now(),
      uploadedBy: json['uploaded_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day_num': dayNum,
      'waypoint_id': waypointId,
      'download_url': downloadUrl,
      'file_name': fileName,
      'uploaded_at': Timestamp.fromDate(uploadedAt),
      if (uploadedBy != null) 'uploaded_by': uploadedBy,
    };
  }
}
