import 'package:flutter/material.dart';

import '../../../core/utils/inr_format.dart';
import '../models/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onDelete,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final priceLabel = formatInr(product.price, decimalDigits: 0);
    final cardSurface = Color.lerp(
      colorScheme.surface,
      colorScheme.primary,
      0.02,
    )!;
    final iconSurface = colorScheme.primary.withAlpha(14);

    // Try to parse color if it's a hex value
    Color? displayColor;
    try {
      if (product.color.startsWith('#')) {
        displayColor = Color(
          int.parse(product.color.replaceFirst('#', '0xff')),
        );
      }
    } catch (_) {
      // Color parsing failed, will show as chip instead
    }

    return Container(
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.primary.withAlpha(76)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Product Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                // Product Name + Company Name (separate rolling boxes)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Product Name and Company Name side by side in boxes
                      Row(
                        children: [
                          // Product Name (scrollable box)
                          Expanded(
                            child: Container(
                              height: 26,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withAlpha(
                                  70,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: colorScheme.primary.withAlpha(70),
                                  width: 0.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withAlpha(10),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    product.name,
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.visible,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: colorScheme.onPrimaryContainer,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Company Name (scrollable box)
                          Expanded(
                            child: Container(
                              height: 26,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: colorScheme.outlineVariant.withAlpha(
                                    120,
                                  ),
                                  width: 0.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.shadow.withAlpha(18),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    product.companyName.isEmpty
                                        ? '—'
                                        : product.companyName,
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.visible,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                      color: colorScheme.onSurfaceVariant,
                                      letterSpacing: 0.05,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Chips Row: Gender + Size + Color
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          // Only show gender chip if explicitly provided by backend
                          if (product.gender != null)
                            _MetaChip(
                              text: product.gender!.label,
                              colorScheme: colorScheme,
                              highlighted: true,
                              compact: true,
                            ),
                          _MetaChip(
                            text: product.size,
                            colorScheme: colorScheme,
                            compact: true,
                          ),
                          if (displayColor != null)
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: displayColor,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                  width: 0.5,
                                ),
                              ),
                            )
                          else
                            _MetaChip(
                              text: product.color,
                              colorScheme: colorScheme,
                              compact: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Right Column: Price and Delete
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Price Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.outlineVariant,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        priceLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                // Delete Button
                if (onDelete != null)
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withAlpha(200),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: colorScheme.error,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.text,
    required this.colorScheme,
    this.highlighted = false,
    this.compact = false,
  });

  final String text;
  final ColorScheme colorScheme;
  final bool highlighted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 7, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    final fontSize = compact ? 10.0 : 12.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: highlighted
            ? colorScheme.primary.withAlpha(12)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? colorScheme.primary.withAlpha(28)
              : colorScheme.outlineVariant.withAlpha(100),
          width: 0.8,
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? 96 : 136),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: theme.textTheme.labelSmall?.copyWith(
              color: highlighted
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }
}
