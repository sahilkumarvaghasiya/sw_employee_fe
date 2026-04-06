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
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _paymentSectionKey = GlobalKey();

  final TextEditingController _totalPaymentController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  final List<_EditableDraftItem> _items = [];

  bool _adjustSellingPrice = false;
  DateTime? _deadline;

  bool _showPaymentSection = false;

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
    _scrollController.dispose();
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

    final drafts = await Navigator.of(context).push<List<StockEntryDraftItem>?>(
      AddStockEntryItemScreen.route(
        initialBarcode: normalized,
        allowBarcodeEdit: false,
      ),
    );

    if (!mounted) return;
    if (drafts == null || drafts.isEmpty) return;

    for (final draft in drafts) {
      _addDraftToList(draft);
    }
  }

  Future<void> _generateBarcode() async {
    final drafts = await Navigator.of(context).push<List<StockEntryDraftItem>?>(
      AddStockEntryItemScreen.route(
        initialBarcode: '',
        allowBarcodeEdit: false,
        enableBarcodeGeneration: true,
      ),
    );

    if (!mounted) return;
    if (drafts == null || drafts.isEmpty) return;

    for (final draft in drafts) {
      _addDraftToList(draft);
    }
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

  bool _validateItemsOnly() {
    if (_items.isEmpty) {
      _showSnack('Scan at least one product to continue.');
      return false;
    }

    for (final item in _items) {
      if (item.quantity <= 0) {
        _showSnack('Quantity must be at least 1.');
        return false;
      }
      if (item.costPrice <= 0) {
        _showSnack('Cost price must be > 0.');
        return false;
      }
      if (item.sellingPrice < 0) {
        _showSnack('Selling price cannot be negative.');
        return false;
      }
    }

    return true;
  }

  Future<void> _proceedToPayment() async {
    if (!_validateItemsOnly()) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.fact_check_outlined),
          title: const Text('Confirm items'),
          content: const Text(
            'Have you entered all stock items for this vendor?\n\nTap Continue to enter payment details and save.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not yet'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() {
      _showPaymentSection = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _paymentSectionKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    });
  }

  Future<void> _saveFinal() async {
    final form = _formKey.currentState;

    if (!_validateItemsOnly()) return;

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

    Widget actionRow({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return Material(
        color: colorScheme.surfaceContainerHigh,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colorScheme.outlineVariant),
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
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
    }

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
          controller: _scrollController,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Add items',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          '${_items.length} added',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            actionRow(
                              icon: Icons.document_scanner_outlined,
                              title: 'Scan barcode',
                              subtitle: 'Scan existing barcode using camera',
                              onTap: _scanBarcode,
                            ),
                            const Divider(height: 1),
                            actionRow(
                              icon: Icons.auto_fix_high_rounded,
                              title: 'Generate barcode',
                              subtitle: 'Create new barcode with item details',
                              onTap: _generateBarcode,
                            ),
                          ],
                        ),
                      ),
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
                          'No items yet. Scan or generate a barcode to add products.',
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

            if (_showPaymentSection) ...[
              KeyedSubtree(
                key: _paymentSectionKey,
                child: PaymentSection(
                  totalPaymentController: _totalPaymentController,
                  paidAmountController: _paidAmountController,
                  remainingAmount: _remainingAmount,
                  deadline: _deadline,
                  onPickDeadline: _pickDeadline,
                ),
              ),
            ],
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
                  onPressed: _showPaymentSection
                      ? _saveFinal
                      : _proceedToPayment,
                  icon: Icon(
                    _showPaymentSection ? Icons.check_circle : Icons.save,
                  ),
                  label: Text(_showPaymentSection ? 'Confirm & Save' : 'Save'),
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
