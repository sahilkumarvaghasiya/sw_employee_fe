import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/billing_models.dart';
import '../providers/billing_provider.dart';
import '../services/billing_service.dart';
import '../widgets/billing_bottom_sheets.dart';
import '../widgets/product_item_widget.dart';
import 'bill_preview_screen.dart';

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

  final MobileScannerController _scannerController = MobileScannerController(
    autoStart: false,
  );

  Timer? _phoneLookupDebounce;
  int _phoneLookupRequestId = 0;
  String? _lastAutoFilledPhone;
  String? _lastAutoFilledName;
  String? _lastAutoFilledAddress;

  String? _lastBarcode;
  DateTime? _lastBarcodeAt;
  bool _handlingBarcode = false;

  final BillingService _billingService = BillingService();

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneLookupDebounce?.cancel();
    _phoneController.removeListener(_onPhoneChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _addressFocusNode.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
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
    if (_handlingBarcode) return;
    _handlingBarcode = true;

    try {
      final lookup = await _billingService.fetchBarcodeLookup(barcode);
      final products = lookup.products;
      if (!mounted) return;

      if (products.isEmpty) {
        _showSnack('No product found for barcode $barcode');
        return;
      }

      if (!lookup.isMultiple) {
        final selected = products.first;
        context.read<BillingProvider>().addOrIncrementProduct(selected);
        _showSnack('${selected.name} added');
        return;
      }

      final shouldRestartScanner = _scanMode;
      if (shouldRestartScanner) {
        await _stopScanner();
      }

      final selected = await _pickProductFromMatches(
        barcode: barcode,
        products: products,
      );
      if (!mounted) return;

      if (selected == null) {
        if (shouldRestartScanner && mounted) {
          await _startScanner();
        }
        return;
      }

      for (final product in selected) {
        context.read<BillingProvider>().addOrIncrementProduct(product);
      }
      _showSnack('${selected.length} product(s) added');

      if (shouldRestartScanner && mounted) {
        await _startScanner();
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Barcode lookup failed. Please try again.');
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      _handlingBarcode = false;
    }
  }

  Future<List<BillingProduct>?> _pickProductFromMatches({
    required String barcode,
    required List<BillingProduct> products,
  }) {
    return showModalBottomSheet<List<BillingProduct>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final searchController = TextEditingController();
        final selectedProductIds = <String>{};
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
        return AlertDialog(
          title: Text('$methodLabel payment'),
          content: const Text('Is the payment completed?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not yet'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Done'),
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
    bool offerExpanded = false;
    String? offerValueError;
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
            Widget segmentLabel(String text) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(text, maxLines: 1, softWrap: false),
              );
            }

            final rawValue = adjustmentController.text.trim();
            final parsedValue = double.tryParse(rawValue);
            final entered = parsedValue ?? 0.0;

            bool validateOfferValue() {
              if (offerMode == 0) {
                offerValueError = null;
                return true;
              }

              if (rawValue.isEmpty) {
                offerValueError = 'Required field';
                return false;
              }

              if (parsedValue == null || parsedValue <= 0) {
                offerValueError = 'Enter a valid value';
                return false;
              }

              if (offerMode == 1 && parsedValue >= baseAmount) {
                offerValueError = 'Must be less than total bill';
                return false;
              }

              if (offerMode == 2 && parsedValue > 100) {
                offerValueError = 'Discount must be up to 100%';
                return false;
              }

              offerValueError = null;
              return true;
            }

            void handleConfirm() {
              bool isValid = true;
              setModalState(() {
                isValid = validateOfferValue();
              });
              if (!isValid) return;
              Navigator.of(sheetContext).pop(true);
            }

            double payable = baseAmount;
            if (offerMode == 1 && entered > 0) {
              payable = (baseAmount - entered).clamp(0, double.infinity);
            } else if (offerMode == 2 && entered > 0) {
              final pct = entered.clamp(0, 100);
              payable = (baseAmount * (1 - pct / 100)).clamp(
                0,
                double.infinity,
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  16 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Review bill total',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Items: ${provider.items.length}'),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        color: colorScheme.surfaceContainerHigh,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: SizedBox(
                            height: (provider.items.length * 44.0).clamp(
                              120.0,
                              240.0,
                            ),
                            child: Scrollbar(
                              thumbVisibility: provider.items.length > 4,
                              child: ListView.separated(
                                primary: false,
                                itemCount: provider.items.length,
                                separatorBuilder: (_, _) => Divider(
                                  height: 10,
                                  color: colorScheme.outlineVariant,
                                ),
                                itemBuilder: (context, index) {
                                  final item = provider.items[index];
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.productName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('x${item.quantity}'),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('Subtotal: ${_money(provider.subtotal)}'),
                      const SizedBox(height: 4),
                      Text('Item discount: ${_money(provider.totalDiscount)}'),
                      const SizedBox(height: 4),
                      Text(
                        'Bill total: ${_money(baseAmount)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Offer on total',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: offerExpanded
                                ? 'Hide offer options'
                                : 'Show offer options',
                            onPressed: () {
                              setModalState(() {
                                offerExpanded = !offerExpanded;
                                if (!offerExpanded) {
                                  offerMode = 0;
                                  adjustmentController.clear();
                                  offerValueError = null;
                                }
                              });
                            },
                            icon: Icon(
                              offerExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                            ),
                          ),
                        ],
                      ),
                      if (offerExpanded) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: SegmentedButton<int>(
                                segments: [
                                  ButtonSegment<int>(
                                    value: 0,
                                    label: segmentLabel('None'),
                                  ),
                                  ButtonSegment<int>(
                                    value: 1,
                                    label: segmentLabel('Price'),
                                  ),
                                  ButtonSegment<int>(
                                    value: 2,
                                    label: segmentLabel('Discount'),
                                  ),
                                ],
                                multiSelectionEnabled: false,
                                emptySelectionAllowed: false,
                                selected: {offerMode},
                                showSelectedIcon: false,
                                style: ButtonStyle(
                                  padding: WidgetStateProperty.all(
                                    const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onSelectionChanged: (selection) {
                                  setModalState(() {
                                    offerMode = selection.first;
                                    adjustmentController.clear();
                                    offerValueError = null;
                                  });
                                },
                              ),
                            ),
                            if (offerMode != 0) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: adjustmentController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  onChanged: (_) {
                                    setModalState(() {
                                      validateOfferValue();
                                    });
                                  },
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'Value',
                                    prefixText: offerMode == 1 ? '₹' : null,
                                    suffixText: offerMode == 2 ? '%' : null,
                                    errorText: offerValueError,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (!offerExpanded) const SizedBox(height: 6),
                      Card(
                        margin: EdgeInsets.zero,
                        color: colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.receipt_long_rounded),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Payable total',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                _money(payable),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 340;
                          if (stacked) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                OutlinedButton(
                                  onPressed: () =>
                                      Navigator.of(sheetContext).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                const SizedBox(height: 8),
                                FilledButton(
                                  onPressed: handleConfirm,
                                  child: const Text('Confirm'),
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      Navigator.of(sheetContext).pop(false),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: handleConfirm,
                                  child: const Text('Confirm'),
                                ),
                              ),
                            ],
                          );
                        },
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

    if (confirmed != true) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        adjustmentController.dispose();
      });
      return false;
    }

    final entered = double.tryParse(adjustmentController.text.trim()) ?? 0.0;
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      adjustmentController.dispose();
    });

    if (offerMode == 0) {
      provider.setManualFinalAmount(null);
      return true;
    }

    if (offerMode == 1) {
      provider.setManualFinalAmount(
        (baseAmount - entered).clamp(0, double.infinity),
      );
      return true;
    }

    final pct = entered.clamp(0, 100);
    provider.setManualFinalAmount(
      (baseAmount * (1 - pct / 100)).clamp(0, double.infinity),
    );
    return true;
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
    Navigator.of(context).push(BillPreviewScreen.route(context));
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
    Navigator.of(context).push(BillPreviewScreen.route(context));
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Close',
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              ),
                              Text(
                                'Select a QR from dashboard and show it to customer.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (qrConfigs.isEmpty)
                                Card(
                                  elevation: 0,
                                  color: colorScheme.surfaceContainerHigh,
                                  child: const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: Text('No QR barcode available.'),
                                  ),
                                )
                              else
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Choose barcode',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
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
                                        final isSelected =
                                            selectedQr?.id == qr.id;
                                        return InkWell(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          onTap: () {
                                            p.setPaymentMethod(
                                              BillingPaymentMethod.qr,
                                            );
                                            p.selectQrConfig(qr);
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 140,
                                            ),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? colorScheme.primary
                                                        .withOpacity(0.12)
                                                  : colorScheme
                                                        .surfaceContainerHigh,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: isSelected
                                                    ? colorScheme.primary
                                                    : colorScheme
                                                          .outlineVariant,
                                                width: isSelected ? 1.5 : 1,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    child: Image.network(
                                                      qr.imageUrl,
                                                      width: double.infinity,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, _, _) =>
                                                          Container(
                                                            color: colorScheme
                                                                .surface,
                                                            child: Icon(
                                                              Icons
                                                                  .qr_code_2_rounded,
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
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
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
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
                                                style: theme
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                              ),
                                              const SizedBox(height: 10),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                child: Image.network(
                                                  selectedQr.imageUrl,
                                                  height: 180,
                                                  width: double.infinity,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, _, _) =>
                                                      Container(
                                                        height: 180,
                                                        color:
                                                            colorScheme.surface,
                                                        child: Icon(
                                                          Icons
                                                              .qr_code_2_rounded,
                                                          size: 92,
                                                          color: colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton.icon(
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
                                          Navigator.of(context).push(
                                            BillPreviewScreen.route(context),
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
    if (!canContinue) return;

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
                  subtitle: 'Confirm card payment received',
                  onTap: () async {
                    await _confirmCardAndGenerateBill(
                      closePaymentOptionsOnSuccess: true,
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

  Future<void> _onPaymentTap() async {
    try {
      final provider = context.read<BillingProvider>();
      if (provider.items.isEmpty) {
        _showSnack('Add at least one product before payment.');
        return;
      }

      await _showPaymentOptions();
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not open payment. Please try again.');
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
    if (_startingScanner || _scannerActive) return;
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

  void _editCustomer() {
    unawaited(_stopScanner());
    setState(() => _scanMode = false);
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
        helperText: helper,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      );
    }

    return Scaffold(
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
                        : '${customer.name} • ${customer.phone}',
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
                  final totals = Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
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

                  return CustomScrollView(
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
                                  child: _scannerActive
                                      ? MobileScanner(
                                          controller: _scannerController,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, child) {
                                            return Container(
                                              color: colorScheme
                                                  .surfaceContainerHighest,
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    16,
                                                    16,
                                                    16,
                                                    16,
                                                  ),
                                              child: Center(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.camera_alt_outlined,
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                      size: 28,
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      'Camera unavailable',
                                                      style: theme
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w900,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'This emulator/device may not support camera scanning.',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: colorScheme
                                                                .onSurfaceVariant,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    FilledButton.icon(
                                                      onPressed: () {
                                                        unawaited(
                                                          _stopScanner(),
                                                        );
                                                      },
                                                      icon: const Icon(
                                                        Icons.close_rounded,
                                                      ),
                                                      label: const Text(
                                                        'Close scanner',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                          onDetect: (capture) {
                                            final barcodes = capture.barcodes;
                                            if (barcodes.isEmpty) return;

                                            final raw = barcodes.first.rawValue;
                                            final value = raw?.trim();
                                            if (value == null ||
                                                value.isEmpty) {
                                              return;
                                            }

                                            final now = DateTime.now();
                                            final last = _lastBarcodeAt;
                                            final same = _lastBarcode == value;
                                            final tooSoon =
                                                last != null &&
                                                now.difference(last) <
                                                    const Duration(
                                                      milliseconds: 1200,
                                                    );
                                            if (same && tooSoon) return;

                                            _lastBarcode = value;
                                            _lastBarcodeAt = now;

                                            unawaited(_handleBarcode(value));
                                          },
                                        )
                                      : Container(
                                          color: colorScheme
                                              .surfaceContainerHighest,
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            16,
                                            16,
                                            16,
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  height: 44,
                                                  width: 44,
                                                  decoration: BoxDecoration(
                                                    color: colorScheme.primary
                                                        .withOpacity(0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons
                                                        .qr_code_scanner_rounded,
                                                    color: colorScheme.primary,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  'Camera scanning is off',
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Start scanning to add products faster.',
                                                  textAlign: TextAlign.center,
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                const SizedBox(height: 12),
                                                FilledButton.icon(
                                                  onPressed: _startingScanner
                                                      ? null
                                                      : () {
                                                          unawaited(
                                                            _startScanner(),
                                                          );
                                                        },
                                                  icon: _startingScanner
                                                      ? const SizedBox(
                                                          width: 18,
                                                          height: 18,
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                              ),
                                                        )
                                                      : const Icon(
                                                          Icons
                                                              .camera_alt_rounded,
                                                        ),
                                                  label: Text(
                                                    _startingScanner
                                                        ? 'Starting…'
                                                        : 'Start scanning',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                ),
                                Positioned(
                                  left: 12,
                                  right: 12,
                                  bottom: 12,
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerLow
                                          .withAlpha(235),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.qr_code_scanner),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _scannerActive
                                                ? 'Keep scanning products one by one. The bill updates automatically.'
                                                : 'Tap “Start scanning” to use camera. You can also add products manually.',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
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
                              color: colorScheme.surfaceContainerHigh,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
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
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = provider.items[index];
                              return ProductItemWidget(
                                key: ValueKey(item.id),
                                item: item,
                                onPriceChanged: (double? v) {
                                  context
                                      .read<BillingProvider>()
                                      .updateItemPrice(item.id, v);
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
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.account_circle_outlined,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customer details',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Basic info to start a new bill.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Text(
                                'Step 1 of 2',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                            const SizedBox(height: 4),
                            Text(
                              'We’ll use this for bills and history.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
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
                              validator: (v) =>
                                  _validateRequired(v, label: 'Customer name'),
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
                                  subtitle: const Text('Add items to the bill'),
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _scanMode
              ? Card(
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
                          onPressed: _onPaymentTap,
                          icon: const Icon(Icons.payments_outlined),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text('Payment'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _start,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('Continue to Scan'),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
