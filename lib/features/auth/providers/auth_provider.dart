import 'package:flutter/material.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../../core/network/http_client_manager.dart';
import '../services/auth_service.dart';
import '../services/session_notifier.dart';
import '../services/token_storage.dart';

enum LoginOutcome {
  success,
  forceLoginRequired,
  blocked,
  failure,
}

class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    SessionNotifier.register(_handleSessionExpired);
  }

  @override
  void dispose() {
    SessionNotifier.unregister(_handleSessionExpired);
    super.dispose();
  }

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

  bool _isBlocked = false;
  bool get isBlocked => _isBlocked;

  String? _forceLoginMessage;
  String? get forceLoginMessage => _forceLoginMessage;

  int? _remainingAttempts;
  int? get remainingAttempts => _remainingAttempts;

  String? _sessionMessage;
  String? get sessionMessage => _sessionMessage;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadToken() async {
    _isLoading = true;
    _errorMessage = null;
    _forceLoginMessage = null;
  _remainingAttempts = null;
    _sessionMessage = null;
    _isBlocked = false;
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

  Future<void> _handleSessionExpired(String message) async {
    await logoutUser(reason: message, showMessage: true);
  }

  void clearSessionMessage() {
    if (_sessionMessage == null) return;
    _sessionMessage = null;
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

  Future<LoginOutcome> login(
    String email,
    String password, {
    bool forceLogin = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _forceLoginMessage = null;
    _sessionMessage = null;
    _isBlocked = false;
    notifyListeners();

    try {
      final loginData =
          await _authService.login(email, password, forceLogin: forceLogin);

      if (loginData['requires_force_login'] == true) {
        _forceLoginMessage =
            loginData['message']?.toString() ??
            'You are already logged in on another device.';
        final attemptsValue = loginData['remaining_attempts'];
        if (attemptsValue is int) {
          _remainingAttempts = attemptsValue;
        } else if (attemptsValue != null) {
          _remainingAttempts = int.tryParse(attemptsValue.toString());
        }
        _isLoading = false;
        notifyListeners();
        return LoginOutcome.forceLoginRequired;
      }

      await _tokenStorage.saveTokens(
        loginData['access']!.toString(),
        loginData['refresh']!.toString(),
        tokenVersion: loginData['token_version']?.toString(),
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
      _isBlocked = false;
      _forceLoginMessage = null;
    _remainingAttempts = null;
      _sessionMessage = null;
      _isLoading = false;
      notifyListeners();
    await AppNavigator.pushToHome();
      return LoginOutcome.success;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      _errorMessage = message;
      _isAuthenticated = false;
      _employeeName = '';
      _branchName = '';
  _remainingAttempts = null;
      if (message.contains('Account blocked') ||
          message.contains('blocked due to multiple')) {
        _isBlocked = true;
        _isLoading = false;
        notifyListeners();
        return LoginOutcome.blocked;
      }
      _isLoading = false;
      notifyListeners();
      return LoginOutcome.failure;
    }
  }

  Future<void> logout() async {
    await logoutUser(showMessage: false);
  }

  Future<void> logoutUser({String? reason, bool showMessage = true}) async {
    await _authService.logoutRemote();
    await _tokenStorage.deleteTokens();
    HttpClientManager.reset();
    _isAuthenticated = false;
    _employeeName = '';
    _branchName = '';
    _sessionMessage = showMessage ? reason : null;
    _forceLoginMessage = null;
    _errorMessage = null;
    _isBlocked = false;
    notifyListeners();

    await SessionNotifier.notifyLogout(reason);

    await AppNavigator.pushToLogin();
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
