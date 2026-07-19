import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../models/vendor_bill.dart';
import '../providers/vendors_provider.dart';
import '../widgets/vendors_ui.dart';

class VendorReportScreen extends StatefulWidget {
  const VendorReportScreen({super.key});

  static const String routeName = '/vendors/report';

  static Route<void> route({required VendorsProvider provider}) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const VendorReportScreen(),
      ),
    );
  }

  @override
  State<VendorReportScreen> createState() => _VendorReportScreenState();
}

class _VendorReportScreenState extends State<VendorReportScreen> {
  DateTimeRange? _dateRange;
  VendorReportPreview? _preview;
  bool _isLoadingPreview = false;
  bool _isSharingPdf = false;
  String? _error;
  static final DateFormat _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreview();
    });
  }

  String _dateLabel() {
    final range = _dateRange;
    if (range == null) return 'All dates';
    return '${_dateFmt.format(range.start)} – ${_dateFmt.format(range.end)}';
  }

  Future<void> _openDatePickerAndApply() async {
    DateTime? start = _dateRange?.start;
    DateTime? end = _dateRange?.end;

    final result = await showDialog<_ReportDateResult>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Report period'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> pickStart() async {
                final now = DateTime.now();
                final selected = await showDatePicker(
                  context: context,
                  initialDate: start ?? now,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(now.year + 1),
                );
                if (selected == null) return;
                setDialogState(() {
                  start = selected;
                  if (end != null && end!.isBefore(selected)) {
                    end = selected;
                  }
                });
              }

              Future<void> pickEnd() async {
                final now = DateTime.now();
                final selected = await showDatePicker(
                  context: context,
                  initialDate: end ?? start ?? now,
                  firstDate: start ?? DateTime(2020),
                  lastDate: DateTime(now.year + 1),
                );
                if (selected == null) return;
                setDialogState(() => end = selected);
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start'),
                    subtitle: Text(
                      start == null ? 'Select' : _dateFmt.format(start!),
                    ),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: pickStart,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End'),
                    subtitle: Text(
                      end == null ? 'Select' : _dateFmt.format(end!),
                    ),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: pickEnd,
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(const _ReportDateCleared());
              },
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () {
                if (start == null || end == null) {
                  Navigator.of(dialogContext).pop(const _ReportDateCleared());
                  return;
                }
                Navigator.of(dialogContext).pop(
                  _ReportDateApplied(DateTimeRange(start: start!, end: end!)),
                );
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) return;

    if (result is _ReportDateCleared) {
      setState(() => _dateRange = null);
    } else if (result is _ReportDateApplied) {
      setState(() => _dateRange = result.range);
    }
    await _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoadingPreview = true;
      _error = null;
    });

    try {
      final preview = await context.read<VendorsProvider>().fetchReportPreview(
            startDate: _dateRange?.start,
            endDate: _dateRange?.end,
          );
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load report preview');
    } finally {
      if (mounted) setState(() => _isLoadingPreview = false);
    }
  }

  Future<void> _sharePdf() async {
    setState(() => _isSharingPdf = true);
    try {
      final bytes = await context.read<VendorsProvider>().fetchReportPdf(
            startDate: _dateRange?.start,
            endDate: _dateRange?.end,
          );
      if (!mounted) return;

      final filename = () {
        final range = _dateRange;
        if (range == null) return 'vendor-report.pdf';
        final start =
            DateFormat('yyyyMMdd').format(range.start);
        final end = DateFormat('yyyyMMdd').format(range.end);
        return 'vendor-report-$start-$end.pdf';
      }();

      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: filename,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to download report PDF')),
      );
    } finally {
      if (mounted) setState(() => _isSharingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final preview = _preview;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Vendor report'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Period',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openDatePickerAndApply,
            icon: const Icon(Icons.date_range_outlined, size: 18),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(_dateLabel(), overflow: TextOverflow.ellipsis),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_isLoadingPreview)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            AppSurfaceCard(
              child: Column(
                children: [
                  Text(
                    _error!,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loadPreview,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (preview != null) ...[
            Text(
              'Preview',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            AppSurfaceCard(
              child: Column(
                children: [
                  _PreviewRow(label: 'Bills', value: '${preview.bills}'),
                  const Divider(height: 20),
                  _PreviewMoneyRow(
                    label: 'Total billed',
                    amount: preview.totalBilledDisplay,
                  ),
                  const Divider(height: 20),
                  _PreviewMoneyRow(
                    label: 'Total paid',
                    amount: preview.totalPaidDisplay,
                  ),
                  const Divider(height: 20),
                  _PreviewMoneyRow(
                    label: 'Total pending',
                    amount: preview.totalPendingDisplay,
                    emphasize: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSharingPdf ? null : _sharePdf,
              icon: _isSharingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.share_rounded),
              label: Text(
                _isSharingPdf ? 'Preparing PDF…' : 'Download / Share PDF',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.homeAccentRose,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

abstract class _ReportDateResult {
  const _ReportDateResult();
}

class _ReportDateApplied extends _ReportDateResult {
  const _ReportDateApplied(this.range);

  final DateTimeRange range;
}

class _ReportDateCleared extends _ReportDateResult {
  const _ReportDateCleared();
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    // ignore: unused_element_parameter
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: emphasize ? const Color(0xFFBE185D) : null,
          ),
        ),
      ],
    );
  }
}

class _PreviewMoneyRow extends StatelessWidget {
  const _PreviewMoneyRow({
    required this.label,
    required this.amount,
    this.emphasize = false,
  });

  final String label;
  final String amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        InrAmountText(
          amount,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: emphasize ? const Color(0xFFBE185D) : null,
          ),
        ),
      ],
    );
  }
}
