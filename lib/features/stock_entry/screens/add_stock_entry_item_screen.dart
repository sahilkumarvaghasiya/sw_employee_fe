import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/stock_entry_draft_item.dart';

class AddStockEntryItemScreen extends StatefulWidget {
  const AddStockEntryItemScreen({
    super.key,
    required this.initialBarcode,
    required this.allowBarcodeEdit,
  });

  final String initialBarcode;
  final bool allowBarcodeEdit;

  static Route<StockEntryDraftItem?> route({
    required String initialBarcode,
    required bool allowBarcodeEdit,
  }) {
    return MaterialPageRoute<StockEntryDraftItem?>(
      settings: const RouteSettings(name: '/stock-entry/add-item'),
      builder: (_) => AddStockEntryItemScreen(
        initialBarcode: initialBarcode,
        allowBarcodeEdit: allowBarcodeEdit,
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
  final TextEditingController _sizeController = TextEditingController();
  final TextEditingController _colourController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _sellController = TextEditingController();

  StockEntryItemGender? _gender;
  bool _isPair = false;
  String? _itemType1;
  String? _itemType2;

  static const String _customOption = '__custom__';

  String? _brandSelection;
  bool get _isBrandCustom => _brandSelection == _customOption;

  String? _sizeSelection;
  bool get _isSizeCustom => _sizeSelection == _customOption;

  String? _colourSelection;
  bool get _isColourCustom => _colourSelection == _customOption;

  static const List<String> _brandOptions = <String>[
    'Nova Apparel',
    'UrbanCo',
    'BluePeak',
    'Astra',
    'DashWear',
    'MintMode',
  ];

  static const List<String> _sizeOptions = <String>[
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

  static const List<String> _colourOptions = <String>[
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

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController(text: widget.initialBarcode);

    // Sanitize any state that might be kept across hot reloads.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final nextGender =
          _gender != null && StockEntryItemGender.values.contains(_gender)
          ? _gender
          : null;

      final nextBrand =
          _brandSelection == null ||
              _brandSelection == _customOption ||
              _brandOptions.contains(_brandSelection)
          ? _brandSelection
          : null;

      final nextSize =
          _sizeSelection == null ||
              _sizeSelection == _customOption ||
              _sizeOptions.contains(_sizeSelection)
          ? _sizeSelection
          : null;

      final nextColour =
          _colourSelection == null ||
              _colourSelection == _customOption ||
              _colourOptions.contains(_colourSelection)
          ? _colourSelection
          : null;

      if (nextGender != _gender ||
          nextBrand != _brandSelection ||
          nextSize != _sizeSelection ||
          nextColour != _colourSelection) {
        setState(() {
          _gender = nextGender;
          _brandSelection = nextBrand;
          _sizeSelection = nextSize;
          _colourSelection = nextColour;
        });
      }
    });
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _brandController.dispose();
    _sizeController.dispose();
    _colourController.dispose();
    _qtyController.dispose();
    _costController.dispose();
    _sellController.dispose();
    super.dispose();
  }

  int _qty() => int.tryParse(_qtyController.text.trim()) ?? 0;

  void _setQty(int value) {
    final next = value.clamp(1, 9999);
    _qtyController.text = next.toString();
  }

  void _onGenderChanged(StockEntryItemGender value) {
    setState(() {
      _gender = value;
      if ((_gender == StockEntryItemGender.boy ||
              _gender == StockEntryItemGender.girl) &&
          !_isPair) {
        _isPair = true;
      }
    });
  }

  void _generateBarcode() {
    FocusManager.instance.primaryFocus?.unfocus();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Barcode generation API is not connected yet.'),
        ),
      );
  }

  void _togglePair(bool value) {
    setState(() {
      _isPair = value;
      if (!_isPair) _itemType2 = null;
    });
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    final barcode = _barcodeController.text.trim();
    final brand = _isBrandCustom
        ? _brandController.text.trim()
        : (_brandSelection ?? '').trim();
    final size = _isSizeCustom
        ? _sizeController.text.trim()
        : (_sizeSelection ?? '');
    final colour = _isColourCustom
        ? _colourController.text.trim()
        : (_colourSelection ?? '');

    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    final cost = double.tryParse(_costController.text.trim()) ?? 0;
    final sell = double.tryParse(_sellController.text.trim()) ?? 0;

    final item1 = _itemType1;
    final item2 = _itemType2;

    final gender = _gender;
    if (gender == null) return;

    final result = StockEntryDraftItem(
      barcode: barcode,
      brandName: brand,
      size: size,
      colour: colour,
      gender: gender,
      isPair: _isPair,
      itemType1: item1!,
      itemType2: _isPair ? item2 : null,
      quantity: qty,
      costPrice: cost,
      sellingPrice: sell,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Hot reload can keep old enum/string values in State. If an enum value was
    // removed (ex: Unisex), DropdownButtonFormField will assert unless we
    // sanitize it.
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

    final String? safeSizeSelection =
        _sizeSelection == null ||
            _sizeSelection == _customOption ||
            _sizeOptions.contains(_sizeSelection)
        ? _sizeSelection
        : null;

    final String? safeColourSelection =
        _colourSelection == null ||
            _colourSelection == _customOption ||
            _colourOptions.contains(_colourSelection)
        ? _colourSelection
        : null;

    Widget sectionHeader(String title, {String? subtitle}) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      );
    }

    InputDecoration decoration({
      required String label,
      required IconData icon,
      String? hint,
      String? helper,
      String? prefixText,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        prefixText: prefixText,
        prefixIcon: Icon(icon),
      );
    }

