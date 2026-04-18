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
  static const String _barcodeLookupPath = '/api/sales/barcode-lookup/';
  static const String _customerLookupPath = '/api/sales/customer-lookup/';

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

  Future<List<BillingProduct>> fetchProductsByBarcode(String barcode) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return const [];

    final uri = _url('$_barcodeLookupPath${Uri.encodeComponent(normalized)}/');

    final response = await _apiService.get(uri.toString());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _errorMessageFromResponse(response);
      throw http.ClientException(
        message.isEmpty ? 'Failed to fetch products by barcode' : message,
      );
    }

    final decoded = jsonDecode(response.body);
    final records = _extractProductRecords(decoded);

    return records
        .map(_productFromMap)
        .whereType<BillingProduct>()
        .toList(growable: false);
  }

  Future<BillingCustomer?> fetchCustomerByPhone(String phone) async {
    final normalized = phone.trim();
    if (normalized.isEmpty) return null;

    final uri = _url('$_customerLookupPath${Uri.encodeComponent(normalized)}/');

    final response = await _apiService.get(uri.toString());
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _errorMessageFromResponse(response);
      throw http.ClientException(
        message.isEmpty ? 'Failed to fetch customer by phone' : message,
      );
    }

    final decoded = jsonDecode(response.body);
    final records = _extractCustomerRecords(decoded);
    if (records.isEmpty) return null;

    for (final record in records) {
      final customer = _customerFromMap(record);
      if (customer != null) return customer;
    }

    return null;
  }

  List<Map<String, dynamic>> _extractProductRecords(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }

    if (decoded is! Map) return const [];

    final map = Map<String, dynamic>.from(decoded);
    final productNode = map['product'];
    if (productNode is Map) {
      return [Map<String, dynamic>.from(productNode)];
    }

    final dynamic productsNode = map['products'];
    if (productsNode is Map) {
      final nested = Map<String, dynamic>.from(productsNode);
      final dynamic nestedResults =
          nested['results'] ?? nested['data'] ?? nested['items'];
      if (nestedResults is List) {
        return nestedResults
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
      return [nested];
    }

    final dynamic listValue = map['results'] ?? map['data'] ?? map['items'];

    if (listValue is List) {
      return listValue
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }

    return [map];
  }

  BillingProduct? _productFromMap(Map<String, dynamic> map) {
    final idValue = map['id'] ?? map['product_id'] ?? map['sku'] ?? map['code'];
    final nameValue = map['name'] ?? map['product_name'] ?? map['title'];
    final companyValue = map['company_name'] ?? map['companyName'];
    final priceValue =
        map['unit_price'] ?? map['sell_price'] ?? map['price'] ?? map['mrp'];
    final barcodeValue = map['barcode'] ?? map['barcode_number'] ?? map['ean'];
    final sizeValue =
        map['size'] ?? map['product_size'] ?? map['variant_size'] ?? map['sz'];

    final id = idValue?.toString().trim() ?? '';
    final name = nameValue?.toString().trim() ?? '';
    final price = priceValue is num
        ? priceValue.toDouble()
        : double.tryParse('${priceValue ?? ''}');

    if (id.isEmpty || name.isEmpty || price == null || price <= 0) {
      return null;
    }

    final barcode = barcodeValue?.toString().trim();
    final quantityValue = map['quantity'] ?? map['available_quantity'];
    final availableQuantity = quantityValue is num
        ? quantityValue.toInt()
        : int.tryParse('${quantityValue ?? ''}');

    return BillingProduct(
      id: id,
      name: name,
      unitPrice: price,
      barcode: barcode == null || barcode.isEmpty ? null : barcode,
      size: sizeValue?.toString().trim().isEmpty == true
          ? null
          : sizeValue?.toString().trim(),
      companyName: companyValue?.toString().trim().isEmpty == true
          ? null
          : companyValue?.toString().trim(),
      availableQuantity: availableQuantity,
    );
  }

  List<Map<String, dynamic>> _extractCustomerRecords(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }

    if (decoded is! Map) return const [];

    final map = Map<String, dynamic>.from(decoded);
    final dynamic listValue =
        map['customers'] ?? map['results'] ?? map['data'] ?? map['items'];

    if (listValue is List) {
      return listValue
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }

    final customerNode = map['customer'];
    if (customerNode is Map) {
      return [Map<String, dynamic>.from(customerNode)];
    }

    return [map];
  }

  BillingCustomer? _customerFromMap(Map<String, dynamic> map) {
    final nameValue = map['name'] ?? map['customer_name'] ?? map['full_name'];
    final phoneValue = map['phone'] ?? map['phone_number'] ?? map['mobile'];
    final addressValue = map['address'] ?? map['customer_address'];

    final name = nameValue?.toString().trim() ?? '';
    final phone = phoneValue?.toString().trim() ?? '';
    final address = addressValue?.toString().trim();

    if (name.isEmpty && phone.isEmpty) return null;

    return BillingCustomer(
      name: name.isEmpty ? 'Unknown' : name,
      phone: phone,
      address: address == null || address.isEmpty ? null : address,
    );
  }
}
