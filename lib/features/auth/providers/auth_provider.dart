import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final TokenStorage _tokenStorage = TokenStorage();

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  String _employeeName = 'Employee';
  String get employeeName => _employeeName;

  String _branchName = 'Main Branch';
  String get branchName => _branchName;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadToken() async {
    final token = await _tokenStorage.getAccessToken();
    _isAuthenticated = token != null;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // DEV ONLY: Allow a quick preview of the app without a backend.
    // This will not run in release builds.
    if (kDebugMode) {
      final normalizedEmail = email.trim().toLowerCase();
      final normalizedPassword = password.trim();
      if (normalizedEmail == 'demo@retailagent.com' &&
          normalizedPassword == 'demo123') {
        _employeeName = 'Demo Employee';
        _branchName = 'Demo Branch';
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return;
      }
    }

    try {
      final tokens = await _authService.login(email, password);
      await _tokenStorage.saveTokens(tokens['access']!, tokens['refresh']!);
      _isAuthenticated = true;

      final localPart = email.trim().split('@').first;
      _employeeName = localPart.isEmpty ? 'Employee' : localPart;

      // Placeholder until branch details are fetched from the backend.
      _branchName = 'Main Branch';
    } catch (e) {
      _errorMessage = 'Invalid email or password';
      _isAuthenticated = false;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _tokenStorage.deleteTokens();
    _isAuthenticated = false;
    _employeeName = 'Employee';
    _branchName = 'Main Branch';
    notifyListeners();
  }

  void setBranchName(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty || normalized == _branchName) return;
    _branchName = normalized;
    notifyListeners();
  }

  Future<void> changePassword({required String newPassword}) async {
    final normalized = newPassword.trim();
    if (normalized.isEmpty) {
      throw Exception('Password cannot be empty');
    }

    // DEV ONLY: allow UX testing without backend.
    if (kDebugMode) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      return;
    }

    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null) {
      throw Exception('Not authenticated');
    }

    await _authService.changePassword(
      accessToken: accessToken,
      newPassword: normalized,
    );
  }
}
