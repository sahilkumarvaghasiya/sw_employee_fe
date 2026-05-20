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

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _displayDateFallback(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    if (date == today) return 'Today';
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == yesterday) return 'Yesterday';
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
  }

  Future<void> _onRefresh() {
    return context.read<StockAlertsProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Stock alerts')),
      body: Consumer<StockAlertsProvider>(
        builder: (context, provider, _) {
          final alerts = provider.alerts;

          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (provider.isLoading && alerts.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (provider.error != null && alerts.isEmpty)
                  SliverFillRemaining(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          provider.error!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (alerts.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'No stock alerts',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index.isOdd) {
                          return const SizedBox(height: 10);
                        }
                        final alertIndex = index ~/ 2;
                        final alert = alerts[alertIndex];
                        final color = _severityColor(scheme, alert.severity);

                        // Tint the row lightly according to severity to make high-priority
                        // notifications stand out while preserving the surface look.
                        final rowColor = Color.alphaBlend(
                          color.withOpacity(0.08),
                          scheme.surface,
                        );

                        return Card(
                          elevation: 0,
                          color: rowColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide.none,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.inventory_2_outlined,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Title + message expanded
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  alert.typeDisplay,
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            alert.message,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Unseen dot
                                    alert.isSeen
                                        ? const SizedBox(width: 10)
                                        : Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: scheme.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Bottom row with display_date and display_time (API-provided preferred)
                                Row(
                                  children: [
                                    const Spacer(),
                                    Text(
                                      '${alert.displayDate ?? _displayDateFallback(alert.createdAt)} ${alert.displayTime ?? _formatTime(alert.createdAt)}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }, childCount: alerts.isEmpty ? 0 : alerts.length * 2 - 1),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
