import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../models/vendor_bill.dart';

/// Renders an INR amount with a font that includes the ₹ glyph.
class InrAmountText extends StatelessWidget {
  const InrAmountText(
    this.amountDisplay, {
    super.key,
    this.style,
    this.prefixSpace = true,
  });

  final String amountDisplay;
  final TextStyle? style;
  final bool prefixSpace;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.titleMedium;
    final symbolStyle = (base ?? const TextStyle()).copyWith(
      fontFamily: 'Roboto',
      fontFamilyFallback: const ['Arial', 'Noto Sans', 'sans-serif'],
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: prefixSpace ? '₹ ' : '₹', style: symbolStyle),
          TextSpan(text: amountDisplay, style: base),
        ],
      ),
    );
  }
}

class VendorDueChip extends StatelessWidget {
  const VendorDueChip({super.key, required this.due});

  final VendorDueInfo due;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color bg, Color fg) = () {
      if (due.isPaid) {
        return (
          AppColors.emerald.withValues(alpha: 0.12),
          AppColors.emeraldDark,
        );
      }
      if (due.isOverdue) {
        return (
          AppColors.error.withValues(alpha: 0.12),
          AppColors.error,
        );
      }
      if (due.isDueSoon) {
        return (
          AppColors.warning.withValues(alpha: 0.16),
          const Color(0xFFB45309),
        );
      }
      return (
        AppColors.slate100,
        AppColors.slate600,
      );
    }();

    final label = due.days != null
        ? (due.isOverdue
            ? 'Overdue ${due.days!.abs()}d'
            : due.days == 0
                ? 'Due today'
                : 'Due in ${due.days}d')
        : due.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class PayableTotalCard extends StatelessWidget {
  const PayableTotalCard({
    super.key,
    required this.totalDisplay,
    this.pendingBills = 0,
    this.overdue = 0,
    this.dueThisWeek = 0,
  });

  final String totalDisplay;
  final int pendingBills;
  final int overdue;
  final int dueThisWeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  colorScheme.surface,
                  AppColors.emerald.withValues(alpha: 0.12),
                ]
              : [
                  Colors.white,
                  AppColors.emerald.withValues(alpha: 0.08),
                ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.emerald.withValues(alpha: 0.18),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.emerald.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.emerald,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Total payable',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InrAmountText(
            totalDisplay,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryMiniStat(
                  label: 'Open bills',
                  value: '$pendingBills',
                ),
              ),
              Expanded(
                child: _SummaryMiniStat(
                  label: 'Overdue',
                  value: '$overdue',
                  emphasize: overdue > 0,
                ),
              ),
              Expanded(
                child: _SummaryMiniStat(
                  label: 'Due soon',
                  value: '$dueThisWeek',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMiniStat extends StatelessWidget {
  const _SummaryMiniStat({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: emphasize ? AppColors.error : colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Search bar shown above the total card on the Pay Vendor hub.
class VendorsSearchBar extends StatelessWidget {
  const VendorsSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasText = controller.text.trim().isNotEmpty;

        return TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search vendor',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 22,
              color: colorScheme.onSurfaceVariant,
            ),
            suffixIcon: hasText
                ? IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: const Icon(Icons.close_rounded, size: 20),
                  )
                : null,
            filled: true,
            fillColor: isDark ? colorScheme.surface : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColors.slate200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide:
                  const BorderSide(color: AppColors.emerald, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        );
      },
    );
  }
}

