import 'dart:convert';
import 'dart:html' as html;

/// Build identity stamped at compile time via `--dart-define=BUILD_ID=...`.
const String _localBuildId = String.fromEnvironment(
  'BUILD_ID',
  defaultValue: 'local',
);

/// Compares the running build against hosted `version.json`.
/// When a newer deploy is detected, clears SW/caches and hard-reloads.
Future<void> checkForWebAppUpdate() async {
  if (_localBuildId == 'local') return;

  try {
    final uri = Uri.parse('version.json').replace(
      queryParameters: <String, String>{
        '_': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    final response = await html.HttpRequest.request(
      uri.toString(),
      method: 'GET',
      requestHeaders: <String, String>{
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );
    if (response.status != 200 || response.responseText == null) return;

    final decoded = jsonDecode(response.responseText!) as Map<String, dynamic>;
    final remoteBuildId = decoded['build_id']?.toString();
    if (remoteBuildId == null ||
        remoteBuildId.isEmpty ||
        remoteBuildId == 'local' ||
        remoteBuildId == _localBuildId) {
      return;
    }

    await _forceReload();
  } catch (_) {
    // Ignore update-check failures; login/API errors are handled elsewhere.
  }
}

Future<void> _forceReload() async {
  try {
    if (html.window.caches != null) {
      final keys = await html.window.caches!.keys();
      await Future.wait(keys.map(html.window.caches!.delete));
    }
  } catch (_) {}

  try {
    final registrations =
        await html.window.navigator.serviceWorker?.getRegistrations() ??
            <html.ServiceWorkerRegistration>[];
    await Future.wait(
      registrations.map((registration) => registration.unregister()),
    );
  } catch (_) {}

  final current = Uri.parse(html.window.location.href);
  final url = current.replace(
    queryParameters: <String, String>{
      ...current.queryParameters,
      '_reload': DateTime.now().millisecondsSinceEpoch.toString(),
    },
  );
  html.window.location.replace(url.toString());
}
