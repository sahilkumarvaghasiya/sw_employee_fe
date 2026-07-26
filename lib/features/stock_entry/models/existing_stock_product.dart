import 'package:flutter/foundation.dart';

import '../../products/models/product.dart';
import 'stock_entry_draft_item.dart';

/// Catalog product selected for restocking (from product details API).
@immutable
class ExistingStockProduct {
  const ExistingStockProduct({
    required this.barcode,
    this.barcodeUrl,
    this.brandId,
    required this.brandName,
    required this.gender,
    required this.isPair,
    this.itemTypeId,
    required this.itemType1,
    this.itemType2,
    required this.variants,
  });

  final String barcode;
  final String? barcodeUrl;
  final String? brandId;
  final String brandName;
  final StockEntryItemGender gender;
  final bool isPair;
  final int? itemTypeId;
  final String itemType1;
  final String? itemType2;
  final List<ExistingStockProductVariant> variants;

  String get displayName {
    final brand = brandName.trim();
    final type = itemType2 != null && itemType2!.trim().isNotEmpty
        ? '$itemType1 / ${itemType2!.trim()}'
        : itemType1;
    if (brand.isEmpty) return type;
    return '$brand • $type';
  }

  /// Maps `/products/details/{id}` (or list row fallback) into a restock model.
  factory ExistingStockProduct.fromProduct(Product product) {
    final variantId = int.tryParse(product.id.trim());
    if (variantId == null) {
      throw FormatException('Invalid product variant id: ${product.id}');
    }

    final size = product.size.trim();
    final colour = product.color.trim();

    return ExistingStockProduct(
      barcode: product.barcode.trim().isEmpty ? product.id : product.barcode,
      brandName: product.companyName,
      gender: _mapGender(product.gender),
      isPair: false,
      itemType1: product.name.trim().isEmpty ? 'Product' : product.name.trim(),
      variants: [
        ExistingStockProductVariant(
          variantId: variantId,
          size: size.isEmpty || size == '—' ? '—' : size,
          colour: colour.isEmpty || colour == '—' ? '—' : colour,
          purchasePrice: product.purchasePrice,
          sellPrice: product.price,
          inStock: product.quantityInStock,
        ),
      ],
    );
  }

  static StockEntryItemGender _mapGender(ProductGender? gender) {
    switch (gender) {
      case ProductGender.boy:
        return StockEntryItemGender.boy;
      case ProductGender.girl:
        return StockEntryItemGender.girl;
      case ProductGender.women:
        return StockEntryItemGender.women;
      case ProductGender.men:
      case null:
        return StockEntryItemGender.men;
    }
  }
}

@immutable
class ExistingStockProductVariant {
  const ExistingStockProductVariant({
    required this.variantId,
    this.sizeId,
    required this.size,
    this.colourId,
    required this.colour,
    this.purchasePrice = 0,
    this.sellPrice = 0,
    this.inStock = 0,
  });

  /// Backend ProductVariant primary key.
  final int variantId;
  final int? sizeId;
  final String size;
  final int? colourId;
  final String colour;
  final double purchasePrice;
  final double sellPrice;
  final int inStock;

  String get label => '$size · $colour';
}
