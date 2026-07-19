import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../models/vendor_bill.dart';
import '../providers/vendors_provider.dart';
import '../widgets/vendors_ui.dart';
import 'vendor_bill_detail_screen.dart';

class VendorPayableDetailScreen extends StatefulWidget {
  const VendorPayableDetailScreen({
    super.key,
    required this.group,
  });

  final VendorPayableGroup group;

  static Route<void> route({
    required VendorPayableGroup group,
    required VendorsProvider provider,
  }) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: '/vendors/payable/${group.vendorName}'),
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: VendorPayableDetailScreen(group: group),
      ),
    );
  }

  @override
  State<VendorPayableDetailScreen> createState() =>
      _VendorPayableDetailScreenState();
}

class _VendorPayableDetailScreenState extends State<VendorPayableDetailScreen> {
  final Set<int> _selectedIds = <int>{};
  static final NumberFormat _inr = NumberFormat('#,##,##0.00', 'en_IN');

  void _toggle(int billId) {
    setState(() {
      if (_selectedIds.contains(billId)) {
        _selectedIds.remove(billId);
      } else {
        _selectedIds.add(billId);
      }
    });
  }

  void _selectAll(List<VendorBill> bills) {
    setState(() {
      if (_selectedIds.length == bills.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(bills.map((b) => b.id));
      }
    });
  }

  Future<void> _paySelected(List<VendorBill> bills) async {
    final selected = bills
        .where((b) => _selectedIds.contains(b.id))
        .toList(growable: false);
    if (selected.isEmpty) return;

    final total = selected.fold<double>(0, (sum, b) => sum + b.pendingAmount);
    final totalDisplay = _inr.format(total);

    final amount = await showBulkPaymentSheet(
      context: context,
      title: 'Pay ${widget.group.displayName}',
      subtitle:
          '${selected.length} bill${selected.length == 1 ? '' : 's'} · Rs. $totalDisplay',
      selectedTotal: total,
      selectedTotalDisplay: totalDisplay,
    );
    if (amount == null || !mounted) return;

    try {
      await context.read<VendorsProvider>().bulkPay(
            billIds: selected.map((b) => b.id).toList(growable: false),
            amount: amount,
          );
      if (!mounted) return;
      setState(() => _selectedIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment allocated')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('ClientException: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<VendorsProvider>();
    final live = provider.vendorByName(widget.group.vendorName) ?? widget.group;
    final bills = live.bills.where((b) => !b.isFullyPaid).toList();
    final validIds = bills.map((b) => b.id).toSet();
    final selectedBills =
        bills.where((b) => _selectedIds.contains(b.id)).toList();
    final selectedTotal =
        selectedBills.fold<double>(0, (sum, b) => sum + b.pendingAmount);
    final selectedTotalDisplay = _inr.format(selectedTotal);
    final allSelected =
        bills.isNotEmpty &&
        _selectedIds.intersection(validIds).length == bills.length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          live.displayName,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (bills.isNotEmpty)
            TextButton(
              onPressed: () => _selectAll(bills),
              child: Text(allSelected ? 'Clear' : 'Select all'),
            ),
        ],
      ),
      bottomNavigationBar: selectedBills.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${selectedBills.length} selected',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          InrAmountText(
                            selectedTotalDisplay,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: provider.isPaying
                          ? null
                          : () => _paySelected(bills),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(120, 48),
                      ),
                      child: Text(provider.isPaying ? 'Saving…' : 'Pay'),
                    ),
                  ],
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          PayableTotalCard(totalDisplay: live.pendingDisplay),
          const SizedBox(height: 20),
          Text(
            'Open bills',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select one or more bills, then pay a single amount',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (bills.isEmpty)
            Text(
              'All bills for this vendor are paid.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...bills.map((bill) {
              final selected = _selectedIds.contains(bill.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppSurfaceCard(
                  onTap: () => _toggle(bill.id),
                  padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
                  borderColor: selected
                      ? AppColors.emerald.withValues(alpha: 0.45)
                      : null,
                  child: Row(
                    children: [
                      Checkbox(
                        value: selected,
                        onChanged: (_) => _toggle(bill.id),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bill.stkNo,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                bill.billDate,
                                if (bill.due.label.isNotEmpty) bill.due.label,
                              ].join(' · '),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: bill.due.isOverdue
                                    ? AppColors.error
                                    : colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          InrAmountText(
                            bill.pendingDisplay,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                VendorBillDetailScreen.route(
                                  bill: bill,
                                  provider: provider,
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Details'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
