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
    required this.size,
    required this.colour,
    required this.gender,
    required this.isPair,
    required this.itemType1,
    required this.itemType2,
    required this.quantity,
    required this.costPrice,
    required this.sellingPrice,
  });

  final String barcode;
  final String? barcodeUrl;
  final String? brandId;
  final String brandName;
  final String size;
  final String colour;
  final StockEntryItemGender gender;

  final bool isPair;
  final String itemType1;
  final String? itemType2;

  final int quantity;
  final double costPrice;
  final double sellingPrice;
}
