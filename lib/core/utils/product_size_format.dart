/// Formats clothing/product size labels for display (always uppercase).
String formatProductSize(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '—') return trimmed;
  return trimmed.toUpperCase();
}

/// Same as [formatProductSize] but returns null for empty input.
String? formatProductSizeOrNull(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed == '—') return trimmed;
  return trimmed.toUpperCase();
}
