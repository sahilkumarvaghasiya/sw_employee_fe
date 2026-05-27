class BarcodeLabelData {
  const BarcodeLabelData({
    required this.itemName,
    required this.barcode,
    this.price,
    this.subtitleLines = const <String>[],
  });

  final String itemName;
  final String barcode;
  final String? price;
  final List<String> subtitleLines;
}
