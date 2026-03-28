import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vendor.dart';
import '../providers/stock_entry_provider.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('New Vendor Entry')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: VendorForm(
            onStartStockEntry: (values) {
              final id = 'v_${DateTime.now().millisecondsSinceEpoch}';
              final vendor = Vendor(
                id: id,
                name: values.name,
                address: values.address,
                gender: values.gender,
              );

              context.read<StockEntryProvider>().addVendor(vendor);
              Navigator.of(
                context,
              ).push(StockScanningScreen.route(vendor: vendor));
            },
          ),
        ),
      ),
    );
  }
}
