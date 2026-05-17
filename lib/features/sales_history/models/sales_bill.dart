import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../billing/models/billing_models.dart';

@immutable
class SalesLineItem {
  const SalesLineItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.discountAmount,
    required this.enteredDiscountPercent,
  });

  final String id;
  final String productName;
  final int quantity;

  /// Unit price used for displaying in sales-history details.
  ///
  /// Note: This is derived from backend values and should be treated as
  /// informational only.
  final double unitPrice;

  /// Amount for this line as returned by the API.
  final double lineTotal;

  /// Discount amount for this line as returned by the API.
  ///
  /// This represents the explicit amount reduction (e.g., custom price flow)
  /// or the backend-calculated discount amount.
  final double discountAmount;

  /// Discount percentage *only when the API explicitly provides it*.
  ///
  /// We intentionally do NOT derive a percentage from amounts, because that
  /// would create a “fake” value that the user never entered.
  final double? enteredDiscountPercent;
}

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
  final List<SalesLineItem> items;
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
      items: const <SalesLineItem>[],
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

  static List<SalesLineItem> _parseItems(Object? rawItems) {
    if (rawItems is! List) return const <SalesLineItem>[];

    return rawItems
      .whereType<Map>()
      .map((row) {
        final item = row.cast<String, dynamic>();

        final quantityRaw = item['quantity'];
        final quantity = quantityRaw is int
          ? quantityRaw
          : int.tryParse(quantityRaw?.toString() ?? '') ?? 0;
        final safeQuantity = quantity <= 0 ? 1 : quantity;

          final rawUnitPrice = _parseNullableDouble(
            item['amount'] ?? item['unit_price'] ?? item['rate'],
          );

          final lineTotal = _parseNullableDouble(
                item['total_amount'] ?? item['line_total'],
              ) ??
              0;

          final discountAmount = _parseNullableDouble(
                item['discount_amount'] ??
                    item['discount_rs'] ??
                    item['discount'],
              ) ??
              0;

        final rawDiscountPercent = _parseNullableDouble(
        item['discount_percent'] ??
          item['discountPercent'] ??
          item['discount_percentage'] ??
          item['discountPercentage'],
        );

        final enteredDiscountPercent =
          (rawDiscountPercent == null || rawDiscountPercent <= 0)
            ? null
            : rawDiscountPercent.clamp(0, 100).toDouble();

          final unitPrice = rawUnitPrice ??
            (safeQuantity <= 0
              ? lineTotal
              : (lineTotal / safeQuantity).toDouble());

        return SalesLineItem(
        id: (item['id'] ?? item['type_name'] ?? '').toString(),
        productName: (item['type_name'] ?? '-').toString(),
        quantity: safeQuantity,
        unitPrice: unitPrice,
        lineTotal: lineTotal,
        discountAmount: discountAmount.clamp(0, double.infinity).toDouble(),
        enteredDiscountPercent: enteredDiscountPercent,
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
      subtotalAmount ?? items.fold<double>(0, (sum, i) => sum + i.lineTotal);

    double get totalDiscount =>
      discountAmount ??
      items.fold<double>(0, (sum, i) => sum + i.discountAmount);

  double get total {
    if (totalAmount != null) return totalAmount!;
    if (items.isNotEmpty) {
      return (subtotal - totalDiscount).clamp(0, double.infinity);
    }
    return listAmount ?? 0;
  }
}
