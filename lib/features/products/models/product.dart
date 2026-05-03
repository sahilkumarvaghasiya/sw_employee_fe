import 'package:flutter/foundation.dart';

enum ProductGender { men, women, boy, girl }

@immutable
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.quantityInStock,
    required this.size,
    required this.color,
    required this.companyName,
    required this.price,
    required this.gender,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String barcode;
  final int quantityInStock;
  final String size;
  final String color;
  final String companyName;
  final double price;
  final ProductGender gender;
  final DateTime createdAt;

  /// List API model mapping for `/api/products/list/`.
  ///
  /// Backend fields used:
  /// - id
  /// - product_name
  /// - company_name
  /// - size
  /// - final_price
  factory Product.fromVariantListJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    final name =
        (json['product_name'] ?? json['productName'] ?? json['name'] ?? '')
            .toString();
    final companyName = (json['company_name'] ?? json['companyName'] ?? '')
        .toString();
    final size = (json['size'] ?? '').toString().trim();
    final colorRaw = json['color'];
    final colorStr = colorRaw == null ? '' : colorRaw.toString().trim();

    final rawPrice =
        json['final_price'] ?? json['finalPrice'] ?? json['price'] ?? 0;
    final price = _toDouble(rawPrice);

    // These are not currently returned by the list serializer, so keep safe defaults.
    final barcode = (json['barcode_number'] ?? json['barcode'] ?? id)
        .toString();
    final quantityInStock = _toInt(
      json['quantity'] ?? json['quantityInStock'] ?? 0,
    );

    final genderRaw = (json['gender'] ?? json['product_gender'] ?? '')
        .toString();
    final gender = _parseGender(genderRaw) ?? ProductGender.men;

    final createdRaw = (json['created_at'] ?? json['createdAt'] ?? '')
        .toString();
    final createdAt = DateTime.tryParse(createdRaw) ?? DateTime.now();

    return Product(
      id: id,
      name: name,
      barcode: barcode,
      quantityInStock: quantityInStock,
      size: size.isEmpty ? '—' : size,
      color: colorStr.isEmpty ? '—' : colorStr,
      companyName: companyName,
      price: price,
      gender: gender,
      createdAt: createdAt,
    );
  }

  /// Details API model mapping for `/api/products/details/{id}`.
  ///
  /// Response can be either the object itself or wrapped under keys like
  /// `data`, `result`, `product`, or `details`.
  factory Product.fromDetailsJson(Map<String, dynamic> json) {
    final wrapped = _unwrapDetailsPayload(json);

    final id = (wrapped['id'] ?? wrapped['product_id'] ?? '').toString();
    final name =
        (wrapped['product_name'] ??
                wrapped['productName'] ??
                wrapped['name'] ??
                '')
            .toString();
    final companyName =
        (wrapped['company_name'] ??
                wrapped['companyName'] ??
                wrapped['brand_name'] ??
                '')
            .toString();

    final barcode = (wrapped['barcode_number'] ?? wrapped['barcode'] ?? id)
        .toString();

    final size =
        (wrapped['size'] ??
                wrapped['size_name'] ??
                wrapped['variant_size'] ??
                '—')
            .toString()
            .trim();

    final colorVal = wrapped['color'];
    final colorStr =
        colorVal == null ? '' : colorVal.toString().trim();

    final rawPrice =
        wrapped['final_price'] ??
        wrapped['finalPrice'] ??
        wrapped['price'] ??
        wrapped['sellprice'] ??
        0;
    final price = _toDouble(rawPrice);

    final quantityInStock = _toInt(
      wrapped['quantity'] ??
          wrapped['quantity_in_stock'] ??
          wrapped['quantityInStock'] ??
          wrapped['stock'] ??
          0,
    );

    final genderRaw = (wrapped['gender'] ?? wrapped['product_gender'] ?? '')
        .toString();
    final gender = _parseGender(genderRaw) ?? ProductGender.men;

    final createdRaw = (wrapped['created_at'] ?? wrapped['createdAt'] ?? '')
        .toString();
    final createdAt = DateTime.tryParse(createdRaw) ?? DateTime.now();

    return Product(
      id: id,
      name: name,
      barcode: barcode,
      quantityInStock: quantityInStock,
      size: size.isEmpty ? '—' : size,
      color: colorStr.isEmpty ? '—' : colorStr,
      companyName: companyName,
      price: price,
      gender: gender,
      createdAt: createdAt,
    );
  }

  static Map<String, dynamic> _unwrapDetailsPayload(Map<String, dynamic> json) {
    final candidates = <String>['data', 'result', 'product', 'details'];
    for (final key in candidates) {
      final value = json[key];
      if (value is Map<String, dynamic>) return value;
    }
    return json;
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    var s = (value ?? 0).toString().trim();
    // Allow API strings like "₹1,50,000" / Indian grouping before parsing.
    s = s.replaceAll(RegExp(r'[₹\s,]'), '');
    return double.tryParse(s) ?? 0.0;
  }

  static int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? 0).toString()) ?? 0;
  }

  static ProductGender? _parseGender(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return null;

    switch (v) {
      case 'men':
      case 'man':
      case 'male':
        return ProductGender.men;
      case 'women':
      case 'woman':
      case 'female':
        return ProductGender.women;
      case 'boy':
        return ProductGender.boy;
      case 'girl':
        return ProductGender.girl;
    }
    return null;
  }
}

extension ProductGenderLabel on ProductGender {
  String get label {
    switch (this) {
      case ProductGender.men:
        return 'Men';
      case ProductGender.women:
        return 'Women';
      case ProductGender.boy:
        return 'Boy';
      case ProductGender.girl:
        return 'Girl';
    }
  }
}
