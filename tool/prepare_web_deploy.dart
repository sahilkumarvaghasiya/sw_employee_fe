import 'dart:convert';
import 'dart:io';

/// Post-process build/web for iOS PWA recovery:
/// replace Flutter SW with cleanup worker, strip SW registration, stamp version.
void main(List<String> args) {
  final root = Directory.current;
  final webOut = Directory.fromUri(root.uri.resolve('build/web/'));
  final cleanupSw = File.fromUri(root.uri.resolve('web/sw_cleanup.js'));

  if (!webOut.existsSync()) {
    stderr.writeln('Missing ${webOut.path}. Run flutter build web first.');
    exitCode = 1;
    return;
  }
  if (!cleanupSw.existsSync()) {
    stderr.writeln('Missing ${cleanupSw.path}.');
    exitCode = 1;
    return;
  }

  final buildId = Platform.environment['BUILD_ID'] ?? 'local';
  final buildNumber = Platform.environment['BUILD_NUMBER'] ?? '0';

  File.fromUri(webOut.uri.resolve('flutter_service_worker.js'))
      .writeAsStringSync(cleanupSw.readAsStringSync());

  final bootstrap = File.fromUri(webOut.uri.resolve('flutter_bootstrap.js'));
  if (bootstrap.existsSync()) {
    final original = bootstrap.readAsStringSync();
    final sanitized = original.replaceAll(
      RegExp(r'serviceWorker\s*:\s*\{[^{}]*\}\s*,?', multiLine: true),
      '',
    );
    if (sanitized != original) {
      bootstrap.writeAsStringSync(sanitized);
    }
    if (RegExp(r'serviceWorker\s*:').hasMatch(sanitized)) {
      stderr.writeln(
        'ERROR: flutter_bootstrap.js still registers a service worker.',
      );
      exitCode = 1;
      return;
    }
  }

  final versionFile = File.fromUri(webOut.uri.resolve('version.json'));
  if (versionFile.existsSync()) {
    final data =
        jsonDecode(versionFile.readAsStringSync()) as Map<String, dynamic>;
    data['build_id'] = buildId;
    data['build_number'] =
        (data['build_number'] ?? buildNumber).toString();
    versionFile.writeAsStringSync(jsonEncode(data));
  }

  stdout.writeln('Prepared web deploy artifacts in ${webOut.path}');
}
