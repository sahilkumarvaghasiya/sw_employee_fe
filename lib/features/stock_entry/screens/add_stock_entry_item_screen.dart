import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/stock_entry_draft_item.dart';
import '../services/stock_entry_service.dart';
import 'barcode_preview_screen.dart';

class AddStockEntryItemScreen extends StatefulWidget {
  const AddStockEntryItemScreen({
    super.key,
    required this.initialBarcode,
    required this.allowBarcodeEdit,
    this.initialDrafts,
    this.enableBarcodeGeneration = false,
  });

  final String initialBarcode;
  final bool allowBarcodeEdit;
  final List<StockEntryDraftItem>? initialDrafts;
  final bool enableBarcodeGeneration;

  static Route<List<StockEntryDraftItem>?> route({
    required String initialBarcode,
    required bool allowBarcodeEdit,
    List<StockEntryDraftItem>? initialDrafts,
    bool enableBarcodeGeneration = false,
  }) {
    return MaterialPageRoute<List<StockEntryDraftItem>?>(
      settings: const RouteSettings(name: '/stock-entry/add-item'),
      builder: (_) => AddStockEntryItemScreen(
        initialBarcode: initialBarcode,
        allowBarcodeEdit: allowBarcodeEdit,
        initialDrafts: initialDrafts,
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

  final GlobalKey _commonSectionKey = GlobalKey();
  final GlobalKey _itemsSectionKey = GlobalKey();

  late final TextEditingController _barcodeController;
  final TextEditingController _brandController = TextEditingController();

  StockEntryItemGender? _gender;
  String? _itemType;

  String? _brandSelection;
  bool get _isBrandCustom => _brandSelection == _customOption;

  bool _isGeneratingBarcode = false;
  String? _barcodeUrl;

  final _VariantDraftRow _draftRow = _VariantDraftRow();
  final List<_VariantEntry> _entries = <_VariantEntry>[];

  final FocusNode _sellFocusNode = FocusNode();
  bool _programmaticSellTextUpdate = false;
  double? _sellUnitPrice;

  int? _editingIndex;

  bool _commonExpanded = true;
  bool _itemsExpanded = true;

  final MenuController _sizeMenuController = MenuController();
  final MenuController _colourMenuController = MenuController();

  void _ensureVisible(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: 0.05,
      );
    });
  }

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
    final prefill = widget.initialDrafts;
    final initialBarcode = (prefill != null && prefill.isNotEmpty)
        ? prefill.first.barcode
        : widget.initialBarcode;

    _barcodeController = TextEditingController(text: initialBarcode);
    _loadCustomOptions();

    if (prefill != null && prefill.isNotEmpty) {
      _prefillFromDrafts(prefill);
    }

