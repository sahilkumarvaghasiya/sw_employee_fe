import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/products_provider.dart';

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

  final TextEditingController _maxPriceController = TextEditingController();
  final FocusNode _maxPriceFocusNode = FocusNode();

  double? _priceMaxLimit;
  static const double _minAllowedPrice = 100;

  @override
  void dispose() {
    _maxPriceController.dispose();
    _maxPriceFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final provider = context.watch<ProductsProvider>();

    if (_priceRange == null || _priceMaxLimit == null) {
      final bounds = provider.priceBounds;

      _genders
        ..clear()
        ..addAll(provider.selectedGenders);

      final selected = provider.selectedPriceRange;
      final start = selected.start < _minAllowedPrice
          ? _minAllowedPrice
          : selected.start;
      final end = selected.end < start ? start : selected.end;
      _priceRange = RangeValues(start, end);
      _dateRange = provider.selectedDateRange;

      _priceMaxLimit = bounds.$2 < end ? end : bounds.$2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final provider = context.watch<ProductsProvider>();
    final bounds = provider.priceBounds;

    final range = _priceRange ?? provider.selectedPriceRange;

    final sliderMin = _minAllowedPrice;
    final sliderMax = (_priceMaxLimit ?? bounds.$2) < sliderMin
        ? sliderMin
        : (_priceMaxLimit ?? bounds.$2);

    if (!_maxPriceFocusNode.hasFocus) {
      final nextText = sliderMax.toStringAsFixed(0);
      if (_maxPriceController.text != nextText) {
        _maxPriceController.value = TextEditingValue(
          text: nextText,
          selection: TextSelection.collapsed(offset: nextText.length),
        );
      }
    }

    RangeValues clampRangeToMax(RangeValues v, double maxLimit) {
      final start = v.start.clamp(sliderMin, maxLimit);
      final end = v.end.clamp(sliderMin, maxLimit);

      if (start > end) {
        return RangeValues(end, end);
      }
      return RangeValues(start, end);
    }

    RangeValues clampRange(RangeValues v) {
      final start = v.start.clamp(sliderMin, sliderMax);
      final end = v.end.clamp(sliderMin, sliderMax);

      if (start > end) {
        return RangeValues(end, end);
      }
      return RangeValues(start, end);
    }

    void setRange(RangeValues v) {
      final nextMax = v.end;
      if ((_priceMaxLimit ?? bounds.$2) < nextMax) {
        _priceMaxLimit = nextMax;
      }
      _priceRange = clampRange(v);
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
              TextButton(
                onPressed: () {
                  setState(() {
                    _genders.clear();
                    _priceMaxLimit = bounds.$2;
                    _priceRange = RangeValues(sliderMin, bounds.$2);
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
                '₹${range.start.toStringAsFixed(0)}',
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
                '₹${range.end.toStringAsFixed(0)}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                'Min ₹${sliderMin.toStringAsFixed(0)}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          RangeSlider(
            values: range,
            min: sliderMin,
            max: sliderMax,
            labels: RangeLabels(
              '₹${range.start.toStringAsFixed(0)}',
              '₹${range.end.toStringAsFixed(0)}',
            ),
            onChanged: (v) {
              setState(() {
                setRange(v);
              });
            },
          ),

          const SizedBox(height: 10),

          TextField(
            controller: _maxPriceController,
            focusNode: _maxPriceFocusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Max price',
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
                tooltip: 'Use default max',
                onPressed: () {
                  setState(() {
                    _priceMaxLimit = bounds.$2;
                    _priceRange = clampRangeToMax(
                      _priceRange ?? provider.selectedPriceRange,
                      _priceMaxLimit!,
                    );
                  });
                },
                icon: const Icon(Icons.refresh),
              ),
            ),
            onChanged: (value) {
              final parsed = double.tryParse(value.trim());
              if (parsed == null) return;
              final nextMax = parsed < sliderMin ? sliderMin : parsed;
              setState(() {
                _priceMaxLimit = nextMax;
                _priceRange = clampRangeToMax(
                  _priceRange ?? provider.selectedPriceRange,
                  nextMax,
                );
              });
            },
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
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now(),
                      initialDateRange: _dateRange,
                    );
                    if (picked == null) return;
                    setState(() => _dateRange = picked);
                  },
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
                  priceRange: _priceRange ?? provider.selectedPriceRange,
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