class VendorsFilterButton extends StatelessWidget {
  const VendorsFilterButton({
    super.key,
    required this.active,
    required this.onTap,
  });

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: active
          ? AppColors.emerald.withValues(alpha: 0.1)
          : (isDark ? theme.colorScheme.surface : Colors.white),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: Container(
          height: 48,
          width: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: active
                  ? AppColors.emerald.withValues(alpha: 0.3)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : AppColors.slate200),
            ),
          ),
          child: Badge(
            isLabelVisible: active,
            smallSize: 8,
            child: Icon(
              Icons.tune_rounded,
              size: 20,
              color: active
                  ? AppColors.emeraldDark
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class VendorPayableTile extends StatelessWidget {
  const VendorPayableTile({
    super.key,
    required this.group,
    required this.onTap,
  });

  final VendorPayableGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final billLabel =
        '${group.billCount} bill${group.billCount == 1 ? '' : 's'}';
    final overdueCount = group.bills.where((b) => b.due.isOverdue).length;

    return AppSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: AppColors.emerald,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  overdueCount > 0
                      ? '$billLabel · $overdueCount overdue'
                      : billLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: overdueCount > 0
                        ? AppColors.error
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              InrAmountText(
                group.pendingDisplay,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.emeraldDark,
                ),
              ),
              const SizedBox(height: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class VendorBillSelectTile extends StatelessWidget {
  const VendorBillSelectTile({
    super.key,
    required this.bill,
    required this.selected,
    required this.onToggle,
    this.onOpenDetails,
  });

  final VendorBill bill;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback? onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppSurfaceCard(
      onTap: onToggle,
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
      borderColor: selected ? AppColors.emerald.withValues(alpha: 0.4) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: selected,
            onChanged: (_) => onToggle(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Purchase #${bill.stkNo}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      bill.billDate,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    VendorDueChip(due: bill.due),
                  ],
                ),
              ],
            ),
          ),
          if (onOpenDetails != null)
            IconButton(
              tooltip: 'Details',
              onPressed: onOpenDetails,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
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
              const SizedBox(height: 4),
              Text(
                bill.statusDisplay,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum StatementEntryKind { purchase, payment, discount }

class StatementEntryTile extends StatelessWidget {
  const StatementEntryTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amountDisplay,
    required this.kind,
    this.amountPrefix,
    this.onTap,
    this.trailingLabel,
  });

  final String title;
  final String subtitle;
  final String amountDisplay;
  final StatementEntryKind kind;
  final String? amountPrefix;
  final VoidCallback? onTap;
  final String? trailingLabel;

  Color get _amountColor {
    switch (kind) {
      case StatementEntryKind.purchase:
        return AppColors.emeraldDark;
      case StatementEntryKind.payment:
      case StatementEntryKind.discount:
        return const Color(0xFFC2410C);
    }
  }

  Color get _iconBg {
    switch (kind) {
      case StatementEntryKind.purchase:
        return AppColors.emerald.withValues(alpha: 0.1);
      case StatementEntryKind.payment:
      case StatementEntryKind.discount:
        return const Color(0xFFC2410C).withValues(alpha: 0.1);
    }
  }

  Color get _iconColor {
    switch (kind) {
      case StatementEntryKind.purchase:
        return AppColors.emerald;
      case StatementEntryKind.payment:
      case StatementEntryKind.discount:
        return const Color(0xFFC2410C);
    }
  }

  IconData get _icon {
    switch (kind) {
      case StatementEntryKind.purchase:
        return Icons.inventory_2_outlined;
      case StatementEntryKind.payment:
        return Icons.payments_outlined;
      case StatementEntryKind.discount:
        return Icons.percent_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.slate200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, size: 20, color: _iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (trailingLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    trailingLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.emeraldDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (amountPrefix != null)
                    Text(
                      amountPrefix!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _amountColor,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  InrAmountText(
                    amountDisplay,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _amountColor,
                    ),
                  ),
                ],
              ),
              if (onTap != null) ...[
                const SizedBox(height: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: content,
      ),
    );
  }
}

Future<void> showStatementPaymentDetailSheet({
  required BuildContext context,
  required VendorStatementPayment payment,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StatementPaymentDetailSheet(payment: payment),
  );
}

class _StatementPaymentDetailSheet extends StatelessWidget {
  const _StatementPaymentDetailSheet({required this.payment});

  final VendorStatementPayment payment;

  static final NumberFormat _inr = NumberFormat('#,##,##0.00', 'en_IN');
  static final DateFormat _dateTimeFmt = DateFormat('dd MMM yyyy · hh:mm a');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Payment details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC2410C).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              const Color(0xFFC2410C).withValues(alpha: 0.14),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Amount paid',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '− ₹ ${payment.amountDisplay}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFC2410C),
                              letterSpacing: -0.5,
                              fontFamily: 'Roboto',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _dateTimeFmt.format(payment.paidAt),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (payment.hasAdjustments) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (payment.discount > 0)
                            _DetailChip(
                              label:
                                  'Discount −₹ ${_inr.format(payment.discount)}',
                              color: const Color(0xFFC2410C),
                            ),
                          if (payment.surcharge > 0)
                            _DetailChip(
                              label:
                                  'Surcharge +₹ ${_inr.format(payment.surcharge)}',
                              color: AppColors.emeraldDark,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      'Bills paid (${payment.billCount})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.35)
                            : AppColors.slate50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : AppColors.slate200,
                        ),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < payment.bills.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.4),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Purchase #${payment.bills[i].stkNo}',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          payment.bills[i].billDate,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  InrAmountText(
                                    payment.bills[i].pendingDisplay,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ledger API coming next — this payment is shown from this session.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Future<void> showPaymentReceiptSheet({
  required BuildContext context,
  required String vendorName,
  required String amountDisplay,
  required List<VendorBill> bills,
  double discount = 0,
  double surcharge = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaymentReceiptSheet(
      vendorName: vendorName,
      amountDisplay: amountDisplay,
      bills: bills,
      discount: discount,
      surcharge: surcharge,
    ),
  );
}

