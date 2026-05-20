import 'package:flutter/foundation.dart';

@immutable
class ProductSize {
  const ProductSize({required this.id, required this.name});

  final int id;
  final String name;

  factory ProductSize.fromJson(Map<String, dynamic> json) {
    final id = int.tryParse((json['id'] ?? 0).toString()) ?? 0;
    final name = (json['name'] ?? json['size'] ?? '').toString().trim();
    return ProductSize(id: id, name: name);
  }
}
