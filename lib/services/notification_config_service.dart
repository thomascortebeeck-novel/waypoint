import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Push notification config stored at config/notifications.
/// When the doc does not exist, all flags default to true (notifications enabled).
class NotificationConfig {
  final bool pushEnabled;
  final bool checkInEnabled;
  final bool voteResolvedEnabled;

  const NotificationConfig({
    this.pushEnabled = true,
    this.checkInEnabled = true,
    this.voteResolvedEnabled = true,
  });

  static const NotificationConfig defaultConfig = NotificationConfig();

  factory NotificationConfig.fromJson(Map<String, dynamic>? data) {
    if (data == null) return defaultConfig;
    return NotificationConfig(
      pushEnabled: data['pushEnabled'] as bool? ?? true,
      checkInEnabled: data['checkInEnabled'] as bool? ?? true,
      voteResolvedEnabled: data['voteResolvedEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'pushEnabled': pushEnabled,
        'checkInEnabled': checkInEnabled,
        'voteResolvedEnabled': voteResolvedEnabled,
      };

  NotificationConfig copyWith({
    bool? pushEnabled,
    bool? checkInEnabled,
    bool? voteResolvedEnabled,
  }) =>
      NotificationConfig(
        pushEnabled: pushEnabled ?? this.pushEnabled,
        checkInEnabled: checkInEnabled ?? this.checkInEnabled,
        voteResolvedEnabled: voteResolvedEnabled ?? this.voteResolvedEnabled,
      );
}

/// Read/write config/notifications. Missing doc is treated as default (all true).
class NotificationConfigService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _path = 'config/notifications';

  /// One-off read. Returns default config when doc does not exist.
  Future<NotificationConfig> getConfig() async {
    try {
      final snap = await _firestore.doc(_path).get();
      if (!snap.exists || snap.data() == null) return NotificationConfig.defaultConfig;
      return NotificationConfig.fromJson(snap.data());
    } catch (e) {
      debugPrint('[NotificationConfigService] getConfig error: $e');
      return NotificationConfig.defaultConfig;
    }
  }

  /// Stream for real-time updates. When doc does not exist, snapshot still emits;
  /// check snapshot.exists and use default config when false.
  Stream<NotificationConfig> streamConfig() {
    return _firestore.doc(_path).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return NotificationConfig.defaultConfig;
      return NotificationConfig.fromJson(snap.data());
    });
  }

  /// Write config (admin only; Firestore rules enforce).
  Future<void> setConfig(NotificationConfig config) async {
    await _firestore.doc(_path).set(config.toJson(), SetOptions(merge: true));
  }
}
