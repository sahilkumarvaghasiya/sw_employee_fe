import 'package:flutter/foundation.dart';

import '../models/billing_models.dart';

class BillingProvider extends ChangeNotifier {
  BillingProvider() {
    // TODO: Replace this local cache with backend-powered search.
    _knownCustomers = const [
      BillingCustomer(name: 'Amit Sharma', phone: '9876543210'),
      BillingCustomer(name: 'Anjali Gupta', phone: '9123456780'),
      BillingCustomer(name: 'Ravi Kumar', phone: '9988776655'),
      BillingCustomer(name: 'Sana Khan', phone: '9090909090'),
      BillingCustomer(name: 'Vikram Singh', phone: '9012345678'),
    ];
  }

  BillingCustomer? _customer;
  BillingPaymentMethod? _paymentMethod;
  bool _markPaid = false;
  double _paidAmount = 0;
  double? _manualFinalAmount;
  BillingQrConfig? _selectedQrConfig;

  final List<String> _scannedBarcodes = [];
  final Map<String, Set<String>> _selectedProductIdsByBarcode = {};

  late final List<BillingCustomer> _knownCustomers;

  final List<BillingLineItem> _items = [];

  BillingCustomer? get customer => _customer;
  BillingPaymentMethod? get paymentMethod => _paymentMethod;
  bool get markPaid => _markPaid;
  double get paidAmount => _paidAmount;
  double? get manualFinalAmount => _manualFinalAmount;
  BillingQrConfig? get selectedQrConfig => _selectedQrConfig;
  List<String> get scannedBarcodes => List.unmodifiable(_scannedBarcodes);

  List<BillingLineItem> get items => List.unmodifiable(_items);

  List<String> buildScannedBarcodesForLookup(String barcode) {
    final normalized = barcode.trim();
    final values = List<String>.from(_scannedBarcodes);
    if (normalized.isNotEmpty) {
      values.add(normalized);
    }
    return values;
  }

  Set<String> selectedProductIdsForBarcode(String barcode) {
    final normalized = barcode.trim();
    final selected = _selectedProductIdsByBarcode[normalized];
    return selected == null ? <String>{} : Set<String>.from(selected);
  }

  void registerScannedBarcode(String barcode) {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return;
    _scannedBarcodes.add(normalized);
  }

  void syncMultiBarcodeSelection({
    required String barcode,
    required List<BillingProduct> selectedProducts,
  }) {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return;

    final previousSelectedIds =
        _selectedProductIdsByBarcode[normalized] ?? <String>{};
    final nextSelectedIds = selectedProducts.map((p) => p.id).toSet();

    for (final removedId in previousSelectedIds.difference(nextSelectedIds)) {
      _items.removeWhere((item) => item.id == removedId);
    }

    for (final product in selectedProducts) {
      if (previousSelectedIds.contains(product.id)) continue;
      addOrIncrementProduct(product);
    }

    if (nextSelectedIds.isEmpty) {
      _selectedProductIdsByBarcode.remove(normalized);
    } else {
      _selectedProductIdsByBarcode[normalized] = nextSelectedIds;
    }

    _manualFinalAmount = null;
    notifyListeners();
  }

