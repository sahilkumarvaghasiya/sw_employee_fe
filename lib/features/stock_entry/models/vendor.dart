import 'package:flutter/foundation.dart';

@immutable
class Vendor {
  const Vendor({
    required this.id,
    required this.name,
    required this.phone,
    required this.gst,
    this.email,
    this.address,
  });

  final String id;
  final String name;
  final String phone;
  final String gst;
  final String? email;
  final String? address;
}
