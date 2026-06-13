import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../models/vendor.dart';
import '../services/stock_entry_service.dart';
import '../widgets/stock_entry_ui.dart';
import '../widgets/vendor_form.dart';
import 'stock_scanning_screen.dart';

class NewVendorEntryScreen extends StatefulWidget {
  const NewVendorEntryScreen({super.key});

  static const String routeName = '/stock-entry/new-vendor';

  static Route<void> route() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => const NewVendorEntryScreen(),
    );
  }

  @override
  State<NewVendorEntryScreen> createState() => _NewVendorEntryScreenState();
}

class _NewVendorEntryScreenState extends State<NewVendorEntryScreen> {
  final StockEntryService _stockEntryService = StockEntryService();
  bool _isSubmitting = false;

  Future<void> _handleStartStockEntry(
    BuildContext context,
    VendorFormValues values,
  ) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await _stockEntryService.validateVendor(
        name: values.name,
        phone: values.phone,
        email: values.email,
        gst: values.gst,
      );

      final vendor = Vendor(
        id: 'v_${DateTime.now().millisecondsSinceEpoch}',
        name: values.name,
        phone: values.phone,
        email: values.email,
        address: values.address,
        gst: values.gst,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        StockScanningScreen.route(vendor: vendor),
      );
    } catch (error) {
      if (!mounted) return;
      var message = error.toString();
      message = message
          .replaceFirst('Exception: ', '')
          .replaceFirst('ClientException: ', '')
          .replaceFirst(RegExp(r'^Client\s*', caseSensitive: false), '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('New vendor'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Text(
            'Register vendor details, then add stock items',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          const StockEntrySteps(currentStep: 1),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: isDark ? colorScheme.surface : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColors.slate200,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: VendorForm(
              isSubmitting: _isSubmitting,
              onStartStockEntry: (values) {
                _handleStartStockEntry(context, values);
              },
            ),
          ),
        ],
      ),
    );
  }
}
