import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  static Route<StockEntryDraftItem?> route({
    required String initialBarcode,
    required bool allowBarcodeEdit,
    bool enableBarcodeGeneration = false,
  }) {
    return MaterialPageRoute<StockEntryDraftItem?>(
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
  final TextEditingController _sizeController = TextEditingController();
  final TextEditingController _colourController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _sellController = TextEditingController();

  StockEntryItemGender? _gender;
  String? _itemType1;

  bool _isGeneratingBarcode = false;

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
    });
  }

  String _stubGenerateBarcodeValue() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return '89$ts';
  }

  Future<String> _generateBarcodeFromBackend() async {
    // TODO: Replace this stub with backend API integration.
    // API input: brand/size/colour/gender/itemType/qty/prices etc.
    return _stubGenerateBarcodeValue();
  }

  Future<bool> _confirmEntryIsRight() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm entry'),
        content: const Text('Do your entry is right?'),
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

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    if (_isGeneratingBarcode) return;

    FocusManager.instance.primaryFocus?.unfocus();

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

    final gender = _gender;
    if (gender == null) return;

    var finalBarcode = barcode;
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

    final result = StockEntryDraftItem(
      barcode: finalBarcode,
      brandName: brand,
      size: size,
      colour: colour,
      gender: gender,
      isPair: false,
      itemType1: item1!,
      itemType2: null,
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

    InputDecoration decoration({
      required String label,
      required IconData icon,
      String? hint,
      String? prefixText,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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

    final productSubtitle = widget.enableBarcodeGeneration
        ? 'Enter details and generate barcode.'
        : widget.allowBarcodeEdit
        ? 'Enter barcode and product details.'
        : 'Barcode scanned. Fill remaining details.';

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
                title: 'Product',
                subtitle: productSubtitle,
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
                        child: Text(
                          'Custom entry',
                          overflow: TextOverflow.ellipsis,
                        ),
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
                        final raw = v?.trim() ?? '';
                        if (raw.isEmpty) return 'Enter brand name';
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _itemType1,
                    isExpanded: true,
                    items: _itemTypes
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t, overflow: TextOverflow.ellipsis),
                          ),
                        )
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
                      hint: 'Example: T-Shirt',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<StockEntryItemGender>(
                    initialValue: safeGender,
                    isExpanded: true,
                    items: StockEntryItemGender.values
                        .map(
                          (g) => DropdownMenuItem(
                            value: g,
                            child: Text(
                              g.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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
                          isExpanded: true,
                          items: <DropdownMenuItem<String>>[
                            ..._sizeOptions.map(
                              (s) => DropdownMenuItem<String>(
                                value: s,
                                child: Text(s, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            const DropdownMenuItem<String>(
                              value: _customOption,
                              child: Text(
                                'Custom entry',
                                overflow: TextOverflow.ellipsis,
                              ),
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
                          validator: (v) {
                            final raw = v?.trim() ?? '';
                            if (raw.isEmpty) return 'Size is required';
                            if (raw == _customOption &&
                                _sizeController.text.trim().isEmpty) {
                              return 'Enter size';
                            }
                            return null;
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
                          isExpanded: true,
                          items: <DropdownMenuItem<String>>[
                            ..._colourOptions.map(
                              (c) => DropdownMenuItem<String>(
                                value: c,
                                child: Text(c, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                            const DropdownMenuItem<String>(
                              value: _customOption,
                              child: Text(
                                'Custom entry',
                                overflow: TextOverflow.ellipsis,
                              ),
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
                          validator: (v) {
                            final raw = v?.trim() ?? '';
                            if (raw.isEmpty) return 'Colour is required';
                            if (raw == _customOption &&
                                _colourController.text.trim().isEmpty) {
                              return 'Enter colour';
                            }
                            return null;
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
                    if (_isSizeCustom && _isColourCustom)
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _sizeController,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.next,
                              decoration: decoration(
                                label: 'Enter size',
                                icon: Icons.edit_outlined,
                                hint: 'S / M / L / 30',
                              ),
                              validator: (v) {
                                if (!_isSizeCustom) return null;
                                final raw = v?.trim() ?? '';
                                if (raw.isEmpty) return 'Enter size';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _colourController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: decoration(
                                label: 'Enter colour',
                                icon: Icons.edit_outlined,
                                hint: 'Example: Blue',
                              ),
                              validator: (v) {
                                if (!_isColourCustom) return null;
                                final raw = v?.trim() ?? '';
                                if (raw.isEmpty) return 'Enter colour';
                                return null;
                              },
                            ),
                          ),
                        ],
                      )
                    else if (_isSizeCustom)
                      TextFormField(
                        controller: _sizeController,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.next,
                        decoration: decoration(
                          label: 'Enter size',
                          icon: Icons.edit_outlined,
                          hint: 'S / M / L / 30',
                        ),
                        validator: (v) {
                          if (!_isSizeCustom) return null;
                          final raw = v?.trim() ?? '';
                          if (raw.isEmpty) return 'Enter size';
                          return null;
                        },
                      )
                    else
                      TextFormField(
                        controller: _colourController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: decoration(
                          label: 'Enter colour',
                          icon: Icons.edit_outlined,
                          hint: 'Example: Blue',
                        ),
                        validator: (v) {
                          if (!_isColourCustom) return null;
                          final raw = v?.trim() ?? '';
                          if (raw.isEmpty) return 'Enter colour';
                          return null;
                        },
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              sectionCard(
                icon: Icons.payments_outlined,
                title: 'Stock & pricing',
                subtitle: 'Quantity, cost price and selling price.',
                children: [
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
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          textAlign: TextAlign.center,
                          decoration: decoration(
                            label: 'Qty',
                            icon: Icons.numbers,
                          ),
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
                          : 'Add item',
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
