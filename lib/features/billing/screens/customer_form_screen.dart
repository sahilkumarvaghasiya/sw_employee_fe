import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/barcode_scan_validator.dart';
import '../../../core/widgets/barcode_scanner_view.dart';

import '../models/billing_models.dart';
import '../providers/billing_provider.dart';
import '../services/billing_service.dart';
import '../widgets/product_item_widget.dart';
import '../widgets/billing_ui.dart';
import '../../../core/theme/app_theme.dart';
import 'bill_preview_screen.dart';
import '../../products/models/product.dart';
import '../../products/services/products_service.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/billing/customer'),
      builder: (_) {
        return ChangeNotifierProvider(
          create: (_) => BillingProvider(),
          child: const CustomerFormScreen(),
        );
      },
    );
  }

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  static const bool _useDummyEntryOnStartBilling = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _addressFocusNode = FocusNode();

  bool _showHowBillingWorks = true;
  bool _scanMode = false;

  bool _scannerActive = false;
  bool _startingScanner = false;

  final MobileScannerController _scannerController =
      createBarcodeScannerController(autoStart: false);

  Timer? _phoneLookupDebounce;
  Timer? _productSearchDebounce;
  int _phoneLookupRequestId = 0;
  int _productSearchRequestId = 0;
  TextEditingController? _productSearchController;
  List<Product> _productSearchResults = <Product>[];
  final Set<String> _productSearchLoadingIds = <String>{};
  bool _isProductSearching = false;
  String? _productSearchError;
  String? _lastAutoFilledPhone;
  String? _lastAutoFilledName;
  String? _lastAutoFilledAddress;

  bool _handlingBarcode = false;
  bool _paymentFlowActive = false;
  bool _paymentCheckoutStarted = false;

  bool get _canAcceptBarcodeScans =>
      _scanMode &&
      _scannerActive &&
      !_paymentFlowActive &&
      !_paymentCheckoutStarted;

  final Map<String, GlobalKey> _lineItemKeys = <String, GlobalKey>{};

  final BillingService _billingService = BillingService();
  final ProductsService _productsService = ProductsService();

  bool _hasBillingDraft(BillingProvider provider) {
    return provider.items.isNotEmpty;
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    final provider = context.read<BillingProvider>();
    if (!_hasBillingDraft(provider)) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Discard billing draft?'),
          content: const Text(
            'You have unsaved billing details. Do you want to discard them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Yes, discard'),
            ),
          ],
        );
      },
    );

    return shouldDiscard ?? false;
  }

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneLookupDebounce?.cancel();
    _productSearchDebounce?.cancel();
    _phoneController.removeListener(_onPhoneChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _productSearchController?.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _addressFocusNode.dispose();
    unawaited(_scannerController.stop());
    _scannerController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _revealLineItem(String id) async {
    final key = _lineItemKeys[id];
    final itemContext = key?.currentContext;
    if (itemContext == null) return;

    await Scrollable.ensureVisible(
      itemContext,
      alignment: 0.12,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  String _barcodeErrorMessage(Object error) {
    final message = error.toString();
    const prefix = 'ClientException: ';
    if (message.startsWith(prefix)) {
      return message.substring(prefix.length);
    }
    return message;
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  String? _normalizeIndianPhone(String value) {
    var digits = _digitsOnly(value);
    if (digits.isEmpty) return null;

    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (digits.length != 10) return null;
    return digits;
  }

  void _clearAutoFilledCustomerDetails({required bool force}) {
    final shouldClearName =
        force ||
        (_lastAutoFilledName != null &&
            _nameController.text.trim() == _lastAutoFilledName);
    final shouldClearAddress =
        force ||
        (_lastAutoFilledAddress != null &&
            _addressController.text.trim() == _lastAutoFilledAddress);

    if (shouldClearName && _nameController.text.isNotEmpty) {
      _nameController.clear();
    }
    if (shouldClearAddress && _addressController.text.isNotEmpty) {
      _addressController.clear();
    }

    _lastAutoFilledPhone = null;
    _lastAutoFilledName = null;
    _lastAutoFilledAddress = null;
  }

  void _onPhoneChanged() {
    final rawDigits = _digitsOnly(_phoneController.text);
    final normalizedPhone = _normalizeIndianPhone(_phoneController.text);
    final identity = normalizedPhone ?? rawDigits;

    if (rawDigits.isEmpty) {
      _phoneLookupDebounce?.cancel();
      _clearAutoFilledCustomerDetails(force: false);
      return;
    }

    if (_lastAutoFilledPhone != null && _lastAutoFilledPhone != identity) {
      _clearAutoFilledCustomerDetails(force: false);
    }

    if (normalizedPhone == null) {
      _phoneLookupDebounce?.cancel();
      _clearAutoFilledCustomerDetails(force: false);
      return;
    }

    _phoneLookupDebounce?.cancel();
    _phoneLookupDebounce = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(_lookupCustomerByPhone(normalizedPhone)),
    );
  }

  Future<void> _lookupCustomerByPhone(String phone) async {
    final normalized = _normalizeIndianPhone(phone);
    if (normalized == null) return;

    final requestId = ++_phoneLookupRequestId;

    try {
      final customer = await _billingService.fetchCustomerByPhone(normalized);
      if (!mounted || requestId != _phoneLookupRequestId || customer == null) {
        if (mounted &&
            _normalizeIndianPhone(_phoneController.text) == normalized) {
          _clearAutoFilledCustomerDetails(force: false);
        }
        return;
      }

      final currentPhone = _normalizeIndianPhone(_phoneController.text);
      if (currentPhone != normalized) return;

      final fetchedName = customer.name.trim();
      if (fetchedName.isNotEmpty) {
        final shouldAutofillName =
            _nameController.text.trim().isEmpty ||
            _nameController.text.trim() == _lastAutoFilledName ||
            _lastAutoFilledPhone != normalized;
        if (shouldAutofillName) {
          _nameController.text = fetchedName;
          _nameController.selection = TextSelection.collapsed(
            offset: fetchedName.length,
          );
          _lastAutoFilledName = fetchedName;
          _lastAutoFilledPhone = normalized;
        }
      }

      final fetchedAddress = customer.address?.trim() ?? '';
      if (fetchedAddress.isNotEmpty && _addressController.text.trim().isEmpty) {
        _addressController.text = fetchedAddress;
        _addressController.selection = TextSelection.collapsed(
          offset: fetchedAddress.length,
        );
        _lastAutoFilledPhone = normalized;
        _lastAutoFilledAddress = fetchedAddress;
      }
    } catch (_) {
      // Ignore lookup failures while the user is typing.
    }
  }

  Future<void> _handleBarcode(String barcode) async {
    if (!_canAcceptBarcodeScans) return;
    if (_handlingBarcode) return;
    _handlingBarcode = true;

    final provider = context.read<BillingProvider>();
    final normalizedBarcode = barcode.trim();

    try {
      if (normalizedBarcode.isEmpty) return;

      final lookup = await _billingService.fetchBarcodeLookup(
        normalizedBarcode,
        scannedBarcodes: provider.buildScannedBarcodesForLookup(),
      );
      final products = lookup.products
          .where(
            (product) =>
                product.availableQuantity == null ||
                product.availableQuantity! > 0,
          )
          .toList(growable: false);
      if (!mounted) return;

      if (products.isEmpty) {
        _showSnack('No product found for barcode $barcode');
        return;
      }

      if (!lookup.isMultiple) {
        final selected = products.first;
        provider.addOrIncrementProduct(selected);
        provider.rememberSingleBarcodeProduct(
          barcode: normalizedBarcode,
          productId: selected.id,
        );
        provider.registerScannedBarcode(normalizedBarcode);
        _showSnack('${selected.name} added');
        return;
      }

      final shouldRestartScanner = _scanMode;
      if (shouldRestartScanner) {
        await _stopScanner();
      }

      final selected = await _pickProductFromMatches(
        barcode: normalizedBarcode,
        products: products,
      );
      if (!mounted) return;

      if (selected == null) {
        if (shouldRestartScanner && mounted) {
          await _startScanner();
        }
        return;
      }

      provider.syncMultiBarcodeSelection(
        barcode: normalizedBarcode,
        selectedProducts: selected,
      );
      provider.registerScannedBarcode(normalizedBarcode);
      _showSnack('${selected.length} product(s) added');

      if (shouldRestartScanner && mounted) {
        await _startScanner();
      }
    } catch (e) {
      if (!mounted) return;
      final message = _barcodeErrorMessage(e).trim();
      _showSnack(
        message.isEmpty ? 'Barcode lookup failed. Please try again.' : message,
      );
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      _handlingBarcode = false;
    }
  }

  Future<List<BillingProduct>?> _pickProductFromMatches({
    required String barcode,
    required List<BillingProduct> products,
  }) {
    final provider = context.read<BillingProvider>();
    final initialSelectedProductIds = provider.selectedProductIdsForBarcode(
      barcode,
    );

    return showModalBottomSheet<List<BillingProduct>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final searchController = TextEditingController();
        final selectedProductIds = Set<String>.from(initialSelectedProductIds);
        List<BillingProduct>? backendSearchProducts;
        bool isSearching = false;
        int searchRequestId = 0;

        Future<void> runBackendSearch(String query) async {
          final q = query.trim();
          if (q.isEmpty) {
            setState(() {
              backendSearchProducts = null;
              isSearching = false;
            });
            return;
          }

          final int requestId = ++searchRequestId;
          setState(() => isSearching = true);

          final results = await _billingService.searchProductsForBarcode(
            barcode: barcode,
            query: q,
          );

          if (!context.mounted || requestId != searchRequestId) return;

          setState(() {
            backendSearchProducts = results;
            isSearching = false;
          });
        }

        String subtitleFor(BillingProduct product) {
          final size = product.size?.trim() ?? '';
          final company = product.companyName?.trim() ?? '';
          final quantity = product.availableQuantity;
          final parts = <String>[];
          if (company.isNotEmpty) parts.add(company);
          if (size.isNotEmpty) parts.add('Size $size');
          parts.add('Price ${_money(product.unitPrice)}');
          if (quantity != null) parts.add('Qty $quantity');
          return parts.join(' • ');
        }

        return StatefulBuilder(
          builder: (context, setState) {
            final query = searchController.text.trim().toLowerCase();
            final sourceProducts = backendSearchProducts ?? products;
            final filteredProducts = sourceProducts
                .where((product) {
                  if (query.isEmpty) return true;
                  return product.name.toLowerCase().contains(query) ||
                      (product.companyName?.toLowerCase().contains(query) ??
                          false);
                })
                .toList(growable: false);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  16 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Select product',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
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
                    const SizedBox(height: 4),
                    Text(
                      'Barcode: $barcode',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      onChanged: (value) {
                        setState(() {});
                        unawaited(runBackendSearch(value));
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Filter by item type or brand name',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (isSearching) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Searching products...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredProducts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final p = filteredProducts[index];
                          final isSelected = selectedProductIds.contains(p.id);
                          return Card(
                            elevation: 0,
                            color: isSelected
                                ? colorScheme.primary.withOpacity(0.10)
                                : colorScheme.surfaceContainerHigh,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant,
                              ),
                            ),
                            child: ListTile(
                              title: Text(
                                p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(subtitleFor(p)),
                              leading: Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.inventory_2_outlined,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.done_rounded,
                                      color: colorScheme.primary,
                                    )
                                  : const Icon(Icons.add_rounded),
                              onTap: () {
                                setState(() {
                                  if (selectedProductIds.contains(p.id)) {
                                    selectedProductIds.remove(p.id);
                                  } else {
                                    selectedProductIds.add(p.id);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: selectedProductIds.isEmpty
                            ? null
                            : () {
                                final selectedProducts = products
                                    .where(
                                      (product) => selectedProductIds.contains(
                                        product.id,
                                      ),
                                    )
                                    .toList(growable: false);
                                Navigator.of(context).pop(selectedProducts);
                              },
                        icon: const Icon(Icons.done_rounded),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            selectedProductIds.isEmpty
                                ? 'Done'
                                : 'Add ${selectedProductIds.length} selected',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmPaymentDone({required String methodLabel}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: Text(
            'Confirm payment',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Mark $methodLabel payment as received?',
            style: theme.textTheme.bodyMedium,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not yet'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes, done'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<bool> _reviewBillAndApplyFinalAmount() async {
    final provider = context.read<BillingProvider>();
    if (provider.items.isEmpty) {
      _showSnack('Scan at least one product to continue.');
      return false;
    }

    final adjustmentController = TextEditingController();
    int offerMode = 0; // 0: none, 1: price, 2: discount
    String? offerValueError;
    bool hasInteractedWithOfferField = false;
    final baseAmount = provider.calculatedFinalAmount;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final rawValue = adjustmentController.text.trim();
            final parsedValue = double.tryParse(rawValue);
            final entered = parsedValue ?? 0.0;

            bool validateOfferValue({
              bool isConfirming = false,
              String? currentValue,
              bool showRequiredOnEmpty = true,
            }) {
              final effectiveRawValue =
                  (currentValue ?? adjustmentController.text).trim();
              final effectiveParsedValue = double.tryParse(effectiveRawValue);

              if (offerMode == 0) {
                offerValueError = null;
                return true;
              }

              if (effectiveRawValue.isEmpty) {
                if (showRequiredOnEmpty &&
                    (isConfirming || hasInteractedWithOfferField)) {
                  offerValueError = 'Required field';
                } else {
                  offerValueError = null;
                }
                return false;
              }

              if (effectiveParsedValue == null || effectiveParsedValue <= 0) {
                offerValueError = 'Enter a valid value';
                return false;
              }

              if (offerMode == 1 && effectiveParsedValue > baseAmount) {
                offerValueError = 'Must be up to total bill';
                return false;
              }

              if (offerMode == 2 && effectiveParsedValue > 100) {
                offerValueError = 'Discount must be up to 100%';
                return false;
              }

              offerValueError = null;
              return true;
            }

            void handleConfirm() {
              final isOfferValueEmpty =
                  offerMode != 0 && adjustmentController.text.trim().isEmpty;

              if (isOfferValueEmpty) {
                setModalState(() {
                  offerMode = 0;
                  offerValueError = null;
                  hasInteractedWithOfferField = false;
                });
              }

              bool isValid = true;
              setModalState(() {
                isValid = validateOfferValue(isConfirming: true);
              });
              if (!isValid) return;

              if (offerMode != 0 &&
                  adjustmentController.text.trim().isNotEmpty) {
                final parsed = double.tryParse(
                  adjustmentController.text.trim(),
                );
                if (parsed == null || parsed <= 0) {
                  _showSnack('Enter a valid offer value or choose None.');
                  return;
                }
              }

              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.of(sheetContext).pop(true);
            }

            double payable = baseAmount;
            if (offerMode == 1 && entered > 0) {
              payable = entered.clamp(0, baseAmount);
            } else if (offerMode == 2 && entered > 0) {
              final pct = entered.clamp(0, 100);
              payable = (baseAmount * (1 - pct / 100)).clamp(
                0,
                double.infinity,
              );
            }

            final breakdownDiscount = provider.billSavingsForPayable(payable);
            final breakdownDiscountPercent =
                provider.billSavingsPercentForPayable(payable);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  16 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Confirm bill',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      BillingPayableHero(
                        amount: _money(payable),
                        subtitle:
                            '${provider.items.length} item${provider.items.length == 1 ? '' : 's'}',
                      ),
                      const SizedBox(height: 12),
                      Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 8),
                          shape: const RoundedRectangleBorder(
                            side: BorderSide(color: Colors.transparent),
                          ),
                          collapsedShape: const RoundedRectangleBorder(
                            side: BorderSide(color: Colors.transparent),
                          ),
                          title: Text(
                            'View items',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            provider.items.length <= 3
                                ? provider.items
                                    .map((i) => i.productName)
                                    .join(', ')
                                : '${provider.items.take(2).map((i) => i.productName).join(', ')}…',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          children: provider.items
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.productName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                      Text(
                                        '×${item.quantity}',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      if (breakdownDiscount > 0.0001 ||
                          provider.originalSubtotal != payable) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          child: Column(
                            children: [
                              BillingSummaryLine(
                                label: 'Original',
                                value: _money(provider.originalSubtotal),
                              ),
                              if (breakdownDiscount > 0.0001)
                                BillingSummaryLine(
                                  label: 'Discount',
                                  value: BillingProvider.formatDiscountSummary(
                                    breakdownDiscount,
                                    breakdownDiscountPercent,
                                  ),
                                  valueColor: colorScheme.tertiary,
                                ),
                              BillingSummaryLine(
                                label: 'Subtotal',
                                value: _money(payable),
                                bold: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Adjust total (optional)',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment<int>(
                            value: 0,
                            label: Text('None'),
                          ),
                          ButtonSegment<int>(
                            value: 1,
                            label: Text('Price'),
                          ),
                          ButtonSegment<int>(
                            value: 2,
                            label: Text('% Off'),
                          ),
                        ],
                        multiSelectionEnabled: false,
                        emptySelectionAllowed: false,
                        selected: {offerMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) {
                          setModalState(() {
                            offerMode = selection.first;
                            hasInteractedWithOfferField = false;
                            adjustmentController.clear();
                            offerValueError = null;
                          });
                        },
                      ),
                      if (offerMode != 0) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: adjustmentController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (value) {
                            hasInteractedWithOfferField = true;
                            setModalState(() {
                              validateOfferValue(
                                currentValue: value,
                                showRequiredOnEmpty: false,
                              );
                            });
                          },
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: offerMode == 1
                                ? 'Final amount'
                                : 'Discount %',
                            hintText: offerMode == 1 ? 'Enter amount' : '1–100',
                            prefixText: offerMode == 1 ? '₹ ' : null,
                            suffixText: offerMode == 2 ? ' %' : null,
                            errorText: offerValueError,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                Navigator.of(sheetContext).pop(false);
                              },
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: handleConfirm,
                              child: const Text('Continue'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    final entered = double.tryParse(adjustmentController.text.trim()) ?? 0.0;
    // Delay disposal until after the bottom sheet teardown/IME transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      adjustmentController.dispose();
    });

    if (confirmed != true) {
      return false;
    }

    if (offerMode == 0) {
      provider.setManualFinalAmount(null);
      return true;
    }

    if (offerMode == 1) {
      provider.setManualFinalAmount(entered.clamp(0, baseAmount));
      return true;
    }

    final pct = entered.clamp(0, 100);
    provider.setManualFinalAmount(
      (baseAmount * (1 - pct / 100)).clamp(0, double.infinity),
    );
    return true;
  }

  Future<void> _navigateToBillPreview() async {
    _paymentCheckoutStarted = true;
    await _stopScanner();
    if (!mounted) return;

    await Navigator.of(context).push(BillPreviewScreen.route(context));

    _paymentCheckoutStarted = false;
    if (!mounted) return;
    await _resumeScannerIfScanning();
  }

  Future<void> _confirmCashAndGenerateBill({
    bool closePaymentOptionsOnSuccess = false,
  }) async {
    final confirmed = await _confirmPaymentDone(methodLabel: 'Cash');
    if (!mounted || !confirmed) return;

    if (closePaymentOptionsOnSuccess && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    final provider = context.read<BillingProvider>();
    provider.setPaymentMethod(BillingPaymentMethod.cash);
    provider.setMarkPaid(true);
    await _navigateToBillPreview();
  }

  Future<void> _confirmCardAndGenerateBill({
    bool closePaymentOptionsOnSuccess = false,
  }) async {
    final confirmed = await _confirmPaymentDone(methodLabel: 'Card');
    if (!mounted || !confirmed) return;

    if (closePaymentOptionsOnSuccess && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    final provider = context.read<BillingProvider>();
    provider.setPaymentMethod(BillingPaymentMethod.card);
    provider.setMarkPaid(true);
    await _navigateToBillPreview();
  }

  Future<void> _showQrPaymentSheet() async {
    final provider = context.read<BillingProvider>();
    late final Future<List<BillingQrConfig>> qrConfigsFuture;
    qrConfigsFuture = _billingService.fetchQrPaymentConfigs();

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
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Consumer<BillingProvider>(
                    builder: (context, p, _) {
                      final selectedQr = p.selectedQrConfig;
                      final canContinue = selectedQr != null;

                      return FutureBuilder<List<BillingQrConfig>>(
                        future: qrConfigsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 28),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (snapshot.hasError) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Could not load QR codes',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please try again.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    unawaited(_showQrPaymentSheet());
                                  },
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry'),
                                ),
                              ],
                            );
                          }

                          final qrConfigs =
                              snapshot.data ?? const <BillingQrConfig>[];
                          return SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Scan to pay',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                BillingPayableHero(
                                  amount: _money(p.finalAmount),
                                ),
                                const SizedBox(height: 16),
                                if (qrConfigs.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMd,
                                      ),
                                    ),
                                    child: Text(
                                      'No QR codes available.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  )
                                else ...[
                                  Text(
                                    'Pick a QR',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurfaceVariant,
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
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 8,
                                      childAspectRatio: 0.95,
                                    ),
                                    itemBuilder: (context, index) {
                                      final qr = qrConfigs[index];
                                      final isSelected =
                                          selectedQr?.id == qr.id;
                                      return Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            AppTheme.radiusMd,
                                          ),
                                          onTap: () {
                                            p.setPaymentMethod(
                                              BillingPaymentMethod.qr,
                                            );
                                            p.selectQrConfig(qr);
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 150,
                                            ),
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? colorScheme.primary
                                                      .withValues(alpha: 0.1)
                                                  : colorScheme
                                                      .surfaceContainerHighest
                                                      .withValues(alpha: 0.5),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                AppTheme.radiusMd,
                                              ),
                                              border: Border.all(
                                                color: isSelected
                                                    ? colorScheme.primary
                                                    : colorScheme.outlineVariant
                                                        .withValues(alpha: 0.5),
                                                width: isSelected ? 1.5 : 1,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      8,
                                                    ),
                                                    child: Image.network(
                                                      qr.imageUrl,
                                                      width: double.infinity,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (_, _, _) => Icon(
                                                        Icons.qr_code_2_rounded,
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  qr.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: theme
                                                      .textTheme.labelSmall
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (selectedQr != null) ...[
                                    const SizedBox(height: 14),
                                    Text(
                                      selectedQr.name,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMd,
                                      ),
                                      child: Image.network(
                                        selectedQr.imageUrl,
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => Container(
                                          height: 160,
                                          color: colorScheme.surface,
                                          child: Icon(
                                            Icons.qr_code_2_rounded,
                                            size: 72,
                                            color:
                                                colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: canContinue
                                        ? () async {
                                            final done =
                                                await _confirmPaymentDone(
                                              methodLabel: 'QR Barcode',
                                            );
                                            if (!done || !context.mounted) {
                                              return;
                                            }
                                            provider.setPaymentMethod(
                                              BillingPaymentMethod.qr,
                                            );
                                            provider.setMarkPaid(true);
                                            Navigator.of(context).pop();
                                            await _navigateToBillPreview();
                                          }
                                        : null,
                                    child: const Text('Payment received'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
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

    final canContinue = await _reviewBillAndApplyFinalAmount();
    if (!canContinue) {
      await _resumeScannerIfScanning();
      return;
    }
    if (!mounted) return;

    // Let the review sheet fully dismiss before opening the next overlay.
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        bool actionInProgress = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> runAction(Future<void> Function() action) async {
              if (actionInProgress) return;
              setModalState(() => actionInProgress = true);
              try {
                await action();
              } finally {
                if (context.mounted) {
                  setModalState(() => actionInProgress = false);
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'How did they pay?',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    BillingPayableHero(
                      amount: _money(provider.finalAmount),
                    ),
                    const SizedBox(height: 16),
                    BillingPaymentMethodTile(
                      icon: Icons.payments_outlined,
                      title: 'Cash',
                      loading: actionInProgress,
                      enabled: !actionInProgress,
                      onTap: () => runAction(() async {
                        await _confirmCashAndGenerateBill(
                          closePaymentOptionsOnSuccess: true,
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    BillingPaymentMethodTile(
                      icon: Icons.qr_code_2_rounded,
                      title: 'QR code',
                      loading: actionInProgress,
                      enabled: !actionInProgress,
                      onTap: () => runAction(() async {
                        await _showQrPaymentSheet();
                      }),
                    ),
                    const SizedBox(height: 8),
                    BillingPaymentMethodTile(
                      icon: Icons.credit_card_outlined,
                      title: 'Card',
                      loading: actionInProgress,
                      enabled: !actionInProgress,
                      onTap: () => runAction(() async {
                        await _confirmCardAndGenerateBill(
                          closePaymentOptionsOnSuccess: true,
                        );
                      }),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (!_paymentCheckoutStarted) {
      await _resumeScannerIfScanning();
    }
  }

  Future<void> _onPaymentTap() async {
    if (_paymentFlowActive) return;

    final provider = context.read<BillingProvider>();
    if (provider.items.isEmpty) {
      _showSnack('Add at least one product before payment.');
      return;
    }

    await _stopScanner();
    _paymentFlowActive = true;

    try {
      await _showPaymentOptions();
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not open payment. Please try again.');
      await _resumeScannerIfScanning();
    } finally {
      _paymentFlowActive = false;
    }
  }

  String? _validateRequired(String? value, {required String label}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label is required';
    return null;
  }

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Phone number is required';

    final normalized = _normalizeIndianPhone(v);
    if (normalized == null) {
      return 'Enter a valid 10-digit Indian phone number';
    }

    return null;
  }

  Future<void> _start() async {
    final form = _formKey.currentState;
    if (form == null) return;

    if (_digitsOnly(_phoneController.text).isNotEmpty) {
      await _lookupCustomerByPhone(_phoneController.text);
    }

    if (!form.validate()) {
      _showSnack('Please fix highlighted fields.');
      return;
    }

    final normalizedPhone = _normalizeIndianPhone(_phoneController.text);
    if (normalizedPhone == null) {
      _showSnack('Enter a valid 10-digit Indian phone number.');
      return;
    }

    final customer = BillingCustomer(
      name: _nameController.text.trim(),
      phone: normalizedPhone,
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
    );

    final provider = context.read<BillingProvider>();
    provider.setCustomer(customer);

    if (_useDummyEntryOnStartBilling && provider.items.isEmpty) {
      provider.addManualProduct(name: 'Dummy item', unitPrice: 10);
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _scanMode = true;
      _scannerActive = false;
      _startingScanner = false;
      _showHowBillingWorks = false;
    });

    await _startScanner();
  }

  Future<void> _startScanner() async {
    if (_paymentFlowActive ||
        _paymentCheckoutStarted ||
        _startingScanner ||
        _scannerActive) {
      return;
    }
    setState(() => _startingScanner = true);

    try {
      FocusManager.instance.primaryFocus?.unfocus();
      await _scannerController.start();
      if (!mounted) return;
      setState(() {
        _scannerActive = true;
        _startingScanner = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scannerActive = false;
        _startingScanner = false;
      });
      _showSnack(
        'Camera could not start on this device. Use manual add or try again.',
      );
    }
  }

  Future<void> _stopScanner() async {
    try {
      await _scannerController.stop();
    } catch (_) {
      // ignore
    }

    if (!mounted) return;
    setState(() {
      _scannerActive = false;
      _startingScanner = false;
    });
  }

  Future<void> _resumeScannerIfScanning() async {
    if (!_scanMode ||
        _paymentFlowActive ||
        _paymentCheckoutStarted ||
        _scannerActive ||
        _startingScanner) {
      return;
    }
    await _startScanner();
  }

  void _editCustomer() {
    unawaited(_stopScanner());
    setState(() => _scanMode = false);
  }

  TextEditingController _ensureProductSearchController() {
    return _productSearchController ??= TextEditingController();
  }

  void _scheduleProductSearchClear() {
    final controller = _productSearchController;
    if (controller == null) return;
    final queryAtTap = controller.text;

    Future<void>.delayed(const Duration(milliseconds: 6000), () {
      if (!mounted) return;
      if (_productSearchController?.text != queryAtTap) return;

      _productSearchDebounce?.cancel();
      _productSearchController?.clear();
      setState(() {
        _productSearchResults = <Product>[];
        _isProductSearching = false;
        _productSearchError = null;
      });
    });
  }

  BillingProduct _billingProductFromProduct(
    Product product, {
    bool preserveZeroQuantity = false,
  }) {
    final size = product.size.trim();
    final company = product.companyName.trim();
    final availableQty = preserveZeroQuantity
        ? product.quantityInStock
        : product.quantityInStock > 0
        ? product.quantityInStock
        : null;

    return BillingProduct(
      id: product.id,
      name: product.name,
      unitPrice: product.price,
      barcode: product.barcode.isEmpty ? null : product.barcode,
      size: size.isEmpty || size == '—' ? null : size,
      companyName: company.isEmpty ? null : company,
      availableQuantity: availableQty,
    );
  }

  Future<void> _addProductFromSearch(Product product) async {
    if (_productSearchLoadingIds.contains(product.id)) return;

    setState(() {
      _productSearchLoadingIds.add(product.id);
    });

    Product resolved = product;
    try {
      resolved = await _productsService.fetchProductDetails(
        productId: product.id,
      );
    } catch (_) {
      // Fall back to list response when details are unavailable.
    }

    if (!mounted) return;

    final provider = context.read<BillingProvider>();
    final added = provider.addOrIncrementProduct(
      _billingProductFromProduct(
        resolved,
        preserveZeroQuantity: resolved != product,
      ),
    );
    _showSnack('Added ${added.productName}');
    _scheduleProductSearchClear();
    unawaited(_revealLineItem(added.id));

    if (!mounted) return;
    setState(() {
      _productSearchLoadingIds.remove(product.id);
    });
  }

  Future<void> _runProductSearch(String query) async {
    if (!mounted) return;
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _productSearchResults = <Product>[];
        _isProductSearching = false;
        _productSearchError = null;
      });
      return;
    }

    final currentRequest = ++_productSearchRequestId;
    setState(() {
      _isProductSearching = true;
      _productSearchError = null;
    });

    Future<List<Product>> fetchProducts(String q) async {
      final filters = <String, String>{};
      if (q.isNotEmpty) {
        filters['search'] = q;
      }

      try {
        final page = await _productsService.fetchProductVariants(
          page: 1,
          pageSize: 30,
          filters: filters,
        );
        return page.items;
      } catch (_) {
        if (filters.isEmpty) rethrow;
        final page = await _productsService.fetchProductVariants(
          page: 1,
          pageSize: 30,
          filters: const <String, String>{},
        );
        return page.items;
      }
    }

    bool matchesQuery(Product product, String q) {
      final needle = q.toLowerCase();
      return product.name.toLowerCase().contains(needle) ||
          product.companyName.toLowerCase().contains(needle);
    }

    try {
      final items = await fetchProducts(trimmed);
      if (!mounted || currentRequest != _productSearchRequestId) return;
      final filtered = items
          .where((product) => matchesQuery(product, trimmed))
          .toList(growable: false);

      setState(() {
        _productSearchResults = filtered;
        _isProductSearching = false;
      });
    } catch (_) {
      if (!mounted || currentRequest != _productSearchRequestId) return;
      setState(() {
        _productSearchResults = <Product>[];
        _isProductSearching = false;
        _productSearchError = 'Could not load products. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final billingProvider = context.read<BillingProvider>();
    final provider = context.watch<BillingProvider>();
    final customer = provider.customer;

    InputDecoration fieldDecoration({
      required String label,
      required IconData icon,
      String? helper,
    }) {
      return InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        helperText: helper,
        prefixIcon: Icon(icon, color: colorScheme.primary),
        filled: true,
        fillColor: colorScheme.primary.withOpacity(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.primary.withOpacity(0.12),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      );
    }

    return WillPopScope(
      onWillPop: _confirmDiscardIfNeeded,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: colorScheme.surfaceContainerLow.withAlpha(235),
          surfaceTintColor: colorScheme.surfaceTint,
          title: _scanMode
              ? Column(
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
                )
              : const Text(
                  'Start billing',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
          actions: _scanMode
              ? [
                  IconButton(
                    tooltip: 'Edit customer',
                    onPressed: _editCustomer,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ]
              : null,
        ),
        body: SafeArea(
          bottom: false,
          child: _scanMode
              ? Builder(
                  builder: (context) {
                    final productSearchController =
                        _ensureProductSearchController();
                    return CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: productSearchController,
                                  onChanged: (value) {
                                    _productSearchDebounce?.cancel();
                                    _productSearchDebounce = Timer(
                                      const Duration(milliseconds: 350),
                                      () => unawaited(_runProductSearch(value)),
                                    );
                                    setState(() {});
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search product or brand…',
                                    prefixIcon: const Icon(Icons.search_rounded),
                                    suffixIcon: productSearchController
                                            .text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.close_rounded),
                                            onPressed: () {
                                              productSearchController.clear();
                                              _productSearchDebounce?.cancel();
                                              setState(() {
                                                _productSearchResults = [];
                                                _productSearchError = null;
                                                _isProductSearching = false;
                                              });
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: theme.brightness == Brightness.dark
                                        ? colorScheme.surface
                                        : Colors.white,
                                  ),
                                ),
                                if (_isProductSearching)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: LinearProgressIndicator(minHeight: 2),
                                  )
                                else if (_productSearchError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      _productSearchError!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                else if (productSearchController.text.isNotEmpty &&
                                    _productSearchResults.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'No matching products',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                if (_productSearchResults.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight:
                                            MediaQuery.sizeOf(context).height *
                                            0.22,
                                      ),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        padding: EdgeInsets.zero,
                                        itemCount: _productSearchResults.length,
                                        separatorBuilder: (_, _) =>
                                            const SizedBox(height: 6),
                                        itemBuilder: (context, index) {
                                          final product =
                                              _productSearchResults[index];
                                          final isLoading =
                                              _productSearchLoadingIds.contains(
                                                product.id,
                                              );
                                          return BillingSearchResultTile(
                                            product: product,
                                            priceLabel: _money(product.price),
                                            isLoading: isLoading,
                                            onTap: isLoading
                                                ? null
                                                : () => unawaited(
                                                    _addProductFromSearch(
                                                      product,
                                                    ),
                                                  ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                BillingCompactScannerBar(
                                  scannerActive: _scannerActive,
                                  startingScanner: _startingScanner,
                                  onToggleScanner: () {
                                    if (_scannerActive) {
                                      unawaited(_stopScanner());
                                    } else {
                                      unawaited(_startScanner());
                                    }
                                  },
                                ),
                                if (_scannerActive) ...[
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMd,
                                    ),
                                    child: AspectRatio(
                                      aspectRatio: 4 / 3,
                                      child: BarcodeScannerView(
                                        controller: _scannerController,
                                        enabled: _canAcceptBarcodeScans,
                                        hintText:
                                            'Align the barcode inside the frame and hold steady.',
                                        onBarcodeConfirmed: (value) {
                                          unawaited(_handleBarcode(value));
                                        },
                                        errorBuilder: (context, error, child) {
                                          return Container(
                                            color: colorScheme
                                                .surfaceContainerHighest,
                                            padding: const EdgeInsets.all(16),
                                            child: Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.camera_alt_outlined,
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Camera unavailable',
                                                    style: theme
                                                        .textTheme.titleSmall
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  TextButton(
                                                    onPressed: () {
                                                      unawaited(_stopScanner());
                                                    },
                                                    child: const Text('Close'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                          sliver: SliverToBoxAdapter(
                            child: Text(
                              'Bill items (${provider.items.length})',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),

                        if (provider.items.isEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                            sliver: SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Text(
                                  'Search above or scan to add products',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                            sliver: SliverList.separated(
                              itemCount: provider.items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = provider.items[index];
                                return ProductItemWidget(
                                  key: _lineItemKeys.putIfAbsent(
                                    item.id,
                                    () => GlobalKey(),
                                  ),
                                  item: item,
                                  priceEntryAsUnitPrice: true,
                                  onPriceChanged: (double? v) {
                                    context
                                        .read<BillingProvider>()
                                        .updateItemUnitPrice(item.id, v);
                                  },
                                  onDiscountChanged: (double? v) {
                                    context
                                        .read<BillingProvider>()
                                        .updateItemDiscountPercent(item.id, v);
                                  },
                                  onIncrement: () {
                                    context
                                        .read<BillingProvider>()
                                        .incrementItemQuantity(item.id);
                                  },
                                  onDecrement: () {
                                    context
                                        .read<BillingProvider>()
                                        .decrementItemQuantity(item.id);
                                  },
                                  onRemove: () {
                                    context.read<BillingProvider>().removeItem(
                                      item.id,
                                    );
                                    _lineItemKeys.remove(item.id);
                                    _showSnack('Removed ${item.productName}');
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final header = Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary.withOpacity(0.14),
                                    colorScheme.primary.withOpacity(0.06),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.account_circle_outlined,
                                color: colorScheme.primary,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Customer details',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Basic info to start a new bill',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(
                                'Step 1 of 2',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );

                    final formCard = Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Customer',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'We’ll use this for bills and history.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _phoneController,
                                focusNode: _phoneFocusNode,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                decoration: fieldDecoration(
                                  label: 'Phone number',
                                  icon: Icons.phone_outlined,
                                  helper:
                                      'Indian format: 10 digits (optional +91 or 0 prefix)',
                                ),
                                validator: _validatePhone,
                                onFieldSubmitted: (_) {
                                  FocusScope.of(
                                    context,
                                  ).requestFocus(_nameFocusNode);
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _nameController,
                                focusNode: _nameFocusNode,
                                textInputAction: TextInputAction.next,
                                decoration: fieldDecoration(
                                  label: 'Customer name',
                                  icon: Icons.person_outline,
                                ),
                                validator: (v) => _validateRequired(
                                  v,
                                  label: 'Customer name',
                                ),
                                onFieldSubmitted: (_) {
                                  FocusScope.of(
                                    context,
                                  ).requestFocus(_addressFocusNode);
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _addressController,
                                focusNode: _addressFocusNode,
                                keyboardType: TextInputType.streetAddress,
                                textInputAction: TextInputAction.done,
                                decoration: fieldDecoration(
                                  label: 'Address (optional)',
                                  icon: Icons.location_on_outlined,
                                ),
                                minLines: 1,
                                maxLines: 3,
                                onFieldSubmitted: (_) => _start(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                    final sidePanel = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_showHowBillingWorks)
                          Card(
                            elevation: 0,
                            color: colorScheme.surfaceContainerHigh,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'How billing works',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Close',
                                        onPressed: () {
                                          setState(
                                            () => _showHowBillingWorks = false,
                                          );
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: colorScheme.primary
                                          .withOpacity(0.12),
                                      child: Text(
                                        '1',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: colorScheme.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    title: const Text('Enter customer'),
                                    subtitle: const Text(
                                      'Phone number, name and address',
                                    ),
                                  ),
                                  ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: colorScheme.primary
                                          .withOpacity(0.12),
                                      child: Text(
                                        '2',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: colorScheme.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    title: const Text('Scan products'),
                                    subtitle: const Text(
                                      'Add items to the bill',
                                    ),
                                  ),
                                  ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: colorScheme.primary
                                          .withOpacity(0.12),
                                      child: Text(
                                        '3',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: colorScheme.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    title: const Text('Take payment'),
                                    subtitle: const Text('QR / Cash / Card'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          color: colorScheme.surfaceContainerHigh,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.privacy_tip_outlined,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Customer details are only used for billing and invoice reference.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );

                    return CustomScrollView(
                      slivers: [
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverToBoxAdapter(child: header),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 14)),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverToBoxAdapter(child: formCard),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverToBoxAdapter(child: sidePanel),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 140)),
                      ],
                    );
                  },
                ),
        ),
        bottomNavigationBar: _scanMode
            ? BillingCheckoutBar(
                itemCount: provider.totalItems,
                subtotalLabel: _money(provider.subtotal),
                discountLabel: _money(provider.totalDiscount),
                onPayment: _onPaymentTap,
                enabled: provider.items.isNotEmpty,
              )
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Continue to scan'),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
