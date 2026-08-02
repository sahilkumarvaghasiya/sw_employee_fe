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
    this.dueDate,
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
  /// Payment deadline (YYYY-MM-DD). Prefer this next to due chip.
  final String? dueDate;
  final String totalDisplay;
  final String paidDisplay;
  final String pendingDisplay;
  final String statusDisplay;
  final VendorDueInfo due;
  final List<VendorStockLine> stockLines;

  double get pendingAmount => parseIndianAmount(pendingDisplay) ?? 0;
  double get totalAmount => parseIndianAmount(totalDisplay) ?? 0;
  double get paidAmount => parseIndianAmount(paidDisplay) ?? 0;

  /// Date shown beside due status — stock entry date (not payment due date).
  String get displayDate {
    final entry = billDate.trim();
    if (entry.isNotEmpty) return entry;
    return dueDate?.trim() ?? '';
  }

  bool get isFullyPaid {
    final status = statusDisplay.toLowerCase();
    return due.isPaid || status == 'paid' || pendingAmount <= 0;
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

    final dueDateRaw = (json['due_date'] ?? '').toString().trim();

    return VendorBill(
      id: id,
      vendor: (json['vendor'] ?? '').toString(),
      stkNo: (json['stk_no'] ?? '').toString(),
      billDate: (json['bill_date'] ?? '').toString(),
      dueDate: dueDateRaw.isEmpty ? null : dueDateRaw,
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
      dueThisWeek: asInt(json['due_soon']),
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

class VendorStatementPage {
  const VendorStatementPage({
    required this.entries,
    required this.hasNext,
    required this.count,
  });

  final List<VendorStatementEntry> entries;
  final bool hasNext;
  final int count;
}

class VendorPayableVendorsPage {
  const VendorPayableVendorsPage({
    required this.vendors,
    required this.hasNext,
    required this.count,
  });

  final List<VendorPayableGroup> vendors;
  final bool hasNext;
  final int count;
}

/// One row on the Payable hub — vendor with aggregated open balance.
class VendorPayableGroup {
  const VendorPayableGroup({
    this.vendorId,
    required this.vendorName,
    required this.pendingAmount,
    required this.pendingDisplay,
    this.billsCount = 0,
    this.overdueCount = 0,
    this.isSettled = false,
    this.bills = const <VendorBill>[],
  });

  final int? vendorId;
  final String vendorName;
  final double pendingAmount;
  final String pendingDisplay;
  final int billsCount;
  final int overdueCount;
  final bool isSettled;
  final List<VendorBill> bills;

  int get billCount => billsCount > 0 ? billsCount : bills.length;

  String get displayName => vendorName.toUpperCase();

  factory VendorPayableGroup.fromPayableApi(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final pendingDisplay = (json['total_pending'] ?? '0.00').toString();
    final pendingAmount = parseIndianAmount(pendingDisplay) ?? 0;
    final billsCount = asInt(json['bills_count']);
    final isSettled = json['is_settled'] == true ||
        pendingAmount <= 0 ||
        billsCount == 0;

    return VendorPayableGroup(
      vendorId: asInt(json['vendor_id']),
      vendorName: (json['vendor_name'] ?? '').toString(),
      pendingAmount: pendingAmount,
      pendingDisplay: pendingDisplay,
      billsCount: billsCount,
      overdueCount: asInt(json['overdue_count']),
      isSettled: isSettled,
    );
  }

  VendorPayableGroup copyWith({
    int? vendorId,
    String? vendorName,
    double? pendingAmount,
    String? pendingDisplay,
    int? billsCount,
    int? overdueCount,
    bool? isSettled,
    List<VendorBill>? bills,
  }) {
    return VendorPayableGroup(
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      pendingAmount: pendingAmount ?? this.pendingAmount,
      pendingDisplay: pendingDisplay ?? this.pendingDisplay,
      billsCount: billsCount ?? this.billsCount,
      overdueCount: overdueCount ?? this.overdueCount,
      isSettled: isSettled ?? this.isSettled,
      bills: bills ?? this.bills,
    );
  }
}

class VendorPaymentAllocationLine {
  const VendorPaymentAllocationLine({
    required this.billId,
    required this.stkNo,
    required this.billDate,
    required this.appliedDisplay,
    this.dueDate,
  });

  final int billId;
  final String stkNo;
  final String billDate;
  final String appliedDisplay;
  final String? dueDate;

  factory VendorPaymentAllocationLine.fromJson(Map<String, dynamic> json) {
    final idRaw = json['bill_id'];
    final id = idRaw is int
        ? idRaw
        : int.tryParse(idRaw?.toString() ?? '') ?? 0;
    final dueRaw = (json['due_date'] ?? '').toString().trim();
    return VendorPaymentAllocationLine(
      billId: id,
      stkNo: (json['stk_no'] ?? '').toString(),
      billDate: (json['bill_date'] ?? '').toString(),
      appliedDisplay: (json['applied'] ?? '0.00').toString(),
      dueDate: dueRaw.isEmpty ? null : dueRaw,
    );
  }
}

/// Persisted / session payment ledger entry for Statement.
class VendorStatementPayment {
  const VendorStatementPayment({
    required this.id,
    required this.paidAt,
    required this.amount,
    required this.amountDisplay,
    required this.allocations,
    this.discount = 0,
    this.surcharge = 0,
    this.bills = const <VendorBill>[],
  });

  final String id;
  final DateTime paidAt;
  final double amount;
  final String amountDisplay;
  final List<VendorPaymentAllocationLine> allocations;
  final double discount;
  final double surcharge;
  final List<VendorBill> bills;

  int get billCount =>
      allocations.isNotEmpty ? allocations.length : bills.length;

  bool get hasAdjustments => discount > 0 || surcharge > 0;

  factory VendorStatementPayment.fromPaymentApi(Map<String, dynamic> json) {
    double asAmount(dynamic value) {
      if (value is num) return value.toDouble();
      return parseIndianAmount(value?.toString()) ?? 0;
    }

    // Prefer created_at (real payment timestamp). payment_date is date-only
    // and would always render as 12:00 AM. Always convert to device local (IST).
    final dateRaw = (json['payment_date'] ?? '').toString().trim();
    final paidAt = _parseLocalDateTime(json['created_at']?.toString()) ??
        _parseLocalDateTime(dateRaw) ??
        _tryParseDdMmYyyy(dateRaw) ??
        DateTime.now();

    final allocationsRaw = json['allocations'];
    final allocations = <VendorPaymentAllocationLine>[];
    if (allocationsRaw is List) {
      for (final row in allocationsRaw) {
        if (row is Map) {
          allocations.add(
            VendorPaymentAllocationLine.fromJson(row.cast<String, dynamic>()),
          );
        }
      }
    }

    final amountDisplay = (json['amount'] ?? '0.00').toString();
    return VendorStatementPayment(
      id: (json['id'] ?? '').toString(),
      paidAt: paidAt,
      amount: asAmount(json['amount']),
      amountDisplay: amountDisplay,
      allocations: List.unmodifiable(allocations),
      discount: asAmount(json['discount']),
      surcharge: asAmount(json['surcharge']),
    );
  }

  static DateTime? _parseLocalDateTime(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  static DateTime? _tryParseDdMmYyyy(String raw) {
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final dd = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    final yyyy = int.tryParse(parts[2]);
    if (dd == null || mm == null || yyyy == null) return null;
    return DateTime(yyyy, mm, dd);
  }
}

class VendorPayablePayResult {
  const VendorPayablePayResult({
    required this.payment,
    required this.bills,
  });

  final VendorStatementPayment payment;
  final List<VendorBill> bills;
}

enum VendorStatementKind { purchase, payment }

/// Unified statement timeline row for purchases and payments.
class VendorStatementEntry {
  const VendorStatementEntry.purchase({
    required this.bill,
    required this.sortAt,
  })  : kind = VendorStatementKind.purchase,
        payment = null;

  const VendorStatementEntry.payment({
    required this.payment,
    required this.sortAt,
  })  : kind = VendorStatementKind.payment,
        bill = null;

  final VendorStatementKind kind;
  final VendorBill? bill;
  final VendorStatementPayment? payment;
  final DateTime sortAt;
}


