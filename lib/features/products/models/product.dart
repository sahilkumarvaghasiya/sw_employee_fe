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
