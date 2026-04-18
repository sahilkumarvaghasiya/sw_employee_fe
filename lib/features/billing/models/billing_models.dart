import 'package:flutter/foundation.dart';

@immutable
class BillingCustomer {
  const BillingCustomer({
    required this.name,
    required this.phone,
    this.address,
  });

  final String name;
  final String phone;
  final String? address;
}

@immutable
class BillingProduct {
  const BillingProduct({
    required this.id,
    required this.name,
    required this.unitPrice,
    this.barcode,
    this.size,
    this.companyName,
    this.availableQuantity,
  });

  final String id;
  final String name;
  final double unitPrice;
  final String? barcode;
  final String? size;
  final String? companyName;
  final int? availableQuantity;
}

@immutable
class BillingLineItem {
  const BillingLineItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.originalUnitPrice,
    required this.unitPrice,
    required this.discountPercent,
    this.size,
  });

  final String id;
  final String productName;
  final int quantity;
  final double originalUnitPrice;
  final double unitPrice;
  final double discountPercent;
  final String? size;

  double get lineSubtotal => unitPrice * quantity;

  double get lineDiscount =>
      lineSubtotal * (discountPercent.clamp(0, 100) / 100);

  double get lineTotal =>
      (lineSubtotal - lineDiscount).clamp(0, double.infinity);

  BillingLineItem copyWith({
    String? id,
    String? productName,
    int? quantity,
    double? originalUnitPrice,
    double? unitPrice,
    double? discountPercent,
    String? size,
  }) {
    return BillingLineItem(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      originalUnitPrice: originalUnitPrice ?? this.originalUnitPrice,
      unitPrice: unitPrice ?? this.unitPrice,
      discountPercent: discountPercent ?? this.discountPercent,
      size: size ?? this.size,
    );
  }
}

enum BillingPaymentMethod { cash, paytm, upi, card }

@immutable
class PaytmQrCode {
  const PaytmQrCode({required this.id, required this.label});

  final String id;
  final String label;
}

@immutable
class UpiQrCode {
  const UpiQrCode({required this.id, required this.label});

  final String id;
  final String label;
}
