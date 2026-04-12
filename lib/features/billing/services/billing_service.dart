import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/services/api_service.dart';
import '../models/billing_models.dart';

class BillingService {
  BillingService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  // Flip this to true once the backend endpoint is available.
  static const bool whatsAppApiIntegrated = false;

  final ApiService _apiService;

  static Uri _url(String path) {
    final base = ApiConfig.baseUrl;
    final normalizedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  Future<void> sendWhatsAppInvoice({
    required BillingCustomer customer,
    required List<BillingLineItem> items,
    required BillingPaymentMethod? paymentMethod,
    required bool markPaid,
    required double paidAmount,
    required double subtotal,
    required double totalDiscount,
    required double finalAmount,
  }) async {
    if (!whatsAppApiIntegrated) {
      return;
    }

    final response = await _apiService.post(
      _url('/billing/send-whatsapp-invoice/').toString(),
      body: {
        'customer': {
          'name': customer.name,
          'phone': customer.phone,
          if (customer.address != null) 'address': customer.address,
        },
        'items': [
          for (final item in items)
            {
              'id': item.id,
              'name': item.productName,
              'quantity': item.quantity,
              'unitPrice': item.unitPrice,
              'discountPercent': item.discountPercent,
              'lineTotal': item.lineTotal,
            },
        ],
        'paymentMethod': paymentMethod?.name,
        'markPaid': markPaid,
        'paidAmount': paidAmount,
        'totals': {
          'subtotal': subtotal,
          'discount': totalDiscount,
          'final': finalAmount,
        },
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final message = _errorMessageFromResponse(response);
    throw http.ClientException(
      message.isEmpty ? 'Failed to send invoice' : message,
    );
  }

  String _errorMessageFromResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final value =
            decoded['error'] ?? decoded['detail'] ?? decoded['message'];
        if (value != null) return value.toString();
      }
    } catch (_) {
      // ignore
    }

    return 'Failed to send invoice (${response.statusCode})';
  }
}
