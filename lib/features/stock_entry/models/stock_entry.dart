import 'package:flutter/foundation.dart';

import 'vendor.dart';

enum PaymentStatus { paid, pending }

@immutable
class StockEntryLineItem {
  const StockEntryLineItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.costPrice,
    required this.sellingPrice,
  });

  final String productId;
  final String productName;
  final int quantity;
  final double costPrice;
  final double sellingPrice;

  double get lineTotal => quantity * costPrice;

  StockEntryLineItem copyWith({
    String? productId,
    String? productName,
    int? quantity,
    double? costPrice,
    double? sellingPrice,
  }) {
    return StockEntryLineItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
    );
  }
}

@immutable
class StockEntryPayment {
  const StockEntryPayment({
    required this.totalPayment,
    required this.paidAmount,
    required this.deadline,
  });

  final double totalPayment;
  final double paidAmount;
  final DateTime? deadline;

  double get remainingAmount {
    final value = totalPayment - paidAmount;
    if (value <= 0) return 0;
    return value;
  }

  PaymentStatus get status =>
      remainingAmount <= 0 ? PaymentStatus.paid : PaymentStatus.pending;

  StockEntryPayment copyWith({
    double? totalPayment,
    double? paidAmount,
    DateTime? deadline,
  }) {
    return StockEntryPayment(
      totalPayment: totalPayment ?? this.totalPayment,
      paidAmount: paidAmount ?? this.paidAmount,
      deadline: deadline ?? this.deadline,
    );
  }
}

@immutable
class StockEntry {
  const StockEntry({
    required this.id,
    this.invoiceNumber,
    this.backendStatus,
    required this.vendor,
    required this.createdAt,
    required this.items,
    required this.payment,
  });

  final String id;
  final String? invoiceNumber;

  /// Raw backend status for history list/details.
  /// Expected values: paid | unpaid | partial (older: half_paid)
  final String? backendStatus;
  final Vendor vendor;
  final DateTime createdAt;
  final List<StockEntryLineItem> items;
  final StockEntryPayment payment;

  int get totalItems => items.fold<int>(0, (sum, item) => sum + item.quantity);

  double get totalStockValue =>
      items.fold<double>(0, (sum, item) => sum + item.lineTotal);
}
