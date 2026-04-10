import 'package:flutter/foundation.dart';

import '../../../core/config/api_config.dart';
import '../models/stock_alert.dart';
import '../services/stock_alerts_service.dart';

class StockAlertsProvider extends ChangeNotifier {
  StockAlertsProvider({StockAlertsService? service})
    : _service = service ?? StockAlertsService();

  final StockAlertsService _service;

  bool _requestedUnseenCount = false;

  int _unseenCount = 0;
  int get unseenCount => _unseenCount;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<StockAlert> _alerts = const [];
  List<StockAlert> get alerts => _alerts;

  Future<void> loadUnseenCountIfNeeded() async {
    if (_requestedUnseenCount) return;
    _requestedUnseenCount = true;
    Future<void>.microtask(fetchUnseenCount);
  }

  Future<void> fetchUnseenCount() async {
    try {
      final count = await _service.fetchUnseenCount();
      final normalized = count < 0 ? 0 : count;
      if (_unseenCount == normalized && _error == null) return;

      _unseenCount = normalized;
      _error = null;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        if (ApiConfig.baseUrl.contains('your-backend.com')) {
          final demoCount = _alerts.where((a) => !a.isSeen).length;
          final normalized = demoCount <= 0 ? 2 : demoCount;
          if (_unseenCount != normalized) {
            _unseenCount = normalized;
            notifyListeners();
          }
        }
        return;
      }
      if (_error == 'Failed to fetch alerts count') return;
      _error = 'Failed to fetch alerts count';
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _service.fetchAlerts();
      _alerts = results;

      final count = await _service.fetchUnseenCount();
      _unseenCount = count < 0 ? 0 : count;
    } catch (e) {
      if (kDebugMode) {
        final now = DateTime.now();
        _alerts = [
          StockAlert(
            id: 'a_1',
            title: 'Low stock: Sugar 1kg',
            message: 'Only 3 units left. Consider restocking today.',
            createdAt: now.subtract(const Duration(minutes: 25)),
            isSeen: false,
            severity: StockAlertSeverity.warning,
          ),
          StockAlert(
            id: 'a_2',
            title: 'Out of stock: Tea 500g',
            message:
                'This item is out of stock. Add stock entry to continue sales.',
            createdAt: now.subtract(const Duration(hours: 3, minutes: 10)),
            isSeen: true,
            severity: StockAlertSeverity.critical,
          ),
        ];
        _unseenCount = _alerts.where((a) => !a.isSeen).length;
      } else {
        _error = 'Failed to load stock alerts';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> openInbox() async {
    await refresh();
    await markAllSeen();
  }

  Future<void> markAllSeen() async {
    if (_unseenCount == 0 && _alerts.every((a) => a.isSeen)) return;

    try {
      await _service.markAllSeen();

      _alerts = _alerts
          .map((a) => a.isSeen ? a : a.copyWith(isSeen: true))
          .toList(growable: false);
      _unseenCount = 0;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        _alerts = _alerts
            .map((a) => a.isSeen ? a : a.copyWith(isSeen: true))
            .toList(growable: false);
        _unseenCount = 0;
        notifyListeners();
        return;
      }
      _error = 'Failed to mark alerts as seen';
      notifyListeners();
    }
  }
}
