typedef SessionExpiredCallback = Future<void> Function(String message);

class SessionNotifier {
  static SessionExpiredCallback? _onSessionExpired;

  static void register(SessionExpiredCallback callback) {
    _onSessionExpired = callback;
  }

  static void clear() {
    _onSessionExpired = null;
  }

  static Future<void> notifySessionExpired(String message) async {
    final callback = _onSessionExpired;
    if (callback != null) {
      await callback(message);
    }
  }
}
