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
  });

  final String id;
  final String name;
  final double unitPrice;
  final String? barcode;
}

@immutable
class BillingLineItem {
  const BillingLineItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.discountPercent,
  });

  final String id;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double discountPercent;

  double get lineSubtotal => unitPrice * quantity;

  double get lineDiscount =>
      lineSubtotal * (discountPercent.clamp(0, 100) / 100);

  double get lineTotal =>
      (lineSubtotal - lineDiscount).clamp(0, double.infinity);

  BillingLineItem copyWith({
    String? id,
    String? productName,
    int? quantity,
    double? unitPrice,
    double? discountPercent,
  }) {
    return BillingLineItem(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discountPercent: discountPercent ?? this.discountPercent,
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
