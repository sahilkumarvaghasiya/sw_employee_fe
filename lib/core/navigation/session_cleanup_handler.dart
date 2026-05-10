import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/services/session_notifier.dart';
import '../../features/home/providers/home_dashboard_provider.dart';
import '../../features/stock_alerts/providers/stock_alerts_provider.dart';
import '../../features/stock_entry/providers/stock_entry_provider.dart';

class SessionCleanupHandler extends StatefulWidget {
  const SessionCleanupHandler({super.key, required this.child});

  final Widget child;

  @override
  State<SessionCleanupHandler> createState() => _SessionCleanupHandlerState();
}

class _SessionCleanupHandlerState extends State<SessionCleanupHandler> {
  @override
  void initState() {
    super.initState();
    SessionNotifier.registerLogout(_handleLogout);
  }

  @override
  void dispose() {
    SessionNotifier.unregisterLogout(_handleLogout);
    super.dispose();
  }

  Future<void> _handleLogout(String? _) async {
    if (!mounted) return;
    context.read<HomeDashboardProvider>().reset();
    context.read<StockEntryProvider>().reset();
    context.read<StockAlertsProvider>().reset();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
