import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'web_app_updater_stub.dart'
    if (dart.library.html) 'web_app_updater_web.dart' as impl;

/// On web, periodically checks `version.json` and force-reloads when a newer
/// deploy is available. No-op on mobile/desktop.
class WebAppUpdateListener extends StatefulWidget {
  const WebAppUpdateListener({super.key, required this.child});

  final Widget child;

  @override
  State<WebAppUpdateListener> createState() => _WebAppUpdateListenerState();
}

class _WebAppUpdateListenerState extends State<WebAppUpdateListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        impl.checkForWebAppUpdate();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb && state == AppLifecycleState.resumed) {
      impl.checkForWebAppUpdate();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
