import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../billing/models/billing_models.dart';

enum WhatsAppBillStatus {
  pending,
  sent,
  failed;

  static WhatsAppBillStatus fromRaw(String? raw) {
    return switch (raw?.toLowerCase().trim()) {
      'sent' => WhatsAppBillStatus.sent,
      'failed' => WhatsAppBillStatus.failed,
      _ => WhatsAppBillStatus.pending,
    };
  }

  String get label => switch (this) {
    WhatsAppBillStatus.pending => 'Pending',
    WhatsAppBillStatus.sent => 'Sent',
    WhatsAppBillStatus.failed => 'Failed',
  };
}

@immutable
class SalesLineItem {
  const SalesLineItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.finalUnitPrice,
    required this.lineTotal,
    required this.discountAmount,
    required this.enteredDiscountPercent,
    this.isReturn = false,
  });

  final String id;
  final String productName;
  final int quantity;

  /// Original (actual) unit price shown on the bill.
  ///
  /// Note: This is derived from backend values and should be treated as
  /// informational only. Magnitude only — use [isReturn] for sign.
  final double unitPrice;

  /// Per-unit price actually charged after item discount / custom price.
  ///
  /// May be negative for return lines when the API already signed the amount.
  final double finalUnitPrice;

  /// Whether this line is a product return (refund).
  final bool isReturn;

  /// Catalog original line total, signed like live billing.
  double get signedOriginalLineTotal {
    final original = unitPrice.abs() * quantity;
    return isReturn ? -original : original;
  }

  /// Whether this sale line was sold below its original price.
  ///
  /// Return lines compare magnitudes only — flipping a price to negative is
  /// not a discount.
  bool get hasUnitPriceReduction {
    if (isReturn) {
      return (unitPrice.abs() - finalUnitPrice.abs()) > 0.0001;
    }
    return (unitPrice - finalUnitPrice) > 0.0001;
  }

  /// Amount for this line as returned by the API.
  final double lineTotal;

  /// Discount amount for this line as returned by the API.
  ///
  /// This represents the explicit amount reduction (e.g., custom price flow)
  /// or the backend-calculated discount amount.
  final double discountAmount;

  /// Real markdown shown for this line (ignores return sign-flip artifacts).
  double get displayDiscountAmount {
    if (isReturn) {
      final catalog = unitPrice.abs() * quantity;
      final charged = lineTotal.abs();
      final savings = catalog - charged;
      return savings > 0.0001 ? savings : 0;
    }
    return discountAmount;
  }

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
    this.whatsappStatus = WhatsAppBillStatus.pending,
    this.listAmount,
    this.originalTotalAmount,
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
  final WhatsAppBillStatus whatsappStatus;
  final double? listAmount;
  final double? originalTotalAmount;
  final double? subtotalAmount;
  final double? discountAmount;
  final double? totalAmount;

  SalesBill copyWith({
    String? id,
    String? billNo,
    DateTime? createdAt,
    BillingCustomer? customer,
    List<SalesLineItem>? items,
    BillingPaymentMethod? paymentMethod,
    WhatsAppBillStatus? whatsappStatus,
    double? listAmount,
    double? originalTotalAmount,
    double? subtotalAmount,
    double? discountAmount,
    double? totalAmount,
  }) {
    return SalesBill(
      id: id ?? this.id,
      billNo: billNo ?? this.billNo,
      createdAt: createdAt ?? this.createdAt,
      customer: customer ?? this.customer,
      items: items ?? this.items,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      whatsappStatus: whatsappStatus ?? this.whatsappStatus,
      listAmount: listAmount ?? this.listAmount,
      originalTotalAmount: originalTotalAmount ?? this.originalTotalAmount,
      subtotalAmount: subtotalAmount ?? this.subtotalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }

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
      whatsappStatus: WhatsAppBillStatus.fromRaw(
        json['whatsapp_status']?.toString(),
      ),
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
      whatsappStatus: WhatsAppBillStatus.fromRaw(
        json['whatsapp_status']?.toString(),
      ),
      listAmount: _parseNullableDouble(json['total_amount']),
      originalTotalAmount: _parseNullableDouble(json['original_total']),
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
            item['original_amount'] ??
                item['amount'] ??
                item['unit_price'] ??
                item['rate'],
          );

          final lineTotal = _parseNullableDouble(
                item['total_amount'] ?? item['line_total'],
              ) ??
              0;

          final rawFinalUnitPrice = _parseNullableDouble(item['final_amount']);

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

          final finalUnitPrice = rawFinalUnitPrice ??
            (safeQuantity <= 0
              ? lineTotal
              : (lineTotal / safeQuantity).toDouble());

          final unitPrice = (rawUnitPrice ?? finalUnitPrice).abs();

          final isReturnFlag = item['is_return'] == true ||
              item['is_return']?.toString().toLowerCase().trim() == 'true' ||
              item['isReturn'] == true;
          final isReturn = isReturnFlag || lineTotal < -0.0001;

        return SalesLineItem(
        id: (item['id'] ?? item['type_name'] ?? '').toString(),
        productName: (item['type_name'] ?? '-').toString(),
        quantity: safeQuantity,
        unitPrice: unitPrice,
        finalUnitPrice: finalUnitPrice,
        lineTotal: lineTotal,
        discountAmount: discountAmount.clamp(0, double.infinity).toDouble(),
        enteredDiscountPercent: enteredDiscountPercent,
        isReturn: isReturn,
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

  bool get hasReturnItems => items.any((i) => i.isReturn);

  /// Sum of each item's original (actual) price × qty, before discount.
  ///
  /// When the bill includes returns, originals are signed (sale +, return −)
  /// so they stay consistent with [subtotal] / refund math. Unsigned API
  /// `original_total` must not be mixed with a signed negative subtotal.
  double get originalTotal {
    if (hasReturnItems && items.isNotEmpty) {
      return items.fold<double>(
        0,
        (sum, i) => sum + i.signedOriginalLineTotal,
      );
    }
    return originalTotalAmount ??
        items.fold<double>(0, (sum, i) => sum + i.unitPrice * i.quantity);
  }

  /// Per-item markdowns on sale lines only. Return sign-flips are not savings.
  double get itemSavings => items.fold<double>(0, (sum, i) {
        if (i.isReturn) return sum;
        final originalLine = i.unitPrice * i.quantity;
        final savings = originalLine - i.lineTotal;
        return sum + (savings > 0.0001 ? savings : 0);
      });

  /// Whether any real item-level savings exist on sale lines.
  bool get hasItemSavings => itemSavings > 0.0001;

  double get subtotal =>
      subtotalAmount ?? items.fold<double>(0, (sum, i) => sum + i.lineTotal);

    double get totalDiscount {
      if (subtotalAmount != null && totalAmount != null) {
        return (subtotalAmount! - totalAmount!).clamp(0, double.infinity);
      }
      if (discountAmount != null) return discountAmount!;
      return items.fold<double>(0, (sum, i) => sum + i.discountAmount);
    }

  double get total {
    if (totalAmount != null) return totalAmount!;
    if (items.isNotEmpty) {
      return (subtotal - totalDiscount).clamp(0, double.infinity);
    }
    return listAmount ?? 0;
  }
}
