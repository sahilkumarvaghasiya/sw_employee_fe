import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock_entry.dart';
import '../models/stock_entry_draft_item.dart';
import '../models/vendor.dart';
import '../providers/stock_entry_provider.dart';
import '../widgets/payment_section.dart';
import '../widgets/product_scan_card.dart';
import 'add_stock_entry_item_screen.dart';
import 'stock_barcode_scanner_screen.dart';
import 'stock_entry_history_screen.dart';
import 'stock_entry_main_screen.dart';

class StockScanningScreen extends StatefulWidget {
  const StockScanningScreen({super.key, required this.vendor});

  final Vendor vendor;

  static const String routeName = '/stock-entry/scan';

  static Route<void> route({required Vendor vendor}) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => StockScanningScreen(vendor: vendor),
    );
  }

  @override
  State<StockScanningScreen> createState() => _StockScanningScreenState();
}

class _StockScanningScreenState extends State<StockScanningScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _totalPaymentController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  final List<_EditableDraftItem> _items = [];

  bool _adjustSellingPrice = false;
  DateTime? _deadline;

  double _totalStockValue = 0;
  double _paidAmount = 0;
  double _remainingAmount = 0;

  @override
  void initState() {
    super.initState();
    _paidAmountController.addListener(_syncTotalsFromControllers);
    _syncTotalsFromControllers();
  }

  @override
  void dispose() {
    _paidAmountController.removeListener(_syncTotalsFromControllers);

    for (final item in _items) {
      item.dispose();
    }

    _totalPaymentController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  String _displayName(StockEntryDraftItem item) {
    final types = <String>[item.itemType1];
    if (item.itemType2 != null && item.itemType2!.trim().isNotEmpty) {
      types.add(item.itemType2!.trim());
    }

    final typeText = types.join(' / ');
    final pairText = item.isPair ? ' (Pair)' : '';

    if (item.brandName.trim().isEmpty) return '$typeText$pairText';
    return '${item.brandName.trim()} • $typeText$pairText';
  }

  String _metaLine(StockEntryDraftItem item) {
    final parts = <String>[
      'Barcode: ${item.barcode}',
      'Size: ${item.size}',
      'Colour: ${item.colour}',
      'Gender: ${item.gender.label}',
    ];
    return parts.join(' • ');
  }

  void _syncTotalsFromControllers() {
    final total = _items.fold<double>(
      0,
      (sum, e) => sum + (e.costPrice * e.quantity),
    );

    final paid = double.tryParse(_paidAmountController.text.trim()) ?? 0;

    setState(() {
      _totalStockValue = total;
      _paidAmount = paid;
      _remainingAmount = _totalStockValue - _paidAmount;
      if (_remainingAmount < 0) _remainingAmount = 0;

      _totalPaymentController.text = _totalStockValue.toStringAsFixed(2);
    });
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.of(
      context,
    ).push<String?>(StockBarcodeScannerScreen.route());

    if (!mounted) return;
    if (barcode == null || barcode.trim().isEmpty) return;

    final normalized = barcode.trim();

    final draft = await Navigator.of(context).push<StockEntryDraftItem?>(
      AddStockEntryItemScreen.route(
        initialBarcode: normalized,
        allowBarcodeEdit: false,
      ),
    );

    if (!mounted) return;
    if (draft == null) return;

    _addDraftToList(draft);
  }

  Future<void> _generateBarcode() async {
    final draft = await Navigator.of(context).push<StockEntryDraftItem?>(
      AddStockEntryItemScreen.route(
        initialBarcode: '',
        allowBarcodeEdit: false,
        enableBarcodeGeneration: true,
      ),
    );

    if (!mounted) return;
    if (draft == null) return;

    _addDraftToList(draft);
  }

  void _addDraftToList(StockEntryDraftItem draft) {
    final item = _EditableDraftItem.fromDraft(draft);

    item.attachOnChanged(() {
      _syncTotalsFromControllers();
    });

    setState(() {
      _items.insert(0, item);
      _syncTotalsFromControllers();
    });

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('Added: ${draft.barcode}')));
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked == null) return;
    setState(() => _deadline = picked);
  }

  void _toggleAdjustSellingPrice(bool value) {
    setState(() {
      _adjustSellingPrice = value;

      if (!_adjustSellingPrice) {
        for (final item in _items) {
          item.resetSellingPriceToDefault();
        }
      }
    });
  }

  void _removeItemAt(int index) {
    final removed = _items.removeAt(index);
    removed.dispose();

    _syncTotalsFromControllers();

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('Removed: ${removed.draft.barcode}')),
      );
  }

  void _save() async {
    final form = _formKey.currentState;

    if (_items.isEmpty) {
      _showSnack('Scan at least one product to continue.');
      return;
    }

    if (form == null || !form.validate()) {
      _showSnack('Please fix highlighted fields.');
      return;
    }

    if (_paidAmount > _totalStockValue + 0.0001) {
      _showSnack('Paid amount cannot exceed total payment.');
      return;
    }

    if (_remainingAmount > 0 && _deadline == null) {
      _showSnack('Please select a payment deadline.');
      return;
    }

    for (final item in _items) {
      if (item.quantity <= 0) {
        _showSnack('Quantity must be at least 1.');
        return;
      }
      if (item.costPrice <= 0) {
        _showSnack('Cost price must be > 0.');
        return;
      }
      if (item.sellingPrice < 0) {
        _showSnack('Selling price cannot be negative.');
        return;
      }
    }

    final entry = StockEntry(
      id: 'se_${DateTime.now().millisecondsSinceEpoch}',
      vendor: widget.vendor,
      createdAt: DateTime.now(),
      items: _items
          .map(
            (e) => StockEntryLineItem(
              productId: e.draft.barcode,
              productName: _displayName(e.draft),
              quantity: e.quantity,
              costPrice: e.costPrice,
              sellingPrice: e.sellingPrice,
            ),
          )
          .toList(growable: false),
      payment: StockEntryPayment(
        totalPayment: _totalStockValue,
        paidAmount: _paidAmount,
        deadline: _deadline,
      ),
    );

    await context.read<StockEntryProvider>().saveStockEntry(entry);

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.check_circle_outline),
          title: const Text('Stock entry saved'),
          content: Text(
            'Saved for ${widget.vendor.name}.\nTotal: ${_money(entry.payment.totalPayment)} • Due: ${_money(entry.payment.remainingAmount)}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    Navigator.of(context).popUntil(
      (route) => route.settings.name == StockEntryMainScreen.routeName,
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Form(
      key: _formKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Stock Entry • ${widget.vendor.name}'),
          actions: [
            IconButton(
              tooltip: 'Vendor history',
              onPressed: () {
                Navigator.of(
                  context,
                ).push(StockEntryHistoryScreen.route(vendor: widget.vendor));
              },
              icon: const Icon(Icons.history),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: colorScheme.primary.withAlpha(33),
                      child: Icon(Icons.store, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.vendor.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.vendor.address,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add items',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: _scanBarcode,
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: const Text('Scan barcode'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _generateBarcode,
                          icon: const Icon(Icons.auto_fix_high_rounded),
                          label: const Text('Generate barcode'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            if (_items.isEmpty)
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.qr_code_2,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No items yet. Scan a barcode to add products.',
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
            else ...[
              Card(
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  title: const Text('Adjust selling price'),
                  subtitle: Text(
                    _adjustSellingPrice
                        ? 'Selling price can be edited'
                        : 'Selling price is auto-filled',
                  ),
                  value: _adjustSellingPrice,
                  onChanged: _toggleAdjustSellingPrice,
                ),
              ),
              const SizedBox(height: 14),
              ...List.generate(_items.length, (index) {
                final item = _items[index];

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _items.length - 1 ? 0 : 12,
                  ),
                  child: ProductScanCard(
                    productName: _displayName(item.draft),
                    metaLine: _metaLine(item.draft),
                    quantityController: item.qtyController,
                    costPriceController: item.costController,
                    sellingPriceController: item.sellController,
                    allowSellingPriceEdit: _adjustSellingPrice,
                    onRemove: () => _removeItemAt(index),
                    onIncrementQty: () {
                      item.incrementQty();
                      _syncTotalsFromControllers();
                    },
                    onDecrementQty: () {
                      item.decrementQty();
                      _syncTotalsFromControllers();
                    },
                  ),
                );
              }),
            ],

            const SizedBox(height: 14),

            PaymentSection(
              totalPaymentController: _totalPaymentController,
              paidAmountController: _paidAmountController,
              remainingAmount: _remainingAmount,
              deadline: _deadline,
              onPickDeadline: _pickDeadline,
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total: ${_money(_totalStockValue)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Due: ${_money(_remainingAmount)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _remainingAmount <= 0
                              ? colorScheme.tertiary
                              : colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableDraftItem {
  _EditableDraftItem._({
    required this.draft,
    required this.qtyController,
    required this.costController,
    required this.sellController,
    required this.defaultSellingPrice,
  });

  final StockEntryDraftItem draft;

  final TextEditingController qtyController;
  final TextEditingController costController;
  final TextEditingController sellController;

  final double defaultSellingPrice;

  VoidCallback? _onChanged;

  factory _EditableDraftItem.fromDraft(StockEntryDraftItem draft) {
    return _EditableDraftItem._(
      draft: draft,
      defaultSellingPrice: draft.sellingPrice,
      qtyController: TextEditingController(text: draft.quantity.toString()),
      costController: TextEditingController(
        text: draft.costPrice.toStringAsFixed(2),
      ),
      sellController: TextEditingController(
        text: draft.sellingPrice.toStringAsFixed(2),
      ),
    );
  }

  void attachOnChanged(VoidCallback onChanged) {
    _onChanged = onChanged;
    qtyController.addListener(onChanged);
    costController.addListener(onChanged);
    sellController.addListener(onChanged);
  }

  int get quantity {
    final parsed = int.tryParse(qtyController.text.trim());
    return parsed ?? 0;
  }

  double get costPrice {
    final parsed = double.tryParse(costController.text.trim());
    return parsed ?? 0;
  }

  double get sellingPrice {
    final parsed = double.tryParse(sellController.text.trim());
    return parsed ?? 0;
  }

  void incrementQty() {
    final next = (quantity <= 0 ? 0 : quantity) + 1;
    qtyController.text = next.toString();
  }

  void decrementQty() {
    final current = quantity;
    if (current <= 1) return;
    qtyController.text = (current - 1).toString();
  }

  void resetSellingPriceToDefault() {
    sellController.text = defaultSellingPrice.toStringAsFixed(2);
  }

  void dispose() {
    if (_onChanged != null) {
      qtyController.removeListener(_onChanged!);
      costController.removeListener(_onChanged!);
      sellController.removeListener(_onChanged!);
    }

    qtyController.dispose();
    costController.dispose();
    sellController.dispose();
  }
}
