import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/services/api_service.dart';
import '../models/billing_models.dart';

class BillingBarcodeLookupResult {
  const BillingBarcodeLookupResult({
    required this.isMultiple,
    required this.products,
  });

  final bool isMultiple;
  final List<BillingProduct> products;
}

class BillingCreateBillResult {
  const BillingCreateBillResult({
    required this.message,
    required this.billId,
    required this.billNumber,
  });

  final String message;
  final String billId;
  final String billNumber;
}

class BillingService {
  BillingService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  // Flip this to true once the backend endpoint is available.
  static const bool whatsAppApiIntegrated = false;
  static const String _barcodeLookupPath = '/sales/barcode-lookup/';
  static const String _barcodeLookupSearchPath =
      '/sales/barcode-lookup/search/';
  static const String _customerLookupPath = '/sales/customer-lookup/';
  static const String _qrConfigsPath = '/sales/payment-configs/qr/';
  static const String _createBillPath = '/sales/bills/create/';

  final ApiService _apiService;

  static Uri _url(String path) {
    final base = ApiConfig.baseUrl;
    final normalizedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  static Uri _urlWithQuery(String path, Map<String, String> queryParameters) {
    final uri = _url(path);
    return uri.replace(queryParameters: queryParameters);
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

  Future<BillingCreateBillResult> createSalesBill({
    required BillingCustomer customer,
    required List<BillingLineItem> items,
    required BillingPaymentMethod paymentMethod,
    String? selectedQrConfigId,
    required bool markPaid,
    required double finalAmount,
    required double calculatedFinalAmount,
    String? notes,
  }) async {
    if (items.isEmpty) {
      throw http.ClientException('No products in the bill');
    }

    String money(double value) => value.toStringAsFixed(2);

    final lineItems = <Map<String, dynamic>>[];
    for (final item in items) {
      final productVariantId = int.tryParse(item.id);
      if (productVariantId == null) {
        throw http.ClientException(
          'Product "${item.productName}" cannot be billed because it is not linked to a backend variant.',
        );
      }

      final row = <String, dynamic>{
        'product_variant_id': productVariantId,
        'quantity': item.quantity,
      };

      if (item.discountPercent > 0) {
        row['discount_percent'] = money(item.discountPercent);
      } else {
        final perUnitReduction = item.originalUnitPrice - item.unitPrice;
        final discountAmount = (perUnitReduction * item.quantity)
            .clamp(0, double.infinity)
            .toDouble();
        if (discountAmount > 0.0001) {
          row['discount_amount'] = money(discountAmount);
        }
      }

      lineItems.add(row);
    }

    final billDiscount = (calculatedFinalAmount - finalAmount)
        .clamp(0, double.infinity)
        .toDouble();

    final paymentMethodValue = switch (paymentMethod) {
      BillingPaymentMethod.cash => 'cash',
      BillingPaymentMethod.card => 'card',
      BillingPaymentMethod.qr => 'qr',
    };

    final paymentStatus = markPaid ? 'paid' : 'unpaid';

    final response = await _apiService.post(
      _url(_createBillPath).toString(),
      body: {
        'customer_name': customer.name,
        'phone': customer.phone,
        'address': customer.address,
        'items': lineItems,
        'bill_discount_amount': money(billDiscount),
        'selected_payment_config_id': paymentMethod == BillingPaymentMethod.qr
            ? selectedQrConfigId
            : null,
        'payment_method': paymentMethodValue,
        'payment_status': paymentStatus,
        'notes': notes,
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return BillingCreateBillResult(
          message: (decoded['message'] ?? 'Bill created successfully.')
              .toString(),
          billId: (decoded['bill_id'] ?? '').toString(),
          billNumber: (decoded['bill_number'] ?? '').toString(),
        );
      }

      return const BillingCreateBillResult(
        message: 'Bill created successfully.',
        billId: '',
        billNumber: '',
      );
    }

    final message = _errorMessageFromResponse(response);
    throw http.ClientException(
      message.isEmpty ? 'Failed to create bill' : message,
    );
  }

  String _errorMessageFromResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      final message = _extractErrorMessage(decoded);
      if (message.isNotEmpty) return message;
    } catch (_) {
      // ignore
    }

    return 'Request failed (${response.statusCode})';
  }

  String _extractErrorMessage(dynamic decoded) {
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);

      const preferredKeys = [
        'error',
        'detail',
        'message',
        'quantity',
        'non_field_errors',
      ];

      for (final key in preferredKeys) {
        final value = map[key];
        if (value == null) continue;
        final message = _extractErrorMessage(value);
        if (message.isNotEmpty) return message;
      }

