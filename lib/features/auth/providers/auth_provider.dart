import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final TokenStorage _tokenStorage = TokenStorage();

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  String _employeeName = '';
  String get employeeName => _employeeName;

  String _branchName = '';
  String get branchName => _branchName;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadToken() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final restored = await _authService.restoreSession();
    if (restored) {
      final savedUserName = (await _tokenStorage.getUserName())?.trim() ?? '';
      final savedShopName = (await _tokenStorage.getShopName())?.trim() ?? '';

      if (savedUserName.isNotEmpty && savedShopName.isNotEmpty) {
        _isAuthenticated = true;
        _employeeName = savedUserName;
        _branchName = savedShopName;
      } else {
        await _tokenStorage.deleteTokens();
        _isAuthenticated = false;
        _employeeName = '';
        _branchName = '';
      }
    } else {
      await _tokenStorage.deleteTokens();
      _isAuthenticated = false;
      _employeeName = '';
      _branchName = '';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loginData = await _authService.login(email, password);
      await _tokenStorage.saveTokens(
        loginData['access']!.toString(),
        loginData['refresh']!.toString(),
      );

      final userName = loginData['user_name']?.toString().trim() ?? '';
      final shopName = loginData['shop_name']?.toString().trim() ?? '';
      if (userName.isEmpty || shopName.isEmpty) {
        throw Exception('Login response missing user_name or shop_name');
      }

      await _tokenStorage.saveUserContext(
        userName: userName,
        shopName: shopName,
      );

      _isAuthenticated = true;
      _employeeName = userName;
      _branchName = shopName;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isAuthenticated = false;
      _employeeName = '';
      _branchName = '';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _tokenStorage.deleteTokens();
    _isAuthenticated = false;
    _employeeName = '';
    _branchName = '';
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

    await _authService.changePassword(
      newPassword: normalized,
    );
  }
}
