import 'package:flutter/foundation.dart';

@immutable
class ProductColor {
  const ProductColor({required this.id, required this.name});

  final int id;
  final String name;

  factory ProductColor.fromJson(Map<String, dynamic> json) {
    final id = int.tryParse((json['id'] ?? 0).toString()) ?? 0;
    final name = (json['name'] ?? json['color'] ?? '').toString().trim();
    return ProductColor(id: id, name: name);
  }
}
