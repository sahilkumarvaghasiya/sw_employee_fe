import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../billing/models/billing_models.dart';

@immutable
class SalesBill {
  const SalesBill({
    required this.id,
    required this.billNo,
    required this.createdAt,
    required this.customer,
    required this.items,
    required this.paymentMethod,
    this.listAmount,
  });

  final String id;
  final String billNo;
  final DateTime createdAt;
  final BillingCustomer customer;
  final List<BillingLineItem> items;
  final BillingPaymentMethod paymentMethod;
  final double? listAmount;

  static final DateFormat _apiCreatedTimeFormat = DateFormat(
    'MMM d, yyyy, hh:mm a',
    'en_US',
  );

  factory SalesBill.fromHistoryListJson(Map<String, dynamic> json) {
    return SalesBill(
      id: (json['id'] ?? json['bill_number'] ?? '').toString(),
      billNo: (json['bill_number'] ?? '-').toString(),
      createdAt: _parseCreatedTime(json['created_time']),
      customer: BillingCustomer(
        name: (json['customer_name'] ?? '-').toString(),
        phone: (json['phone_number'] ?? '-').toString(),
      ),
      items: const <BillingLineItem>[],
      paymentMethod: _paymentMethodFromRaw(json['payment_method']),
      listAmount: _parseNullableDouble(json['amount']),
    );
  }

  static DateTime _parseCreatedTime(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return DateTime.now();

    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;

    try {
      return _apiCreatedTimeFormat.parse(raw);
    } catch (_) {
      return DateTime.now();
    }
  }

  static BillingPaymentMethod _paymentMethodFromRaw(Object? value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';
    switch (raw) {
      case 'cash':
        return BillingPaymentMethod.cash;
      case 'card':
        return BillingPaymentMethod.card;
      case 'paytm':
        return BillingPaymentMethod.paytm;
      case 'upi':
        return BillingPaymentMethod.upi;
      case 'qr':
      default:
        return BillingPaymentMethod.qr;
    }
  }

  static double? _parseNullableDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final normalized = value.toString().replaceAll(',', '').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  int get itemsCount => items.fold<int>(0, (sum, i) => sum + i.quantity);

  double get subtotal =>
      items.fold<double>(0, (sum, i) => sum + i.lineSubtotal);

  double get totalDiscount =>
      items.fold<double>(0, (sum, i) => sum + i.lineDiscount);

  double get total {
    if (items.isNotEmpty) {
      return (subtotal - totalDiscount).clamp(0, double.infinity);
    }
    return listAmount ?? 0;
  }
}
