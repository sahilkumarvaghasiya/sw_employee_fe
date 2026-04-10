import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/stock_alerts_provider.dart';
import '../models/stock_alert.dart';

class StockAlertsScreen extends StatefulWidget {
  const StockAlertsScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const StockAlertsScreen());
  }

  @override
  State<StockAlertsScreen> createState() => _StockAlertsScreenState();
}

class _StockAlertsScreenState extends State<StockAlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<StockAlertsProvider>().openInbox();
    });
  }

  Color _severityColor(ColorScheme scheme, StockAlertSeverity severity) {
    switch (severity) {
      case StockAlertSeverity.critical:
        return scheme.error;
      case StockAlertSeverity.warning:
        return scheme.tertiary;
      case StockAlertSeverity.info:
        return scheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock alerts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => context.read<StockAlertsProvider>().refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Consumer<StockAlertsProvider>(
        builder: (context, provider, _) {
          final alerts = provider.alerts;

          if (provider.isLoading && alerts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && alerts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  provider.error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }

          if (alerts.isEmpty) {
            return Center(
              child: Text(
                'No stock alerts',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<StockAlertsProvider>().refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final alert = alerts[index];
                final color = _severityColor(scheme, alert.severity);

                return Card(
                  elevation: 0,
                  color: scheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide.none,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.inventory_2_outlined, color: color),
                    ),
                    title: Text(
                      alert.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        alert.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    trailing: alert.isSeen
                        ? null
                        : Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
