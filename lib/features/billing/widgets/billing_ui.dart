import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../products/models/product.dart';

class BillingSearchResultTile extends StatelessWidget {
  const BillingSearchResultTile({
    super.key,
    required this.product,
    required this.priceLabel,
    required this.onTap,
    this.isLoading = false,
  });

  final Product product;
  final String priceLabel;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final company = product.companyName.trim();
    final size = product.size.trim();
    final meta = [
      if (company.isNotEmpty) company,
      if (size.isNotEmpty && size != '—') 'Size $size',
    ].join(' · ');

    return Material(
      color: isDark ? colorScheme.surface : Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppColors.slate200,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                priceLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.emeraldDark,
                ),
              ),
              const SizedBox(width: 8),
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.add_circle_rounded,
                  size: 22,
                  color: colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class BillingCheckoutBar extends StatelessWidget {
  const BillingCheckoutBar({
    super.key,
    required this.itemCount,
    required this.subtotalLabel,
    required this.discountLabel,
    required this.onPayment,
    this.enabled = true,
    this.isRefund = false,
  });

  final int itemCount;
  final String subtotalLabel;
  final String discountLabel;
  final VoidCallback? onPayment;
  final bool enabled;
  final bool isRefund;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isRefund
            ? (isDark
                ? AppColors.error.withValues(alpha: 0.16)
                : AppColors.error.withValues(alpha: 0.08))
            : (isDark ? AppColors.slate900 : Colors.white),
        border: Border(
          top: BorderSide(
            color: isRefund
                ? AppColors.error.withValues(alpha: 0.35)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColors.slate200),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isRefund
                          ? 'Refund due'
                          : '$itemCount item${itemCount == 1 ? '' : 's'}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isRefund ? AppColors.error : null,
                      ),
                    ),
                    Text(
                      isRefund
                          ? '$subtotalLabel · $itemCount item${itemCount == 1 ? '' : 's'}'
                          : '$subtotalLabel · Disc $discountLabel',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isRefund
                            ? AppColors.error
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight:
                            isRefund ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: enabled ? onPayment : null,
                icon: Icon(
                  isRefund
                      ? Icons.assignment_return_rounded
                      : Icons.payments_outlined,
                  size: 20,
                ),
                label: Text(isRefund ? 'Refund' : 'Payment'),
                style: FilledButton.styleFrom(
                  backgroundColor: isRefund ? AppColors.error : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large payable amount header for payment sheets.
class BillingPayableHero extends StatelessWidget {
  const BillingPayableHero({
    super.key,
    required this.amount,
    this.label = 'Amount to pay',
    this.subtitle,
    this.isRefund = false,
  });

  final String amount;
  final String label;
  final String? subtitle;
  final bool isRefund;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isRefund ? AppColors.error : AppColors.emerald;
    final accentDark = isRefund ? AppColors.error : AppColors.emeraldDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  accent.withValues(alpha: 0.28),
                  accent.withValues(alpha: 0.1),
                ]
              : [
                  accent.withValues(alpha: 0.14),
                  accent.withValues(alpha: 0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: accent.withValues(alpha: isRefund ? 0.4 : 0.25),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isRefund ? accentDark : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: accentDark,
              letterSpacing: -0.5,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isRefund
                    ? accentDark.withValues(alpha: 0.8)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact label/value row for bill breakdown.
class BillingSummaryLine extends StatelessWidget {
  const BillingSummaryLine({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: (bold
                    ? theme.textTheme.titleSmall
                    : theme.textTheme.bodySmall)
                ?.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable payment method row for the payment picker sheet.
class BillingPaymentMethodTile extends StatelessWidget {
  const BillingPaymentMethodTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.enabled = true,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? colorScheme.surface : Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: enabled && !loading ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: AppColors.emerald),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps modal bottom sheets at a stable height when the keyboard opens.
///
/// Caps visible height and puts keyboard inset inside scroll padding so the
/// sheet does not grow to full screen when a field is focused.
class BillingKeyboardSheetBody extends StatelessWidget {
  const BillingKeyboardSheetBody({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.85,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 16),
  });

  final Widget child;
  final double maxHeightFactor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final maxHeight = media.size.height * maxHeightFactor;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: padding.copyWith(
            bottom: padding.bottom + keyboardInset,
          ),
          child: child,
        ),
      ),
    );
  }
}
