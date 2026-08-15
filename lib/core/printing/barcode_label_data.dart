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

  /// Non-blank subtitle lines, trimmed.
  List<String> get visibleSubtitleLines => subtitleLines
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  /// Subtitle lines capped to what the stock can hold.
  ///
  /// Extra lines are folded into the last permitted one rather than dropped —
  /// a label that silently loses the colour is worse than one that reads
  /// `Size: M · Colour: Red`. Overflowing the cap would push the barcode off
  /// the bottom of a fixed-height label.
  List<String> cappedSubtitleLines(int max) {
    final lines = visibleSubtitleLines;
    if (max <= 0) return const <String>[];
    if (lines.length <= max) return lines;

    return <String>[...lines.take(max - 1), lines.skip(max - 1).join(' · ')];
  }

  bool get hasPrice => (price?.trim() ?? '').isNotEmpty;

  String get trimmedPrice => price?.trim() ?? '';

  /// Name with the subtitle lines folded in — `T-SHIRT · M · Red`.
  ///
  /// Used on stock that is one line short of the full layout. The `Size:` /
  /// `Colour:` prefixes are dropped because the values alone read fine once
  /// they sit beside the item name.
  String get mergedName {
    final parts = visibleSubtitleLines
        .map(_stripAttributePrefix)
        .where((part) => part.isNotEmpty);
    final name = itemName.trim();
    if (parts.isEmpty) return name;
    return <String>[if (name.isNotEmpty) name, ...parts].join(' · ');
  }

  static String _stripAttributePrefix(String line) {
    const prefixes = <String>['size:', 'colour:', 'color:'];
    final lower = line.toLowerCase();
    for (final prefix in prefixes) {
      if (lower.startsWith(prefix)) {
        return line.substring(prefix.length).trim();
      }
    }
    return line;
  }
}
