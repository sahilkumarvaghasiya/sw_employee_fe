import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
  final TextEditingController _itemTypeController = TextEditingController();

  StockEntryItemGender? _gender;
  String? _itemType;
  int? _selectedItemTypeId;

  String? _brandSelection;
  String? _selectedBrandId;
  bool get _isBrandCustom => _brandSelection == _customOption;

  bool _isGeneratingBarcode = false;
  String? _barcodeUrl;

  final _VariantDraftRow _draftRow = _VariantDraftRow();
  final List<_VariantEntry> _entries = <_VariantEntry>[];

  final FocusNode _sellFocusNode = FocusNode();
  bool _programmaticSellTextUpdate = false;
  double? _sellUnitPrice;
  double? _purchaseUnitPrice;

  int? _editingIndex;

  bool _commonExpanded = true;
  bool _itemsExpanded = true;

  final MenuController _sizeMenuController = MenuController();
  final MenuController _colourMenuController = MenuController();
  final MenuController _brandMenuController = MenuController();
  final MenuController _itemTypeMenuController = MenuController();
  final MenuController _genderMenuController = MenuController();

  String _sizeSearchQuery = '';
  String _colourSearchQuery = '';
  String _brandSearchQuery = '';
  String _itemTypeSearchQuery = '';
  bool _showItemFieldErrors = false;

  final StockEntryService _stockEntryService = StockEntryService();

  final Map<String, String> _brandIdByName = <String, String>{};
  final Map<String, int> _itemTypeIdByName = <String, int>{};
  final Map<String, int> _sizeIdByName = <String, int>{};
  final Map<String, int> _colourIdByName = <String, int>{};
  final _PagedOptionsState _brandPaged = _PagedOptionsState();
  final _PagedOptionsState _itemTypePaged = _PagedOptionsState();
  final _PagedOptionsState _sizePaged = _PagedOptionsState();
  final _PagedOptionsState _colourPaged = _PagedOptionsState();

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

  IconData _iconForItemType(String? itemType) {
    if (itemType == null || itemType.trim().isEmpty) {
      return Icons.shopping_bag_rounded;
    }
    final s = itemType.toLowerCase();
    if (s.contains('shoe') || s.contains('sneaker') || s.contains('boot')) {
      return Icons.directions_run;
    }
    if (s.contains('shirt') ||
        s.contains('t-shirt') ||
        s.contains('dress') ||
        s.contains('clothes') ||
        s.contains('jean')) {
      return Icons.checkroom;
    }
    if (s.contains('bag') || s.contains('purse')) {
      return Icons.shopping_bag_rounded;
    }
    if (s.contains('bottle') || s.contains('drink')) return Icons.local_drink;
    if (s.contains('box') || s.contains('pack')) {
      return Icons.inventory_2_outlined;
    }
    if (s.contains('watch') || s.contains('accessory')) {
      return Icons.watch_outlined;
    }
    return Icons.shopping_bag_rounded;
  }

  List<String> _mergeUniqueOptions(List<String> first, List<String> second) {
    final seen = <String>{};
    final out = <String>[];

    void add(String raw) {
      final value = raw.trim();
      if (value.isEmpty) return;
      final key = value.toLowerCase();
      if (seen.add(key)) out.add(value);
    }

    for (final item in first) {
      add(item);
    }
    for (final item in second) {
      add(item);
    }

    return out;
  }

  List<String> _buildBarcodeHeaderLines() {
    final sizes = <String>{};
    final colours = <String>{};

    for (final entry in _entries) {
      final size = entry.size.trim();
      final colour = entry.colour.trim();
      if (size.isNotEmpty) sizes.add(size);
      if (colour.isNotEmpty) colours.add(colour);
    }

    final lines = <String>[];
    if (sizes.isNotEmpty) {
      lines.add('Size: ${sizes.join(', ')}');
    }
    if (colours.isNotEmpty) {
      lines.add('Colour: ${colours.join(', ')}');
    }
    return lines;
  }

  String _normalizeOptionKey(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  bool _isDuplicateOption<T>({
    required String raw,
    required Iterable<String> loadedOptions,
    required Map<String, T> idByName,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return false;

    final keyLower = trimmed.toLowerCase();
    final keyNormalized = _normalizeOptionKey(trimmed);

    if (idByName.containsKey(keyLower) || idByName.containsKey(keyNormalized)) {
      return true;
    }

    for (final option in loadedOptions) {
      if (_normalizeOptionKey(option) == keyNormalized) return true;
    }

    return false;
  }

  void _attachOptionScrollListeners() {
    _brandPaged.scrollController.addListener(() {
      if (!_brandPaged.scrollController.hasClients) return;
      final position = _brandPaged.scrollController.position;
      if (position.pixels >= position.maxScrollExtent - 64) {
        _loadBrandOptions();
      }
    });

    _itemTypePaged.scrollController.addListener(() {
      if (!_itemTypePaged.scrollController.hasClients) return;
      final position = _itemTypePaged.scrollController.position;
      if (position.pixels >= position.maxScrollExtent - 64) {
        _loadItemTypeOptions();
      }
    });

    _sizePaged.scrollController.addListener(() {
      if (!_sizePaged.scrollController.hasClients) return;
      final position = _sizePaged.scrollController.position;
      if (position.pixels >= position.maxScrollExtent - 64) {
        _loadSizeOptions();
      }
    });

    _colourPaged.scrollController.addListener(() {
      if (!_colourPaged.scrollController.hasClients) return;
      final position = _colourPaged.scrollController.position;
      if (position.pixels >= position.maxScrollExtent - 64) {
        _loadColourOptions();
      }
    });
  }

  Future<void> _loadPagedOptions({
    required String option,
    required _PagedOptionsState state,
    bool reset = false,
  }) async {
    if (state.isLoading && !reset) return;
    if (!reset && !state.hasMore) return;

    final requestGeneration = reset
        ? ++state.requestGeneration
        : state.requestGeneration;
    final int page = reset ? 1 : state.nextPage;
    if (mounted) {
      setState(() {
        state.isLoading = true;
        if (reset) {
          state.hasMore = true;
          state.nextPage = 1;
          state.values = const <String>[];
        }
      });
    }

    try {
      final result = await _stockEntryService.fetchStockOptionPage(
        option: option,
        page: page,
        pageSize: 30,
        search: state.searchQuery,
      );

      if (!mounted || requestGeneration != state.requestGeneration) return;
      setState(() {
        state.values = _mergeUniqueOptions(state.values, result.items);
        state.hasMore = result.hasMore;
        state.nextPage = page + 1;
        state.isInitialized = true;
      });
    } catch (_) {
      if (!mounted || requestGeneration != state.requestGeneration) return;
      setState(() {
        state.hasMore = false;
        state.isInitialized = true;
      });
    } finally {
      if (!mounted || requestGeneration != state.requestGeneration) return;
      setState(() {
        state.isLoading = false;
      });
    }
  }

  Future<void> _loadBrandOptions({bool reset = false}) async {
    if (_brandPaged.isLoading && !reset) return;
    if (!reset && !_brandPaged.hasMore) return;

    final nextPage = reset ? 1 : _brandPaged.nextPage;
    if (reset) {
      _brandPaged
        ..values = const <String>[]
        ..hasMore = true
        ..nextPage = 1
        ..isInitialized = false;
      _brandIdByName.clear();
    }

    final requestGeneration = reset
        ? ++_brandPaged.requestGeneration
        : _brandPaged.requestGeneration;

    if (!mounted) return;
    setState(() => _brandPaged.isLoading = true);

    try {
      final result = await _stockEntryService.fetchBrandOptionsPage(
        page: nextPage,
        pageSize: 30,
        search: _brandSearchQuery,
      );

      if (!mounted || requestGeneration != _brandPaged.requestGeneration) {
        return;
      }
      setState(() {
        final current = _brandPaged.values.toSet();
        final names = <String>[];
        for (final brand in result.items) {
          _brandIdByName[brand.name.toLowerCase()] = brand.id;
          if (current.add(brand.name)) names.add(brand.name);
        }
        _brandPaged.values = [..._brandPaged.values, ...names];
        _brandPaged.hasMore = result.hasMore;
        _brandPaged.nextPage = nextPage + 1;
        _brandPaged.isInitialized = true;

        final selected = _brandSelection;
        if (selected != null && selected != _customOption) {
          final selectedId = _brandIdByName[selected.toLowerCase()];
          if (selectedId != null) {
            _selectedBrandId = selectedId;
          }
        }
      });
    } catch (_) {
      if (!mounted || requestGeneration != _brandPaged.requestGeneration) {
        return;
      }
      setState(() {
        _brandPaged.hasMore = false;
        _brandPaged.isInitialized = true;
      });
    } finally {
      if (!mounted || requestGeneration != _brandPaged.requestGeneration) {
        return;
      }
      setState(() => _brandPaged.isLoading = false);
    }
  }

  Future<void> _loadItemTypeOptions({bool reset = false}) async {
    if (_itemTypePaged.isLoading && !reset) return;
    if (!reset && !_itemTypePaged.hasMore) return;

    final nextPage = reset ? 1 : _itemTypePaged.nextPage;
    if (reset) {
      _itemTypePaged
        ..values = const <String>[]
        ..hasMore = true
        ..nextPage = 1
        ..isInitialized = false;
      _itemTypeIdByName.clear();
    }

    final requestGeneration = reset
        ? ++_itemTypePaged.requestGeneration
        : _itemTypePaged.requestGeneration;

    if (!mounted) return;
    setState(() => _itemTypePaged.isLoading = true);

    try {
      final result = await _stockEntryService.fetchItemTypeOptionsPage(
        page: nextPage,
        pageSize: 30,
        search: _itemTypeSearchQuery,
      );

      if (!mounted || requestGeneration != _itemTypePaged.requestGeneration) {
        return;
      }
      setState(() {
        final current = _itemTypePaged.values.toSet();
        final names = <String>[];
        for (final itemType in result.items) {
          _itemTypeIdByName[itemType.name.toLowerCase()] = itemType.id;
          if (current.add(itemType.name)) names.add(itemType.name);
        }
        _itemTypePaged.values = [..._itemTypePaged.values, ...names];
        _itemTypePaged.hasMore = result.hasMore;
        _itemTypePaged.nextPage = nextPage + 1;
        _itemTypePaged.isInitialized = true;

        final selected = _itemType;
        if (selected != null && selected.trim().isNotEmpty) {
          final selectedId = _itemTypeIdByName[selected.toLowerCase()];
          if (selectedId != null) {
            _selectedItemTypeId = selectedId;
          }
        }
      });
    } catch (_) {
      if (!mounted || requestGeneration != _itemTypePaged.requestGeneration) {
        return;
      }
      setState(() {
        _itemTypePaged.hasMore = false;
        _itemTypePaged.isInitialized = true;
      });
    } finally {
      if (!mounted || requestGeneration != _itemTypePaged.requestGeneration) {
        return;
      }
      setState(() => _itemTypePaged.isLoading = false);
    }
  }

  Future<void> _loadSizeOptions({bool reset = false}) async {
    if (_sizePaged.isLoading && !reset) return;
    if (!reset && !_sizePaged.hasMore) return;

    final nextPage = reset ? 1 : _sizePaged.nextPage;
    if (reset) {
      _sizePaged
        ..values = const <String>[]
        ..hasMore = true
        ..nextPage = 1
        ..isInitialized = false;
      _sizeIdByName.clear();
    }

    final requestGeneration = reset
        ? ++_sizePaged.requestGeneration
        : _sizePaged.requestGeneration;

    if (!mounted) return;
    setState(() => _sizePaged.isLoading = true);

    try {
      final result = await _stockEntryService.fetchSizeOptionsPage(
        page: nextPage,
        pageSize: 30,
        search: _sizeSearchQuery,
      );

      if (!mounted || requestGeneration != _sizePaged.requestGeneration) {
        return;
      }
      setState(() {
        final current = _sizePaged.values.toSet();
        final names = <String>[];
        for (final size in result.items) {
          _sizeIdByName[size.name.toLowerCase()] = size.id;
          if (current.add(size.name)) names.add(size.name);
        }
        _sizePaged.values = [..._sizePaged.values, ...names];
        _sizePaged.hasMore = result.hasMore;
        _sizePaged.nextPage = nextPage + 1;
        _sizePaged.isInitialized = true;
      });
    } catch (_) {
      if (!mounted || requestGeneration != _sizePaged.requestGeneration) {
        return;
      }
      setState(() {
        _sizePaged.hasMore = false;
        _sizePaged.isInitialized = true;
      });
    } finally {
      if (!mounted || requestGeneration != _sizePaged.requestGeneration) {
        return;
      }
      setState(() => _sizePaged.isLoading = false);
    }
  }

  Future<void> _loadColourOptions({bool reset = false}) async {
    if (_colourPaged.isLoading && !reset) return;
    if (!reset && !_colourPaged.hasMore) return;

    final nextPage = reset ? 1 : _colourPaged.nextPage;
    if (reset) {
      _colourPaged
        ..values = const <String>[]
        ..hasMore = true
        ..nextPage = 1
        ..isInitialized = false;
      _colourIdByName.clear();
    }

    final requestGeneration = reset
        ? ++_colourPaged.requestGeneration
        : _colourPaged.requestGeneration;

    if (!mounted) return;
    setState(() => _colourPaged.isLoading = true);

    try {
      final result = await _stockEntryService.fetchColourOptionsPage(
        page: nextPage,
        pageSize: 30,
        search: _colourSearchQuery,
      );

      if (!mounted || requestGeneration != _colourPaged.requestGeneration) {
        return;
      }
      setState(() {
        final current = _colourPaged.values.toSet();
        final names = <String>[];
        for (final colour in result.items) {
          _colourIdByName[colour.name.toLowerCase()] = colour.id;
          if (current.add(colour.name)) names.add(colour.name);
        }
        _colourPaged.values = [..._colourPaged.values, ...names];
        _colourPaged.hasMore = result.hasMore;
        _colourPaged.nextPage = nextPage + 1;
        _colourPaged.isInitialized = true;
      });
    } catch (_) {
      if (!mounted || requestGeneration != _colourPaged.requestGeneration) {
        return;
      }
      setState(() {
        _colourPaged.hasMore = false;
        _colourPaged.isInitialized = true;
      });
    } finally {
      if (!mounted || requestGeneration != _colourPaged.requestGeneration) {
        return;
      }
      setState(() => _colourPaged.isLoading = false);
    }
  }

  void _ensureBrandOptionsLoaded() {
    if (_brandPaged.isInitialized) return;
    _loadBrandOptions(reset: true);
  }

  void _ensureItemTypeOptionsLoaded() {
    if (_itemTypePaged.isInitialized) return;
    _loadItemTypeOptions(reset: true);
  }

  void _ensureSizeOptionsLoaded() {
    if (_sizePaged.isInitialized) return;
    _loadSizeOptions(reset: true);
  }

  void _ensureColourOptionsLoaded() {
    if (_colourPaged.isInitialized) return;
    _loadColourOptions(reset: true);
  }

  static const String _customOption = '__custom__';

  @override
  void initState() {
    super.initState();
    final prefill = widget.initialDrafts;
    final initialBarcode = (prefill != null && prefill.isNotEmpty)
        ? prefill.first.barcode
        : widget.initialBarcode;

    _barcodeController = TextEditingController(text: initialBarcode);

    if (prefill != null && prefill.isNotEmpty) {
      _prefillFromDrafts(prefill);
    }

    _sellUnitPrice = double.tryParse(_draftRow.sellController.text.trim());
    _purchaseUnitPrice = double.tryParse(
      _draftRow.purchaseController.text.trim(),
    );
    _draftRow.sellController.addListener(_onSellTextChanged);
    _draftRow.purchaseController.addListener(_onPurchaseTextChanged);
    _draftRow.qtyController.addListener(_onQtyChanged);
    _sellFocusNode.addListener(_onSellFocusChanged);
    _attachOptionScrollListeners();
  }

  void _prefillFromDrafts(List<StockEntryDraftItem> drafts) {
    final first = drafts.first;

    _barcodeUrl = first.barcodeUrl;

    _gender = first.gender;
    _itemType = first.itemType1;
    _selectedItemTypeId = first.itemTypeId;

    final brand = first.brandName.trim();
    if (brand.isEmpty) {
      _brandSelection = null;
      _selectedBrandId = null;
      _brandController.text = '';
    } else {
      _brandSelection = brand;
      _selectedBrandId = null;
      _brandController.text = '';
    }

    _entries
      ..clear()
      ..addAll(
        drafts.map(
          (d) => _VariantEntry(
            sizeId: d.sizeId,
            size: d.size,
            colourId: d.colourId,
            colour: d.colour,
            qty: d.quantity,
            purchaseUnit: d.costPrice,
            sellUnit: d.sellingPrice,
          ),
        ),
      );

    _commonExpanded = true;
    _itemsExpanded = true;
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _brandController.dispose();
    _itemTypeController.dispose();
    _draftRow.sellController.removeListener(_onSellTextChanged);
    _draftRow.purchaseController.removeListener(_onPurchaseTextChanged);
    _draftRow.qtyController.removeListener(_onQtyChanged);
    _sellFocusNode.removeListener(_onSellFocusChanged);
    _sellFocusNode.dispose();
    _brandPaged.scrollController.dispose();
    _itemTypePaged.scrollController.dispose();
    _sizePaged.scrollController.dispose();
    _colourPaged.scrollController.dispose();
    _draftRow.dispose();
    super.dispose();
  }

  String _formatPriceValue(double value) {
    final whole = (value - value.truncateToDouble()).abs() < 0.000001;
    return whole ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  String _formatAmountValue(double value) {
    return NumberFormat('#,##,##0', 'en_IN').format(value);
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

  void _onPurchaseTextChanged() {
    if (!mounted) return;

    final raw = _draftRow.purchaseController.text.trim();
    if (raw.isEmpty) {
      setState(() => _purchaseUnitPrice = null);
      return;
    }
    final parsed = double.tryParse(raw);
    if (parsed == null) return;
    if (_purchaseUnitPrice == parsed) return;

    setState(() {
      _purchaseUnitPrice = parsed;
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

  Future<bool> _addItemToTable() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final form = _formKey.currentState;
    if (form == null) return false;
    if (!form.validate()) {
      setState(() => _commonExpanded = true);
      _ensureVisible(_commonSectionKey);
      return false;
    }

    setState(() {
      _showItemFieldErrors = true;
    });

    final size = _draftRow.resolvedSize.trim();
    final colour = _draftRow.resolvedColour.trim();
    final qty = _draftRow.qty;
    final purchase = _purchaseUnitPrice;
    final sell = _sellUnitPrice;

    if (size.isEmpty) {
      return false;
    }
    if (colour.isEmpty) {
      return false;
    }
    if (qty <= 0) {
      return false;
    }
    if (purchase == null) {
      return false;
    }
    if (purchase <= 0) {
      return false;
    }
    if (sell == null) {
      return false;
    }
    if (sell <= 0) {
      return false;
    }

    setState(() {
      final next = _VariantEntry(
        sizeId: _sizeIdByName[size.toLowerCase()],
        size: size,
        colourId: _colourIdByName[colour.toLowerCase()],
        colour: colour,
        qty: qty,
        purchaseUnit: purchase,
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
      _purchaseUnitPrice = 0;
      _draftRow.purchaseController.text = '0';
      _setSellText('0');
      _showItemFieldErrors = false;
    });

    return true;
  }

  Future<void> _addNewSizeFromField() async {
    final raw = _draftRow.sizeController.text.trim();
    if (raw.isEmpty) {
      _showSnack('Enter a size to add.');
      return;
    }

    if (_isDuplicateOption<int>(
      raw: raw,
      loadedOptions: _sizePaged.values,
      idByName: _sizeIdByName,
    )) {
      _showSnack('Size already exists. Please select it from the list.');
      return;
    }

    setState(() {
      _draftRow.sizeSelection = raw;
    });

    // Match Item Type behavior: close dropdown after successful add,
    // and keep the entered text visible when reopening.
    _sizeMenuController.close();
  }

  Future<void> _addNewColourFromField() async {
    final raw = _draftRow.colourController.text.trim();
    if (raw.isEmpty) {
      _showSnack('Enter a colour to add.');
      return;
    }

    if (_isDuplicateOption<int>(
      raw: raw,
      loadedOptions: _colourPaged.values,
      idByName: _colourIdByName,
    )) {
      _showSnack('Colour already exists. Please select it from the list.');
      return;
    }

    setState(() {
      _draftRow.colourSelection = raw;
    });

    // Match Item Type behavior: close dropdown after successful add,
    // and keep the entered text visible when reopening.
    _colourMenuController.close();
  }

  void _startEditEntry(int index) {
    if (index < 0 || index >= _entries.length) return;
    final entry = _entries[index];

    setState(() {
      _showItemFieldErrors = false;
      _editingIndex = index;

      _draftRow.sizeSelection = entry.size;
      // If this was a custom/manual size (no id), also show it in the
      // "Add new size" field when reopening the dropdown.
      _draftRow.sizeController.text = entry.sizeId == null ? entry.size : '';

      _draftRow.colourSelection = entry.colour;
      // If this was a custom/manual colour (no id), also show it in the
      // "Add new colour" field when reopening the dropdown.
      _draftRow.colourController.text = entry.colourId == null
          ? entry.colour
          : '';

      _draftRow.qtyController.text = entry.qty.toString();

      _sellUnitPrice = entry.sellUnit;
      _purchaseUnitPrice = entry.purchaseUnit;
      _draftRow.purchaseController.text = _formatPriceValue(entry.purchaseUnit);

      // Not focused here; show total.
      final total = entry.sellUnit * entry.qty;
      _setSellText(_formatPriceValue(total));
    });
  }

  void _cancelEdit() {
    setState(() {
      _showItemFieldErrors = false;
      _editingIndex = null;
      _draftRow.reset();
      _sellUnitPrice = 0;
      _purchaseUnitPrice = 0;
      _setSellText('0');
      _draftRow.purchaseController.text = '0';
    });
  }

  Future<bool> _confirmDeleteEntry({required bool isLastEntry}) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text(
          isLastEntry
              ? 'This is the last item in this block. Deleting it will remove the whole block. Continue?'
              : 'Do you want to delete this item?',
        ),
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

    return shouldDelete == true;
  }

  Future<void> _removeEntryAt(int index) async {
    if (index < 0 || index >= _entries.length) return;

    final isLastEntry = _entries.length == 1;
    final shouldDelete = await _confirmDeleteEntry(isLastEntry: isLastEntry);
    if (!shouldDelete || !mounted) return;

    if (isLastEntry) {
      Navigator.of(context).pop(<StockEntryDraftItem>[]);
      return;
    }

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
            'purchase_price': e.purchaseUnit.toStringAsFixed(2),
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

  bool _setCustomBrandFromField() {
    final raw = _brandController.text.trim();
    if (raw.isEmpty) {
      _showSnack('Enter a brand name.');
      return false;
    }

    if (_isDuplicateOption<String>(
      raw: raw,
      loadedOptions: _brandPaged.values,
      idByName: _brandIdByName,
    )) {
      _showSnack('Brand already exists. Please select it from the list.');
      return false;
    }
    setState(() {
      _brandSelection = _customOption;
      _selectedBrandId = null;
      _brandController.text = raw;
    });
    return true;
  }

  bool _setCustomItemTypeFromField() {
    final raw = _itemTypeController.text.trim();
    if (raw.isEmpty) {
      _showSnack('Enter an item type.');
      return false;
    }

    if (_isDuplicateOption<int>(
      raw: raw,
      loadedOptions: _itemTypePaged.values,
      idByName: _itemTypeIdByName,
    )) {
      _showSnack('Item type already exists. Please select it from the list.');
      return false;
    }
    setState(() {
      _itemType = raw;
      _selectedItemTypeId = null;
      _itemTypeController.text = raw;
    });
    return true;
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
            headerLines: _buildBarcodeHeaderLines(),
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
          brandId: _selectedBrandId,
          brandName: brand,
          sizeId: row.sizeId,
          size: row.size,
          colourId: row.colourId,
          colour: row.colour,
          gender: gender,
          isPair: false,
          itemTypeId: _selectedItemTypeId,
          itemType1: itemType,
          itemType2: null,
          quantity: row.qty,
          costPrice: row.purchaseUnit,
          sellingPrice: row.sellUnit,
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(out);
  }

  Future<bool> _confirmDiscardOnBackIfNeeded() async {
    if (_entries.isEmpty) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard entries?'),
        content: const Text(
          'Do you want to go back? This entry will be discarded.',
        ),
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

    return shouldDiscard == true;
  }

  Future<void> _handleBackPressed() async {
    final canGoBack = await _confirmDiscardOnBackIfNeeded();
    if (!canGoBack || !mounted) return;
    Navigator.of(context).pop();
  }

  Future<bool> _onWillPop() async {
    return _confirmDiscardOnBackIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditingExistingBlock =
        widget.initialDrafts != null && widget.initialDrafts!.isNotEmpty;

    final StockEntryItemGender? safeGender =
        _gender != null && StockEntryItemGender.values.contains(_gender)
        ? _gender
        : null;

    final String? safeBrandSelection = _brandSelection;

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
      ValueChanged<String>? onChanged,
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
              onChanged: onChanged,
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
        shadowColor: colorScheme.shadow.withValues(alpha: 0.10),
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

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 2,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _handleBackPressed,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text(
            'Manage Stock Items',
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
                  FormField<String>(
                    initialValue: safeBrandSelection,
                    builder: (field) {
                      final selected = _brandSelection;
                      final isEmpty =
                          selected == null || selected.trim().isEmpty;

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return MenuAnchor(
                            controller: _brandMenuController,
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
                              return ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 56,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    _ensureBrandOptionsLoaded();
                                    _brandMenuController.isOpen
                                        ? _brandMenuController.close()
                                        : _brandMenuController.open();
                                  },
                                  child: InputDecorator(
                                    isEmpty: isEmpty,
                                    decoration:
                                        decoration(
                                          label: 'Brand (optional)',
                                          icon: Icons.storefront_outlined,
                                        ).copyWith(
                                          suffixIcon: const Icon(
                                            Icons.expand_more_rounded,
                                          ),
                                          floatingLabelBehavior:
                                              FloatingLabelBehavior.always,
                                          errorText: field.errorText,
                                        ),
                                    child: Text(
                                      isEmpty
                                          ? 'Select or search brand'
                                          : selected == _customOption
                                          ? _brandController.text.trim()
                                          : selected,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
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
                                width: constraints.maxWidth,
                                height: 320,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        8,
                                        8,
                                        4,
                                      ),
                                      child: TextField(
                                        autofocus: false,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          prefixIcon: const Icon(
                                            Icons.search_rounded,
                                          ),
                                          hintText: 'Search Brand',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        onChanged: (q) {
                                          setState(() {
                                            _brandSearchQuery = q;
                                            _brandPaged.searchQuery = q;
                                          });
                                          _loadBrandOptions(reset: true);
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Expanded(
                                      child: Scrollbar(
                                        controller:
                                            _brandPaged.scrollController,
                                        child: ListView(
                                          controller:
                                              _brandPaged.scrollController,
                                          padding: const EdgeInsets.fromLTRB(
                                            8,
                                            4,
                                            8,
                                            8,
                                          ),
                                          children: [
                                            ..._brandPaged.values
                                                .where((o) {
                                                  final q = _brandSearchQuery
                                                      .trim()
                                                      .toLowerCase();
                                                  if (q.isEmpty) return true;
                                                  return o
                                                      .toLowerCase()
                                                      .contains(q);
                                                })
                                                .map((o) {
                                                  final isSelected =
                                                      selected == o;
                                                  return MenuItemButton(
                                                    leadingIcon: isSelected
                                                        ? const Icon(
                                                            Icons.check_rounded,
                                                          )
                                                        : const SizedBox(
                                                            width: 24,
                                                            height: 24,
                                                          ),
                                                    onPressed: () {
                                                      setState(() {
                                                        _brandSelection = o;
                                                        _selectedBrandId =
                                                            _brandIdByName[o
                                                                .toLowerCase()];
                                                        _brandController
                                                            .clear();
                                                      });
                                                      field.didChange(o);
                                                      _brandMenuController
                                                          .close();
                                                    },
                                                    child: Text(
                                                      o,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                }),
                                            if (_brandPaged.isLoading)
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 10,
                                                ),
                                                child: Center(
                                                  child: SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(height: 8),
                                            Divider(
                                              height: 1,
                                              color: colorScheme.outlineVariant,
                                            ),
                                            const SizedBox(height: 6),
                                            dottedAddField(
                                              controller: _brandController,
                                              hint: 'Add brand',
                                              onChanged: (raw) {
                                                setState(() {
                                                  final text = raw.trim();
                                                  if (text.isEmpty) {
                                                    _brandSelection = null;
                                                    _selectedBrandId = null;
                                                    return;
                                                  }
                                                  _brandSelection =
                                                      _customOption;
                                                  _selectedBrandId = null;
                                                });
                                              },
                                              onAdd: () {
                                                final ok =
                                                    _setCustomBrandFromField();
                                                if (!ok) return;
                                                field.didChange(_customOption);
                                                _brandMenuController.close();
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  FormField<String>(
                    initialValue: _itemType,
                    validator: (v) {
                      final raw = (v ?? _itemType ?? '').trim();
                      if (raw.isEmpty) return 'Item type is required';
                      return null;
                    },
                    builder: (field) {
                      final selected = _itemType;
                      final isEmpty =
                          selected == null || selected.trim().isEmpty;

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return MenuAnchor(
                            controller: _itemTypeMenuController,
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
                              return ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 56,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    _ensureItemTypeOptionsLoaded();
                                    _itemTypeMenuController.isOpen
                                        ? _itemTypeMenuController.close()
                                        : _itemTypeMenuController.open();
                                  },
                                  child: InputDecorator(
                                    isEmpty: isEmpty,
                                    decoration:
                                        decoration(
                                          label: 'Item type',
                                          icon: Icons.checkroom_outlined,
                                        ).copyWith(
                                          suffixIcon: const Icon(
                                            Icons.expand_more_rounded,
                                          ),
                                          floatingLabelBehavior:
                                              FloatingLabelBehavior.always,
                                          errorText: field.errorText,
                                        ),
                                    child: Text(
                                      isEmpty ? 'Select item type' : selected,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
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
                                width: constraints.maxWidth,
                                height: 320,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        8,
                                        8,
                                        4,
                                      ),
                                      child: TextField(
                                        autofocus: false,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          prefixIcon: const Icon(
                                            Icons.search_rounded,
                                          ),
                                          hintText: 'Search Item type',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        onChanged: (q) {
                                          setState(() {
                                            _itemTypeSearchQuery = q;
                                            _itemTypePaged.searchQuery = q;
                                          });
                                          _loadItemTypeOptions(reset: true);
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Expanded(
                                      child: Scrollbar(
                                        controller:
                                            _itemTypePaged.scrollController,
                                        child: ListView(
                                          controller:
                                              _itemTypePaged.scrollController,
                                          padding: const EdgeInsets.fromLTRB(
                                            8,
                                            4,
                                            8,
                                            8,
                                          ),
                                          children: [
                                            ..._itemTypePaged.values
                                                .where((o) {
                                                  final q = _itemTypeSearchQuery
                                                      .trim()
                                                      .toLowerCase();
                                                  if (q.isEmpty) return true;
                                                  return o
                                                      .toLowerCase()
                                                      .contains(q);
                                                })
                                                .map<Widget>((o) {
                                                  final isSelected =
                                                      selected == o;
                                                  return MenuItemButton(
                                                    leadingIcon: isSelected
                                                        ? const Icon(
                                                            Icons.check_rounded,
                                                          )
                                                        : const SizedBox(
                                                            width: 24,
                                                            height: 24,
                                                          ),
                                                    onPressed: () {
                                                      setState(() {
                                                        _itemType = o;
                                                        _selectedItemTypeId =
                                                            _itemTypeIdByName[o
                                                                .toLowerCase()];
                                                      });
                                                      field.didChange(o);
                                                      field.validate();
                                                      _itemTypeMenuController
                                                          .close();
                                                    },
                                                    child: Text(
                                                      o,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                }),
                                            if (_itemTypePaged.isLoading)
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 10,
                                                ),
                                                child: Center(
                                                  child: SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(height: 8),
                                            Divider(
                                              height: 1,
                                              color: colorScheme.outlineVariant,
                                            ),
                                            const SizedBox(height: 6),
                                            dottedAddField(
                                              controller: _itemTypeController,
                                              hint: 'Add item type',
                                              onChanged: (raw) {
                                                setState(() {
                                                  final text = raw.trim();
                                                  _itemType = text.isEmpty
                                                      ? null
                                                      : text;
                                                  _selectedItemTypeId = null;
                                                });
                                                field.didChange(_itemType);
                                                field.validate();
                                              },
                                              onAdd: () {
                                                final ok =
                                                    _setCustomItemTypeFromField();
                                                if (!ok) return;
                                                field.didChange(_itemType);
                                                field.validate();
                                                _itemTypeMenuController.close();
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  FormField<StockEntryItemGender>(
                    initialValue: safeGender,
                    validator: (v) => v == null ? 'Gender is required' : null,
                    builder: (field) {
                      final selected = _gender;
                      final isEmpty = selected == null;

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return MenuAnchor(
                            controller: _genderMenuController,
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
                              return ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 56,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    _genderMenuController.isOpen
                                        ? _genderMenuController.close()
                                        : _genderMenuController.open();
                                  },
                                  child: InputDecorator(
                                    isEmpty: isEmpty,
                                    decoration:
                                        decoration(
                                          label: 'Gender',
                                          icon: Icons.wc_outlined,
                                        ).copyWith(
                                          suffixIcon: const Icon(
                                            Icons.expand_more_rounded,
                                          ),
                                          floatingLabelBehavior:
                                              FloatingLabelBehavior.always,
                                          errorText: field.errorText,
                                        ),
                                    child: Text(
                                      isEmpty
                                          ? 'Select gender'
                                          : selected.label,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
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
                                width: constraints.maxWidth,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: StockEntryItemGender.values
                                      .map((g) {
                                        final isSelected = selected == g;
                                        return MenuItemButton(
                                          leadingIcon: isSelected
                                              ? const Icon(Icons.check_rounded)
                                              : const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                ),
                                          onPressed: () {
                                            setState(() {
                                              _gender = g;
                                            });
                                            field.didChange(g);
                                            field.validate();
                                            _genderMenuController.close();
                                          },
                                          child: Text(
                                            g.label,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      })
                                      .toList(growable: false),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              sectionCard(
                key: _itemsSectionKey,
                icon: Icons.view_list_outlined,
                title: 'Items',
                subtitle:
                    'Add one or more variants (size, colour, pieces, purchase price, selling price).',
                expanded: _itemsExpanded,
                onToggle: () =>
                    setState(() => _itemsExpanded = !_itemsExpanded),
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 12.0;
                      final gridHeight = 52.0;
                      final width = constraints.maxWidth;
                      final isTwoCol = width >= 360;
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
                        String? errorText,
                      }) {
                        return SizedBox(
                          width: fieldWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              fieldLabel(label),
                              const SizedBox(height: 8),
                              child,
                              if (errorText != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  errorText,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      Widget piecesStepper() {
                        return SizedBox(
                          height: gridHeight,
                          child: InputDecorator(
                            isEmpty: false,
                            decoration:
                                gridDecoration(
                                  icon: Icons.confirmation_number_outlined,
                                  hint: '1',
                                ).copyWith(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: 'Decrease',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 32,
                                    height: 32,
                                  ),
                                  iconSize: 18,
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
                                  child: Transform.translate(
                                    offset: const Offset(-9, -3),
                                    child: TextFormField(
                                      controller: _draftRow.qtyController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      textAlignVertical:
                                          TextAlignVertical.center,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            height: 1,
                                            fontWeight: FontWeight.w700,
                                          ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        isCollapsed: true,
                                        border: InputBorder.none,
                                        hintText: '1',
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Increase',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 32,
                                    height: 32,
                                  ),
                                  iconSize: 18,
                                  onPressed: () {
                                    final current =
                                        int.tryParse(
                                          _draftRow.qtyController.text.trim(),
                                        ) ??
                                        0;
                                    final next =
                                        (current <= 0 ? 0 : current) + 1;
                                    _draftRow.qtyController.text = next
                                        .toString();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.add_rounded),
                                ),
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
                        required ValueChanged<String> onAddChanged,
                        required Future<void> Function() onAdd,
                        required List<String> options,
                        required String? value,
                        required ValueChanged<String> onSelected,
                        required MenuController menuController,
                        VoidCallback? onMenuTap,
                        required ValueGetter<String?> selectionGetter,
                        required String searchQuery,
                        required ValueChanged<String> onSearchChanged,
                        required ScrollController scrollController,
                        required bool isLoadingOptions,
                        required double menuWidth,
                        String? errorText,
                      }) {
                        return gridField(
                          label: label,
                          errorText: errorText,
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
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    onMenuTap?.call();
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
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
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
                                width: menuWidth,
                                height: 320,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        8,
                                        8,
                                        4,
                                      ),
                                      child: TextField(
                                        autofocus: false,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          prefixIcon: const Icon(
                                            Icons.search_rounded,
                                          ),
                                          hintText: 'Search $label',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        onChanged: onSearchChanged,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Expanded(
                                      child: Scrollbar(
                                        controller: scrollController,
                                        child: ListView(
                                          controller: scrollController,
                                          padding: const EdgeInsets.fromLTRB(
                                            8,
                                            4,
                                            8,
                                            8,
                                          ),
                                          children: [
                                            ...options
                                                .where((o) {
                                                  final q = searchQuery
                                                      .trim()
                                                      .toLowerCase();
                                                  if (q.isEmpty) return true;
                                                  return o
                                                      .toLowerCase()
                                                      .contains(q);
                                                })
                                                .map((o) {
                                                  final isSelected =
                                                      (value ?? '') == o;
                                                  return MenuItemButton(
                                                    leadingIcon: isSelected
                                                        ? const Icon(
                                                            Icons.check_rounded,
                                                          )
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
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                }),
                                            if (isLoadingOptions)
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 10,
                                                ),
                                                child: Center(
                                                  child: SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(height: 8),
                                            Divider(
                                              height: 1,
                                              color: colorScheme.outlineVariant,
                                            ),
                                            const SizedBox(height: 6),
                                            dottedAddField(
                                              controller: addController,
                                              hint: addHint,
                                              onChanged: onAddChanged,
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
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final sizeError =
                          _showItemFieldErrors &&
                              _draftRow.resolvedSize.trim().isEmpty
                          ? 'Required field'
                          : null;
                      final colourError =
                          _showItemFieldErrors &&
                              _draftRow.resolvedColour.trim().isEmpty
                          ? 'Required field'
                          : null;
                      final qtyError =
                          _showItemFieldErrors && _draftRow.qty <= 0
                          ? 'Required field'
                          : null;
                      final purchaseError = (() {
                        if (!_showItemFieldErrors) return null;
                        final purchase = _purchaseUnitPrice;
                        if (purchase == null || purchase <= 0) {
                          return 'Required field';
                        }
                        return null;
                      })();
                      final sellError = (() {
                        if (!_showItemFieldErrors) return null;
                        final sell = _sellUnitPrice;
                        if (sell == null || sell <= 0) return 'Required field';
                        return null;
                      })();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: gap,
                            runSpacing: 14,
                            children: [
                              menuDropdown(
                                label: 'Size',
                                icon: Icons.straighten_outlined,
                                hint: 'Size',
                                addHint: 'Add new size',
                                addController: _draftRow.sizeController,
                                onAddChanged: (raw) {
                                  setState(() {
                                    final text = raw.trim();
                                    _draftRow.sizeSelection = text.isEmpty
                                        ? null
                                        : text;
                                  });
                                },
                                onAdd: _addNewSizeFromField,
                                options: _sizePaged.values,
                                value: _draftRow.resolvedSize,
                                menuController: _sizeMenuController,
                                onMenuTap: _ensureSizeOptionsLoaded,
                                selectionGetter: () => _draftRow.sizeSelection,
                                searchQuery: _sizeSearchQuery,
                                onSearchChanged: (q) {
                                  setState(() {
                                    _sizeSearchQuery = q;
                                    _sizePaged.searchQuery = q;
                                  });
                                  _loadSizeOptions(reset: true);
                                },
                                scrollController: _sizePaged.scrollController,
                                isLoadingOptions: _sizePaged.isLoading,
                                menuWidth: width - 32,
                                errorText: sizeError,
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
                                onAddChanged: (raw) {
                                  setState(() {
                                    final text = raw.trim();
                                    _draftRow.colourSelection = text.isEmpty
                                        ? null
                                        : text;
                                  });
                                },
                                onAdd: _addNewColourFromField,
                                options: _colourPaged.values,
                                value: _draftRow.resolvedColour,
                                menuController: _colourMenuController,
                                onMenuTap: _ensureColourOptionsLoaded,
                                selectionGetter: () =>
                                    _draftRow.colourSelection,
                                searchQuery: _colourSearchQuery,
                                onSearchChanged: (q) {
                                  setState(() {
                                    _colourSearchQuery = q;
                                    _colourPaged.searchQuery = q;
                                  });
                                  _loadColourOptions(reset: true);
                                },
                                scrollController: _colourPaged.scrollController,
                                isLoadingOptions: _colourPaged.isLoading,
                                menuWidth: width - 32,
                                errorText: colourError,
                                onSelected: (v) {
                                  setState(() {
                                    _draftRow.colourSelection = v;
                                  });
                                },
                              ),
                              gridField(
                                label: 'Pieces',
                                errorText: qtyError,
                                child: piecesStepper(),
                              ),
                              gridField(
                                label: 'Purchase Price',
                                errorText: purchaseError,
                                child: SizedBox(
                                  height: gridHeight,
                                  child: TextFormField(
                                    controller: _draftRow.purchaseController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: gridDecoration(
                                      icon: Icons.payments_outlined,
                                      hint: '0',
                                    ),
                                  ),
                                ),
                              ),
                              gridField(
                                label: 'Sell Price',
                                errorText: sellError,
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
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      '1 x ${_formatPriceValue(_sellUnitPrice!)}',
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
                          Row(
                            children: [
                              if (_editingIndex != null)
                                TextButton(
                                  onPressed: _cancelEdit,
                                  child: const Text('Cancel edit'),
                                ),
                              const Spacer(),
                              OutlinedButton.icon(
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
                                      ? 'Save'
                                      : 'Update Item',
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Text(
                          'Stock items',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        if (_entries.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${_entries.length} items',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
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
                    Column(
                      children: List<Widget>.generate(_entries.length, (i) {
                        final e = _entries[i];
                        final selected =
                            _editingIndex != null && _editingIndex == i;
                        final total = e.sellUnit * e.qty;
                        final priceStr = _formatAmountValue(total);

                        final itemTypeName = (_itemType ?? '').trim();
                        final itemName = _barcodeController.text.trim();
                        final itemLabel = itemTypeName.isEmpty
                            ? itemName
                            : (itemName.isEmpty
                                  ? itemTypeName
                                  : '$itemName ($itemTypeName)');

                        final brandName =
                            (_isBrandCustom
                                    ? _brandController.text
                                    : (_brandSelection ?? ''))
                                .trim();

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: i == _entries.length - 1 ? 0 : 8,
                          ),
                          child: Card(
                            margin: EdgeInsets.zero,
                            elevation: selected ? 4 : 0,
                            color: colorScheme.surfaceContainerHighest,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: selected
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _startEditEntry(i),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: colorScheme.surface,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            _iconForItemType(_itemType),
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            colorScheme.surface,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              999,
                                                            ),
                                                      ),
                                                      child: SingleChildScrollView(
                                                        scrollDirection:
                                                            Axis.horizontal,
                                                        physics:
                                                            const BouncingScrollPhysics(),
                                                        child: Text(
                                                          itemLabel,
                                                          style: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  if (brandName.isNotEmpty) ...[
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 6,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: colorScheme
                                                              .surface,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                999,
                                                              ),
                                                        ),
                                                        child: SingleChildScrollView(
                                                          scrollDirection:
                                                              Axis.horizontal,
                                                          physics:
                                                              const BouncingScrollPhysics(),
                                                          child: Text(
                                                            brandName,
                                                            style: theme
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              if (itemName.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  physics:
                                                      const BouncingScrollPhysics(),
                                                  child: Text(
                                                    itemName,
                                                    style: theme
                                                        .textTheme
                                                        .labelMedium
                                                        ?.copyWith(
                                                          color: colorScheme
                                                              .onSurfaceVariant,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Row(
                                          children: [
                                            InkWell(
                                              onTap: () => _startEditEntry(i),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: colorScheme
                                                      .errorContainer,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  Icons.edit_outlined,
                                                  size: 20,
                                                  color: colorScheme.error,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () => _removeEntryAt(i),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: colorScheme
                                                      .errorContainer,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  Icons.delete_outline,
                                                  size: 20,
                                                  color: colorScheme.error,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: colorScheme.surface,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 12,
                                                        height: 12,
                                                        decoration:
                                                            BoxDecoration(
                                                              color:
                                                                  Colors.green,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: SingleChildScrollView(
                                                          scrollDirection:
                                                              Axis.horizontal,
                                                          physics:
                                                              const BouncingScrollPhysics(),
                                                          child: Text(
                                                            e.colour,
                                                            style: theme
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.surface,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .inventory_2_outlined,
                                                      size: 14,
                                                      color:
                                                          colorScheme.primary,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '${e.qty} pcs',
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: colorScheme.surface,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                  ),
                                                  child: SingleChildScrollView(
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    physics:
                                                        const BouncingScrollPhysics(),
                                                    child: Text(
                                                      e.size,
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorScheme.surface,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '₹$priceStr',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Buy: ₹${_formatAmountValue(e.purchaseUnit)} · Sell: ₹${_formatAmountValue(e.sellUnit)}',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
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
                  color: colorScheme.shadow.withValues(alpha: 0.08),
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
                                : const Icon(Icons.qr_code_2_rounded))
                          : const Icon(Icons.checklist_rounded),
                      label: Text(
                        widget.enableBarcodeGeneration
                            ? (_isGeneratingBarcode
                                  ? 'Generating...'
                                  : 'Generate Barcode')
                            : (isEditingExistingBlock ? 'Update' : 'Add Items'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PagedOptionsState {
  final ScrollController scrollController = ScrollController();
  List<String> values = const <String>[];
  String searchQuery = '';
  int nextPage = 1;
  bool hasMore = true;
  bool isLoading = false;
  bool isInitialized = false;
  int requestGeneration = 0;
}

class _VariantDraftRow {
  _VariantDraftRow()
    : qtyController = TextEditingController(text: '1'),
      sizeController = TextEditingController(),
      colourController = TextEditingController();

  String? sizeSelection;
  String? colourSelection;

  final TextEditingController qtyController;
  TextEditingController? _purchaseController;
  TextEditingController? _sellController;

  TextEditingController get purchaseController =>
      _purchaseController ??= TextEditingController(text: '0');
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

  double? get purchase {
    final raw = purchaseController.text.trim();
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
    purchaseController.text = '0';
    sellController.text = '0';
  }

  void dispose() {
    qtyController.dispose();
    _purchaseController?.dispose();
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
    this.sizeId,
    required this.size,
    this.colourId,
    required this.colour,
    required this.qty,
    required this.purchaseUnit,
    required this.sellUnit,
  });

  final int? sizeId;
  final String size;
  final int? colourId;
  final String colour;
  final int qty;
  final double purchaseUnit;
  final double sellUnit;
}
