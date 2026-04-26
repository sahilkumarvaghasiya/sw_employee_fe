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
    this.subtotalAmount,
    this.discountAmount,
    this.totalAmount,
  });

  final String id;
  final String billNo;
  final DateTime createdAt;
  final BillingCustomer customer;
  final List<BillingLineItem> items;
  final BillingPaymentMethod paymentMethod;
  final double? listAmount;
  final double? subtotalAmount;
  final double? discountAmount;
  final double? totalAmount;

  static final DateFormat _apiCreatedTimeFormat = DateFormat(
    'MMM d, yyyy, hh:mm a',
    'en_US',
  );

  factory SalesBill.fromHistoryListJson(Map<String, dynamic> json) {
    return SalesBill(
      id:
          (json['id'] ??
                  json['bill_id'] ??
                  json['list_uuid'] ??
                  json['uuid'] ??
                  json['bill_number'] ??
                  '')
              .toString(),
      billNo: (json['bill_number'] ?? '-').toString(),
      createdAt: _parseCreatedTime(json['created_time']),
      customer: BillingCustomer(
        name: (json['customer_name'] ?? '-').toString(),
        phone: (json['phone_number'] ?? '-').toString(),
      ),
      items: const <BillingLineItem>[],
      paymentMethod: _paymentMethodFromRaw(json['payment_method']),
      listAmount: _parseNullableDouble(json['amount']),
      totalAmount: _parseNullableDouble(json['amount']),
    );
  }

  factory SalesBill.fromHistoryDetailsJson(Map<String, dynamic> json) {
    final parsedItems = _parseItems(json['items']);

    return SalesBill(
      id:
          (json['id'] ??
                  json['bill_id'] ??
                  json['list_uuid'] ??
                  json['uuid'] ??
                  json['bill_number'] ??
                  '')
              .toString(),
      billNo: (json['bill_number'] ?? '-').toString(),
      createdAt: _parseCreatedTime(json['created_time']),
      customer: BillingCustomer(
        name: (json['customer_name'] ?? '-').toString(),
        phone: (json['phone_number'] ?? '-').toString(),
      ),
      items: parsedItems,
      paymentMethod: _paymentMethodFromRaw(json['payment_method']),
      listAmount: _parseNullableDouble(json['total_amount']),
      subtotalAmount: _parseNullableDouble(json['subtotal']),
      discountAmount: _parseNullableDouble(json['discount_rs']),
      totalAmount: _parseNullableDouble(json['total_amount']),
    );
  }

  static List<BillingLineItem> _parseItems(Object? rawItems) {
    if (rawItems is! List) return const <BillingLineItem>[];

    return rawItems
        .whereType<Map>()
        .map((row) {
          final item = row.cast<String, dynamic>();

          final quantityRaw = item['quantity'];
          final quantity = quantityRaw is int
              ? quantityRaw
              : int.tryParse(quantityRaw?.toString() ?? '') ?? 0;
          final safeQuantity = quantity <= 0 ? 1 : quantity;

          final lineSubtotal = _parseNullableDouble(item['amount']) ?? 0;
          final lineDiscount = _parseNullableDouble(item['discount']) ?? 0;

          final unitPrice = safeQuantity == 0
              ? lineSubtotal
              : lineSubtotal / safeQuantity;

          final discountPercent = lineSubtotal <= 0
              ? 0.0
              : ((lineDiscount / lineSubtotal) * 100).clamp(0, 100).toDouble();

          return BillingLineItem(
            id: (item['id'] ?? item['type_name'] ?? '').toString(),
            productName: (item['type_name'] ?? '-').toString(),
            quantity: safeQuantity,
            originalUnitPrice: unitPrice,
            unitPrice: unitPrice,
            discountPercent: discountPercent,
          );
        })
        .toList(growable: false);
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
      subtotalAmount ?? items.fold<double>(0, (sum, i) => sum + i.lineSubtotal);

  double get totalDiscount =>
      discountAmount ?? items.fold<double>(0, (sum, i) => sum + i.lineDiscount);

  double get total {
    if (totalAmount != null) return totalAmount!;
    if (items.isNotEmpty) {
      return (subtotal - totalDiscount).clamp(0, double.infinity);
    }
    return listAmount ?? 0;
  }
}
