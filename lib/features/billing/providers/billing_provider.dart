import 'package:flutter/foundation.dart';

import '../models/billing_models.dart';

class BillingProvider extends ChangeNotifier {
  BillingCustomer? _customer;
  BillingPaymentMethod? _paymentMethod;
  bool _markPaid = false;
  double _paidAmount = 0;
  PaytmQrCode? _selectedPaytmQr;

  final List<BillingLineItem> _items = [];

  BillingCustomer? get customer => _customer;
  BillingPaymentMethod? get paymentMethod => _paymentMethod;
  bool get markPaid => _markPaid;
  double get paidAmount => _paidAmount;
  PaytmQrCode? get selectedPaytmQr => _selectedPaytmQr;

  List<BillingLineItem> get items => List.unmodifiable(_items);

  int get totalItems => _items.fold<int>(0, (sum, i) => sum + i.quantity);

  double get subtotal =>
      _items.fold<double>(0, (sum, i) => sum + i.lineSubtotal);

  double get totalDiscount =>
      _items.fold<double>(0, (sum, i) => sum + i.lineDiscount);

  double get finalAmount =>
      (subtotal - totalDiscount).clamp(0, double.infinity);

  double get remainingAmount =>
      (finalAmount - _paidAmount).clamp(0, double.infinity);

  List<PaytmQrCode> get paytmQrs => const [
    PaytmQrCode(id: 'ptm_001', label: 'Counter QR #1'),
    PaytmQrCode(id: 'ptm_002', label: 'Counter QR #2'),
    PaytmQrCode(id: 'ptm_003', label: 'Delivery QR'),
  ];

  void setCustomer(BillingCustomer customer) {
    _customer = customer;
    notifyListeners();
  }

  void clearAll() {
    _customer = null;
    _paymentMethod = null;
    _selectedPaytmQr = null;
    _markPaid = false;
    _paidAmount = 0;
    _items.clear();
    notifyListeners();
  }

  void addOrIncrementProduct(BillingProduct product) {
    final existingIndex = _items.indexWhere((i) => i.id == product.id);
    if (existingIndex >= 0) {
      final existing = _items[existingIndex];
      _items[existingIndex] = existing.copyWith(
        quantity: existing.quantity + 1,
      );
      notifyListeners();
      return;
    }

    _items.insert(
      0,
      BillingLineItem(
        id: product.id,
        productName: product.name,
        quantity: 1,
        unitPrice: product.unitPrice,
        discountPercent: 0,
      ),
    );
    notifyListeners();
  }

  void addManualProduct({required String name, required double unitPrice}) {
    final id = 'manual_${DateTime.now().microsecondsSinceEpoch}';
    _items.insert(
      0,
      BillingLineItem(
        id: id,
        productName: name,
        quantity: 1,
        unitPrice: unitPrice,
        discountPercent: 0,
      ),
    );
    notifyListeners();
  }

  void updateItemPrice(String id, double unitPrice) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(unitPrice: unitPrice);
    notifyListeners();
  }

  void updateItemDiscountPercent(String id, double percent) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(
      discountPercent: percent.clamp(0, 100),
    );
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  void setPaymentMethod(BillingPaymentMethod? method) {
    _paymentMethod = method;
    if (_paymentMethod != BillingPaymentMethod.paytm) {
      _selectedPaytmQr = null;
    }
    notifyListeners();
  }

  void selectPaytmQr(PaytmQrCode? qr) {
    _selectedPaytmQr = qr;
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
