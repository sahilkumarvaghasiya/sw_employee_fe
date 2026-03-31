import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock_entry.dart';
import '../models/vendor.dart';
import '../providers/stock_entry_provider.dart';
import 'stock_entry_detail_screen.dart';

class StockEntryHistoryScreen extends StatefulWidget {
  const StockEntryHistoryScreen({super.key, this.vendor});

  final Vendor? vendor;

  static const String routeName = '/stock-entry/history';

  static Route<void> route({Vendor? vendor}) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => StockEntryHistoryScreen(vendor: vendor),
    );
  }

  @override
  State<StockEntryHistoryScreen> createState() =>
      _StockEntryHistoryScreenState();
}

class _StockEntryHistoryScreenState extends State<StockEntryHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent <= 0) return;

      if (position.pixels >= position.maxScrollExtent - 320) {
        context.read<StockEntryProvider>().loadMoreHistory();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final provider = context.watch<StockEntryProvider>();

    final filteredEntries = widget.vendor == null
        ? provider.entries
        : provider.entries
              .where((e) => e.vendor.id == widget.vendor!.id)
              .toList(growable: false);

    final title = widget.vendor == null
        ? 'Stock Entry History'
        : 'History • ${widget.vendor!.name}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: provider.refreshHistory,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            if (provider.isLoadingInitial)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          provider.error!,
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: provider.refreshHistory,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (filteredEntries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    widget.vendor == null
                        ? 'No stock entries yet'
                        : 'No stock entries for this vendor yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                sliver: SliverList.separated(
                  itemCount: filteredEntries.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = filteredEntries[index];
                    return _HistoryRow(
                      entry: entry,
                      money: _money,
                      onTap: () {
                        Navigator.of(
                          context,
                        ).push(StockEntryDetailScreen.route(entry: entry));
                      },
                    );
                  },
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: _PaginationFooter(
                  isLoadingMore: provider.isLoadingMore,
                  hasMore: provider.hasMore,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.money,
    required this.onTap,
  });

  final StockEntry entry;
  final String Function(double) money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final dateLabel = MaterialLocalizations.of(
      context,
    ).formatMediumDate(entry.createdAt);

    final isPaid = entry.payment.status == PaymentStatus.paid;
    final statusColor = isPaid ? colorScheme.tertiary : colorScheme.error;
    final statusText = isPaid ? 'Paid' : 'Pending';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: const Icon(Icons.receipt_long_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.vendor.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateLabel • ${money(entry.payment.totalPayment)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(31),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withAlpha(89)),
                ),
                child: Text(
                  statusText,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({required this.isLoadingMore, required this.hasMore});

  final bool isLoadingMore;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isLoadingMore) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'Loading more…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    if (!hasMore) {
      return Text(
        'You’re all caught up',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
