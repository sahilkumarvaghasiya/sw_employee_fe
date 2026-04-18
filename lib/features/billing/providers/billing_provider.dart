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
  PaytmQrCode? _selectedPaytmQr;
  UpiQrCode? _selectedUpiQr;

  late final List<BillingCustomer> _knownCustomers;

  final List<BillingLineItem> _items = [];

  BillingCustomer? get customer => _customer;
  BillingPaymentMethod? get paymentMethod => _paymentMethod;
  bool get markPaid => _markPaid;
  double get paidAmount => _paidAmount;
  double? get manualFinalAmount => _manualFinalAmount;
  BillingQrConfig? get selectedQrConfig => _selectedQrConfig;
  PaytmQrCode? get selectedPaytmQr => _selectedPaytmQr;
  UpiQrCode? get selectedUpiQr => _selectedUpiQr;

  List<BillingLineItem> get items => List.unmodifiable(_items);

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

  List<PaytmQrCode> get paytmQrs => const [
    PaytmQrCode(id: 'ptm_001', label: 'Counter QR #1'),
    PaytmQrCode(id: 'ptm_002', label: 'Counter QR #2'),
    PaytmQrCode(id: 'ptm_003', label: 'Delivery QR'),
  ];

  List<UpiQrCode> get upiQrs => const [
    UpiQrCode(id: 'upi_001', label: 'UPI QR #1'),
    UpiQrCode(id: 'upi_002', label: 'UPI QR #2'),
    UpiQrCode(id: 'upi_003', label: 'UPI QR #3'),
  ];

  void setCustomer(BillingCustomer customer) {
    _customer = customer;
    notifyListeners();
  }

  void clearAll() {
    _customer = null;
    _paymentMethod = null;
    _selectedQrConfig = null;
    _selectedPaytmQr = null;
    _selectedUpiQr = null;
    _markPaid = false;
    _paidAmount = 0;
    _manualFinalAmount = null;
    _items.clear();
    notifyListeners();
  }

  BillingLineItem addOrIncrementProduct(BillingProduct product) {
    final existingIndex = _items.indexWhere((i) => i.id == product.id);
    if (existingIndex >= 0) {
      final existing = _items[existingIndex];
      _items[existingIndex] = existing.copyWith(
        quantity: existing.quantity + 1,
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
    _items[index] = _items[index].copyWith(
      unitPrice: unitPrice ?? _items[index].originalUnitPrice,
    );
    _manualFinalAmount = null;
    notifyListeners();
  }

  void updateItemDiscountPercent(String id, double? percent) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(
      discountPercent: percent == null ? 0 : percent.clamp(0, 100),
    );
    _manualFinalAmount = null;
    notifyListeners();
  }

  void incrementItemQuantity(String id) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return;
    final item = _items[index];
    _items[index] = item.copyWith(quantity: item.quantity + 1);
    _manualFinalAmount = null;
    notifyListeners();
  }

  void decrementItemQuantity(String id) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return;
    final item = _items[index];
    if (item.quantity <= 1) return;
    _items[index] = item.copyWith(quantity: item.quantity - 1);
    _manualFinalAmount = null;
    notifyListeners();
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
    if (_paymentMethod != BillingPaymentMethod.paytm) _selectedPaytmQr = null;
    if (_paymentMethod != BillingPaymentMethod.upi) _selectedUpiQr = null;

    notifyListeners();
  }

  void selectQrConfig(BillingQrConfig? qr) {
    _selectedQrConfig = qr;
    notifyListeners();
  }

  void selectPaytmQr(PaytmQrCode? qr) {
    _selectedPaytmQr = qr;
    notifyListeners();
  }

  void selectUpiQr(UpiQrCode? qr) {
    _selectedUpiQr = qr;
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
