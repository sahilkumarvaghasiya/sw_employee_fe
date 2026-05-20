import 'package:flutter/material.dart';

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

    final dueColor = remainingAmount <= 0
        ? colorScheme.tertiary
        : colorScheme.error;

    final deadlineLabel = deadline == null
        ? 'Select date'
        : MaterialLocalizations.of(context).formatMediumDate(deadline!);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Payment',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: dueColor.withAlpha(31),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: dueColor.withAlpha(89)),
                  ),
                  child: Text(
                    'Due: ${_money(remainingAmount)}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: dueColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
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
                      labelText: 'Total Payment',
                      prefixText: '₹',
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: paidAmountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: onPaidAmountChanged,
                    decoration: const InputDecoration(
                      labelText: 'Paid Amount',
                      prefixText: '₹',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final parsed = double.tryParse(v.trim());
                      if (parsed == null) return 'Enter a valid amount';
                      if (parsed < 0) return 'Amount cannot be negative';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: onPickDeadline,
              icon: const Icon(Icons.event_outlined),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Payment Deadline: $deadlineLabel',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            if (deadlineErrorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
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
    );
  }
}