    Widget sectionCard(List<Widget> children) {
      return Card(
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Stock Item'),
        actions: [
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            sectionHeader(
              'Product',
              subtitle: widget.allowBarcodeEdit
                  ? 'Enter barcode and basic product details.'
                  : 'Barcode is already scanned. Fill remaining details.',
            ),
            sectionCard([
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
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
                  ),
                  if (widget.allowBarcodeEdit) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _generateBarcode,
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      label: const Text('Generate'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: safeBrandSelection,
                items: <DropdownMenuItem<String>>[
                  ..._brandOptions.map(
                    (b) => DropdownMenuItem<String>(value: b, child: Text(b)),
                  ),
                  const DropdownMenuItem<String>(
                    value: _customOption,
                    child: Text('Custom entry'),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    _brandSelection = v;
                    if (v != _customOption) {
                      _brandController.text = '';
                    }
                  });
                },
                decoration: decoration(
                  label: 'Brand',
                  icon: Icons.storefront_outlined,
                  helper: 'Select from database or choose custom entry',
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
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<StockEntryItemGender>(
                initialValue: safeGender,
                items: StockEntryItemGender.values
                    .map(
                      (g) => DropdownMenuItem(value: g, child: Text(g.label)),
                    )
                    .toList(growable: false),
                onChanged: (v) {
                  if (v == null) return;
                  _onGenderChanged(v);
                },
                validator: (v) {
                  if (v == null) return 'Gender is required';
                  return null;
                },
                decoration: decoration(
                  label: 'Gender',
                  icon: Icons.wc_outlined,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: safeSizeSelection,
                      items: <DropdownMenuItem<String>>[
                        ..._sizeOptions.map(
                          (s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(s),
                          ),
                        ),
                        const DropdownMenuItem<String>(
                          value: _customOption,
                          child: Text('Custom entry'),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _sizeSelection = v;
                          if (v != _customOption) {
                            _sizeController.text = '';
                          }
                        });
                      },
                      decoration: decoration(
                        label: 'Size',
                        icon: Icons.straighten_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: safeColourSelection,
                      items: <DropdownMenuItem<String>>[
                        ..._colourOptions.map(
                          (c) => DropdownMenuItem<String>(
                            value: c,
                            child: Text(c),
                          ),
                        ),
                        const DropdownMenuItem<String>(
                          value: _customOption,
                          child: Text('Custom entry'),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _colourSelection = v;
                          if (v != _customOption) {
                            _colourController.text = '';
                          }
                        });
                      },
                      decoration: decoration(
                        label: 'Colour',
                        icon: Icons.palette_outlined,
                      ),
                    ),
                  ),
                ],
              ),
              if (_isSizeCustom || _isColourCustom) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _isSizeCustom
                          ? TextFormField(
                              controller: _sizeController,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.next,
                              decoration: decoration(
                                label: 'Enter size',
                                icon: Icons.edit_outlined,
                                hint: 'S / M / L / 30',
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (_isSizeCustom && _isColourCustom)
                      const SizedBox(width: 12),
                    Expanded(
                      child: _isColourCustom
                          ? TextFormField(
                              controller: _colourController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: decoration(
                                label: 'Enter colour',
                                icon: Icons.edit_outlined,
                                hint: 'Example: Blue',
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ]),

            sectionHeader(
              'Item details',
              subtitle: 'Select what type of item this barcode represents.',
            ),
            sectionCard([
              DropdownButtonFormField<String>(
                initialValue: _itemType1,
                items: _itemTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(growable: false),
                onChanged: (v) => setState(() => _itemType1 = v),
                validator: (v) {
                  final raw = v?.trim() ?? '';
                  if (raw.isEmpty) return 'Item type is required';
                  return null;
                },
                decoration: decoration(
                  label: 'Item type',
                  icon: Icons.checkroom_outlined,
                  helper: 'Example: T-Shirt',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isPair,
                onChanged: _togglePair,
                title: const Text('Combo / Pair (2 items)'),
                subtitle: const Text('Example: T-Shirt + Jeans'),
              ),
              if (_isPair) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _itemType2,
                  items: _itemTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(growable: false),
                  onChanged: (v) => setState(() => _itemType2 = v),
                  validator: (v) {
                    if (!_isPair) return null;
                    final raw = v?.trim() ?? '';
                    if (raw.isEmpty) return 'Combo item 2 is required';
                    return null;
                  },
                  decoration: decoration(
                    label: 'Combo item 2',
                    icon: Icons.checkroom_outlined,
                    helper: 'Only for combos',
                  ),
                ),
              ],
            ]),

            sectionHeader(
              'Stock & pricing',
              subtitle: 'Enter quantity, cost price and selling price.',
            ),
            sectionCard([
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Decrease quantity',
                    onPressed: () => _setQty(_qty() - 1),
                    icon: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      decoration: decoration(label: 'Qty', icon: Icons.numbers),
                      validator: (v) {
                        final raw = v?.trim() ?? '';
                        final parsed = int.tryParse(raw);
                        if (parsed == null) return 'Enter qty';
                        if (parsed <= 0) return 'Qty must be > 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Increase quantity',
                    onPressed: () => _setQty(_qty() + 1),
                    icon: const Icon(Icons.add),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: decoration(
                        label: 'Cost price',
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
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sellController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: decoration(
                  label: 'Selling price',
                  icon: Icons.sell_outlined,
                  prefixText: '₹',
                ),
                validator: (v) {
                  final raw = v?.trim() ?? '';
                  final parsed = double.tryParse(raw);
                  if (parsed == null) return 'Enter selling price';
                  if (parsed < 0) return 'Selling cannot be negative';
                  return null;
                },
              ),
            ]),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Cancel'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.add),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Add item'),
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