class _PaymentReceiptSheet extends StatelessWidget {
  const _PaymentReceiptSheet({
    required this.vendorName,
    required this.amountDisplay,
    required this.bills,
    this.discount = 0,
    this.surcharge = 0,
  });

  final String vendorName;
  final String amountDisplay;
  final List<VendorBill> bills;
  final double discount;
  final double surcharge;

  static final NumberFormat _inr = NumberFormat('#,##,##0.00', 'en_IN');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final billCountLabel =
        '${bills.length} bill${bills.length == 1 ? '' : 's'}';

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        constraints: BoxConstraints(maxHeight: media.size.height * 0.78),
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 34,
                          color: AppColors.emerald,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Payment recorded',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      vendorName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.emerald.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Amount paid',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InrAmountText(
                            amountDisplay,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              color: AppColors.emeraldDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (discount > 0 || surcharge > 0) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          if (discount > 0)
                            _ReceiptAdjustmentChip(
                              label: 'Discount −₹ ${_inr.format(discount)}',
                              tone: _ReceiptChipTone.discount,
                            ),
                          if (surcharge > 0)
                            _ReceiptAdjustmentChip(
                              label: 'Surcharge +₹ ${_inr.format(surcharge)}',
                              tone: _ReceiptChipTone.surcharge,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Text(
                          'Applied to',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          billCountLabel,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.35)
                            : AppColors.slate50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : AppColors.slate200,
                        ),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < bills.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.4),
                              ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Purchase #${bills[i].stkNo}',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          bills[i].billDate,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  InrAmountText(
                                    bills[i].pendingDisplay,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
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
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                16 + media.viewPadding.bottom.clamp(0, 8),
              ),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ReceiptChipTone { discount, surcharge }

class _ReceiptAdjustmentChip extends StatelessWidget {
  const _ReceiptAdjustmentChip({
    required this.label,
    required this.tone,
  });

  final String label;
  final _ReceiptChipTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDiscount = tone == _ReceiptChipTone.discount;
    final fg = isDiscount ? const Color(0xFFC2410C) : AppColors.emeraldDark;
    final bg = isDiscount
        ? const Color(0xFFC2410C).withValues(alpha: 0.1)
        : AppColors.emerald.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class VendorsEmptyState extends StatelessWidget {
  const VendorsEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.check_circle_outline_rounded,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 32, color: AppColors.emerald),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
