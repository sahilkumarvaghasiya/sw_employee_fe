import 'package:flutter/material.dart';
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
  String? _brand;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final provider = context.watch<ProductsProvider>();

    if (_priceRange == null) {
      _genders
        ..clear()
        ..addAll(provider.selectedGenders);
      _priceRange = provider.selectedPriceRange;
      _dateRange = provider.selectedDateRange;
      _brand = provider.selectedBrand;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final provider = context.watch<ProductsProvider>();
    final bounds = provider.priceBounds;

    final range = _priceRange ?? provider.selectedPriceRange;

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
                    _priceRange = RangeValues(bounds.$1, bounds.$2);
                    _dateRange = null;
                    _brand = null;
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
          RangeSlider(
            values: range,
            min: bounds.$1,
            max: bounds.$2,
            divisions: ((bounds.$2 - bounds.$1) / 50).round().clamp(1, 200),
            labels: RangeLabels(
              '₹${range.start.toStringAsFixed(0)}',
              '₹${range.end.toStringAsFixed(0)}',
            ),
            onChanged: (v) => setState(() => _priceRange = v),
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              Expanded(
                child: _InfoPill(
                  label: 'Min',
                  value: '₹${range.start.toStringAsFixed(0)}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoPill(
                  label: 'Max',
                  value: '₹${range.end.toStringAsFixed(0)}',
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

          const SizedBox(height: 16),

          Text(
            'Company / Brand',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            value: _brand,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All brands'),
              ),
              ...provider.availableBrands.map(
                (b) => DropdownMenuItem<String?>(value: b, child: Text(b)),
              ),
            ],
            onChanged: (v) => setState(() => _brand = v),
            decoration: InputDecoration(
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
            ),
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
                  brand: _brand,
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
