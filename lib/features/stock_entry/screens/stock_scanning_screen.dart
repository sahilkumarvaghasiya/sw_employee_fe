import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock_entry.dart';
import '../models/vendor.dart';
import '../providers/stock_entry_provider.dart';
import '../widgets/payment_section.dart';
import '../widgets/product_scan_card.dart';
import 'stock_barcode_scanner_screen.dart';
import 'stock_entry_history_screen.dart';
import 'stock_entry_main_screen.dart';

class StockScanningScreen extends StatefulWidget {
  const StockScanningScreen({super.key, required this.vendor});

  static const String routeName = '/stock-entry/scan';

  static Route<void> route({required Vendor vendor}) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => StockScanningScreen(vendor: vendor),
    );
  }

  final Vendor vendor;

  @override
  State<StockScanningScreen> createState() => _StockScanningScreenState();
}

class _StockScanningScreenState extends State<StockScanningScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _totalPaymentController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  final List<_ScannedItem> _items = [];

  DateTime? _deadline;
  bool _adjustSellingPrice = false;

  int _catalogIndex = 0;

  final List<_CatalogProduct> _catalog = const [
    _CatalogProduct(id: 'p_101', name: 'Parle-G 250g', cost: 18.0, sell: 20.0),
    _CatalogProduct(
      id: 'p_112',
      name: 'Aashirvaad Atta 5kg',
      cost: 250.0,
      sell: 275.0,
    ),
    _CatalogProduct(
      id: 'p_205',
      name: 'Coca-Cola 750ml',
      cost: 32.0,
      sell: 40.0,
    ),
    _CatalogProduct(id: 'p_207', name: 'Sprite 750ml', cost: 32.0, sell: 40.0),
    _CatalogProduct(id: 'p_309', name: 'Lux Soap', cost: 28.0, sell: 35.0),
    _CatalogProduct(
      id: 'p_410',
      name: 'Colgate Toothpaste 200g',
      cost: 78.0,
      sell: 95.0,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _syncTotalPayment();

    _paidAmountController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _totalPaymentController.dispose();
    _paidAmountController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  double get _totalStockValue {
    return _items.fold<double>(
      0,
      (sum, item) => sum + item.quantity * item.costPrice,
    );
  }

  int get _totalItems {
    return _items.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  double get _paidAmount {
    final raw = _paidAmountController.text.trim();
    if (raw.isEmpty) return 0;
    return double.tryParse(raw) ?? 0;
  }

  double get _remainingAmount {
    return (_totalStockValue - _paidAmount).clamp(0, double.infinity);
  }

  void _syncTotalPayment() {
    _totalPaymentController.text = _totalStockValue.toStringAsFixed(2);
  }

  void _simulateScan() {
    final product = _catalog[_catalogIndex % _catalog.length];
    _catalogIndex++;

    final existingIndex = _items.indexWhere((e) => e.productId == product.id);

    if (existingIndex >= 0) {
      final item = _items[existingIndex];
      item.setQuantity(item.quantity + 1);
      setState(() {
        _syncTotalPayment();
      });
      return;
    }

    final newItem = _ScannedItem.fromCatalog(
      product,
      allowSellingPriceEdit: _adjustSellingPrice,
    );
    newItem.attachOnChanged(() {
      setState(() {
        if (!_adjustSellingPrice) {
          newItem.setSellingPrice(newItem.defaultSellingPrice);
        }
        _syncTotalPayment();
      });
    });

    setState(() {
      _items.insert(0, newItem);
      _syncTotalPayment();
    });
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.of(
      context,
    ).push<String?>(StockBarcodeScannerScreen.route());

    if (!mounted) return;
    if (barcode == null || barcode.trim().isEmpty) return;

    // Today the stock-entry flow uses a local demo catalog (no barcode mapping).
    // We still use the real camera scan to trigger adding a product.
    _simulateScan();
    _showSnack('Scanned: ${barcode.trim()}');
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
          item.setSellingPrice(item.defaultSellingPrice);
        }
      }
    });
  }

  void _removeItem(int index) {
    final removed = _items.removeAt(index);
    removed.dispose();
    setState(() {
      _syncTotalPayment();
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openScannedPreview() async {
    if (_items.isEmpty) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      builder: (context) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.86,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Scanned products',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Card(
                    color: colorScheme.surfaceContainerHigh,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$_totalItems items • ${_money(_totalStockValue)} total',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 44,
                                  width: 44,
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: const Icon(Icons.qr_code_2),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Qty: ${item.quantity} • Cost: ${_money(item.costPrice)} • Sell: ${_money(item.sellingPrice)}',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null) return;

    if (_items.isEmpty) {
      _showSnack('Scan at least one product to continue.');
      return;
    }

    if (!form.validate()) {
      _showSnack('Please fix highlighted fields.');
      return;
    }

    for (final item in _items) {
      if (item.quantity <= 0) {
        _showSnack('Quantity must be at least 1 for ${item.productName}.');
        return;
      }
      if (item.costPrice <= 0) {
        _showSnack('Cost price must be > 0 for ${item.productName}.');
        return;
      }
      if (item.sellingPrice < 0) {
        _showSnack('Selling price cannot be negative for ${item.productName}.');
        return;
      }
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
              productId: e.productId,
              productName: e.productName,
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 220),
          children: [
            Card(
              color: colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Barcode scanning',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap scan to add a product (simulated)',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _scanBarcode,
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: const Text('Scan'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (_items.isNotEmpty)
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Live preview',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$_totalItems items • ${_money(_totalStockValue)} value',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.tonal(
                            onPressed: _openScannedPreview,
                            child: const Text('View'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.price_change_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Adjust selling price',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (_adjustSellingPrice)
                            TextButton(
                              onPressed: () => _toggleAdjustSellingPrice(false),
                              child: const Text('Cancel'),
                            ),
                          Switch(
                            value: _adjustSellingPrice,
                            onChanged: _toggleAdjustSellingPrice,
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _adjustSellingPrice
                              ? 'Selling price is editable for scanned products.'
                              : 'Selling price stays auto-filled until you enable editing.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                color: colorScheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Scan a product to enable preview and price editing.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),

            Text(
              'Scanned products',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),

            if (_items.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No products scanned yet. Tap Scan to add items.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ...List.generate(_items.length, (index) {
                final item = _items[index];

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _items.length - 1 ? 0 : 12,
                  ),
                  child: ProductScanCard(
                    productName: item.productName,
                    quantityController: item.qtyController,
                    costPriceController: item.costController,
                    sellingPriceController: item.sellController,
                    allowSellingPriceEdit: _adjustSellingPrice,
                    onRemove: () => _removeItem(index),
                    onIncrementQty: () {
                      item.setQuantity(item.quantity + 1);
                      setState(_syncTotalPayment);
                    },
                    onDecrementQty: () {
                      final next = (item.quantity - 1).clamp(1, 9999);
                      item.setQuantity(next);
                      setState(_syncTotalPayment);
                    },
                  ),
                );
              }),
          ],
        ),
        bottomNavigationBar: AnimatedPadding(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PaymentSection(
                    totalPaymentController: _totalPaymentController,
                    paidAmountController: _paidAmountController,
                    remainingAmount: _remainingAmount,
                    deadline: _deadline,
                    onPickDeadline: _pickDeadline,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.save_outlined),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Save Stock Entry'),
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

class _CatalogProduct {
  const _CatalogProduct({
    required this.id,
    required this.name,
    required this.cost,
    required this.sell,
  });

  final String id;
  final String name;
  final double cost;
  final double sell;
}

class _ScannedItem {
  _ScannedItem({
    required this.productId,
    required this.productName,
    required this.defaultSellingPrice,
    required int quantity,
    required double costPrice,
    required double sellingPrice,
  }) : qtyController = TextEditingController(text: quantity.toString()),
       costController = TextEditingController(
         text: costPrice.toStringAsFixed(2),
       ),
       sellController = TextEditingController(
         text: sellingPrice.toStringAsFixed(2),
       );

  final String productId;
  final String productName;
  final double defaultSellingPrice;

  final TextEditingController qtyController;
  final TextEditingController costController;
  final TextEditingController sellController;

  VoidCallback? _onChanged;

  static _ScannedItem fromCatalog(
    _CatalogProduct product, {
    required bool allowSellingPriceEdit,
  }) {
    return _ScannedItem(
      productId: product.id,
      productName: product.name,
      defaultSellingPrice: product.sell,
      quantity: 1,
      costPrice: product.cost,
      sellingPrice: allowSellingPriceEdit ? product.sell : product.sell,
    );
  }

  void attachOnChanged(VoidCallback onChanged) {
    _onChanged = onChanged;
    qtyController.addListener(_notify);
    costController.addListener(_notify);
    sellController.addListener(_notify);
  }

  void _notify() {
    _onChanged?.call();
  }

  int get quantity => int.tryParse(qtyController.text.trim()) ?? 0;

  double get costPrice => double.tryParse(costController.text.trim()) ?? 0;

  double get sellingPrice => double.tryParse(sellController.text.trim()) ?? 0;

  void setQuantity(int value) {
    qtyController.text = value.toString();
  }

  void setSellingPrice(double value) {
    sellController.text = value.toStringAsFixed(2);
  }

  void dispose() {
    qtyController
      ..removeListener(_notify)
      ..dispose();
    costController
      ..removeListener(_notify)
      ..dispose();
    sellController
      ..removeListener(_notify)
      ..dispose();
  }
}
