import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

enum StockAlertSeverity { info, warning, critical }

@immutable
class StockAlert {
  const StockAlert({
    required this.id,
    required this.type,
    required this.typeDisplay,
    required this.message,
    required this.createdAt,
    required this.isSeen,
    required this.severity,
    this.displayDate,
    this.displayTime,
  });

  final String id;
  /// Raw API value, e.g. `LOW_STOCK`, `OUT_OF_STOCK`.
  final String type;
  final String typeDisplay;
  final String message;
  final DateTime createdAt;
  final bool isSeen;
  final StockAlertSeverity severity;
  // Optional strings returned by API: keep original display_date/display_time
  final String? displayDate;
  final String? displayTime;

  

  StockAlert copyWith({
    String? id,
    String? type,
    String? typeDisplay,
    String? message,
    DateTime? createdAt,
    bool? isSeen,
    StockAlertSeverity? severity,
    String? displayDate,
    String? displayTime,
  }) {
    return StockAlert(
      id: id ?? this.id,
      type: type ?? this.type,
      typeDisplay: typeDisplay ?? this.typeDisplay,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isSeen: isSeen ?? this.isSeen,
      severity: severity ?? this.severity,
      displayDate: displayDate ?? this.displayDate,
      displayTime: displayTime ?? this.displayTime,
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

  static DateTime _parseCreatedAt(Map<String, dynamic> json) {
    final createdRaw = json['createdAt'] ?? json['created_at'];
    if (createdRaw is String) {
      final parsed = DateTime.tryParse(createdRaw);
      if (parsed != null) return parsed;
    }

    final now = DateTime.now();
    final dateStr = (json['display_date'] ?? '').toString();
    final timeStr = (json['display_time'] ?? '').toString().trim();

    DateTime datePart;
    if (dateStr == 'Today') {
      datePart = DateTime(now.year, now.month, now.day);
    } else if (dateStr == 'Yesterday') {
      final y = now.subtract(const Duration(days: 1));
      datePart = DateTime(y.year, y.month, y.day);
    } else {
      final parsed = DateTime.tryParse(dateStr);
      datePart = parsed ?? DateTime(now.year, now.month, now.day);
    }

    if (timeStr.isEmpty) return datePart;

    try {
      final t = DateFormat.jm().parse(timeStr);
      return DateTime(
        datePart.year,
        datePart.month,
        datePart.day,
        t.hour,
        t.minute,
      );
    } catch (_) {
      return datePart;
    }
  }

  factory StockAlert.fromJson(Map<String, dynamic> json) {
    final createdAt = _parseCreatedAt(json);

    final seenRaw = json['isSeen'] ?? json['seen'] ?? json['is_seen'];
    final isSeen = seenRaw == true || seenRaw == 1 || seenRaw == '1';

    final typeRaw = (json['type'] ?? '').toString().trim();

    return StockAlert(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      type: typeRaw,
      typeDisplay: (json['type_display'] ?? '').toString(),
      message: (json['message'] ?? json['body'] ?? '').toString(),
      createdAt: createdAt,
      isSeen: isSeen,
      severity: _parseSeverity(
        json['severity'] ?? json['level'] ?? json['priority'],
      ),
      displayDate: (json['display_date'] ?? json['displayDate'] ?? '').toString().isEmpty
          ? null
          : (json['display_date'] ?? json['displayDate']).toString(),
      displayTime: (json['display_time'] ?? json['displayTime'] ?? '').toString().isEmpty
          ? null
          : (json['display_time'] ?? json['displayTime']).toString(),
    );
  }
}