    _sellUnitPrice = double.tryParse(_draftRow.sellController.text.trim());
    _draftRow.sellController.addListener(_onSellTextChanged);
    _draftRow.qtyController.addListener(_onQtyChanged);
    _sellFocusNode.addListener(_onSellFocusChanged);
  }

  void _prefillFromDrafts(List<StockEntryDraftItem> drafts) {
    final first = drafts.first;

    _barcodeUrl = first.barcodeUrl;

    _gender = first.gender;
    _itemType = first.itemType1;

    final brand = first.brandName.trim();
    if (brand.isEmpty) {
      _brandSelection = null;
      _brandController.text = '';
    } else if (_brandOptions.contains(brand)) {
      _brandSelection = brand;
      _brandController.text = '';
    } else {
      _brandSelection = _customOption;
      _brandController.text = brand;
    }

    _entries
      ..clear()
      ..addAll(
        drafts.map(
          (d) => _VariantEntry(
            size: d.size,
            colour: d.colour,
            qty: d.quantity,
            sellUnit: d.sellingPrice,
          ),
        ),
      );

    _commonExpanded = true;
    _itemsExpanded = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_entries.isEmpty) return;
      _startEditEntry(0);
    });
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _brandController.dispose();
    _draftRow.sellController.removeListener(_onSellTextChanged);
    _draftRow.qtyController.removeListener(_onQtyChanged);
    _sellFocusNode.removeListener(_onSellFocusChanged);
    _sellFocusNode.dispose();
    _draftRow.dispose();
    super.dispose();
  }

  String _formatPriceValue(double value) {
    final whole = (value - value.truncateToDouble()).abs() < 0.000001;
    return whole ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  double _currentSellTotal() {
    final qty = _draftRow.qty;
    final unit = _sellUnitPrice ?? 0;
    if (qty <= 0) return 0;
    return unit * qty;
  }

  void _setSellText(String value) {
    _programmaticSellTextUpdate = true;
    _draftRow.sellController.text = value;
    _draftRow.sellController.selection = TextSelection.collapsed(
      offset: value.length,
    );
    _programmaticSellTextUpdate = false;
  }

  void _onSellTextChanged() {
    if (_programmaticSellTextUpdate) return;
    if (!_sellFocusNode.hasFocus) return;

    final raw = _draftRow.sellController.text.trim();
    if (raw.isEmpty) {
      setState(() => _sellUnitPrice = null);
      return;
    }
    final parsed = double.tryParse(raw);
    if (parsed == null) return;
    if (_sellUnitPrice == parsed) return;

    setState(() {
      _sellUnitPrice = parsed;
    });
  }

  void _onQtyChanged() {
    if (!mounted) return;
    if (_sellUnitPrice == null) {
      setState(() {});
      return;
    }

    // When not editing the price field, keep the displayed value in sync
    // with total = qty * (unit price).
    if (!_sellFocusNode.hasFocus) {
      final total = _currentSellTotal();
      _setSellText(_formatPriceValue(total));
    }
    setState(() {});
  }

  void _onSellFocusChanged() {
    if (!mounted) return;
    final unit = _sellUnitPrice;
    if (unit == null) return;

    if (_sellFocusNode.hasFocus) {
      // Editing mode: show per-piece price.
      _setSellText(_formatPriceValue(unit));
      _draftRow.sellController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _draftRow.sellController.text.length,
      );
      setState(() {});
      return;
    }

    // Display mode: show total.
    final total = _currentSellTotal();
    _setSellText(_formatPriceValue(total));
    setState(() {});
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

  Future<bool> _addItemToTable() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final size = _draftRow.resolvedSize.trim();
    final colour = _draftRow.resolvedColour.trim();
    final qty = _draftRow.qty;
    final sell = _sellUnitPrice;

    if (size.isEmpty) {
      _showSnack('Select a size.');
      return false;
    }
    if (colour.isEmpty) {
      _showSnack('Select a colour.');
      return false;
    }
    if (qty <= 0) {
      _showSnack('Enter pieces (qty).');
      return false;
    }
    if (sell == null) {
      _showSnack('Enter selling price.');
      return false;
    }
    if (sell < 0) {
      _showSnack('Selling cannot be negative.');
      return false;
    }

    setState(() {
      final next = _VariantEntry(
        size: size,
        colour: colour,
        qty: qty,
        sellUnit: sell,
      );
      final index = _editingIndex;
      if (index != null && index >= 0 && index < _entries.length) {
        _entries[index] = next;
        _editingIndex = null;
      } else {
        _entries.add(next);
      }

      _draftRow.reset();
      _sellUnitPrice = 0;
      _setSellText('0');
    });

    return true;
  }

  Future<void> _addNewSizeFromField() async {
    final raw = _draftRow.sizeController.text.trim();
    if (raw.isEmpty) {
      _showSnack('Enter a size to add.');
      return;
    }

    final exists = _sizeOptions.any(
      (s) => s.toLowerCase() == raw.toLowerCase(),
    );
    if (!exists) {
      final ok = await _maybePersistCustomValue(kind: 'size', value: raw);
      if (!ok) return;
    }

    final selected = _sizeOptions.firstWhere(
      (s) => s.toLowerCase() == raw.toLowerCase(),
      orElse: () => raw,
    );

    setState(() {
      _draftRow.sizeSelection = selected;
      _draftRow.sizeController.clear();
    });
  }

  Future<void> _addNewColourFromField() async {
    final raw = _draftRow.colourController.text.trim();
    if (raw.isEmpty) {
      _showSnack('Enter a colour to add.');
      return;
    }

    final exists = _colourOptions.any(
      (c) => c.toLowerCase() == raw.toLowerCase(),
    );
    if (!exists) {
      final ok = await _maybePersistCustomValue(kind: 'colour', value: raw);
      if (!ok) return;
    }

    final selected = _colourOptions.firstWhere(
      (c) => c.toLowerCase() == raw.toLowerCase(),
      orElse: () => raw,
    );

    setState(() {
      _draftRow.colourSelection = selected;
      _draftRow.colourController.clear();
    });
  }

  void _startEditEntry(int index) {
    if (index < 0 || index >= _entries.length) return;
    final entry = _entries[index];

    setState(() {
      _editingIndex = index;

      final sizeExists = _sizeOptions.any(
        (s) => s.toLowerCase() == entry.size.toLowerCase(),
      );
      if (sizeExists) {
        final matched = _sizeOptions.firstWhere(
          (s) => s.toLowerCase() == entry.size.toLowerCase(),
        );
        _draftRow.sizeSelection = matched;
        _draftRow.sizeController.text = '';
      } else {
        _draftRow.sizeSelection = null;
        _draftRow.sizeController.text = entry.size;
      }

      final colourExists = _colourOptions.any(
        (c) => c.toLowerCase() == entry.colour.toLowerCase(),
      );
      if (colourExists) {
        final matched = _colourOptions.firstWhere(
          (c) => c.toLowerCase() == entry.colour.toLowerCase(),
        );
        _draftRow.colourSelection = matched;
        _draftRow.colourController.text = '';
      } else {
        _draftRow.colourSelection = null;
        _draftRow.colourController.text = entry.colour;
      }

      _draftRow.qtyController.text = entry.qty.toString();

      _sellUnitPrice = entry.sellUnit;

      // Not focused here; show total.
      final total = entry.sellUnit * entry.qty;
      _setSellText(_formatPriceValue(total));
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingIndex = null;
      _draftRow.reset();
    });
  }

  void _removeEntryAt(int index) {
    setState(() {
      _entries.removeAt(index);

      final editingIndex = _editingIndex;
      if (editingIndex == null) return;
      if (editingIndex == index) {
        _editingIndex = null;
        _draftRow.reset();
        return;
      }
      if (editingIndex > index) {
        _editingIndex = editingIndex - 1;
      }
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<GeneratedBarcode> _generateBarcodeFromBackend() async {
    final gender = _gender!;
    final itemType = _itemType!.trim();

    final brand = _isBrandCustom
        ? _brandController.text.trim()
        : (_brandSelection ?? '').trim();

    final companyName = brand.isEmpty ? 'Unknown' : brand;

    final variants = _entries
        .map(
          (e) => <String, dynamic>{
            'size': e.size,
            'colour': e.colour,
            'pieces': e.qty,
            'sellprice': e.sellUnit.toStringAsFixed(2),
          },
        )
        .toList(growable: false);

    return StockEntryService().generateBarcode(
      companyName: companyName,
      productType: itemType,
      gender: gender.name,
      itemVariants: variants,
    );
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
    if (!form.validate()) {
      setState(() => _commonExpanded = true);
      _ensureVisible(_commonSectionKey);
      return;
    }
    if (_isGeneratingBarcode) return;

    FocusManager.instance.primaryFocus?.unfocus();

    final gender = _gender;
    if (gender == null) return;

    final itemType = _itemType;
    if (itemType == null || itemType.trim().isEmpty) return;

    final brand = _isBrandCustom
        ? _brandController.text.trim()
        : (_brandSelection ?? '').trim();

    // If user is editing an existing row, commit it before submit.
    if (_editingIndex != null) {
      final ok = await _addItemToTable();
      if (!ok) return;
    }

    if (_entries.isEmpty) {
      setState(() => _itemsExpanded = true);
      _ensureVisible(_itemsSectionKey);
      _showSnack('Add at least one item row.');
      return;
    }

    const cost = 0.0;

    // Barcode handling: one barcode for the whole group.
    var finalBarcode = _barcodeController.text.trim();
    if (widget.enableBarcodeGeneration) {
      final confirmed = await _confirmEntryIsRight();
      if (!confirmed) return;

      setState(() => _isGeneratingBarcode = true);
      try {
        final generated = await _generateBarcodeFromBackend();
        finalBarcode = generated.barcode.trim();
        _barcodeUrl = generated.barcodeUrl.trim();
        _barcodeController.text = finalBarcode;

        if (!mounted) return;
        await Navigator.of(context).push<void>(
          BarcodePreviewScreen.route(
            barcode: finalBarcode,
            barcodeUrl: _barcodeUrl,
          ),
        );
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
          barcodeUrl: _barcodeUrl,
          brandName: brand,
          size: row.size,
          colour: row.colour,
          gender: gender,
          isPair: false,
          itemType1: itemType,
          itemType2: null,
          quantity: row.qty,
          costPrice: cost,
          sellingPrice: row.sellUnit,
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

    final List<String> customSizes = _sizeOptions
        .where((s) => !_sizeOptionsDefault.contains(s))
        .toList(growable: false);
    final List<String> customColours = _colourOptions
        .where((c) => !_colourOptionsDefault.contains(c))
        .toList(growable: false);

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
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      );
    }

    InputDecoration gridDecoration({
      required IconData icon,
      required String hint,
      String? prefixText,
    }) {
      return InputDecoration(
        isDense: true,
        hintText: hint,
        prefixText: prefixText,
        prefixIcon: Icon(icon),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      );
    }

    Widget dottedAddField({
      required TextEditingController controller,
      required String hint,
      required VoidCallback onAdd,
    }) {
      return SizedBox(
        height: 52,
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: colorScheme.outlineVariant,
            radius: 14,
            strokeWidth: 1.2,
            dashLength: 4,
            gapLength: 3,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onAdd(),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                suffixIcon: IconButton(
                  tooltip: 'Add',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget sectionCard({
      Key? key,
      required IconData icon,
      required String title,
      String? subtitle,
      required bool expanded,
      required VoidCallback onToggle,
      required List<Widget> children,
    }) {
      return Card(
        key: key,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        shadowColor: colorScheme.shadow.withOpacity(0.10),
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
                  IconButton(
                    tooltip: expanded ? 'Minimize' : 'Expand',
                    onPressed: onToggle,
                    icon: Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                    ),
                  ),
                ],
              ),
              if (expanded) ...[const SizedBox(height: 14), ...children],
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
        elevation: 0,
        scrolledUnderElevation: 2,
        title: const Text(
          'Add Stock Items',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
          children: [
            sectionCard(
              key: _commonSectionKey,
              icon: Icons.inventory_2_outlined,
              title: 'Common Details',
              subtitle: subtitle,
              expanded: _commonExpanded,
              onToggle: () =>
                  setState(() => _commonExpanded = !_commonExpanded),
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
                  icon: const Icon(Icons.expand_more_rounded),
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
                  decoration: decoration(
                    label: 'Brand (optional)',
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
                      label: 'Brand name (optional)',
                      icon: Icons.storefront_outlined,
                      hint: 'Example: Nike',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _itemType,
                  isExpanded: true,
                  icon: const Icon(Icons.expand_more_rounded),
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
                  icon: const Icon(Icons.expand_more_rounded),
                  items: StockEntryItemGender.values
                      .map(
                        (g) => DropdownMenuItem<StockEntryItemGender>(
                          value: g,
                          child: Text(g.label, overflow: TextOverflow.ellipsis),
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
              ],
            ),
            const SizedBox(height: 14),
            sectionCard(
              key: _itemsSectionKey,
              icon: Icons.view_list_outlined,
              title: 'Items',
              subtitle:
                  'Add one or more variants (size, colour, pieces, selling price).',
              expanded: _itemsExpanded,
              onToggle: () => setState(() => _itemsExpanded = !_itemsExpanded),
              children: [
                if (_editingIndex != null) ...[
                  Material(
                    color: colorScheme.primary.withAlpha(14),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            color: colorScheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Editing item ${(_editingIndex ?? 0) + 1}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _cancelEdit,
                            child: const Text('Cancel edit'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 12.0;
                    const gridHeight = 52.0;
                    final width = constraints.maxWidth;
                    final isTwoCol = width >= 320;
                    final fieldWidth = isTwoCol ? ((width - gap) / 2) : width;

                    Widget fieldLabel(String text) {
                      return Text(
                        text,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }

                    Widget gridField({
                      required String label,
                      required Widget child,
                    }) {
                      return SizedBox(
                        width: fieldWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            fieldLabel(label),
                            const SizedBox(height: 6),
                            child,
                          ],
                        ),
                      );
                    }

                    Widget piecesStepper() {
                      return SizedBox(
                        height: gridHeight,
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 2),
                              IconButton(
                                tooltip: 'Decrease',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 40,
                                  height: 40,
                                ),
                                onPressed: () {
                                  final current =
                                      int.tryParse(
                                        _draftRow.qtyController.text.trim(),
                                      ) ??
                                      0;
                                  if (current <= 1) return;
                                  _draftRow.qtyController.text = (current - 1)
                                      .toString();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.remove_rounded),
                              ),
                              Expanded(
                                child: TextFormField(
                                  controller: _draftRow.qtyController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: '1',
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Increase',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 40,
                                  height: 40,
                                ),
                                onPressed: () {
                                  final current =
                                      int.tryParse(
                                        _draftRow.qtyController.text.trim(),
                                      ) ??
                                      0;
                                  final next = (current <= 0 ? 0 : current) + 1;
                                  _draftRow.qtyController.text = next
                                      .toString();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.add_rounded),
                              ),
                              const SizedBox(width: 2),
                            ],
                          ),
                        ),
                      );
                    }

                    Widget menuDropdown({
                      required String label,
                      required IconData icon,
                      required String hint,
                      required String addHint,
                      required TextEditingController addController,
                      required Future<void> Function() onAdd,
                      required List<String> options,
                      required String? value,
                      required ValueChanged<String> onSelected,
                      required MenuController menuController,
                      required ValueGetter<String?> selectionGetter,
                    }) {
                      return gridField(
                        label: label,
                        child: MenuAnchor(
                          controller: menuController,
                          style: MenuStyle(
                            backgroundColor: WidgetStatePropertyAll(
                              colorScheme.surfaceContainerHighest,
                            ),
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                          builder: (context, controller, child) {
                            final isEmpty =
                                value == null || value.trim().isEmpty;

                            return SizedBox(
                              height: gridHeight,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  menuController.isOpen
                                      ? menuController.close()
                                      : menuController.open();
                                },
                                child: InputDecorator(
                                  decoration:
                                      gridDecoration(
                                        icon: icon,
                                        hint: hint,
                                      ).copyWith(
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                        suffixIcon: const Icon(
                                          Icons.expand_more_rounded,
                                        ),
                                      ),
                                  isEmpty: isEmpty,
                                  child: Text(
                                    isEmpty ? hint : value,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: isEmpty
                                          ? FontWeight.w600
                                          : FontWeight.w700,
                                      color: isEmpty
                                          ? colorScheme.onSurfaceVariant
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          menuChildren: [
                            SizedBox(
                              width: fieldWidth,
                              height: 320,
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                                children: [
                                  dottedAddField(
                                    controller: addController,
                                    hint: addHint,
                                    onAdd: () async {
                                      final before = value;
                                      await onAdd();
                                      if (!mounted) return;
                                      final after = selectionGetter();
                                      final changed =
                                          (after != null &&
                                          after.trim().isNotEmpty &&
                                          after != before);
                                      if (changed) {
                                        menuController.close();
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Divider(
                                    height: 1,
                                    color: colorScheme.outlineVariant,
                                  ),
                                  const SizedBox(height: 6),
                                  ...options.map((o) {
                                    final isSelected = (value ?? '') == o;
                                    return MenuItemButton(
                                      leadingIcon: isSelected
                                          ? const Icon(Icons.check_rounded)
                                          : const SizedBox(
                                              width: 24,
                                              height: 24,
                                            ),
                                      onPressed: () {
                                        onSelected(o);
                                        menuController.close();
                                      },
                                      child: Text(
                                        o,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: gap,
                          runSpacing: 10,
                          children: [
                            menuDropdown(
                              label: 'Size',
                              icon: Icons.straighten_outlined,
                              hint: 'Size',
                              addHint: 'Add new size',
                              addController: _draftRow.sizeController,
                              onAdd: _addNewSizeFromField,
                              options: [...customSizes, ..._sizeOptionsDefault],
                              value: _draftRow.safeSizeSelection(_sizeOptions),
                              menuController: _sizeMenuController,
                              selectionGetter: () => _draftRow.sizeSelection,
                              onSelected: (v) {
                                setState(() {
                                  _draftRow.sizeSelection = v;
                                });
                              },
                            ),
                            menuDropdown(
                              label: 'Colour',
                              icon: Icons.palette_outlined,
                              hint: 'Colour',
                              addHint: 'Add new colour',
                              addController: _draftRow.colourController,
                              onAdd: _addNewColourFromField,
                              options: [
                                ...customColours,
                                ..._colourOptionsDefault,
                              ],
                              value: _draftRow.safeColourSelection(
                                _colourOptions,
                              ),
                              menuController: _colourMenuController,
                              selectionGetter: () => _draftRow.colourSelection,
                              onSelected: (v) {
                                setState(() {
                                  _draftRow.colourSelection = v;
                                });
                              },
                            ),
                            gridField(label: 'Pieces', child: piecesStepper()),
                            gridField(
                              label: 'Sell Price',
                              child: SizedBox(
                                height: gridHeight,
                                child: Builder(
                                  builder: (context) {
                                    final showSellOverlay =
                                        _draftRow.qty > 1 &&
                                        _sellUnitPrice != null;

                                    final baseDecoration =
                                        gridDecoration(
                                          icon: Icons.currency_rupee_rounded,
                                          hint: '0',
                                        ).copyWith(
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                        );

                                    return Stack(
                                      children: [
                                        Positioned.fill(
                                          child: TextFormField(
                                            controller:
                                                _draftRow.sellController,
                                            focusNode: _sellFocusNode,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration: showSellOverlay
                                                ? baseDecoration.copyWith(
                                                    contentPadding:
                                                        const EdgeInsets.fromLTRB(
                                                          12,
                                                          8,
                                                          64,
                                                          14,
                                                        ),
                                                  )
                                                : baseDecoration,
                                          ),
                                        ),
                                        if (showSellOverlay)
                                          Positioned(
                                            right: 12,
                                            bottom: 6,
                                            child: IgnorePointer(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    '1× ${_formatPriceValue(_sellUnitPrice!)}',
                                                    style: theme
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: colorScheme
                                                              .onSurfaceVariant,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          height: 1.0,
                                                        ),
                                                  ),
                                                  Text(
                                                    'Total ${_formatPriceValue(_currentSellTotal())}',
                                                    style: theme
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: colorScheme
                                                              .onSurfaceVariant,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          height: 1.0,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await _addItemToTable();
                            },
                            icon: Icon(
                              _editingIndex == null
                                  ? Icons.add_rounded
                                  : Icons.check_rounded,
                            ),
                            label: Text(
                              _editingIndex == null
                                  ? 'Add Item'
                                  : 'Update Item',
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (_entries.isEmpty)
                  Material(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.playlist_add_outlined,
                            color: colorScheme.primary.withAlpha(140),
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No items added yet',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...List<Widget>.generate(_entries.length, (i) {
                    final e = _entries[i];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: i == _entries.length - 1 ? 0 : 8,
                      ),
                      child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        color: colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _startEditEntry(i),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${e.size} • ${e.colour}',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Pieces: ${e.qty} • Price: ₹${(e.sellUnit * e.qty).toStringAsFixed(0)}',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  onPressed: () => _removeEntryAt(i),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 44,
                                    height: 44,
                                  ),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
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
                        : const Icon(Icons.qr_code_2_rounded),
                    label: Text(
                      widget.enableBarcodeGeneration
                          ? (_isGeneratingBarcode
                                ? 'Generating…'
                                : 'Generate Barcode')
                          : 'Add Items',
                    ),
                  ),
                ),
              ],
            ),
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
  TextEditingController? _sellController;

  TextEditingController get sellController =>
      _sellController ??= TextEditingController(text: '0');
  final TextEditingController sizeController;
  final TextEditingController colourController;

  int get qty => int.tryParse(qtyController.text.trim()) ?? 0;

  double? get sell {
    final raw = sellController.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  String get resolvedSize => (sizeSelection ?? '').trim();

  String get resolvedColour => (colourSelection ?? '').trim();

  String? safeSizeSelection(List<String> options) {
    final v = sizeSelection;
    if (v == null) return null;
    return options.contains(v) ? v : null;
  }

  String? safeColourSelection(List<String> options) {
    final v = colourSelection;
    if (v == null) return null;
    return options.contains(v) ? v : null;
  }

  void reset() {
    sizeSelection = null;
    colourSelection = null;
    sizeController.text = '';
    colourController.text = '';
    qtyController.text = '1';
    sellController.text = '0';
  }

  void dispose() {
    qtyController.dispose();
    _sellController?.dispose();
    sizeController.dispose();
    colourController.dispose();
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList(growable: false);
    if (metrics.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final len = math.min(dashLength, metric.length - distance);
        final extract = metric.extractPath(distance, distance + len);
        canvas.drawPath(extract, paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength;
  }
}

class _VariantEntry {
  const _VariantEntry({
    required this.size,
    required this.colour,
    required this.qty,
    required this.sellUnit,
  });

  final String size;
  final String colour;
  final int qty;
  final double sellUnit;
}
