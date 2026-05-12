typedef SessionExpiredCallback = Future<void> Function(String message);
typedef SessionLogoutCallback = Future<void> Function(String? reason);

class SessionNotifier {
  static final List<SessionExpiredCallback> _onSessionExpired = [];
  static final List<SessionLogoutCallback> _onSessionLogout = [];
  static String? _lastSessionMessage;
  static DateTime? _lastSessionMessageAt;

  static const Duration _dedupeWindow = Duration(seconds: 2);

  static void register(SessionExpiredCallback callback) {
    _onSessionExpired.add(callback);
  }

  static void unregister(SessionExpiredCallback callback) {
    _onSessionExpired.remove(callback);
  }

  static void registerLogout(SessionLogoutCallback callback) {
    _onSessionLogout.add(callback);
  }

  static void unregisterLogout(SessionLogoutCallback callback) {
    _onSessionLogout.remove(callback);
  }

  static void clear() {
    _onSessionExpired.clear();
    _onSessionLogout.clear();
    _lastSessionMessage = null;
    _lastSessionMessageAt = null;
  }

  static Future<void> notifySessionExpired(String message) async {
    final now = DateTime.now();
    if (_lastSessionMessage == message &&
        _lastSessionMessageAt != null &&
        now.difference(_lastSessionMessageAt!) <= _dedupeWindow) {
      return;
    }
    _lastSessionMessage = message;
    _lastSessionMessageAt = now;
    for (final callback in List<SessionExpiredCallback>.from(_onSessionExpired)) {
      await callback(message);
    }
  }

  static Future<void> notifyLogout(String? reason) async {
    for (final callback in List<SessionLogoutCallback>.from(_onSessionLogout)) {
      await callback(reason);
    }
  }
}
