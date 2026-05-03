import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../auth/services/api_service.dart';
import '../models/product.dart';
import '../models/product_size.dart';
import '../models/product_color.dart';

class ProductsPage {
  const ProductsPage({required this.items, required this.hasMore});

  final List<Product> items;
  final bool hasMore;
}

class ProductsService {
  ProductsService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  static Uri _url(String path, {Map<String, String>? queryParameters}) {
    final base = ApiConfig.baseUrl;
    final normalizedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    final uri = Uri.parse('$normalizedBase$normalizedPath');
    if (queryParameters == null || queryParameters.isEmpty) return uri;
    return uri.replace(queryParameters: queryParameters);
  }

  Future<ProductsPage> fetchProductVariants({
    required int page,
    required int pageSize,
    required Map<String, String> filters,
  }) async {
    final qp = <String, String>{
      ...filters,
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };

    final response = await _apiService.get(
      _url('/products/list/', queryParameters: qp).toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load products (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);

    List<dynamic> list;
    bool hasMore;

    if (decoded is Map<String, dynamic>) {
      if (decoded['results'] is List) {
        list = decoded['results'] as List<dynamic>;
        hasMore = decoded['next'] != null;
      } else if (decoded['data'] is List) {
        list = decoded['data'] as List<dynamic>;
        hasMore = list.length >= pageSize;
      } else if (decoded['items'] is List) {
        list = decoded['items'] as List<dynamic>;
        hasMore = decoded['next'] != null || list.length >= pageSize;
      } else {
        list = const [];
        hasMore = false;
      }
    } else if (decoded is List) {
      list = decoded;
      hasMore = list.length >= pageSize;
    } else {
      list = const [];
      hasMore = false;
    }

    final items = list
        .whereType<Map<String, dynamic>>()
        .map(Product.fromVariantListJson)
        .toList(growable: false);

    return ProductsPage(items: items, hasMore: hasMore);
  }

  Future<Product> fetchProductDetails({required String productId}) async {
    final safeProductId = productId.trim();
    if (safeProductId.isEmpty) {
      throw http.ClientException('Invalid product id');
    }

    final response = await _apiService.get(
      _url('/products/details/$safeProductId').toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load product details (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw http.ClientException('Invalid product details response');
    }

    return Product.fromDetailsJson(decoded);
  }

  Future<List<ProductSize>> fetchSizes() async {
    final response = await _apiService.get(
      _url('/products/sizes/list/').toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load sizes (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);

    List<dynamic> list;
    if (decoded is Map<String, dynamic>) {
      if (decoded['results'] is List) {
        list = decoded['results'] as List<dynamic>;
      } else if (decoded['data'] is List) {
        list = decoded['data'] as List<dynamic>;
      } else if (decoded['items'] is List) {
        list = decoded['items'] as List<dynamic>;
      } else {
        list = const [];
      }
    } else if (decoded is List) {
      list = decoded;
    } else {
      list = const [];
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map(ProductSize.fromJson)
        .where((s) => s.name.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<ProductColor>> fetchColors() async {
    final response = await _apiService.get(
      _url('/products/colors/list/').toString(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to load colors (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);

    List<dynamic> list;
    if (decoded is Map<String, dynamic>) {
      if (decoded['results'] is List) {
        list = decoded['results'] as List<dynamic>;
      } else if (decoded['data'] is List) {
        list = decoded['data'] as List<dynamic>;
      } else if (decoded['items'] is List) {
        list = decoded['items'] as List<dynamic>;
      } else {
        list = const [];
      }
    } else if (decoded is List) {
      list = decoded;
    } else {
      list = const [];
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map(ProductColor.fromJson)
        .where((s) => s.name.isNotEmpty)
        .toList(growable: false);
  }
}
