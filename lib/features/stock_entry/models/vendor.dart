import 'package:flutter/foundation.dart';

enum VendorGender { male, female, other }

@immutable
class Vendor {
  const Vendor({
    required this.id,
    required this.name,
    required this.address,
    required this.gender,
  });

  final String id;
  final String name;
  final String address;
  final VendorGender gender;
}
