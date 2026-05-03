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
      _isAuthenticated = true;
      _employeeName = (await _tokenStorage.getUserName())?.trim() ?? '';
      _branchName = (await _tokenStorage.getShopName())?.trim() ?? '';

      if (_employeeName.isEmpty || _branchName.isEmpty) {
        try {
          final userInfo = await _authService.fetchUserInfo();
          await _applyUserInfoMap(userInfo);
        } catch (_) {
          // Keep session; home screen refresh will retry userinfo.
        }
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

  Future<void> _applyUserInfoMap(Map<String, dynamic> userInfo) async {
    final userName = userInfo['user_name']?.toString().trim() ?? '';
    final shopName = userInfo['shop_name']?.toString().trim() ?? '';

    if (userName.isNotEmpty) {
      _employeeName = userName;
    }
    if (shopName.isNotEmpty) {
      _branchName = shopName;
    }

    await _tokenStorage.saveUserContext(
      userName: userName.isNotEmpty ? userName : _employeeName,
      shopName: shopName.isNotEmpty ? shopName : _branchName,
    );
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

      Map<String, dynamic> userInfo;
      try {
        userInfo = await _authService.fetchUserInfo();
      } catch (e) {
        await _tokenStorage.deleteTokens();
        rethrow;
      }

      await _applyUserInfoMap(userInfo);
      _isAuthenticated = true;
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
    await _authService.logoutRemote();
    await _tokenStorage.deleteTokens();
    _isAuthenticated = false;
    _employeeName = '';
    _branchName = '';
    notifyListeners();
  }

  Future<void> refreshUserInfo() async {
    if (!_isAuthenticated) return;

    try {
      final userInfo = await _authService.fetchUserInfo();
      await _applyUserInfoMap(userInfo);
      notifyListeners();
    } catch (_) {
      // Ignore errors to avoid blocking the home UI.
    }
  }

  void setBranchName(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty || normalized == _branchName) return;
    _branchName = normalized;
    notifyListeners();
  }

  Future<String> changePassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    final n = newPassword.trim();
    final c = confirmPassword.trim();
    if (n.isEmpty) {
      throw Exception('Password cannot be empty');
    }
    if (n != c) {
      throw Exception('Passwords do not match');
    }

    return _authService.changePassword(
      newPassword: n,
      confirmPassword: c,
    );
  }
}
