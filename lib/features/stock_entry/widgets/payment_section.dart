import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class PaymentSection extends StatelessWidget {
  const PaymentSection({
    super.key,
    required this.totalPaymentController,
    required this.paidAmountController,
    required this.remainingAmount,
    required this.deadline,
    required this.onPickDeadline,
    this.onPaidAmountChanged,
    this.totalPaymentEditable = false,
    this.onTotalPaymentChanged,
    this.deadlineErrorText,
  });

  final TextEditingController totalPaymentController;
  final TextEditingController paidAmountController;

  final double remainingAmount;
  final DateTime? deadline;

  final VoidCallback onPickDeadline;
  final ValueChanged<String>? onPaidAmountChanged;

  final bool totalPaymentEditable;
  final ValueChanged<String>? onTotalPaymentChanged;
  final String? deadlineErrorText;

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isFullyPaid = remainingAmount <= 0;
    final dueColor = isFullyPaid ? AppColors.emerald : AppColors.error;

    final deadlineLabel = deadline == null
        ? 'Pick a date'
        : MaterialLocalizations.of(context).formatMediumDate(deadline!);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.slate200,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: AppColors.indigo,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Payment details',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: dueColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isFullyPaid ? 'Fully paid' : 'Due ${_money(remainingAmount)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: dueColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: totalPaymentController,
            readOnly: !totalPaymentEditable,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            keyboardType: totalPaymentEditable
                ? const TextInputType.numberWithOptions(decimal: true)
                : null,
            onChanged: totalPaymentEditable
                ? (v) => onTotalPaymentChanged?.call(v)
                : null,
            decoration: const InputDecoration(
              labelText: 'Total amount',
              prefixText: '₹ ',
              prefixIcon: Icon(Icons.calculate_outlined),
            ),
            validator: (v) {
              if (!totalPaymentEditable) return null;
              if (v == null || v.trim().isEmpty) {
                return 'Enter a valid amount';
              }
              final parsed = double.tryParse(v.trim());
              if (parsed == null) return 'Enter a valid amount';
              if (parsed <= 0) return 'Enter a valid amount';
              return null;
            },
          ),
          const SizedBox(height: 14),

          TextFormField(
            controller: paidAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: onPaidAmountChanged,
            decoration: const InputDecoration(
              labelText: 'Paid now',
              prefixText: '₹ ',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final parsed = double.tryParse(v.trim());
              if (parsed == null) return 'Enter a valid amount';
              if (parsed < 0) return 'Amount cannot be negative';
              return null;
            },
          ),
          const SizedBox(height: 14),

          OutlinedButton.icon(
            onPressed: onPickDeadline,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              alignment: Alignment.centerLeft,
            ),
            icon: const Icon(Icons.event_outlined),
            label: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment deadline',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  deadlineLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          if (deadlineErrorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: colorScheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      deadlineErrorText!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
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
}
