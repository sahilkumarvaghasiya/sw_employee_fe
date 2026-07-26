import 'package:flutter/foundation.dart';

enum StockEntryItemGender { boy, girl, men, women }

extension StockEntryItemGenderLabel on StockEntryItemGender {
  String get label {
    switch (this) {
      case StockEntryItemGender.boy:
        return 'Boy';
      case StockEntryItemGender.girl:
        return 'Girl';
      case StockEntryItemGender.men:
        return 'Men';
      case StockEntryItemGender.women:
        return 'Women';
    }
  }
}

@immutable
class StockEntryDraftItem {
  const StockEntryDraftItem({
    required this.barcode,
    this.barcodeUrl,
    this.brandId,
    required this.brandName,
    this.sizeId,
    required this.size,
    this.colourId,
    required this.colour,
    required this.gender,
    required this.isPair,
    this.itemTypeId,
    required this.itemType1,
    required this.itemType2,
    required this.quantity,
    required this.costPrice,
    required this.sellingPrice,
    this.isExisting = false,
    this.variantId,
    this.costPriceOverride,
    this.sellingPriceOverride,
  });

  final String barcode;
  final String? barcodeUrl;
  final String? brandId;
  final String brandName;
  final int? sizeId;
  final String size;
  final int? colourId;
  final String colour;
  final StockEntryItemGender gender;

  final bool isPair;
  final int? itemTypeId;
  final String itemType1;
  final String? itemType2;

  final int quantity;
  final double costPrice;
  final double sellingPrice;

  /// Restock path — maps to backend `is_existing`.
  final bool isExisting;

  /// Backend `ProductVariant` PK — required when [isExisting] is true.
  final int? variantId;

  /// When set, sent as `purchase_price` for existing products; otherwise omitted.
  final double? costPriceOverride;

  /// When set, sent as `sellprice` for existing products; otherwise omitted.
  final double? sellingPriceOverride;
}
