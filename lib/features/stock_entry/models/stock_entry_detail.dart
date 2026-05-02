import 'package:flutter/foundation.dart';

enum StockEntryStatus { paid, unpaid, partial }

StockEntryStatus _parseStatus(Object? value) {
  final raw = (value ?? '').toString().trim().toLowerCase();
  switch (raw) {
    case 'paid':
      return StockEntryStatus.paid;
    case 'unpaid':
      return StockEntryStatus.unpaid;
    case 'partial':
      return StockEntryStatus.partial;
    default:
      return StockEntryStatus.partial;
  }
}

DateTime? _parseDdMmYyyyDate(Object? value) {
  if (value == null) return null;
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;

  // Expected: dd-MM-yyyy, but also accept yyyy-MM-dd.
  final parts = raw.split('-');
  if (parts.length != 3) return DateTime.tryParse(raw);

  // yyyy-MM-dd
  if (parts[0].length == 4) {
    final yyyy = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    final dd = int.tryParse(parts[2]);
    if (dd == null || mm == null || yyyy == null) return null;
    return DateTime(yyyy, mm, dd);
  }

  // dd-MM-yyyy
  final dd = int.tryParse(parts[0]);
  final mm = int.tryParse(parts[1]);
  final yyyy = int.tryParse(parts[2]);
  if (dd == null || mm == null || yyyy == null) return null;
  return DateTime(yyyy, mm, dd);
}

double _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  var raw = (value ?? '').toString().trim();
  if (raw.isEmpty) return 0;
  raw = raw.replaceAll(',', '');
  return double.tryParse(raw) ?? 0;
}

int _toInt(Object? value) {
  if (value is num) return value.toInt();
  final raw = (value ?? '').toString().trim();
  if (raw.isEmpty) return 0;
  return int.tryParse(raw) ?? 0;
}

@immutable
class StockEntryDetailVariant {
  const StockEntryDetailVariant({
    required this.size,
    required this.color,
    required this.actualPrice,
    required this.quantity,
  });

  final String size;
  final String color;
  final double? actualPrice;
  final int quantity;

  factory StockEntryDetailVariant.fromJson(Map<String, dynamic> json) {
    final actualRaw = json['actual_price'];
    final actual = actualRaw == null ? null : _toDouble(actualRaw);

    return StockEntryDetailVariant(
      size: (json['size'] ?? json['variant_size'] ?? '—').toString(),
      color: (json['color'] ?? json['colour'] ?? '—').toString(),
      actualPrice: actual,
      quantity: _toInt(json['quantity'] ?? json['pieces']),
    );
  }
}

@immutable
class StockEntryDetailProduct {
  const StockEntryDetailProduct({
    required this.productName,
    required this.companyName,
    required this.gender,
    required this.variants,
  });

  final String productName;
  final String companyName;
  final String gender;
  final List<StockEntryDetailVariant> variants;

  factory StockEntryDetailProduct.fromJson(Map<String, dynamic> json) {
    final variantsRaw = json['variants'];
    final variants = <StockEntryDetailVariant>[];
    if (variantsRaw is List) {
      for (final v in variantsRaw) {
        if (v is Map<String, dynamic>) {
          variants.add(StockEntryDetailVariant.fromJson(v));
        }
      }
    }

    return StockEntryDetailProduct(
      productName: (json['product_name'] ?? '').toString(),
      companyName: (json['company_name'] ?? '').toString(),
      gender: (json['gender'] ?? '').toString(),
      variants: List.unmodifiable(variants),
    );
  }
}

@immutable
class StockEntryDetail {
  const StockEntryDetail({
    required this.invoiceNumber,
    required this.createdDate,
    required this.vendorName,
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.paymentDeadline,
    required this.status,
    required this.products,
  });

  final String invoiceNumber;
  final DateTime createdDate;
  final String vendorName;

  final double totalAmount;
  final double paidAmount;
  final double pendingAmount;
  final DateTime? paymentDeadline;

  final StockEntryStatus status;
  final List<StockEntryDetailProduct> products;

  factory StockEntryDetail.fromJson(Map<String, dynamic> json) {
    final created = _parseDdMmYyyyDate(json['created_date']) ?? DateTime.now();
    final deadline = _parseDdMmYyyyDate(json['payment_deadline']);

    final productsRaw = json['products'];
    final products = <StockEntryDetailProduct>[];
    if (productsRaw is List) {
      for (final p in productsRaw) {
        if (p is Map<String, dynamic>) {
          products.add(StockEntryDetailProduct.fromJson(p));
        }
      }
    }

    return StockEntryDetail(
      invoiceNumber: (json['invoice_number'] ?? '').toString(),
      createdDate: created,
      vendorName: (json['vendor_name'] ?? '').toString(),
      totalAmount: _toDouble(json['total_amount']),
      paidAmount: _toDouble(json['paid_amount']),
      pendingAmount: _toDouble(json['pending_amount']),
      paymentDeadline: deadline,
      status: _parseStatus(json['status']),
      products: List.unmodifiable(products),
    );
  }
}
