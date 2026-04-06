import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/stock_entry_draft_item.dart';
import 'barcode_preview_screen.dart';

class AddStockEntryItemScreen extends StatefulWidget {
  const AddStockEntryItemScreen({
    super.key,
    required this.initialBarcode,
    required this.allowBarcodeEdit,
    this.enableBarcodeGeneration = false,
  });

  final String initialBarcode;
  final bool allowBarcodeEdit;
  final bool enableBarcodeGeneration;

  static Route<List<StockEntryDraftItem>?> route({
    required String initialBarcode,
    required bool allowBarcodeEdit,
    bool enableBarcodeGeneration = false,
  }) {
    return MaterialPageRoute<List<StockEntryDraftItem>?>(
      settings: const RouteSettings(name: '/stock-entry/add-item'),
      builder: (_) => AddStockEntryItemScreen(
        initialBarcode: initialBarcode,
        allowBarcodeEdit: allowBarcodeEdit,
        enableBarcodeGeneration: enableBarcodeGeneration,
      ),
    );
  }

  @override
  State<AddStockEntryItemScreen> createState() =>
      _AddStockEntryItemScreenState();
}

class _AddStockEntryItemScreenState extends State<AddStockEntryItemScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _barcodeController;
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _sellController = TextEditingController();

  StockEntryItemGender? _gender;
  String? _itemType;

  String? _brandSelection;
  bool get _isBrandCustom => _brandSelection == _customOption;

  bool _isGeneratingBarcode = false;

  final _VariantDraftRow _draftRow = _VariantDraftRow();
  final List<_VariantEntry> _entries = <_VariantEntry>[];

  static const String _customOption = '__custom__';

  static const List<String> _brandOptions = <String>[
    'Nova Apparel',
    'UrbanCo',
    'BluePeak',
    'Astra',
    'DashWear',
    'MintMode',
  ];

  static const List<String> _itemTypes = <String>[
    'T-Shirt',
    'Jeans',
    'Shirt',
    'Trouser',
    'Shorts',
    'Top',
    'Frock',
    'Skirt',
    'Kurta',
    'Track Pant',
    'Dress',
    'Other',
  ];

  static const List<String> _sizeOptionsDefault = <String>[
    'XS',
    'S',
    'M',
    'L',
    'XL',
    'XXL',
    '28',
    '30',
    '32',
    '34',
    '36',
    '38',
    '40',
    '42',
    '44',
  ];

  static const List<String> _colourOptionsDefault = <String>[
    'Black',
    'White',
    'Blue',
    'Navy',
    'Grey',
    'Green',
    'Red',
    'Yellow',
    'Pink',
    'Brown',
    'Beige',
    'Purple',
    'Orange',
  ];

  static const String _prefsKeySizes = 'stock_entry_custom_sizes_v1';
  static const String _prefsKeyColours = 'stock_entry_custom_colours_v1';

  List<String> _sizeOptions = List<String>.from(_sizeOptionsDefault);
  List<String> _colourOptions = List<String>.from(_colourOptionsDefault);

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController(text: widget.initialBarcode);
    _loadCustomOptions();
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _brandController.dispose();
    _costController.dispose();
    _sellController.dispose();
    _draftRow.dispose();
    super.dispose();
  }

  Future<void> _loadCustomOptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sizes = prefs.getStringList(_prefsKeySizes) ?? const <String>[];
      final colours = prefs.getStringList(_prefsKeyColours) ?? const <String>[];

      if (!mounted) return;
      setState(() {
        _sizeOptions = _mergeOptions(_sizeOptionsDefault, sizes);
        _colourOptions = _mergeOptions(_colourOptionsDefault, colours);
      });
    } catch (_) {
      // Ignore; defaults will be used.
    }
  }

  List<String> _mergeOptions(List<String> defaults, List<String> custom) {
    final seen = <String>{};
    final out = <String>[];

    void add(String v) {
      final trimmed = v.trim();
      if (trimmed.isEmpty) return;
      final key = trimmed.toLowerCase();
      if (seen.add(key)) out.add(trimmed);
    }

    for (final v in defaults) {
      add(v);
    }
    for (final v in custom) {
      add(v);
    }

    return out;
  }

  Future<void> _persistCustomOptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final customSizes = _sizeOptions
          .where((s) => !_sizeOptionsDefault.contains(s))
          .toList(growable: false);
      final customColours = _colourOptions
          .where((c) => !_colourOptionsDefault.contains(c))
          .toList(growable: false);

      await prefs.setStringList(_prefsKeySizes, customSizes);
      await prefs.setStringList(_prefsKeyColours, customColours);
    } catch (_) {
      // Ignore.
    }
  }

  Future<bool> _maybePersistCustomValue({
    required String kind,
    required String value,
  }) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;

    if (kind == 'size') {
      final exists = _sizeOptions.any(
        (o) => o.toLowerCase() == trimmed.toLowerCase(),
      );
      if (exists) return true;

      final ok = await _confirmNewCustomEntry(kind: 'size', value: trimmed);
      if (!ok) return false;
      setState(() {
        _sizeOptions = [..._sizeOptions, trimmed];
      });
      await _persistCustomOptions();
      return true;
    }

    if (kind == 'colour') {
      final exists = _colourOptions.any(
        (o) => o.toLowerCase() == trimmed.toLowerCase(),
      );
      if (exists) return true;

      final ok = await _confirmNewCustomEntry(kind: 'colour', value: trimmed);
      if (!ok) return false;
      setState(() {
        _colourOptions = [..._colourOptions, trimmed];
      });
      await _persistCustomOptions();
      return true;
    }

    return true;
  }

  Future<void> _addItemToTable() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final size = _draftRow.resolvedSize.trim();
    final colour = _draftRow.resolvedColour.trim();
    final qty = _draftRow.qty;

    if (size.isEmpty) {
      _showSnack('Select a size.');
      return;
    }
    if (colour.isEmpty) {
      _showSnack('Select a colour.');
      return;
    }
    if (qty <= 0) {
      _showSnack('Enter pieces (qty).');
      return;
    }

    if (_draftRow.isSizeCustom) {
      final ok = await _maybePersistCustomValue(kind: 'size', value: size);
      if (!ok) return;
    }
    if (_draftRow.isColourCustom) {
      final ok = await _maybePersistCustomValue(kind: 'colour', value: colour);
      if (!ok) return;
    }

    setState(() {
      _entries.add(_VariantEntry(size: size, colour: colour, qty: qty));
      _draftRow.reset();
    });
  }

  void _removeEntryAt(int index) {
    setState(() {
      _entries.removeAt(index);
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _stubGenerateBarcodeValue() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return '89$ts';
  }

  Future<String> _generateBarcodeFromBackend() async {
    // TODO: Replace with backend API.
    return _stubGenerateBarcodeValue();
  }

  Future<bool> _confirmEntryIsRight() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm entry'),
        content: const Text('Is the entry correct?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<bool> _confirmNewCustomEntry({
    required String kind,
    required String value,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm entry'),
        content: Text('Save "$value" as a new $kind option for future use?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, save'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;
    if (_isGeneratingBarcode) return;

    FocusManager.instance.primaryFocus?.unfocus();

    final gender = _gender;
    if (gender == null) return;

    final itemType = _itemType;
    if (itemType == null || itemType.trim().isEmpty) return;

    final brand = _isBrandCustom
        ? _brandController.text.trim()
        : (_brandSelection ?? '').trim();
    if (brand.isEmpty) return;

    if (_entries.isEmpty) {
      _showSnack('Add at least one item row.');
      return;
    }

    final cost = double.tryParse(_costController.text.trim()) ?? 0;
    final sell = double.tryParse(_sellController.text.trim()) ?? 0;

    // Barcode handling: one barcode for the whole group.
    var finalBarcode = _barcodeController.text.trim();
    if (widget.enableBarcodeGeneration) {
      final confirmed = await _confirmEntryIsRight();
      if (!confirmed) return;

      setState(() => _isGeneratingBarcode = true);
      try {
        final generated = await _generateBarcodeFromBackend();
        finalBarcode = generated.trim();
        _barcodeController.text = finalBarcode;

        if (!mounted) return;
        await Navigator.of(
          context,
        ).push<void>(BarcodePreviewScreen.route(barcode: finalBarcode));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text('Could not generate barcode: $e')),
          );
        return;
      } finally {
        if (mounted) setState(() => _isGeneratingBarcode = false);
      }
    }

    if (finalBarcode.isEmpty) return;

    final out = <StockEntryDraftItem>[];
    for (final row in _entries) {
      out.add(
        StockEntryDraftItem(
          barcode: finalBarcode,
          brandName: brand,
          size: row.size,
          colour: row.colour,
          gender: gender,
          isPair: false,
          itemType1: itemType,
          itemType2: null,
          quantity: row.qty,
          costPrice: cost,
          sellingPrice: sell,
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final StockEntryItemGender? safeGender =
        _gender != null && StockEntryItemGender.values.contains(_gender)
        ? _gender
        : null;

    final String? safeBrandSelection =
        _brandSelection == null ||
            _brandSelection == _customOption ||
            _brandOptions.contains(_brandSelection)
        ? _brandSelection
        : null;

    InputDecoration decoration({
      required String label,
      required IconData icon,
      String? hint,
      String? prefixText,
    }) {
      return InputDecoration(
        isDense: true,
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );
    }

    InputDecoration rowDecoration({required String hint}) {
      return InputDecoration(
        isDense: true,
        hintText: hint,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      );
    }

    Widget sectionCard({
      required IconData icon,
      required String title,
      String? subtitle,
      required List<Widget> children,
    }) {
      return Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withAlpha(28),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.primary.withAlpha(64),
                      ),
                    ),
                    child: Icon(icon, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (subtitle != null && subtitle.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      );
    }

    final subtitle = widget.enableBarcodeGeneration
        ? 'Enter details and generate one barcode for this group.'
        : widget.allowBarcodeEdit
        ? 'Enter barcode and details.'
        : 'Barcode scanned. Fill remaining details.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Stock Items'),
        actions: [
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorScheme.primary.withAlpha(18), colorScheme.surface],
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              sectionCard(
                icon: Icons.inventory_2_outlined,
                title: 'Common details',
                subtitle: subtitle,
                children: [
                  if (!widget.enableBarcodeGeneration) ...[
                    TextFormField(
                      controller: _barcodeController,
                      readOnly: !widget.allowBarcodeEdit,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.next,
                      decoration: decoration(
                        label: 'Barcode',
                        icon: Icons.qr_code_2,
                        hint: 'Example: 8901234567890',
                      ),
                      validator: (v) {
                        final raw = v?.trim() ?? '';
                        if (raw.isEmpty) return 'Barcode is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: safeBrandSelection,
                    isExpanded: true,
                    items: <DropdownMenuItem<String>>[
                      ..._brandOptions.map(
                        (b) => DropdownMenuItem<String>(
                          value: b,
                          child: Text(b, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      const DropdownMenuItem<String>(
                        value: _customOption,
                        child: Text('Custom entry'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _brandSelection = v;
                        if (v != _customOption) _brandController.text = '';
                      });
                    },
                    validator: (v) {
                      final raw = v?.trim() ?? '';
                      if (raw.isEmpty) return 'Brand is required';
                      if (raw == _customOption &&
                          _brandController.text.trim().isEmpty) {
                        return 'Enter brand name';
                      }
                      return null;
                    },
                    decoration: decoration(
                      label: 'Brand',
                      icon: Icons.storefront_outlined,
                    ),
                  ),
                  if (_isBrandCustom) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _brandController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: decoration(
                        label: 'Enter brand name',
                        icon: Icons.edit_outlined,
                        hint: 'Example: Nike',
                      ),
                      validator: (v) {
                        if (!_isBrandCustom) return null;
                        if ((v ?? '').trim().isEmpty) return 'Enter brand name';
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _itemType,
                    isExpanded: true,
                    items: _itemTypes
                        .map(
                          (t) => DropdownMenuItem<String>(
                            value: t,
                            child: Text(t, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (v) => setState(() => _itemType = v),
                    validator: (v) {
                      final raw = v?.trim() ?? '';
                      if (raw.isEmpty) return 'Item type is required';
                      return null;
                    },
                    decoration: decoration(
                      label: 'Item type',
                      icon: Icons.checkroom_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<StockEntryItemGender>(
                    initialValue: safeGender,
                    isExpanded: true,
                    items: StockEntryItemGender.values
                        .map(
                          (g) => DropdownMenuItem<StockEntryItemGender>(
                            value: g,
                            child: Text(
                              g.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (v) => setState(() => _gender = v),
                    validator: (v) => v == null ? 'Gender is required' : null,
                    decoration: decoration(
                      label: 'Gender',
                      icon: Icons.wc_outlined,
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _costController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: decoration(
                            label: 'Cost',
                            icon: Icons.payments_outlined,
                            prefixText: '₹',
                          ),
                          validator: (v) {
                            final raw = v?.trim() ?? '';
                            final parsed = double.tryParse(raw);
                            if (parsed == null) return 'Enter cost';
                            if (parsed <= 0) return 'Cost must be > 0';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _sellController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: decoration(
                            label: 'Selling',
                            icon: Icons.sell_outlined,
                            prefixText: '₹',
                          ),
                          validator: (v) {
                            final raw = v?.trim() ?? '';
                            final parsed = double.tryParse(raw);
                            if (parsed == null) return 'Enter selling';
                            if (parsed < 0) return 'Selling cannot be negative';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              sectionCard(
                icon: Icons.view_list_outlined,
                title: 'Items',
                subtitle: 'Add size, colour and pieces in a row.',
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<String>(
                          initialValue: _draftRow.safeSizeSelection(
                            _sizeOptions,
                          ),
                          isExpanded: true,
                          menuMaxHeight: 360,
                          items: <DropdownMenuItem<String>>[
                            ..._sizeOptions.map(
                              (v) => DropdownMenuItem<String>(
                                value: v,
                                child: Text(v, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            const DropdownMenuItem<String>(
                              value: _customOption,
                              child: Text('Custom entry'),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _draftRow.sizeSelection = v;
                              if (v != _customOption) {
                                _draftRow.sizeController.text = '';
                              }
                            });
                          },
                          decoration: rowDecoration(hint: 'Size'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: DropdownButtonFormField<String>(
                          initialValue: _draftRow.safeColourSelection(
                            _colourOptions,
                          ),
                          isExpanded: true,
                          menuMaxHeight: 360,
                          items: <DropdownMenuItem<String>>[
                            ..._colourOptions.map(
                              (v) => DropdownMenuItem<String>(
                                value: v,
                                child: Text(v, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            const DropdownMenuItem<String>(
                              value: _customOption,
                              child: Text('Custom entry'),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _draftRow.colourSelection = v;
                              if (v != _customOption) {
                                _draftRow.colourController.text = '';
                              }
                            });
                          },
                          decoration: rowDecoration(hint: 'Colour'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 96,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _draftRow.qtyController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              textAlign: TextAlign.center,
                              decoration: rowDecoration(hint: 'Pieces'),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _addItemToTable,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 28),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  textStyle: theme.textTheme.labelSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add item'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_draftRow.isSizeCustom || _draftRow.isColourCustom) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (_draftRow.isSizeCustom)
                          Expanded(
                            child: TextFormField(
                              controller: _draftRow.sizeController,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.next,
                              decoration: decoration(
                                label: 'Enter size',
                                icon: Icons.edit_outlined,
                                hint: 'S / M / L / 30',
                              ),
                            ),
                          ),
                        if (_draftRow.isSizeCustom && _draftRow.isColourCustom)
                          const SizedBox(width: 12),
                        if (_draftRow.isColourCustom)
                          Expanded(
                            child: TextFormField(
                              controller: _draftRow.colourController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: decoration(
                                label: 'Enter colour',
                                icon: Icons.edit_outlined,
                                hint: 'Example: Blue',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                'Size',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 6,
                              child: Text(
                                'Colour',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 96,
                              child: Text(
                                'Pieces',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 36),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_entries.isEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'No items added yet',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          ...List.generate(_entries.length, (i) {
                            final e = _entries[i];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: i == _entries.length - 1 ? 0 : 6,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        e.size,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 6,
                                      child: Text(
                                        e.colour,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 96,
                                      child: Text(
                                        e.qty.toString(),
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete',
                                      visualDensity: VisualDensity.compact,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      onPressed: () => _removeEntryAt(i),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isGeneratingBarcode ? null : _submit,
                  icon: widget.enableBarcodeGeneration
                      ? (_isGeneratingBarcode
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_fix_high_rounded))
                      : const Icon(Icons.add),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      widget.enableBarcodeGeneration
                          ? (_isGeneratingBarcode
                                ? 'Generating...'
                                : 'Generate barcode')
                          : 'Add items',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantDraftRow {
  _VariantDraftRow()
    : qtyController = TextEditingController(text: '1'),
      sizeController = TextEditingController(),
      colourController = TextEditingController();

  String? sizeSelection;
  String? colourSelection;

  final TextEditingController qtyController;
  final TextEditingController sizeController;
  final TextEditingController colourController;

  bool get isSizeCustom =>
      sizeSelection == _AddStockEntryItemScreenState._customOption;
  bool get isColourCustom =>
      colourSelection == _AddStockEntryItemScreenState._customOption;

  int get qty => int.tryParse(qtyController.text.trim()) ?? 0;

  String get resolvedSize =>
      isSizeCustom ? sizeController.text.trim() : (sizeSelection ?? '').trim();

  String get resolvedColour => isColourCustom
      ? colourController.text.trim()
      : (colourSelection ?? '').trim();

  String? safeSizeSelection(List<String> options) {
    final v = sizeSelection;
    if (v == null) return null;
    if (v == _AddStockEntryItemScreenState._customOption) return v;
    return options.contains(v) ? v : null;
  }

  String? safeColourSelection(List<String> options) {
    final v = colourSelection;
    if (v == null) return null;
    if (v == _AddStockEntryItemScreenState._customOption) return v;
    return options.contains(v) ? v : null;
  }

  void reset() {
    sizeSelection = null;
    colourSelection = null;
    sizeController.text = '';
    colourController.text = '';
    qtyController.text = '1';
  }

  void dispose() {
    qtyController.dispose();
    sizeController.dispose();
    colourController.dispose();
  }
}

class _VariantEntry {
  const _VariantEntry({
    required this.size,
    required this.colour,
    required this.qty,
  });

  final String size;
  final String colour;
  final int qty;
}
