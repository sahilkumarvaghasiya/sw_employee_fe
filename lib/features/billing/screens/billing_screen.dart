import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../core/scanner/web_scan_pump.dart';
import '../../../core/utils/barcode_scan_validator.dart';
import '../../../core/utils/web_camera_tuner.dart';
import '../../../core/widgets/scan_camera_controls.dart';
import '../services/billing_service.dart';
import '../models/billing_models.dart';
import '../providers/billing_provider.dart';
import '../widgets/billing_bottom_sheets.dart';
import '../widgets/product_item_widget.dart';
import 'bill_preview_screen.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  static Route<void> route(BuildContext context) {
    final provider = context.read<BillingProvider>();
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/billing/scan'),
      builder: (_) {
        return ChangeNotifierProvider.value(
          value: provider,
          child: const BillingScreen(),
        );
      },
    );
  }

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  // Restricted to the shared 1D profile: hang tags often carry a 2D code next
  // to the product barcode, and an unrestricted controller happily returns that
  // one instead.
  final MobileScannerController _scannerController =
      createBarcodeScannerController(autoStart: true);
  final BillingService _billingService = BillingService();

  late final Future<List<BillingQrConfig>> _qrConfigsFuture;

  String? _lastBarcode;
  DateTime? _lastBarcodeAt;
  bool _handlingBarcode = false;
  WebCameraTuning _cameraTuning = const WebCameraTuning.unavailable();
  WebScanPump? _webScanPump;

  @override
  void initState() {
    super.initState();
    _qrConfigsFuture = _billingService.fetchQrPaymentConfigs();
    unawaited(_tuneCamera());

    if (kIsWeb && kUseWebScanPump) {
      // No scan window is set: this preview has no green frame, so the whole
      // frame stays in play rather than silently ignoring barcodes at the edge.
      _webScanPump = WebScanPump(onBarcode: _acceptBarcode)..start();
    }
  }

  /// Shared by the plugin's detector and the web decode pump: drops repeats of
  /// the same code within the debounce window so one tag is not billed twice.
  void _acceptBarcode(String raw) {
    final value = normalizeStockBarcodeValue(raw);
    if (value.isEmpty || isSuspiciousStockBarcodeMisread(value)) return;

    final now = DateTime.now();
    final last = _lastBarcodeAt;
    final tooSoon =
        last != null &&
        now.difference(last) < const Duration(milliseconds: 1200);
    if (_lastBarcode == value && tooSoon) return;

    _lastBarcode = value;
    _lastBarcodeAt = now;

    unawaited(_handleBarcode(value));
  }

  /// Web only: the plugin opens the camera at the browser's 640x480 default,
  /// which cannot carry a small hang-tag barcode. See [tuneWebCameraForScanning].
  Future<void> _tuneCamera() async {
    final tuning = await tuneWebCameraForScanning();
    if (!mounted) return;
    setState(() => _cameraTuning = tuning);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  BillingProduct? _findProductByBarcode(String barcode) {
    // No local catalog, products come from backend lookup
    return null;
  }

  Future<void> _handleBarcode(String barcode) async {
    if (_handlingBarcode) return;
    _handlingBarcode = true;

    try {
      final product = _findProductByBarcode(barcode);
      if (product != null) {
        final provider = context.read<BillingProvider>();
        final item = provider.addOrIncrementProduct(product);
        await _editItem(item, originalUnitPrice: product.unitPrice);
        _showSnack('${product.name} added');
        return;
      }

      await _addUnknownProduct();
    } finally {
      // Small cooldown to avoid rapid repeats from the camera.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      _handlingBarcode = false;
    }
  }

  Future<void> _addUnknownProduct() async {
    final result = await showModalBottomSheet<BillingManualProductResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const BillingManualProductSheet(),
    );

    if (!mounted) return;
    if (result == null) return;

    final item = context.read<BillingProvider>().addManualProduct(
      name: result.name,
      unitPrice: result.price,
    );
    await _editItem(item, originalUnitPrice: result.price);
    _showSnack('${result.name} added');
  }

  Future<void> _editItem(
    BillingLineItem item, {
    double? originalUnitPrice,
  }) async {
    final action = await showModalBottomSheet<BillingItemEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => BillingItemEditSheet(
        item: item,
        originalUnitPrice: originalUnitPrice,
      ),
    );

    if (!mounted) return;
    if (action == null) return;

    final provider = context.read<BillingProvider>();

    if (action.remove) {
      provider.removeItem(item.id);
      _showSnack('Removed ${item.productName}');
      return;
    }

    if (action.unitPrice != null) {
      provider.updateItemPrice(item.id, action.unitPrice!);
    }
    if (action.discountPercent != null) {
      provider.updateItemDiscountPercent(item.id, action.discountPercent!);
    }

    _showSnack('Updated ${item.productName}');
  }

  Future<void> _confirmCashAndGenerateBill({
    bool closePaymentOptionsOnSuccess = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cash payment'),
          content: const Text('Did you receive payment from customer?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    if (closePaymentOptionsOnSuccess && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    final provider = context.read<BillingProvider>();
    provider.setPaymentMethod(BillingPaymentMethod.cash);
    provider.setMarkPaid(true);
    Navigator.of(context).push(BillPreviewScreen.route(context));
  }

  Future<void> _showQrPaymentSheet() async {
    final provider = context.read<BillingProvider>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return ChangeNotifierProvider.value(
          value: provider,
          child: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final colorScheme = theme.colorScheme;

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FutureBuilder<List<BillingQrConfig>>(
                    future: _qrConfigsFuture,
                    builder: (context, snapshot) {
                      final selectedQr = provider.selectedQrConfig;
                      final qrConfigs =
                          snapshot.data ?? const <BillingQrConfig>[];
                      final canContinue = selectedQr != null;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.qr_code_2_rounded,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'QR barcode payment',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          Text(
                            'Select a QR from dashboard and show it to the customer.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (snapshot.hasError)
                            Card(
                              color: colorScheme.surfaceContainerHigh,
                              child: const Padding(
                                padding: EdgeInsets.all(14),
                                child: Text('Could not load QR codes.'),
                              ),
                            )
                          else if (qrConfigs.isEmpty)
                            Card(
                              color: colorScheme.surfaceContainerHigh,
                              child: const Padding(
                                padding: EdgeInsets.all(14),
                                child: Text('No QR barcode available.'),
                              ),
                            )
                          else ...[
                            Text(
                              'Choose barcode',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: qrConfigs.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 1,
                                  ),
                              itemBuilder: (context, index) {
                                final qr = qrConfigs[index];
                                final isSelected = selectedQr?.id == qr.id;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    provider.setPaymentMethod(
                                      BillingPaymentMethod.qr,
                                    );
                                    provider.selectQrConfig(qr);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 140),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? colorScheme.primary.withOpacity(
                                              0.12,
                                            )
                                          : colorScheme.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? colorScheme.primary
                                            : colorScheme.outlineVariant,
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: Image.network(
                                              qr.imageUrl,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  Container(
                                                    color: colorScheme.surface,
                                                    child: Icon(
                                                      Icons.qr_code_2_rounded,
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          qr.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (selectedQr != null) ...[
                              const SizedBox(height: 12),
                              Card(
                                elevation: 0,
                                color: colorScheme.surfaceContainerHigh,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      Text(
                                        selectedQr.name,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                      const SizedBox(height: 10),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.network(
                                          selectedQr.imageUrl,
                                          height: 180,
                                          width: double.infinity,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, _, _) => Container(
                                            height: 180,
                                            color: colorScheme.surface,
                                            child: Icon(
                                              Icons.qr_code_2_rounded,
                                              size: 92,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Show this QR to customer to scan and pay.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: canContinue
                                  ? () {
                                      provider.setPaymentMethod(
                                        BillingPaymentMethod.qr,
                                      );
                                      provider.setMarkPaid(true);
                                      Navigator.of(context).pop();
                                      Navigator.of(this.context).push(
                                        BillPreviewScreen.route(this.context),
                                      );
                                    }
                                  : null,
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Payment received'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showPaymentOptions() async {
    final provider = context.read<BillingProvider>();

    if (provider.items.isEmpty) {
      _showSnack('Scan at least one product to continue.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        Widget option({
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback onTap,
        }) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: ListTile(
              leading: Icon(icon),
              title: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onTap,
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.payments_outlined, color: colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Payment',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Text(
                  'Select a payment option to continue.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                option(
                  icon: Icons.payments_outlined,
                  title: 'Cash',
                  subtitle: 'Confirm cash received',
                  onTap: () async {
                    await _confirmCashAndGenerateBill(
                      closePaymentOptionsOnSuccess: true,
                    );
                  },
                ),
                option(
                  icon: Icons.qr_code_2_rounded,
                  title: 'QR barcode',
                  subtitle: 'Select QR and show to customer',
                  onTap: () async {
                    await _showQrPaymentSheet();
                  },
                ),
                option(
                  icon: Icons.credit_card_outlined,
                  title: 'Card (Credit/Debit)',
                  subtitle: 'Coming soon',
                  onTap: () {
                    showDialog<void>(
                      context: this.context,
                      builder: (context) => AlertDialog(
                        title: const Text('Coming soon'),
                        content: const Text(
                          'Card payments will be available in a future update.',
                        ),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _webScanPump?.dispose();
    releaseWebCameraTuner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final provider = context.watch<BillingProvider>();
    final customer = provider.customer;

    final totals = Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Items ${provider.totalItems} • Subtotal ${_money(provider.subtotal)} • Discount ${_money(provider.totalDiscount)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _money(provider.finalAmount),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surfaceContainerLow.withAlpha(235),
        surfaceTintColor: colorScheme.surfaceTint,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Billing',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              customer == null
                  ? 'Customer not selected'
                  : '${customer.name}  |  ${customer.phone}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: MobileScanner(
                        controller: _scannerController,
                        fit: BoxFit.cover,
                        onDetect: (capture) {
                          final value = capture.barcodes.firstOrNull?.rawValue
                              ?.trim();
                          if (value == null || value.isEmpty) return;

                          _acceptBarcode(value);
                        },
                      ),
                    ),
                    if (_cameraTuning.hasControls)
                      Positioned(
                        left: 12,
                        right: 12,
                        top: 12,
                        child: ScanCameraControls(tuning: _cameraTuning),
                      ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow.withAlpha(235),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code_scanner),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Keep scanning products one by one. The bill updates automatically.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(child: totals),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Scanned items (${provider.items.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),

          if (provider.items.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 220),
              sliver: SliverToBoxAdapter(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No products yet. Point the camera at a barcode to scan.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 220),
              sliver: SliverList.separated(
                itemCount: provider.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = provider.items[index];
                  return ProductItemWidget(
                    key: ValueKey(item.id),
                    item: item,
                    onPriceChanged: (double? value) {
                      provider.updateItemPrice(item.id, value);
                    },
                    onDiscountChanged: (double? value) {
                      provider.updateItemDiscountPercent(item.id, value);
                    },
                    onIncrement: () {
                      provider.incrementItemQuantity(item.id);
                    },
                    onDecrement: () {
                      provider.decrementItemQuantity(item.id);
                    },
                    onRemove: () {
                      provider.removeItem(item.id);
                      _showSnack('Removed ${item.productName}');
                    },
                  );
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Items ${provider.totalItems}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Subtotal ${_money(provider.subtotal)} • Discount ${_money(provider.totalDiscount)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: provider.items.isEmpty
                        ? null
                        : _showPaymentOptions,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Payment'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
