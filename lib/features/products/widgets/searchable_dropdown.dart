import 'package:flutter/material.dart';

class SearchableDropdownOption<T> {
  const SearchableDropdownOption({
    required this.label,
    required this.value,
    this.children = const [],
  });

  final String label;
  final T value;

  /// Optional nested options.
  final List<SearchableDropdownOption<T>> children;
}

class SearchableDropdown<T> extends StatefulWidget {
  const SearchableDropdown({
    super.key,
    required this.placeholder,
    required this.options,
    required this.selectedLabel,
    required this.onSelected,
    required this.width,
    required this.height,
    this.onClear,
    this.clearLabel = 'All',
    this.filterHintText = 'Type to filter',
  });

  final String placeholder;
  final List<SearchableDropdownOption<T>> options;

  /// Label to show in the main box when selected.
  /// Pass null to show [placeholder].
  final String? selectedLabel;

  final ValueChanged<SearchableDropdownOption<T>> onSelected;

  /// Optional clear action (e.g., "All sizes").
  final VoidCallback? onClear;
  final String clearLabel;

  final double width;
  final double height;

  /// Hint shown in the dropdown filter text field.
  final String filterHintText;

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final MenuController _menuController = MenuController();
  final TextEditingController _filterController = TextEditingController();
  final FocusNode _filterFocus = FocusNode();

  @override
  void dispose() {
    _filterController.dispose();
    _filterFocus.dispose();
    super.dispose();
  }

  void _openMenu() {
    if (_menuController.isOpen) {
      _menuController.close();
      return; // Close the menu if it's already open
    }

    setState(() {
      _filterController.text = '';
    });

    _menuController.open();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _filterFocus.requestFocus();
      _filterController.selection = TextSelection.collapsed(
        offset: _filterController.text.length,
      );
    });
  }

  void _closeMenu() {
    if (_menuController.isOpen) _menuController.close();
  }

  List<SearchableDropdownOption<T>> _filterOptions(
    List<SearchableDropdownOption<T>> options,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return options;

    bool matches(SearchableDropdownOption<T> o) {
      if (o.label.toLowerCase().contains(q)) return true;
      return o.children.any(matches);
    }

    List<SearchableDropdownOption<T>> filterNode(
      SearchableDropdownOption<T> o,
    ) {
      if (o.children.isEmpty) return <SearchableDropdownOption<T>>[];
      final filteredChildren = <SearchableDropdownOption<T>>[];
      for (final c in o.children) {
        if (!matches(c)) continue;
        filteredChildren.add(
          SearchableDropdownOption<T>(
            label: c.label,
            value: c.value,
            children: filterNode(c),
          ),
        );
      }
      return filteredChildren;
    }

    final out = <SearchableDropdownOption<T>>[];
    for (final o in options) {
      if (!matches(o)) continue;
      out.add(
        SearchableDropdownOption<T>(
          label: o.label,
          value: o.value,
          children: filterNode(o),
        ),
      );
    }
    return out;
  }

  Widget _buildOptionNode(SearchableDropdownOption<T> option) {
    if (option.children.isEmpty) {
      return MenuItemButton(
        onPressed: () {
          widget.onSelected(option);
          _closeMenu();
        },
        child: Text(option.label, overflow: TextOverflow.ellipsis),
      );
    }

    return SubmenuButton(
      menuChildren: option.children
          .map(_buildOptionNode)
          .toList(growable: false),
      child: Text(option.label, overflow: TextOverflow.ellipsis),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filtered = _filterOptions(widget.options, _filterController.text);

    final menuChildren = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: AnimatedBuilder(
          animation: _filterFocus,
          builder: (context, _) {
            final borderColor = _filterFocus.hasFocus
                ? colorScheme.primary
                : colorScheme.outlineVariant;

            return CustomPaint(
              foregroundPainter: _DashedRRectPainter(
                color: borderColor,
                strokeWidth: 1,
                dashLength: 5,
                gapLength: 3,
                radius: 4,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                child: TextField(
                  controller: _filterController,
                  focusNode: _filterFocus,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.filterHintText,
                    border: InputBorder.none,
                  ),
                ),
              ),
            );
          },
        ),
      ),
      if (widget.onClear != null)
        MenuItemButton(
          onPressed: () {
            widget.onClear?.call();
            _closeMenu();
          },
          child: Text(widget.clearLabel),
        ),
      ...filtered.map(_buildOptionNode),
      if (filtered.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Text(
            'No results',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ];

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: MenuAnchor(
        controller: _menuController,
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            colorScheme.surfaceContainerHigh,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          minimumSize: WidgetStatePropertyAll(Size(widget.width, 0)),
          maximumSize: WidgetStatePropertyAll(Size(widget.width, 360)),
        ),
        menuChildren: menuChildren,
        builder: (context, controller, child) {
          final text = widget.selectedLabel;

          return Semantics(
            button: true,
            label: widget.placeholder,
            child: InkWell(
              onTap: _openMenu,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHigh,
                  prefixIcon: const Icon(Icons.straighten_outlined),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 42,
                    minHeight: 42,
                  ),
                  hintText: widget.placeholder,
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
                    vertical: 12,
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Show options',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onPressed: _openMenu,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ),
                child: Text(
                  (text == null || text.trim().isEmpty)
                      ? widget.placeholder
                      : text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: (text == null || text.trim().isEmpty)
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gapLength != gapLength ||
        oldDelegate.radius != radius;
  }
}
