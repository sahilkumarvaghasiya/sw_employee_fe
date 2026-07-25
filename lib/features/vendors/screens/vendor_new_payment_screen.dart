import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../models/vendor_bill.dart';
import '../providers/vendors_provider.dart';
import '../widgets/vendors_ui.dart';
import 'vendor_bill_detail_screen.dart';

class NewPaymentResult {
  const NewPaymentResult({
    required this.amount,
    required this.billIds,
    required this.paymentDate,
    required this.printPdf,
    this.discount = 0,
    this.surcharge = 0,
  });

  final double amount;
  final List<int> billIds;
  final DateTime paymentDate;
  final bool printPdf;
  final double discount;
  final double surcharge;
}

class VendorNewPaymentScreen extends StatefulWidget {
  const VendorNewPaymentScreen({
    super.key,
    required this.vendorName,
    required this.pendingDisplay,
    required this.pendingAmount,
    required this.bills,
    this.initialSelectedIds = const <int>{},
  });

  final String vendorName;
  final String pendingDisplay;
  final double pendingAmount;
  final List<VendorBill> bills;
  final Set<int> initialSelectedIds;

  static Route<NewPaymentResult?> route({
    required String vendorName,
    required String pendingDisplay,
    required double pendingAmount,
    required List<VendorBill> bills,
    required VendorsProvider provider,
    Set<int> initialSelectedIds = const <int>{},
  }) {
    return MaterialPageRoute<NewPaymentResult?>(
      settings: RouteSettings(name: '/vendors/payable/$vendorName/new-payment'),
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: VendorNewPaymentScreen(
          vendorName: vendorName,
          pendingDisplay: pendingDisplay,
          pendingAmount: pendingAmount,
          bills: bills,
          initialSelectedIds: initialSelectedIds,
        ),
      ),
    );
  }

  @override
  State<VendorNewPaymentScreen> createState() => _VendorNewPaymentScreenState();
}

class _VendorNewPaymentScreenState extends State<VendorNewPaymentScreen> {
  static final NumberFormat _inr = NumberFormat('#,##,##0.00', 'en_IN');
  static final DateFormat _dateFmt = DateFormat('dd/MM/yyyy');

  late final DateTime _paymentDate;
  late final Set<int> _selectedIds;
  late final TextEditingController _paidController;

  bool _transactionsExpanded = true;
  bool _printPdf = false;
  double _discount = 0;
  double _surcharge = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _paymentDate = DateTime(now.year, now.month, now.day);
    _selectedIds = {...widget.initialSelectedIds};
    if (_selectedIds.isEmpty && widget.bills.isNotEmpty) {
      _selectedIds.add(widget.bills.first.id);
    }
    final initialPaid = _selectedTotal;
    _paidController = TextEditingController(
      text: initialPaid > 0 ? initialPaid.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _paidController.dispose();
    super.dispose();
  }

  List<VendorBill> get _selectedBills =>
      widget.bills.where((b) => _selectedIds.contains(b.id)).toList();

  double get _selectedTotal =>
      _selectedBills.fold<double>(0, (sum, b) => sum + b.pendingAmount);

  double get _paidAmount {
    final raw = _paidController.text.trim().replaceAll(',', '');
    return double.tryParse(raw) ?? 0;
  }

  double get _adjustedPending =>
      (widget.pendingAmount - _discount + _surcharge).clamp(0, double.infinity);

  double get _remained =>
      (_adjustedPending - _paidAmount).clamp(0, double.infinity);

