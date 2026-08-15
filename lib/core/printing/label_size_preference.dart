import 'package:shared_preferences/shared_preferences.dart';

import 'barcode_label_layout.dart';

/// Remembers which label roll the shop stocks, so the size is picked once and
/// every later print uses it without asking again.
class LabelSizePreference {
  static const _key = 'barcode_label_size';

  Future<BarcodeLabelSize> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return BarcodeLabelSizeInfo.fromStorageKey(prefs.getString(_key));
    } catch (_) {
      return BarcodeLabelSize.mm50x38;
    }
  }

  Future<void> save(BarcodeLabelSize size) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, size.storageKey);
    } catch (_) {
      // A failed write only costs the shop one re-pick next launch.
    }
  }
}
