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
    this.availableQuantity,
    this.size,
  });

  final String id;
  final String productName;
  final int quantity;
  final double originalUnitPrice;
  final double unitPrice;
  final double discountPercent;
  final int? availableQuantity;
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
    int? availableQuantity,
    String? size,
  }) {
    return BillingLineItem(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      originalUnitPrice: originalUnitPrice ?? this.originalUnitPrice,
      unitPrice: unitPrice ?? this.unitPrice,
      discountPercent: discountPercent ?? this.discountPercent,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      size: size ?? this.size,
    );
  }
}

enum BillingPaymentMethod { cash, card, qr }

@immutable
class BillingQrConfig {
  const BillingQrConfig({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String imageUrl;
}