  void _toggleBill(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        if (_selectedIds.length == 1) return;
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      _paidController.text = _selectedTotal.toStringAsFixed(2);
      _error = null;
    });
  }

  Future<void> _addDiscountOrSurcharge() async {
    final result = await showModalBottomSheet<_AdjustmentDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _DiscountSurchargeSheet(
        pendingAmount: widget.pendingAmount,
        currentDiscount: _discount,
        currentSurcharge: _surcharge,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _discount = result.discount;
      _surcharge = result.surcharge;
      _error = null;
    });
  }

  void _submit() {
    final amount = _paidAmount;
    if (_selectedIds.isEmpty) {
      setState(() => _error = 'Select at least one transaction');
      return;
    }
    if (amount < 0.01) {
      setState(() => _error = 'Enter a paid amount');
      return;
    }
    final maxPayable = _selectedTotal + _surcharge;
    if (amount > maxPayable + 0.001) {
      setState(() {
        _error = 'Cannot exceed selected total ₹ ${_inr.format(maxPayable)}';
      });
      return;
    }

    Navigator.of(context).pop(
      NewPaymentResult(
        amount: amount,
        billIds: _selectedIds.toList(growable: false),
        paymentDate: _paymentDate,
        printPdf: _printPdf,
        discount: _discount,
        surcharge: _surcharge,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<VendorsProvider>();
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('New Payment'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: provider.isPaying ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(provider.isPaying ? 'Saving…' : 'Save payment'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date*',
              filled: true,
            ),
            child: Text(
              _dateFmt.format(_paymentDate),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Contact*',
              filled: true,
            ),
            child: Text(
              widget.vendorName.toUpperCase(),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Pending amount',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              InrAmountText(
                _inr.format(_adjustedPending),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.emeraldDark,
                ),
              ),
            ],
          ),
          if (_discount > 0 || _surcharge > 0) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_discount > 0)
                  InputChip(
                    label: Text('Discount (−) ₹ ${_inr.format(_discount)}'),
                    onDeleted: () => setState(() => _discount = 0),
                    visualDensity: VisualDensity.compact,
                  ),
                if (_surcharge > 0)
                  InputChip(
                    label: Text('Surcharge (+) ₹ ${_inr.format(_surcharge)}'),
                    onDeleted: () => setState(() => _surcharge = 0),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _paidController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: 'Paid amount',
              prefixText: '₹ ',
              filled: true,
              errorText: _error,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Remaining: ₹ ${_inr.format(_remained)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _addDiscountOrSurcharge,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.homeAccentTeal,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('+ Add discount / surcharge'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: () => setState(
              () => _transactionsExpanded = !_transactionsExpanded,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Transactions',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    _transactionsExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.emerald,
                  ),
                ],
              ),
            ),
          ),
          if (_transactionsExpanded) ...[
            const SizedBox(height: 8),
            ...widget.bills.map(
              (bill) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: VendorBillSelectTile(
                  bill: bill,
                  selected: _selectedIds.contains(bill.id),
                  onToggle: () => _toggleBill(bill.id),
                  onOpenDetails: () {
                    Navigator.of(context).push(
                      VendorBillDetailScreen.route(
                        bill: bill,
                        provider: provider,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHighest
                  : AppColors.slate100,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Print PDF of payment',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              value: _printPdf,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.emerald,
              onChanged: (v) => setState(() => _printPdf = v),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustmentDraft {
  const _AdjustmentDraft({
    required this.discount,
    required this.surcharge,
  });

  final double discount;
  final double surcharge;
}

class _DiscountSurchargeSheet extends StatefulWidget {
  const _DiscountSurchargeSheet({
    required this.pendingAmount,
    required this.currentDiscount,
    required this.currentSurcharge,
  });

  final double pendingAmount;
  final double currentDiscount;
  final double currentSurcharge;

  @override
  State<_DiscountSurchargeSheet> createState() =>
      _DiscountSurchargeSheetState();
}

class _DiscountSurchargeSheetState extends State<_DiscountSurchargeSheet> {
  late String _type;
  late final TextEditingController _amountController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.currentSurcharge > 0 ? 'surcharge' : 'discount';
    final seed = _type == 'surcharge'
        ? widget.currentSurcharge
        : widget.currentDiscount;
    _amountController = TextEditingController(
      text: seed > 0 ? seed.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _apply() {
    final raw = _amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(raw);
    if (amount == null || amount < 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (_type == 'discount' && amount > widget.pendingAmount + 0.001) {
      setState(() => _error = 'Discount cannot exceed pending amount');
      return;
    }

    Navigator.of(context).pop(
      _AdjustmentDraft(
        discount: _type == 'discount' ? amount : 0,
        surcharge: _type == 'surcharge' ? amount : 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + media.viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Discount / Surcharge',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'discount', label: Text('Discount')),
                ButtonSegment(value: 'surcharge', label: Text('Surcharge')),
              ],
              selected: {_type},
              onSelectionChanged: (next) {
                setState(() {
                  _type = next.first;
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _type == 'discount' ? 'Discount amount' : 'Surcharge amount',
                prefixText: '₹ ',
                filled: true,
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _apply,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}
