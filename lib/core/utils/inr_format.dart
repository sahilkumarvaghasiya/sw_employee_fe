import 'package:intl/intl.dart';

/// Indian numbering (lakhs/crores grouping) with rupee symbol.
String formatInr(double amount, {int decimalDigits = 0}) {
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: decimalDigits,
  ).format(amount);
}
