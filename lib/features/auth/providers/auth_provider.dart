import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final TokenStorage _tokenStorage = TokenStorage();

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

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
    try {
      final tokens = await _authService.login(email, password);
      await _tokenStorage.saveTokens(tokens['access']!, tokens['refresh']!);
      _isAuthenticated = true;
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
    notifyListeners();
  }
}