      for (final value in map.values) {
        final message = _extractErrorMessage(value);
        if (message.isNotEmpty) return message;
      }

      return '';
    }

    if (decoded is List) {
      final messages = decoded
          .map(_extractErrorMessage)
          .where((message) => message.isNotEmpty)
          .toList(growable: false);
      return messages.isEmpty ? '' : messages.join(' ');
    }

    final text = decoded?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null') return '';
    return text;
  }

  Future<BillingBarcodeLookupResult> fetchBarcodeLookup(
    String barcode, {
    List<String> scannedBarcodes = const [],
  }) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) {
      return const BillingBarcodeLookupResult(isMultiple: false, products: []);
    }

    final queryParameters = <String, String>{};
    if (scannedBarcodes.isNotEmpty) {
      queryParameters['scanned_barcodes'] = scannedBarcodes
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .join(', ');
    }

    final uri = _url(
      '$_barcodeLookupPath${Uri.encodeComponent(normalized)}/',
    ).replace(queryParameters: queryParameters);

    final response = await _apiService.get(uri.toString());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _errorMessageFromResponse(response);
      throw http.ClientException(
        message.isEmpty ? 'Failed to fetch products by barcode' : message,
      );
    }

    final decoded = jsonDecode(response.body);
    final isMultiple = _extractIsMultiple(decoded);
    final records = _extractProductRecords(decoded);

    final products = records
        .map(_productFromMap)
        .whereType<BillingProduct>()
        .toList(growable: false);

    return BillingBarcodeLookupResult(
      isMultiple: isMultiple,
      products: products,
    );
  }

  Future<List<BillingProduct>?> searchProductsForBarcode({
    required String barcode,
    required String query,
  }) async {
    final normalizedBarcode = barcode.trim();
    final normalizedQuery = query.trim();

    if (normalizedBarcode.isEmpty || normalizedQuery.isEmpty) {
      return const <BillingProduct>[];
    }

    final uri = _urlWithQuery(_barcodeLookupSearchPath, {
      'barcode': normalizedBarcode,
      'q': normalizedQuery,
    });

    try {
      final response = await _apiService.get(uri.toString());
      if (response.statusCode == 404) {
        // Search endpoint not available yet.
        return null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      final records = _extractProductRecords(decoded);
      return records
          .map(_productFromMap)
          .whereType<BillingProduct>()
          .toList(growable: false);
    } catch (_) {
      // Backend search is optional for now.
      return null;
    }
  }

  Future<List<BillingProduct>> fetchProductsByBarcode(String barcode) async {
    final result = await fetchBarcodeLookup(barcode);
    return result.products;
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

  Future<List<BillingQrConfig>> fetchQrPaymentConfigs() async {
    final response = await _apiService.get(_url(_qrConfigsPath).toString());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _errorMessageFromResponse(response);
      throw http.ClientException(
        message.isEmpty ? 'Failed to fetch QR payment configs' : message,
      );
    }

    final decoded = jsonDecode(response.body);
    final records = _extractQrConfigRecords(decoded);

    return records
        .map(_qrConfigFromMap)
        .whereType<BillingQrConfig>()
        .toList(growable: false);
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
        map['final_price'] ??
        map['unit_price'] ??
        map['sell_price'] ??
        map['price'] ??
        map['mrp'];
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

  bool _extractIsMultiple(dynamic decoded) {
    if (decoded is! Map) return false;
    final map = Map<String, dynamic>.from(decoded);
    final value = map['is_multiple'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    final raw = value?.toString().trim().toLowerCase();
    if (raw == null || raw.isEmpty) return false;
    return raw == 'true' || raw == '1' || raw == 'yes';
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

  List<Map<String, dynamic>> _extractQrConfigRecords(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }

    if (decoded is! Map) return const [];

    final map = Map<String, dynamic>.from(decoded);
    final dynamic listValue = map['results'] ?? map['data'] ?? map['items'];
    if (listValue is List) {
      return listValue
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }

    return [map];
  }

  BillingQrConfig? _qrConfigFromMap(Map<String, dynamic> map) {
    final id = (map['id'] ?? '').toString().trim();
    final name = (map['name'] ?? map['label'] ?? '').toString().trim();
    final imageUrl = (map['image_url'] ?? map['imageUrl'] ?? '')
        .toString()
        .trim();

    if (id.isEmpty || name.isEmpty || imageUrl.isEmpty) {
      return null;
    }

    return BillingQrConfig(id: id, name: name, imageUrl: imageUrl);
  }
}
