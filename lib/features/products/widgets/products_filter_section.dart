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
  RangeValues? _priceRange;
  DateTimeRange? _dateRange;

  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final FocusNode _minPriceFocusNode = FocusNode();
  final FocusNode _maxPriceFocusNode = FocusNode();

  double? _maxPriceActual;

  static const double _sliderMin = 0;
  static const double _sliderMax = 5000;
  static const double _minMaxPrice = 100;

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

    if (_priceRange == null || _maxPriceActual == null) {
      _genders
        ..clear()
        ..addAll(provider.selectedGenders);

      final selected = provider.selectedPriceRange;
      final rawStart = selected.start < _sliderMin
          ? _sliderMin
          : selected.start;
      final rawEnd = selected.end < _minMaxPrice ? _minMaxPrice : selected.end;

      final effectiveEnd = rawEnd > _sliderMax ? _sliderMax : rawEnd;
      final effectiveStart = rawStart > effectiveEnd ? effectiveEnd : rawStart;

      _priceRange = RangeValues(effectiveStart, effectiveEnd);
      _maxPriceActual = rawEnd;
      _dateRange = provider.selectedDateRange;
    }
  }

  String _moneyLabel(double value) => '₹${value.toStringAsFixed(0)}';

  String _maxMoneyLabel(double actual, double effective) {
    if (actual > _sliderMax) return '₹${_sliderMax.toStringAsFixed(0)}+';
    return _moneyLabel(effective);
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
          return '${d.day}/${d.month}/${d.year}';
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
    final range = _priceRange ?? const RangeValues(_sliderMin, _minMaxPrice);
    final maxActual = _maxPriceActual ?? range.end;

    if (!_minPriceFocusNode.hasFocus) {
      final nextText = range.start.toStringAsFixed(0);
      if (_minPriceController.text != nextText) {
        _minPriceController.value = TextEditingValue(
          text: nextText,
          selection: TextSelection.collapsed(offset: nextText.length),
        );
      }
    }

    if (!_maxPriceFocusNode.hasFocus) {
      final nextText = maxActual.toStringAsFixed(0);
      if (_maxPriceController.text != nextText) {
        _maxPriceController.value = TextEditingValue(
          text: nextText,
          selection: TextSelection.collapsed(offset: nextText.length),
        );
      }
    }

    void setEffectiveRange(RangeValues v, {double? actualMax}) {
      var start = v.start.clamp(_sliderMin, _sliderMax);
      var end = v.end.clamp(_sliderMin, _sliderMax);

      if (end < _minMaxPrice) {
        end = _minMaxPrice;
      }
      if (start > end) start = end;

      _priceRange = RangeValues(start, end);
      _maxPriceActual = actualMax ?? end;
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
                    _priceRange = const RangeValues(_sliderMin, _minMaxPrice);
                    _maxPriceActual = _minMaxPrice;
                    _dateRange = null;
                  });
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
              Text(
                _moneyLabel(range.start),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '  —  ',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _maxMoneyLabel(maxActual, range.end),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
            ],
          ),
          RangeSlider(
            values: range,
            min: _sliderMin,
            max: _sliderMax,
            labels: RangeLabels(
              _moneyLabel(range.start),
              _maxMoneyLabel(maxActual, range.end),
            ),
            onChanged: (v) {
              setState(() {
                setEffectiveRange(v, actualMax: v.end);
              });
            },
          ),

          const SizedBox(height: 10),

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
                  onChanged: (value) {
                    final parsed = double.tryParse(value.trim());
                    if (parsed == null) return;
                    setState(() {
                      final start = parsed.clamp(_sliderMin, _sliderMax);
                      final end = (_priceRange?.end ?? _minMaxPrice);
                      setEffectiveRange(
                        RangeValues(start, end),
                        actualMax: _maxPriceActual,
                      );
                    });
                  },
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
                    suffixIcon: IconButton(
                      tooltip: 'Clear max',
                      onPressed: () {
                        setState(() {
                          _maxPriceActual = _minMaxPrice;
                          setEffectiveRange(
                            RangeValues(
                              _priceRange?.start ?? _sliderMin,
                              _minMaxPrice,
                            ),
                            actualMax: _minMaxPrice,
                          );
                        });
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                  onChanged: (value) {
                    final parsedRaw = double.tryParse(value.trim());
                    if (parsedRaw == null) return;
                    final parsed = parsedRaw < _minMaxPrice
                        ? _minMaxPrice
                        : parsedRaw;
                    final effectiveEnd = parsed > _sliderMax
                        ? _sliderMax
                        : parsed;
                    setState(() {
                      setEffectiveRange(
                        RangeValues(
                          _priceRange?.start ?? _sliderMin,
                          effectiveEnd,
                        ),
                        actualMax: parsed,
                      );
                    });

                    if (parsedRaw < _minMaxPrice) {
                      final nextText = _minMaxPrice.toStringAsFixed(0);
                      _maxPriceController.value = TextEditingValue(
                        text: nextText,
                        selection: TextSelection.collapsed(
                          offset: nextText.length,
                        ),
                      );
                    }
                  },
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
                        : '${_dateRange!.start.day}/${_dateRange!.start.month}/${_dateRange!.start.year} - ${_dateRange!.end.day}/${_dateRange!.end.month}/${_dateRange!.end.year}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Clear date',
                onPressed: _dateRange == null
                    ? null
                    : () => setState(() => _dateRange = null),
                icon: const Icon(Icons.close),
              ),
            ],
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () {
                provider.applyFilters(
                  genders: _genders,
                  priceRange: RangeValues(
                    (_priceRange ?? provider.selectedPriceRange).start,
                    _maxPriceActual ??
                        (_priceRange ?? provider.selectedPriceRange).end,
                  ),
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
