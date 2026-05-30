import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/providers/auth_provider.dart';

class AppLifecycleManager extends StatefulWidget {
  const AppLifecycleManager({super.key, required this.child});

  final Widget child;

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    final authProvider = context.read<AuthProvider>();
    if (authProvider.isAuthenticated) {
      authProvider.refreshUserInfo();
    } else if (!authProvider.hasPendingForceLogin) {
      authProvider.loadToken();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
