import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/products_provider.dart';

abstract class _DateRangeDialogResult {
  const _DateRangeDialogResult();
}

class _DateRangeApplied extends _DateRangeDialogResult {
  const _DateRangeApplied(this.range);

  final DateTimeRange range;
}

class _DateRangeCleared extends _DateRangeDialogResult {
  const _DateRangeCleared();
}

class ProductsFilterSection extends StatefulWidget {
  const ProductsFilterSection({super.key, required this.onCloseRequested});

  final VoidCallback onCloseRequested;

  @override
  State<ProductsFilterSection> createState() => _ProductsFilterSectionState();
}

class _ProductsFilterSectionState extends State<ProductsFilterSection> {
  final Set<ProductGender> _genders = {};
  DateTimeRange? _dateRange;

  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final FocusNode _minPriceFocusNode = FocusNode();
  final FocusNode _maxPriceFocusNode = FocusNode();

  bool _initialized = false;

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _minPriceFocusNode.dispose();
    _maxPriceFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final provider = context.watch<ProductsProvider>();

    if (_initialized) return;
    _initialized = true;

    _genders
      ..clear()
      ..addAll(provider.selectedGenders);

    _dateRange = provider.selectedDateRange;

    final bounds = provider.priceBounds;
    final selected = provider.selectedPriceRange;
    final min = selected.start;
    final max = selected.end;

    // Show empty fields when there's effectively no price filter.
    _minPriceController.text = (min <= bounds.$1) ? '' : min.toStringAsFixed(0);
    _maxPriceController.text = (max >= bounds.$2) ? '' : max.toStringAsFixed(0);
  }

  String _ddMMyyyy(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }

  Future<void> _pickDateRangeDialog() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    DateTime? start = _dateRange?.start;
    DateTime? end = _dateRange?.end;

    final now = DateTime.now();
    final firstDate = now.subtract(const Duration(days: 365));
    final lastDate = now;

    DateTime? clamp(DateTime? d) {
      if (d == null) return null;
      if (d.isBefore(firstDate)) return firstDate;
      if (d.isAfter(lastDate)) return lastDate;
      return d;
    }

    start = clamp(start);
    end = clamp(end);

    final picked = await showDialog<_DateRangeDialogResult?>(
      context: context,
      builder: (dialogContext) {
        String fmt(DateTime? d) {
          if (d == null) return 'Not set';
          return _ddMMyyyy(d);
        }

        Future<void> pickStart() async {
          final next = await showDatePicker(
            context: dialogContext,
            initialDate: start ?? lastDate,
            firstDate: firstDate,
            lastDate: lastDate,
          );
          if (next == null) return;
          start = next;
          if (end != null && end!.isBefore(start!)) {
            end = start;
          }
          (dialogContext as Element).markNeedsBuild();
        }

        Future<void> pickEnd() async {
          final next = await showDatePicker(
            context: dialogContext,
            initialDate: end ?? start ?? lastDate,
            firstDate: firstDate,
            lastDate: lastDate,
          );
          if (next == null) return;
          end = next;
          if (start != null && end!.isBefore(start!)) {
            start = end;
          }
          (dialogContext as Element).markNeedsBuild();
        }

        return AlertDialog(
          title: const Text('Select date range'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Start date'),
                subtitle: Text(fmt(start)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: pickStart,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('End date'),
                subtitle: Text(fmt(end)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: pickEnd,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Text(
                  'Tip: You can cancel anytime using the buttons below.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(const _DateRangeCleared());
              },
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () {
                if (start == null || end == null) {
                  Navigator.of(dialogContext).pop(null);
                  return;
                }

                Navigator.of(dialogContext).pop(
                  _DateRangeApplied(DateTimeRange(start: start!, end: end!)),
                );
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (!mounted || picked == null) return;

    if (picked is _DateRangeCleared) {
      setState(() => _dateRange = null);
      return;
    }

    if (picked is _DateRangeApplied) {
      setState(() => _dateRange = picked.range);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final provider = context.watch<ProductsProvider>();
    final bounds = provider.priceBounds;
    final minBound = bounds.$1;
    final maxBound = bounds.$2;

    void showError(String message) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Filters',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: widget.onCloseRequested,
                icon: const Icon(Icons.close_rounded),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _genders.clear();
                    _dateRange = null;
                    _minPriceController.clear();
                    _maxPriceController.clear();
                  });

                  // Reset means: remove all filters so the full list is visible.
                  provider.resetFilters();
                },
                child: const Text('Reset'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            'Gender',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ProductGender.values.map((g) {
              final selected = _genders.contains(g);
              return FilterChip(
                selected: selected,
                label: Text(g.label),
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _genders.add(g);
                    } else {
                      _genders.remove(g);
                    }
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          Text(
            'Price range',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minPriceController,
                  focusNode: _minPriceFocusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Min',
                    prefixText: '₹',
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _maxPriceController,
                  focusNode: _maxPriceFocusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Max',
                    prefixText: '₹',
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            'Date',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDateRangeDialog,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    _dateRange == null
                        ? 'Select range'
                        : '${_ddMMyyyy(_dateRange!.start)} - ${_ddMMyyyy(_dateRange!.end)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),

          if (_dateRange != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _dateRange = null),
                child: const Text('Clear date'),
              ),
            ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () {
                final minText = _minPriceController.text.trim();
                final maxText = _maxPriceController.text.trim();

                final minParsed = minText.isEmpty
                    ? null
                    : double.tryParse(minText.replaceAll(',', ''));
                final maxParsed = maxText.isEmpty
                    ? null
                    : double.tryParse(maxText.replaceAll(',', ''));

                if (minParsed == null && minText.isNotEmpty) {
                  showError('Enter a valid minimum price.');
                  return;
                }
                if (maxParsed == null && maxText.isNotEmpty) {
                  showError('Enter a valid maximum price.');
                  return;
                }

                final min = (minParsed ?? minBound).clamp(minBound, maxBound);
                final max = (maxParsed ?? maxBound).clamp(minBound, maxBound);

                if (min > max) {
                  showError('Minimum price cannot exceed maximum price.');
                  return;
                }

                provider.applyFilters(
                  genders: _genders,
                  priceRange: RangeValues(min, max),
                  dateRange: _dateRange,
                );
                widget.onCloseRequested();
              },
              icon: const Icon(Icons.tune),
              label: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }
}
