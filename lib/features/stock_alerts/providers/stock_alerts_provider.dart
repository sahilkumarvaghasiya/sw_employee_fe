import 'package:flutter/foundation.dart';

import '../models/stock_alert.dart';
import '../services/stock_alerts_service.dart';

class StockAlertsProvider extends ChangeNotifier {
  StockAlertsProvider({StockAlertsService? service})
    : _service = service ?? StockAlertsService();

  final StockAlertsService _service;

  int _unseenCount = 0;
  int get unseenCount => _unseenCount;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<StockAlert> _alerts = const [];
  List<StockAlert> get alerts => _alerts;

  /// Lightweight sync when the home dashboard refreshes (no loading spinner).
  Future<void> refreshForHome() async {
    try {
      final result = await _service.fetchNotificationsList();
      _alerts = result.notifications;
      // Sort notifications by priority: critical (high) first, then warning (medium), then info (low)
      _alerts = List.of(_alerts)
        ..sort((a, b) {
          int rank(StockAlertSeverity severity) {
            switch (severity) {
              case StockAlertSeverity.critical:
                return 0;
              case StockAlertSeverity.warning:
                return 1;
              case StockAlertSeverity.info:
                return 2;
            }
          }

          final rA = rank(a.severity);
          final rB = rank(b.severity);
          if (rA != rB) return rA - rB;
          // Newer first for same priority
          return b.createdAt.compareTo(a.createdAt);
        });
      _unseenCount = result.totalUnseen < 0 ? 0 : result.totalUnseen;
      _error = null;
      notifyListeners();
    } catch (e) {
      // Remove demo-only fallback. Surface the error so UI can show it.
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
      final result = await _service.fetchNotificationsList();
      _alerts = result.notifications;
      // Sort by priority (high -> medium -> low) and newest first within same priority
      _alerts = List.of(_alerts)
        ..sort((a, b) {
          int rank(StockAlertSeverity severity) {
            switch (severity) {
              case StockAlertSeverity.critical:
                return 0;
              case StockAlertSeverity.warning:
                return 1;
              case StockAlertSeverity.info:
                return 2;
            }
          }

          final rA = rank(a.severity);
          final rB = rank(b.severity);
          if (rA != rB) return rA - rB;
          return b.createdAt.compareTo(a.createdAt);
        });
      _unseenCount = result.totalUnseen < 0 ? 0 : result.totalUnseen;
    } catch (e) {
      // Remove debug/demo fallback; report error so UI can display it
      _error = 'Failed to load stock alerts';
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
