import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../billing/models/billing_models.dart';
import '../models/sales_bill.dart';

class SalesHistoryProvider extends ChangeNotifier {
  SalesHistoryProvider() {
    _bills = _buildSampleBills();
  }

  late List<SalesBill> _bills;

  List<SalesBill> get bills => List.unmodifiable(_bills);

  Future<void> refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    notifyListeners();
  }

  List<SalesBill> _buildSampleBills() {
    final random = Random(7);
    final now = DateTime.now();

    const customers = <BillingCustomer>[
      BillingCustomer(name: 'Amit Sharma', phone: '9876543210'),
      BillingCustomer(name: 'Anjali Gupta', phone: '9123456780'),
      BillingCustomer(name: 'Ravi Kumar', phone: '9988776655'),
      BillingCustomer(name: 'Sana Khan', phone: '9090909090'),
      BillingCustomer(name: 'Vikram Singh', phone: '9012345678'),
    ];

    const catalog = <BillingProduct>[
      BillingProduct(id: 'p_001', name: 'Parle-G 250g', unitPrice: 20.0),
      BillingProduct(
        id: 'p_002',
        name: 'Aashirvaad Atta 5kg',
        unitPrice: 275.0,
      ),
      BillingProduct(id: 'p_003', name: 'Coca-Cola 750ml', unitPrice: 40.0),
      BillingProduct(id: 'p_004', name: 'Lux Soap', unitPrice: 35.0),
      BillingProduct(
        id: 'p_005',
        name: 'Colgate Toothpaste 200g',
        unitPrice: 95.0,
      ),
      BillingProduct(id: 'p_006', name: 'Toor Dal 1kg', unitPrice: 155.0),
      BillingProduct(id: 'p_007', name: 'Cooking Oil 1L', unitPrice: 165.0),
    ];

    final methods = BillingPaymentMethod.values;

    final out = <SalesBill>[];
    for (int i = 0; i < 36; i++) {
      final createdAt = now.subtract(
        Duration(
          days: random.nextInt(25),
          hours: random.nextInt(24),
          minutes: random.nextInt(60),
        ),
      );

      final itemCount = 1 + random.nextInt(5);
      final picked = <BillingLineItem>[];
      final used = <int>{};

      for (int j = 0; j < itemCount; j++) {
        int idx = random.nextInt(catalog.length);
        while (used.contains(idx)) {
          idx = random.nextInt(catalog.length);
        }
        used.add(idx);

        final product = catalog[idx];
        final quantity = 1 + random.nextInt(3);
        final discount = random.nextInt(3) == 0
            ? (5.0 * (1 + random.nextInt(4)))
            : 0.0;

        picked.add(
          BillingLineItem(
            id: product.id,
            productName: product.name,
            quantity: quantity,
            unitPrice: product.unitPrice,
            discountPercent: discount,
          ),
        );
      }

      final customer = customers[random.nextInt(customers.length)];
      final paymentMethod = methods[random.nextInt(methods.length)];

      out.add(
        SalesBill(
          id: 'bill_${i + 1}',
          billNo: (10400 + i).toString(),
          createdAt: createdAt,
          customer: customer,
          items: picked,
          paymentMethod: paymentMethod,
        ),
      );
    }

    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }
}
