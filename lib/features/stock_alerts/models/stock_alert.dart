import 'package:flutter/foundation.dart';

enum StockAlertSeverity { info, warning, critical }

@immutable
class StockAlert {
  const StockAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isSeen,
    required this.severity,
  });

  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isSeen;
  final StockAlertSeverity severity;

  StockAlert copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isSeen,
    StockAlertSeverity? severity,
  }) {
    return StockAlert(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isSeen: isSeen ?? this.isSeen,
      severity: severity ?? this.severity,
    );
  }

  static StockAlertSeverity _parseSeverity(Object? raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    switch (value) {
      case 'critical':
      case 'high':
        return StockAlertSeverity.critical;
      case 'warning':
      case 'medium':
        return StockAlertSeverity.warning;
      default:
        return StockAlertSeverity.info;
    }
  }

  factory StockAlert.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['createdAt'] ?? json['created_at'];
    DateTime createdAt;
    if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    final seenRaw = json['isSeen'] ?? json['seen'] ?? json['is_seen'];
    final isSeen = seenRaw == true || seenRaw == 1 || seenRaw == '1';

    return StockAlert(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? 'Stock alert').toString(),
      message: (json['message'] ?? json['body'] ?? '').toString(),
      createdAt: createdAt,
      isSeen: isSeen,
      severity: _parseSeverity(json['severity'] ?? json['level']),
    );
  }
}
