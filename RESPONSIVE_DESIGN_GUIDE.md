# Responsive Design Guide for RetailAgent App

## Overview
This guide ensures the RetailAgent app looks great on all Android phones (320dp to 600dp+ width).

## Screen Breakpoints

```
Small Phones (320-359dp)  → Compact layouts, smaller padding
Medium Phones (360-479dp) → Standard layouts, normal padding  
Large Phones (480-599dp)  → Spacious layouts, standard spacing
Tablets (600dp+)          → Multi-column, maximum content optimization
```

## Quick Access Utilities

Use the `ResponsiveDesign` class and extension methods in any widget:

```dart
import 'core/utils/responsive.dart';

// Using responsive utils
final padding = ResponsiveDesign.getHorizontalPadding(context);
final isSmall = ResponsiveDesign.isSmallScreen(context);

// Using extension methods (shorter syntax)
if (context.isSmallScreen) {
  // Layout for small screens
}

final columns = context.gridColumns;
final width = context.screenWidth;
```

## Common Responsive Patterns

### 1. Adaptive Padding
```dart
Padding(
  padding: EdgeInsets.symmetric(
    horizontal: ResponsiveDesign.getHorizontalPadding(context),
    vertical: ResponsiveDesign.paddingDefault,
  ),
  child: YourContent(),
)
```

### 2. Responsive Grid Layout
```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: context.gridColumns,
    crossAxisSpacing: ResponsiveDesign.paddingMedium,
    mainAxisSpacing: ResponsiveDesign.paddingMedium,
    childAspectRatio: ResponsiveDesign.getGridChildAspectRatio(context),
  ),
  itemBuilder: ...
)
```

### 3. Responsive Column/Row Layout
```dart
LayoutBuilder(
  builder: (context, constraints) {
    final isWide = constraints.maxWidth >= ResponsiveDesign.mediumPhoneMaxWidth;
    
    return isWide 
      ? Row(children: [...])
      : Column(children: [...]);
  },
)
```

### 4. Limited Content Width (for tablets)
```dart
Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: ResponsiveDesign.getMaxContentWidth(context),
    ),
    child: YourContent(),
  ),
)
```

### 5. Responsive Form Fields
```dart
SizedBox(
  width: ResponsiveDesign.getFormFieldWidth(context, columns: 2),
  child: TextFormField(...),
)
```

## Best Practices

### ✅ DO

1. **Use LayoutBuilder** for context-aware responsive layouts
   ```dart
   LayoutBuilder(
     builder: (context, constraints) {
       final width = constraints.maxWidth;
       // Build responsive layout
     },
   )
   ```

2. **Use Responsive Utils** for spacing and sizing
   ```dart
   padding: EdgeInsets.all(ResponsiveDesign.paddingDefault),
   ```

3. **Test on Multiple Sizes** before committing
   - Pixel 4 (412dp)
   - Pixel 5 (432dp)
   - Pixel 6 (412dp)
   - Small phones (360dp)
   - Tablets (600dp+)

4. **Use Expanded/Flexible** for flexible layouts
   ```dart
   Row(
     children: [
       Expanded(child: Widget1()),
       SizedBox(width: 12),
       Expanded(child: Widget2()),
     ],
   )
   ```

5. **Set Min/Max Constraints** properly
   ```dart
   ConstrainedBox(
     constraints: BoxConstraints(
       maxWidth: 300,
       minHeight: 50,
     ),
     child: Widget(),
   )
   ```

### ❌ DON'T

1. **Don't use hardcoded pixel values** for widths/heights
   ```dart
   // ❌ BAD
   SizedBox(width: 300)
   
   // ✅ GOOD
   Expanded(child: ...)
   // or
   SizedBox(width: constraints.maxWidth * 0.5)
   ```

2. **Don't ignore MediaQuery changes** when device orientation changes
   ```dart
   // ✅ GOOD: Responsive to orientation
   final isLandscape = context.isLandscape;
   ```

3. **Don't use fixed font sizes** for all screens
   ```dart
   // ❌ BAD
   Text('Title', style: TextStyle(fontSize: 24))
   
   // ✅ GOOD: Uses theme font sizes
   Text('Title', style: theme.textTheme.titleLarge)
   ```

4. **Don't hardcode menu widths** for dropdowns (FIXED in add_stock_entry_item_screen.dart)
   ```dart
   // ❌ BAD
   width: MediaQuery.of(context).size.width - 64
   
   // ✅ GOOD
   width: constraints.maxWidth - 32
   // or use menuWidth parameter passed from LayoutBuilder
   ```

5. **Don't add excessive padding** on small screens
   ```dart
   // ❌ BAD
   padding: EdgeInsets.all(24) // Too much on 320dp screen
   
   // ✅ GOOD
   padding: EdgeInsets.symmetric(
     horizontal: ResponsiveDesign.getHorizontalPadding(context)
   )
   ```

## Recent Fixes Applied

### Stock Entry Screen (add_stock_entry_item_screen.dart)
- ✅ Changed breakpoint from `width >= 320` to `width >= 360` (better for different phones)
- ✅ Changed dropdown menu width from `width - 64` to `width - 32` (better margins)
- ✅ Added `menuWidth` parameter for responsive dropdown sizing
- ✅ Added Scrollbars to Size, Color, Brand, and Item Type dropdowns

### Benefits
- All dropdowns now respect available space from LayoutBuilder
- Two-column layout only activates on 360dp+ screens (avoids cramped layouts on 320dp)
- Proper margins on all screen sizes

## Testing Checklist

Before submitting any responsive UI code:

- [ ] Tested on 320dp width (small phones)
- [ ] Tested on 360dp width (Pixel 4a)
- [ ] Tested on 412dp width (Pixel 5)
- [ ] Tested on 600dp width (tablets)
- [ ] Text is readable on all sizes
- [ ] No overlapping widgets
- [ ] Buttons are clickable (48dp minimum touch target)
- [ ] Images scale properly
- [ ] Form fields are accessible
- [ ] Orientation changes work smoothly

## Extension Methods Reference

```dart
// All available on BuildContext
context.screenWidth              // Get screen width
context.screenHeight             // Get screen height
context.isSmallScreen            // Is width < 360dp
context.isMediumScreen           // Is 360dp-599dp
context.isLargeScreen            // Is 600dp+
context.isLandscape              // Is landscape orientation
context.horizontalPadding        // Get responsive padding
context.gridColumns              // Get grid column count
context.devicePixelRatio         // Get device pixel ratio
context.safeAreaPadding          // Get safe area padding (notches, etc)
```

## Resources

- **Flutter Responsive Design Docs**: https://flutter.dev/docs/development/ui/layout/responsive
- **Material Design Responsive**: https://material.io/design/platform-guidance/android-bars.html
- **Android Device Sizes**: https://material.io/design/platform-guidance/android-bars.html#usage

## Questions?

If you encounter responsive design issues, check:
1. Are you using LayoutBuilder for context-aware sizing?
2. Are hardcoded sizes being used?
3. Does the layout change properly on different screen widths?
4. Are all widgets respecting safe areas and notches?

For new screens, use the patterns from:
- `lib/features/home/screens/home_screen.dart` (good patterns)
- `lib/features/products/widgets/product_card.dart` (responsive cards)
- `lib/features/stock_entry/screens/add_stock_entry_item_screen.dart` (responsive dropdowns)
