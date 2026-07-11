/// Indian Standard Time helpers (UTC+5:30, no DST).
DateTime indianDateTimeNow() {
  return DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
}

String greetingForIndianTime([DateTime? at]) {
  final hour = (at ?? indianDateTimeNow()).hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}
