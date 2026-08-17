import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Fonts embedded into the label PDF.
///
/// The `pdf` package defaults to the built-in PDF base fonts, which are
/// WinAnsi-encoded and have no rupee glyph — every price printed as `₹300.00`
/// came out as a hollow box. Roboto carries ₹ (and Devanagari-adjacent Latin
/// text), so it is bundled and embedded instead.
class BarcodeLabelFonts {
  const BarcodeLabelFonts({required this.regular, required this.bold});

  final pw.Font regular;
  final pw.Font bold;

  static const _regularAsset = 'assets/fonts/Roboto-Regular.ttf';
  static const _boldAsset = 'assets/fonts/Roboto-Bold.ttf';

  static BarcodeLabelFonts? _cached;
  static Future<BarcodeLabelFonts?>? _pending;

  /// Loads and caches the label fonts.
  ///
  /// Returns null when the assets cannot be read, so printing degrades to the
  /// built-in fonts rather than failing outright — a label with a boxed rupee
  /// sign still beats no label at all.
  static Future<BarcodeLabelFonts?> load() {
    final cached = _cached;
    if (cached != null) return Future<BarcodeLabelFonts?>.value(cached);

    return _pending ??= _loadFromAssets().then((fonts) {
      _cached = fonts;
      _pending = null;
      return fonts;
    });
  }

  static Future<BarcodeLabelFonts?> _loadFromAssets() async {
    try {
      final regular = await rootBundle.load(_regularAsset);
      final bold = await rootBundle.load(_boldAsset);

      return BarcodeLabelFonts(
        regular: pw.Font.ttf(regular),
        bold: pw.Font.ttf(bold),
      );
    } catch (_) {
      return null;
    }
  }

  pw.ThemeData get theme => pw.ThemeData.withFont(base: regular, bold: bold);
}
