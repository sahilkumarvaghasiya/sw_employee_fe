import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:flutter/scheduler.dart';

import '../models/stock_entry.dart';
import '../models/stock_entry_draft_item.dart';
import '../models/vendor.dart';
import '../providers/stock_entry_provider.dart';
import '../services/stock_entry_service.dart';
import '../widgets/payment_section.dart';
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
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _totalPaymentController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();

  final List<_EditableDraftItem> _items = [];
  DateTime? _deadline;

  bool _itemsLocked = false;
  bool _showDeadlineValidation = false;

  double _totalStockValue = 0;
  double _paidAmount = 0;
  double _remainingAmount = 0;

  @override
  void initState() {
    super.initState();
    _totalPaymentController.addListener(_syncTotalsFromControllers);
    _paidAmountController.addListener(_syncTotalsFromControllers);
    _syncTotalsFromControllers();
  }

  @override
  void dispose() {
    _totalPaymentController.removeListener(_syncTotalsFromControllers);
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

  void _syncTotalsFromControllers() {
    final paidRaw = _paidAmountController.text.trim().replaceAll(',', '');
    final paid = double.tryParse(paidRaw) ?? 0;

    final totalRaw = _totalPaymentController.text.trim().replaceAll(',', '');
    final totalParsed = double.tryParse(totalRaw);
    final total = totalParsed ?? 0.0;

    void apply() {
      if (!mounted) return;

      var nextRemaining = total - paid;
      if (nextRemaining < 0) nextRemaining = 0;

      const epsilon = 0.0001;
      final unchanged =
          (_totalStockValue - total).abs() < epsilon &&
          (_paidAmount - paid).abs() < epsilon &&
          (_remainingAmount - nextRemaining).abs() < epsilon;
      if (unchanged) return;

      setState(() {
        _totalStockValue = total;
        _paidAmount = paid;
        _remainingAmount = nextRemaining;
      });
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    final isInBuildScope =
        phase == SchedulerPhase.transientCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.persistentCallbacks;

    if (isInBuildScope) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
      return;
    }

    apply();
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.of(
      context,
    ).push<String?>(StockBarcodeScannerScreen.route());

    if (!mounted) return;
    if (barcode == null || barcode.trim().isEmpty) return;

    final normalized = barcode.trim();

    final existingIndex = _items.indexWhere(
      (e) => e.draft.barcode.trim() == normalized,
    );
    if (existingIndex != -1) {
      await _editItemAt(existingIndex);
      return;
    }

    final drafts = await Navigator.of(context).push<List<StockEntryDraftItem>?>(
      AddStockEntryItemScreen.route(
        initialBarcode: normalized,
        allowBarcodeEdit: false,
      ),
    );

    if (!mounted) return;
    if (drafts == null || drafts.isEmpty) return;

    _addDraftsToList(drafts);
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

    _addDraftsToList(drafts);
  }

  void _addDraftsToList(List<StockEntryDraftItem> drafts) {
    if (drafts.isEmpty) return;

    final editableItems = drafts
        .map((draft) => _EditableDraftItem.fromDraft(draft))
        .toList(growable: false);

    for (final item in editableItems) {
      item.attachOnChanged(() {
        _syncTotalsFromControllers();
      });
    }

    setState(() {
      for (final item in editableItems.reversed) {
        _items.insert(0, item);
      }
    });
    _syncTotalsFromControllers();

    final barcode = drafts.first.barcode;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Added block: $barcode with ${drafts.length} items'),
        ),
      );
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
    setState(() {
      _deadline = picked;
      _showDeadlineValidation = false;
    });
  }

  Future<bool> _confirmDeleteBlock({
    required String barcode,
    required int itemCount,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete block?'),
        content: Text('Delete all $itemCount item(s) from barcode "$barcode"?'),
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

  Future<void> _removeBlockByBarcode(String barcode) async {
    if (_itemsLocked) return;

    final indices = <int>[];
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].draft.barcode == barcode) {
        indices.add(i);
      }
    }
    if (indices.isEmpty) return;

    final shouldDelete = await _confirmDeleteBlock(
      barcode: barcode,
      itemCount: indices.length,
    );
    if (!shouldDelete || !mounted) return;

    setState(() {
      for (var i = indices.length - 1; i >= 0; i--) {
        final removed = _items.removeAt(indices[i]);
        removed.dispose();
      }
    });

    _syncTotalsFromControllers();

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('Removed block: $barcode')));
  }

  Future<void> _editItemAt(int index) async {
    if (_itemsLocked) return;
    if (index < 0 || index >= _items.length) return;

    await _editBlockByBarcode(_items[index].draft.barcode);
  }

  Future<void> _editBlockByBarcode(String barcode) async {
    if (_itemsLocked) return;

    final indices = <int>[];
    final draftsToEdit = <StockEntryDraftItem>[];

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.draft.barcode != barcode) continue;

      indices.add(i);
      draftsToEdit.add(
        StockEntryDraftItem(
          barcode: item.draft.barcode,
          barcodeUrl: item.draft.barcodeUrl,
          brandName: item.draft.brandName,
          size: item.draft.size,
          colour: item.draft.colour,
          gender: item.draft.gender,
          isPair: item.draft.isPair,
          itemType1: item.draft.itemType1,
          itemType2: item.draft.itemType2,
          quantity: item.quantity,
          costPrice: item.costPrice,
          sellingPrice: item.sellingPrice,
        ),
      );
    }

    if (draftsToEdit.isEmpty) return;
    final insertAt = indices.first;

    final drafts = await Navigator.of(context).push<List<StockEntryDraftItem>?>(
      AddStockEntryItemScreen.route(
        initialBarcode: barcode,
        allowBarcodeEdit: false,
        initialDrafts: draftsToEdit,
      ),
    );

    if (!mounted) return;
    if (drafts == null) return;

    setState(() {
      for (var i = indices.length - 1; i >= 0; i--) {
        final removed = _items.removeAt(indices[i]);
        removed.dispose();
      }

      if (drafts.isNotEmpty) {
        for (var i = drafts.length - 1; i >= 0; i--) {
          final next = _EditableDraftItem.fromDraft(drafts[i]);
          next.attachOnChanged(() {
            _syncTotalsFromControllers();
          });
          _items.insert(insertAt, next);
        }
      }
    });

    _syncTotalsFromControllers();
  }

  Map<String, dynamic> _buildSavePayload() {
    final productsByBarcode = <String, List<_EditableDraftItem>>{};
    for (final item in _items) {
      (productsByBarcode[item.draft.barcode] ??= []).add(item);
    }

    String moneyString(double value) => value.toStringAsFixed(2);
    String? deadlineString(DateTime? d) {
      if (d == null) return null;
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '$y-$m-$day';
    }

    final products = <Map<String, dynamic>>[];
    for (final entry in productsByBarcode.entries) {
      final barcode = entry.key;
      final items = entry.value;
      final first = items.first.draft;

      products.add({
        'company_name': first.brandName,
        if (first.brandId != null && first.brandId!.trim().isNotEmpty)
          'brand_id': first.brandId,
        'product_type': first.itemType1,
        'gender': first.gender.name,
        'barcode_number': barcode,
        'barcode_url': first.barcodeUrl,
        'item_variants': [
          for (final it in items)
            {
              'size': it.draft.size,
              'colour': it.draft.colour,
              'pieces': it.quantity,
              'sellprice': moneyString(it.sellingPrice),
            },
        ],
      });
    }

    return {
      'vendor_name': widget.vendor.name,
      'phone': (widget.vendor.phone?.trim().isNotEmpty ?? false)
          ? widget.vendor.phone?.trim()
          : null,
      'email': (widget.vendor.email?.trim().isNotEmpty ?? false)
          ? widget.vendor.email?.trim()
          : null,
      'gst_number': (widget.vendor.gst?.trim().isNotEmpty ?? false)
          ? widget.vendor.gst?.trim()
          : null,
      'vendor_address': (widget.vendor.address?.trim().isNotEmpty ?? false)
          ? widget.vendor.address?.trim()
          : null,
      'total_amount': moneyString(_totalStockValue),
      'paid_amount': moneyString(_paidAmount),
      'paymentdeadlinedate': deadlineString(_deadline),
      'notes': null,
      'products': products,
    };
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
      if (item.sellingPrice <= 0) {
        _showSnack('Selling price must be > 0.');
        return false;
      }
    }

    return true;
  }

  Future<void> _confirmAndOpenPayment() async {
    if (!_validateItemsOnly()) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.fact_check_outlined),
          title: const Text('Confirm stock entry'),
          content: const Text(
            'Are you sure you want to continue to payment?\n\nAfter you continue, item details will not be changed unless you close payment and edit items.',
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
      _itemsLocked = true;
    });
    _syncTotalsFromControllers();

    final didSave = await _showPaymentPopup();
    if (!mounted) return;

    if (didSave != true) {
      setState(() {
        _itemsLocked = false;
      });
      _syncTotalsFromControllers();
    }
  }

  Future<bool?> _showPaymentPopup() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    bool isSaving = false;

    return showGeneralDialog<bool>(
      context: context,
      barrierLabel: 'Payment',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.22),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final media = MediaQuery.of(dialogContext);

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> onSave() async {
              if (isSaving) return;

              if (_remainingAmount > 0 && _deadline == null) {
                setState(() => _showDeadlineValidation = true);
                return;
              }

              setModalState(() => isSaving = true);
              try {
                final saved = await _saveFinal();
                if (!saved) {
                  setModalState(() => isSaving = false);
                }
              } catch (e) {
                if (mounted) {
                  _showSnack('Unable to save. Please try again.');
                }
                setModalState(() => isSaving = false);
              }
            }

            return WillPopScope(
              onWillPop: () async => !isSaving,
              child: Stack(
                children: [
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: const SizedBox.expand(),
                  ),
                  SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          20,
                          16,
                          20 + media.viewInsets.bottom,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Material(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(22),
                            clipBehavior: Clip.antiAlias,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                16,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Payment details',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Close',
                                        onPressed: isSaving
                                            ? null
                                            : () => Navigator.of(
                                                dialogContext,
                                              ).pop(false),
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Vendor: ${widget.vendor.name}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  PaymentSection(
                                    totalPaymentController:
                                        _totalPaymentController,
                                    paidAmountController: _paidAmountController,
                                    remainingAmount: _remainingAmount,
                                    deadline: _deadline,
                                    onPickDeadline: _pickDeadline,
                                    totalPaymentEditable: true,
                                    onTotalPaymentChanged: (_) =>
                                        _syncTotalsFromControllers(),
                                    deadlineErrorText:
                                        _showDeadlineValidation &&
                                            _remainingAmount > 0 &&
                                            _deadline == null
                                        ? 'Required field'
                                        : null,
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: isSaving
                                              ? null
                                              : () => Navigator.of(
                                                  dialogContext,
                                                ).pop(false),
                                          icon: const Icon(
                                            Icons.cancel_outlined,
                                          ),
                                          label: const Text('Cancel'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: isSaving ? null : onSave,
                                          icon: isSaving
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2.4,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.check_circle_outline,
                                                ),
                                          label: Text(
                                            isSaving
                                                ? 'Saving…'
                                                : 'Confirm & Save',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<bool> _saveFinal() async {
    if (!_validateItemsOnly()) return false;

    final totalRaw = _totalPaymentController.text.trim();
    final parsedTotal = totalRaw.isEmpty
        ? 0.0
        : double.tryParse(totalRaw.replaceAll(',', ''));
    if (parsedTotal == null || parsedTotal <= 0) {
      _showSnack('Enter a valid total payment.');
      return false;
    }

    final paidRaw = _paidAmountController.text.trim();
    final parsedPaid = paidRaw.isEmpty
        ? 0.0
        : double.tryParse(paidRaw.replaceAll(',', ''));
    if (parsedPaid == null) {
      _showSnack('Enter a valid paid amount.');
      return false;
    }
    if (parsedPaid < 0) {
      _showSnack('Paid amount cannot be negative.');
      return false;
    }

    if ((_totalStockValue - parsedTotal).abs() > 0.0001 ||
        (_paidAmount - parsedPaid).abs() > 0.0001) {
      setState(() {
        _totalStockValue = parsedTotal;
        _paidAmount = parsedPaid;
        _remainingAmount = _totalStockValue - _paidAmount;
        if (_remainingAmount < 0) _remainingAmount = 0;
      });
    }

    if (_paidAmount > _totalStockValue + 0.0001) {
      _showSnack('Paid amount cannot exceed total payment.');
      return false;
    }

    if (_remainingAmount > 0 && _deadline == null) {
      if (mounted) {
        setState(() => _showDeadlineValidation = true);
      }
      return false;
    }

    final items = _items
        .map(
          (e) => StockEntryLineItem(
            productId: e.draft.barcode,
            productName: _displayName(e.draft),
            quantity: e.quantity,
            costPrice: e.costPrice,
            sellingPrice: e.sellingPrice,
          ),
        )
        .toList(growable: false);

    final invoiceNumber = await StockEntryService().createStockEntry(
      vendor: widget.vendor,
      payload: _buildSavePayload(),
    );

    final entry = StockEntry(
      id: 'se_${DateTime.now().millisecondsSinceEpoch}',
      invoiceNumber: invoiceNumber,
      backendStatus: null,
      vendor: widget.vendor,
      createdAt: DateTime.now(),
      items: items,
      payment: StockEntryPayment(
        totalPayment: _totalStockValue,
        paidAmount: _paidAmount,
        deadline: _deadline,
      ),
    );

    // Keep local history updated after a successful backend save.
    await context.read<StockEntryProvider>().saveStockEntry(entry);

    if (!mounted) return true;

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

    if (!mounted) return true;

    Navigator.of(context).popUntil(
      (route) => route.settings.name == StockEntryMainScreen.routeName,
    );

    return true;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmDiscardOnBackIfNeeded() async {
    if (_items.isEmpty) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard entries?'),
        content: const Text(
          'Going back will discard listed entries. Do you want to go back?',
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

    Widget buildItemsList() {
      final titleStyle = theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w800,
      );
      final metaStyle = theme.textTheme.labelMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      );

      final grouped = <String, List<_EditableDraftItem>>{};
      for (final item in _items) {
        (grouped[item.draft.barcode] ??= <_EditableDraftItem>[]).add(item);
      }
      final groups = grouped.entries.toList(growable: false);

      return Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(groups.length, (i) {
            final group = groups[i];
            final blockItems = group.value;
            final first = blockItems.first;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Barcode: ${group.key}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${first.draft.brandName} • ${first.draft.gender.name} • ${first.draft.itemType1}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: metaStyle,
                            ),
                            const SizedBox(height: 6),
                            ...List<Widget>.generate(blockItems.length, (j) {
                              final row = blockItems[j];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: j == blockItems.length - 1 ? 0 : 3,
                                ),
                                child: Text(
                                  '${j + 1}. ${_displayName(row.draft)} | ${row.draft.size} / ${row.draft.colour} | Qty: ${row.quantity}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: _itemsLocked
                            ? null
                            : () => _editBlockByBarcode(group.key),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete block',
                        onPressed: _itemsLocked
                            ? null
                            : () => _removeBlockByBarcode(group.key),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                ),
                if (i != groups.length - 1) const Divider(height: 1),
              ],
            );
          }),
        ),
      );
    }

    Widget actionRow({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      required BorderRadius borderRadius,
    }) {
      return InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(22),
                  borderRadius: BorderRadius.circular(14),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 2,
          backgroundColor: colorScheme.surface.withOpacity(0.94),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _handleBackPressed,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stock Entry',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${widget.vendor.name} • ${widget.vendor.phone}${(widget.vendor.address == null || widget.vendor.address!.trim().isEmpty) ? '' : ' • ${widget.vendor.address}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton.filledTonal(
              tooltip: 'Vendor history',
              onPressed: () {
                Navigator.of(
                  context,
                ).push(StockEntryHistoryScreen.route(vendor: widget.vendor));
              },
              icon: const Icon(Icons.history_rounded),
            ),
          ],
        ),
        body: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 34,
                          width: 34,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.qr_code_scanner_rounded,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Quick actions',
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
                    const SizedBox(height: 4),
                    Text(
                      'Scan an existing barcode or generate a new one.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Material(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          actionRow(
                            icon: Icons.document_scanner_outlined,
                            title: 'Scan barcode',
                            subtitle: 'Use camera to scan an existing barcode',
                            onTap: _scanBarcode,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: colorScheme.outlineVariant.withAlpha(120),
                          ),
                          actionRow(
                            icon: Icons.auto_fix_high_rounded,
                            title: 'Generate barcode',
                            subtitle: 'Create a new barcode with item details',
                            onTap: _generateBarcode,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(20),
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
            if (_items.isEmpty)
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        height: 54,
                        width: 54,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.qr_code_2_rounded,
                          color: colorScheme.primary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No items added yet',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use Quick actions to scan or generate barcodes.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              buildItemsList(),
            ],
            const SizedBox(height: 14),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _items.isEmpty ? null : _confirmAndOpenPayment,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
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