  List<BillingCustomer> searchCustomers(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    return _knownCustomers
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.phone.replaceAll(' ', '').contains(q),
        )
        .take(8)
        .toList(growable: false);
  }

  int get totalItems => _items.fold<int>(0, (sum, i) => sum + i.quantity);

  double get subtotal =>
      _items.fold<double>(0, (sum, i) => sum + i.lineSubtotal);

  double get totalDiscount =>
      _items.fold<double>(0, (sum, i) => sum + i.lineDiscount);

  double get calculatedFinalAmount =>
      (subtotal - totalDiscount).clamp(0, double.infinity);

  double get finalAmount =>
      (_manualFinalAmount ?? calculatedFinalAmount).clamp(0, double.infinity);

  double get remainingAmount =>
      (finalAmount - _paidAmount).clamp(0, double.infinity);

  void setCustomer(BillingCustomer customer) {
    _customer = customer;
    notifyListeners();
  }

  void clearAll() {
    _customer = null;
    _paymentMethod = null;
    _selectedQrConfig = null;
    _markPaid = false;
    _paidAmount = 0;
    _manualFinalAmount = null;
    _items.clear();
    _scannedBarcodes.clear();
    _selectedProductIdsByBarcode.clear();
    notifyListeners();
  }

  BillingLineItem addOrIncrementProduct(BillingProduct product) {
    final existingIndex = _items.indexWhere((i) => i.id == product.id);
    if (existingIndex >= 0) {
      final existing = _items[existingIndex];
      final maxQuantity =
          existing.availableQuantity ?? product.availableQuantity;
      if (maxQuantity != null && existing.quantity >= maxQuantity) {
        return existing;
      }
      final nextQty = existing.quantity + 1;
      final nextUnitPrice = _unitPriceKeepingTotalReduction(
        item: existing,
        nextQuantity: nextQty,
      );
      _items[existingIndex] = existing.copyWith(
        quantity: nextQty,
        unitPrice: nextUnitPrice,
      );
      _manualFinalAmount = null;
      notifyListeners();
      return _items[existingIndex];
    }

    _items.insert(
      0,
      BillingLineItem(
        id: product.id,
        productName: product.name,
        quantity: 1,
        originalUnitPrice: product.unitPrice,
        unitPrice: product.unitPrice,
        discountPercent: 0,
        availableQuantity: product.availableQuantity,
        size: product.size,
      ),
    );
    _manualFinalAmount = null;
    notifyListeners();
    return _items.first;
  }

  BillingLineItem addManualProduct({
    required String name,
    required double unitPrice,
  }) {
    final id = 'manual_${DateTime.now().microsecondsSinceEpoch}';
    _items.insert(
      0,
      BillingLineItem(
        id: id,
        productName: name,
        quantity: 1,
        originalUnitPrice: unitPrice,
        unitPrice: unitPrice,
        discountPercent: 0,
      ),
    );
    _manualFinalAmount = null;
    notifyListeners();
    return _items.first;
  }

  void updateItemPrice(String id, double? unitPrice) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return;
    final item = _items[index];
    _items[index] = _items[index].copyWith(
      unitPrice: unitPrice ?? item.originalUnitPrice,
      discountPercent: 0,
    );
    _manualFinalAmount = null;
    notifyListeners();
  }

  void updateItemDiscountPercent(String id, double? percent) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return;
    final item = _items[index];
    _items[index] = _items[index].copyWith(
      unitPrice: item.originalUnitPrice,
      discountPercent: percent == null ? 0 : percent.clamp(0, 100),
    );
    _manualFinalAmount = null;
    notifyListeners();
  }

  void incrementItemQuantity(String id) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return;
    final item = _items[index];
    final maxQuantity = item.availableQuantity;
    if (maxQuantity != null && item.quantity >= maxQuantity) return;
    final nextQty = item.quantity + 1;
    final nextUnitPrice = _unitPriceKeepingTotalReduction(
      item: item,
      nextQuantity: nextQty,
    );
    _items[index] = item.copyWith(quantity: nextQty, unitPrice: nextUnitPrice);
    _manualFinalAmount = null;
    notifyListeners();
  }

  void decrementItemQuantity(String id) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return;
    final item = _items[index];
    if (item.quantity <= 1) return;
    final nextQty = item.quantity - 1;
    final nextUnitPrice = _unitPriceKeepingTotalReduction(
      item: item,
      nextQuantity: nextQty,
    );
    _items[index] = item.copyWith(quantity: nextQty, unitPrice: nextUnitPrice);
    _manualFinalAmount = null;
    notifyListeners();
  }

  double _unitPriceKeepingTotalReduction({
    required BillingLineItem item,
    required int nextQuantity,
  }) {
    // In price mode, keep the entered reduction fixed for the whole line
    // when quantity changes. Do not alter discount mode behavior.
    final priceOverridden = item.unitPrice != item.originalUnitPrice;
    final discountApplied = item.discountPercent > 0;

    if (!priceOverridden || discountApplied || nextQuantity <= 0) {
      return item.unitPrice;
    }

    final totalReduction =
        (item.originalUnitPrice - item.unitPrice) * item.quantity;
    final nextUnitPrice =
        item.originalUnitPrice - (totalReduction / nextQuantity);
    return nextUnitPrice.clamp(0, item.originalUnitPrice).toDouble();
  }

  void removeItem(String id) {
    _items.removeWhere((i) => i.id == id);
    _manualFinalAmount = null;
    notifyListeners();
  }

  void setManualFinalAmount(double? value) {
    if (value == null) {
      _manualFinalAmount = null;
      notifyListeners();
      return;
    }
    _manualFinalAmount = value.clamp(0, double.infinity);
    notifyListeners();
  }

  void setPaymentMethod(BillingPaymentMethod? method) {
    _paymentMethod = method;

    if (_paymentMethod != BillingPaymentMethod.qr) _selectedQrConfig = null;

    notifyListeners();
  }

  void selectQrConfig(BillingQrConfig? qr) {
    _selectedQrConfig = qr;
    notifyListeners();
  }

  void setPaidAmount(double value) {
    _paidAmount = value.clamp(0, double.infinity);
    notifyListeners();
  }

  void setMarkPaid(bool value) {
    _markPaid = value;
    if (_markPaid) {
      _paidAmount = finalAmount;
    }
    notifyListeners();
  }
}
