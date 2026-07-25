import 'dart:convert';
import 'dart:io';

/// Post-process `build/web` so stale iOS PWAs can recover after deploys.
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

  // Replace Flutter's generated worker with an enhanced cleanup worker so any
  // previously installed offline-first service worker migrates cleanly.
  final targetSw = File.fromUri(webOut.uri.resolve('flutter_service_worker.js'));
  cleanupSw.copySync(targetSw.path);

  final buildId = Platform.environment['BUILD_ID'] ?? 'local';
  final buildNumber = Platform.environment['BUILD_NUMBER'] ?? '0';
  final versionFile = File.fromUri(webOut.uri.resolve('version.json'));
  if (versionFile.existsSync()) {
    final data =
        jsonDecode(versionFile.readAsStringSync()) as Map<String, dynamic>;
    data['build_id'] = buildId;
    data['build_number'] =
        (data['build_number'] ?? buildNumber).toString();
    versionFile.writeAsStringSync(jsonEncode(data));
    stdout.writeln('Stamped version.json build_id=$buildId');
  }

  stdout.writeln('Prepared web deploy artifacts in ${webOut.path}');
}
