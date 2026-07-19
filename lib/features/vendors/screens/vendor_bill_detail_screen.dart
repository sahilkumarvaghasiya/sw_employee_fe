import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../models/vendor_bill.dart';
import '../providers/vendors_provider.dart';
import '../widgets/vendors_ui.dart';

class VendorBillDetailScreen extends StatefulWidget {
  const VendorBillDetailScreen({
    super.key,
    required this.initialBill,
  });

  final VendorBill initialBill;

  static Route<void> route({
    required VendorBill bill,
    required VendorsProvider provider,
  }) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: '/vendors/bills/${bill.id}'),
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: VendorBillDetailScreen(initialBill: bill),
      ),
    );
  }

  @override
  State<VendorBillDetailScreen> createState() => _VendorBillDetailScreenState();
}

class _VendorBillDetailScreenState extends State<VendorBillDetailScreen> {
  late VendorBill _bill;

  @override
  void initState() {
    super.initState();
    _bill = widget.initialBill;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBill();
    });
  }

  Future<void> _refreshBill() async {
    try {
      final updated =
          await context.read<VendorsProvider>().fetchBill(_bill.id);
      if (!mounted) return;
      setState(() => _bill = updated);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _bill.vendor.isEmpty ? 'Bill' : _bill.vendor,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _bill.isFullyPaid ? 'Paid' : 'Pending',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                InrAmountText(
                  _bill.isFullyPaid
                      ? _bill.totalDisplay
                      : _bill.pendingDisplay,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  [
                    _bill.stkNo,
                    _bill.billDate,
                    if (_bill.due.label.isNotEmpty) _bill.due.label,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _bill.due.isOverdue
                        ? AppColors.error
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!_bill.isFullyPaid) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  _SimpleRow(
                    label: 'Bill total',
                    value: _bill.totalDisplay,
                  ),
                  const SizedBox(height: 8),
                  _SimpleRow(
                    label: 'Already paid',
                    value: _bill.paidDisplay,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Items',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (_bill.stockLines.isEmpty)
            Text(
              'No items on this bill.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            AppSurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < _bill.stockLines.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _lineTitle(_bill.stockLines[i]),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '× ${_bill.stockLines[i].qty}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _lineTitle(VendorStockLine line) {
    final parts = [
      if (line.itemType != null && line.itemType!.isNotEmpty) line.itemType,
      if (line.brand != null && line.brand!.isNotEmpty) line.brand,
    ];
    return parts.isEmpty ? 'Item' : parts.join(' · ');
  }
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        InrAmountText(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
