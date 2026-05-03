import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/inr_format.dart';
import '../models/product.dart';

double _textSpanWidth(TextSpan span, BuildContext context) {
  final tp = TextPainter(
    text: span,
    textDirection: Directionality.of(context),
    maxLines: 1,
  )..layout();
  return tp.width;
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final company = product.companyName.trim().isEmpty
        ? '—'
        : product.companyName.trim();

    final priceLabel = formatInr(product.price, decimalDigits: 0);

    final nameStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final brandStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );
    final tagLabelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
    );
    final tagValueStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );

    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HorizontalScrollText(
                      text: product.name,
                      style: nameStyle,
                      reverse: false,
                    ),
                    const SizedBox(height: 8),
                    _HorizontalScrollText(
                      text: company,
                      style: brandStyle,
                      reverse: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 45,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            priceLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TagValueChip(
                                attributeLabel: 'Size',
                                value: product.size,
                                labelStyle: tagLabelStyle,
                                valueStyle: tagValueStyle,
                                colorScheme: colorScheme,
                                maxChipWidth: constraints.maxWidth,
                              ),
                              const SizedBox(height: 6),
                              _TagValueChip(
                                attributeLabel: 'Colour',
                                value: product.color,
                                labelStyle: tagLabelStyle,
                                valueStyle: tagValueStyle,
                                colorScheme: colorScheme,
                                maxChipWidth: constraints.maxWidth,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// **Size:** value / **Colour:** value inside a pill — no `(` `)` characters.
/// **Leading** edges of both chips line up; **trailing** edges differ. Only the
/// value scrolls when long.
class _TagValueChip extends StatelessWidget {
  const _TagValueChip({
    required this.attributeLabel,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
    required this.colorScheme,
    required this.maxChipWidth,
  });

  static const double _horizontalPadding = 10;
  static const double _verticalPadding = 4;

  final String attributeLabel;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final ColorScheme colorScheme;
  final double maxChipWidth;

  @override
  Widget build(BuildContext context) {
    final lineStyle = valueStyle ?? Theme.of(context).textTheme.labelSmall!;
    final fontSize = lineStyle.fontSize ?? 12;
    final lineHeight = (lineStyle.height ?? 1.2) * fontSize;
    final base = lineStyle;

    final prefixSpan = TextSpan(
      style: base,
      children: [
        TextSpan(text: attributeLabel, style: labelStyle),
        TextSpan(text: ': ', style: base),
      ],
    );
    final prefixW = _textSpanWidth(prefixSpan, context);

    final innerBudget = maxChipWidth - 2 * _horizontalPadding - prefixW;
    final valueSlotCap = math.max(24.0, innerBudget);

    final valueTextW = _textSpanWidth(
      TextSpan(text: value, style: valueStyle),
      context,
    );
    final valueSlotW =
        math.min(math.max(valueTextW, 1.0), valueSlotCap).toDouble();

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxChipWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: _horizontalPadding,
          vertical: _verticalPadding,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colorScheme.outlineVariant.withAlpha(120)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text.rich(prefixSpan, maxLines: 1, softWrap: false),
            SizedBox(
              width: valueSlotW,
              height: lineHeight,
              child: ClipRect(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: false,
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    value,
                    style: valueStyle,
                    softWrap: false,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single-line text in a fixed vertical slot; swipe horizontally when wider than the slot.
class _HorizontalScrollText extends StatelessWidget {
  const _HorizontalScrollText({
    required this.text,
    required this.style,
    required this.reverse,
  });

  final String text;
  final TextStyle? style;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final s = style ?? Theme.of(context).textTheme.bodyMedium!;
    final fontSize = s.fontSize ?? 14;
    final lineHeight = (s.height ?? 1.25) * fontSize;

    return SizedBox(
      height: lineHeight,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: reverse,
        physics: const BouncingScrollPhysics(),
        child: Text(
          text,
          style: s,
          softWrap: false,
          maxLines: 1,
        ),
      ),
    );
  }
}
