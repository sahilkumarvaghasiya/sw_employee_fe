import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

@immutable
class TodaySummary {
  const TodaySummary({
    required this.totalSalesToday,
    required this.billsGenerated,
    required this.itemsSold,
  });

  final String totalSalesToday;
  final int billsGenerated;
  final int itemsSold;

  static final NumberFormat _inrFormat = NumberFormat('#,##,##0.00', 'en_IN');

  factory TodaySummary.fromJson(Map<String, dynamic> json) {
    return TodaySummary(
      totalSalesToday: json['total_sales_today']?.toString() ?? '0.00',
      billsGenerated: _toInt(json['bills_generated']),
      itemsSold: _toInt(json['items_sold']),
    );
  }

  String get totalSalesDisplay {
    final normalized = totalSalesToday.replaceAll(',', '').trim();
    final value = double.tryParse(normalized) ?? 0;
    return _inrFormat.format(value);
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }
}

@immutable
class RecentActivityItem {
  const RecentActivityItem({
    required this.billNumber,
    required this.paymentMethod,
    required this.amount,
  });

  final String billNumber;
  final String paymentMethod;
  final String amount;

  static final NumberFormat _inrFormat = NumberFormat('#,##,##0.00', 'en_IN');

  factory RecentActivityItem.fromJson(Map<String, dynamic> json) {
    return RecentActivityItem(
      billNumber: json['bill_number']?.toString() ?? '-',
      paymentMethod: json['payment_method']?.toString() ?? '-',
      amount: json['amount']?.toString() ?? '0.00',
    );
  }

  String get paymentMethodLabel {
    final raw = paymentMethod.trim().toLowerCase();
    if (raw.isEmpty) return '-';

    switch (raw) {
      case 'qr':
        return 'QR';
      default:
        return raw[0].toUpperCase() + raw.substring(1);
    }
  }

  double get amountValue {
    final normalized = amount.replaceAll(',', '').trim();
    return double.tryParse(normalized) ?? 0;
  }

  String get amountDisplay => _inrFormat.format(amountValue);
}

@immutable
class HomeDashboardData {
  const HomeDashboardData({
    required this.todaySummary,
    required this.recentActivity,
  });

  final TodaySummary todaySummary;
  final List<RecentActivityItem> recentActivity;

  factory HomeDashboardData.fromJson(Map<String, dynamic> json) {
    final summaryJson =
        (json['today_summary'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    final activityList = (json['recent_activity'] as List?) ?? const [];

    return HomeDashboardData(
      todaySummary: TodaySummary.fromJson(summaryJson),
      recentActivity: activityList
          .whereType<Map>()
          .map((e) => RecentActivityItem.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }
}
