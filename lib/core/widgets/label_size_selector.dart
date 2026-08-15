import 'package:flutter/material.dart';

import '../printing/barcode_label_layout.dart';
import '../printing/label_size_preference.dart';

/// Label-roll picker that owns its own persistence: it loads the saved size on
/// mount, reports it to the parent, and writes back on every change.
///
/// Screens therefore only have to hold the value they are handed and pass the
/// matching layout to the printer.
class LabelSizeSelector extends StatefulWidget {
  const LabelSizeSelector({
    super.key,
    required this.onChanged,
    this.preference,
  });

  final ValueChanged<BarcodeLabelSize> onChanged;

  /// Injectable for tests; defaults to the shared-preferences store.
  final LabelSizePreference? preference;

  @override
  State<LabelSizeSelector> createState() => _LabelSizeSelectorState();
}

class _LabelSizeSelectorState extends State<LabelSizeSelector> {
  late final LabelSizePreference _preference =
      widget.preference ?? LabelSizePreference();
  BarcodeLabelSize _size = BarcodeLabelSize.mm50x38;

  @override
  void initState() {
    super.initState();
    _restoreSavedSize();
  }

  Future<void> _restoreSavedSize() async {
    final saved = await _preference.load();
    if (!mounted) return;
    setState(() => _size = saved);
    widget.onChanged(saved);
  }

  Future<void> _select(BarcodeLabelSize size) async {
    if (size == _size) return;
    setState(() => _size = size);
    widget.onChanged(size);
    await _preference.save(size);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Label size',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        // Scrolls rather than overflows: three segments are wider than a
        // narrow phone once the text scale is turned up.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<BarcodeLabelSize>(
            segments: BarcodeLabelSize.values
                .map(
                  (size) => ButtonSegment<BarcodeLabelSize>(
                    value: size,
                    label: Text(size.shortLabel),
                  ),
                )
                .toList(growable: false),
            selected: <BarcodeLabelSize>{_size},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => _select(selection.first),
          ),
        ),
      ],
    );
  }
}
