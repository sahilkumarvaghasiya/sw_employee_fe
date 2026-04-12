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

    final rawPrice =
        json['final_price'] ?? json['finalPrice'] ?? json['price'] ?? 0;
    final price = _toDouble(rawPrice);

    // These are not currently returned by the list serializer, so keep safe defaults.
    final barcode = (json['qr_code_number'] ?? json['barcode'] ?? id)
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
      companyName: companyName,
      price: price,
      gender: gender,
      createdAt: createdAt,
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? 0).toString()) ?? 0.0;
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
