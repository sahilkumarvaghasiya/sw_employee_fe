import 'package:flutter/foundation.dart';

import '../../../core/utils/product_size_format.dart';

@immutable
class ProductSize {
  const ProductSize({required this.id, required this.name});

  final int id;
  final String name;

  factory ProductSize.fromJson(Map<String, dynamic> json) {
    final id = int.tryParse((json['id'] ?? 0).toString()) ?? 0;
    final name = formatProductSize(
      (json['name'] ?? json['size'] ?? '').toString(),
    );
    return ProductSize(id: id, name: name);
  }
}
