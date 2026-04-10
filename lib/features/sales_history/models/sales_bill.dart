import 'package:flutter/foundation.dart';

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
  });

  final String id;
  final String billNo;
  final DateTime createdAt;
  final BillingCustomer customer;
  final List<BillingLineItem> items;
  final BillingPaymentMethod paymentMethod;

  int get itemsCount => items.fold<int>(0, (sum, i) => sum + i.quantity);

  double get subtotal =>
      items.fold<double>(0, (sum, i) => sum + i.lineSubtotal);

  double get totalDiscount =>
      items.fold<double>(0, (sum, i) => sum + i.lineDiscount);

  double get total => (subtotal - totalDiscount).clamp(0, double.infinity);
}
