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
    this.prefixIcon,
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

  /// Optional leading icon in the field.
  final IconData? prefixIcon;

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
    final theme = Theme.of(context);

    if (option.children.isEmpty) {
      return SizedBox(
        width: widget.width,
        child: MenuItemButton(
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStatePropertyAll(
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ),
          onPressed: () {
            widget.onSelected(option);
            _closeMenu();
          },
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              option.label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      child: SubmenuButton(
        menuChildren: option.children
            .map(_buildOptionNode)
            .toList(growable: false),
        child: Text(option.label, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filtered = _filterOptions(widget.options, _filterController.text);

    final menuChildren = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        child: TextField(
          controller: _filterController,
          focusNode: _filterFocus,
          style: theme.textTheme.bodySmall,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            isDense: true,
            isCollapsed: true,
            hintText: widget.filterHintText,
            hintStyle: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.45,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
            ),
          ),
        ),
      ),
      if (widget.onClear != null)
        MenuItemButton(
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStatePropertyAll(
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ),
          onPressed: () {
            widget.onClear?.call();
            _closeMenu();
          },
          child: Text(
            widget.clearLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
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
          backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          minimumSize: WidgetStatePropertyAll(Size(widget.width, 0)),
          maximumSize: WidgetStatePropertyAll(Size(widget.width, 360)),
        ),
        menuChildren: menuChildren
            .map((child) => SizedBox(width: widget.width, child: child))
            .toList(growable: false),
        builder: (context, controller, child) {
          final text = widget.selectedLabel;
          final hasSelection = text != null && text.trim().isNotEmpty;
          final displayText =
              hasSelection ? text.trim() : widget.placeholder;

          return Semantics(
            button: true,
            label: widget.placeholder,
            child: Material(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _openMenu,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: widget.width,
                  height: widget.height,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.prefixIcon ??
                            Icons.arrow_drop_down_circle_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          displayText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: hasSelection
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
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
