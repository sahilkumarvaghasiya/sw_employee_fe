import 'package:flutter/foundation.dart';

import '../models/home_dashboard_data.dart';
import '../services/home_dashboard_service.dart';

class HomeDashboardProvider extends ChangeNotifier {
  HomeDashboardProvider({HomeDashboardService? service})
    : _service = service ?? HomeDashboardService();

  final HomeDashboardService _service;

  bool _isLoading = false;
  String? _error;
  HomeDashboardData? _data;

  bool get isLoading => _isLoading;
  String? get error => _error;
  HomeDashboardData? get data => _data;

  Future<void> refresh() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _data = await _service.fetchTodaySummary();
    } catch (_) {
      _error = 'Failed to load today summary';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
