import 'package:flutter/material.dart';

import '../models/vendor.dart';
import '../widgets/vendor_form.dart';
import 'stock_scanning_screen.dart';

class NewVendorEntryScreen extends StatelessWidget {
  const NewVendorEntryScreen({super.key});

  static const String routeName = '/stock-entry/new-vendor';

  static Route<void> route() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => const NewVendorEntryScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: colorScheme.surface.withOpacity(0.94),
        title: Row(
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.storefront_outlined,
                color: colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'New vendor',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: VendorForm(
                  onStartStockEntry: (values) {
                    final vendor = Vendor(
                      id: 'v_${DateTime.now().millisecondsSinceEpoch}',
                      name: values.name,
                      address: values.address,
                    );

                    Navigator.of(context).pushReplacement(
                      StockScanningScreen.route(vendor: vendor),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
