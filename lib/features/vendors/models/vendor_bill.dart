double? parseIndianAmount(String? raw) {
  if (raw == null) return null;
  final normalized = raw.replaceAll(RegExp(r'[₹\s,]'), '').trim();
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

class VendorDueInfo {
  const VendorDueInfo({
    required this.label,
    required this.state,
    this.days,
  });

  final String label;
  final String state;
  final int? days;

  factory VendorDueInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const VendorDueInfo(label: 'No due date', state: 'none');
    }
    final daysRaw = json['days'];
    int? days;
    if (daysRaw is int) {
      days = daysRaw;
    } else if (daysRaw != null) {
      days = int.tryParse(daysRaw.toString());
    }
    return VendorDueInfo(
      label: (json['label'] ?? 'No due date').toString(),
      state: (json['state'] ?? 'none').toString().toLowerCase(),
      days: days,
    );
  }

  bool get isOverdue => state == 'overdue';
  bool get isPaid => state == 'paid';
  bool get isDueSoon => state == 'due';
}

class VendorStockLine {
  const VendorStockLine({
    this.itemType,
    this.brand,
    required this.qty,
  });

  final String? itemType;
  final String? brand;
  final int qty;

  factory VendorStockLine.fromJson(Map<String, dynamic> json) {
    final qtyRaw = json['qty'];
    final qty = qtyRaw is int
        ? qtyRaw
        : int.tryParse(qtyRaw?.toString() ?? '') ?? 0;
    return VendorStockLine(
      itemType: json['item_type']?.toString(),
      brand: json['brand']?.toString(),
      qty: qty,
    );
  }
}

class VendorBill {
  const VendorBill({
    required this.id,
    required this.vendor,
    required this.stkNo,
    required this.billDate,
    required this.totalDisplay,
    required this.paidDisplay,
    required this.pendingDisplay,
    required this.statusDisplay,
    required this.due,
    required this.stockLines,
  });

  final int id;
  final String vendor;
  final String stkNo;
  final String billDate;
  final String totalDisplay;
  final String paidDisplay;
  final String pendingDisplay;
  final String statusDisplay;
  final VendorDueInfo due;
  final List<VendorStockLine> stockLines;

  double get pendingAmount => parseIndianAmount(pendingDisplay) ?? 0;
  double get totalAmount => parseIndianAmount(totalDisplay) ?? 0;
  double get paidAmount => parseIndianAmount(paidDisplay) ?? 0;

  bool get isFullyPaid {
    final status = statusDisplay.toLowerCase();
    return due.isPaid || status == 'paid' || pendingAmount <= 0;
  }

  String get statusKey {
    final lower = statusDisplay.toLowerCase();
    if (lower.contains('partial')) return 'partial';
    if (lower.contains('unpaid')) return 'unpaid';
    if (lower == 'paid' || lower.contains('paid')) return 'paid';
    return lower;
  }

  factory VendorBill.fromJson(Map<String, dynamic> json) {
    final linesRaw = json['stock_lines'];
    final lines = <VendorStockLine>[];
    if (linesRaw is List) {
      for (final item in linesRaw) {
        if (item is Map) {
          lines.add(
            VendorStockLine.fromJson(item.cast<String, dynamic>()),
          );
        }
      }
    }

    final dueRaw = json['due'];
    Map<String, dynamic>? dueMap;
    if (dueRaw is Map) {
      dueMap = dueRaw.cast<String, dynamic>();
    }

    final idRaw = json['id'];
    final id = idRaw is int
        ? idRaw
        : int.tryParse(idRaw?.toString() ?? '') ?? 0;

    return VendorBill(
      id: id,
      vendor: (json['vendor'] ?? '').toString(),
      stkNo: (json['stk_no'] ?? '').toString(),
      billDate: (json['bill_date'] ?? '').toString(),
      totalDisplay: (json['total'] ?? '0.00').toString(),
      paidDisplay: (json['paid'] ?? '0.00').toString(),
      pendingDisplay: (json['pending'] ?? '0.00').toString(),
      statusDisplay: (json['status'] ?? 'Unpaid').toString(),
      due: VendorDueInfo.fromJson(dueMap),
      stockLines: List.unmodifiable(lines),
    );
  }
}

class VendorPaymentSummary {
  const VendorPaymentSummary({
    required this.totalPendingDisplay,
    required this.pendingBills,
    required this.overdue,
    required this.dueThisWeek,
  });

  final String totalPendingDisplay;
  final int pendingBills;
  final int overdue;
  final int dueThisWeek;

  factory VendorPaymentSummary.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return VendorPaymentSummary(
      totalPendingDisplay: (json['total_pending'] ?? '0.00').toString(),
      pendingBills: asInt(json['pending_bills']),
      overdue: asInt(json['overdue']),
      dueThisWeek: asInt(json['due_this_week']),
    );
  }

  static const empty = VendorPaymentSummary(
    totalPendingDisplay: '0.00',
    pendingBills: 0,
    overdue: 0,
    dueThisWeek: 0,
  );
}

class VendorReportPreview {
  const VendorReportPreview({
    this.startDate,
    this.endDate,
    required this.bills,
    required this.totalBilledDisplay,
    required this.totalPaidDisplay,
    required this.totalPendingDisplay,
  });

  final String? startDate;
  final String? endDate;
  final int bills;
  final String totalBilledDisplay;
  final String totalPaidDisplay;
  final String totalPendingDisplay;

  factory VendorReportPreview.fromJson(Map<String, dynamic> json) {
    final billsRaw = json['bills'];
    final bills = billsRaw is int
        ? billsRaw
        : int.tryParse(billsRaw?.toString() ?? '') ?? 0;

    return VendorReportPreview(
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      bills: bills,
      totalBilledDisplay: (json['total_billed'] ?? '0.00').toString(),
      totalPaidDisplay: (json['total_paid'] ?? '0.00').toString(),
      totalPendingDisplay: (json['total_pending'] ?? '0.00').toString(),
    );
  }
}

class VendorBillsPage {
  const VendorBillsPage({
    required this.bills,
    required this.hasNext,
    required this.count,
  });

  final List<VendorBill> bills;
  final bool hasNext;
  final int count;
}

/// One row on the Payable hub — vendor with aggregated open balance.
class VendorPayableGroup {
  const VendorPayableGroup({
    required this.vendorName,
    required this.pendingAmount,
    required this.pendingDisplay,
    required this.bills,
  });

  final String vendorName;
  final double pendingAmount;
  final String pendingDisplay;
  final List<VendorBill> bills;

  int get billCount => bills.length;

  String get displayName => vendorName.toUpperCase();
}

