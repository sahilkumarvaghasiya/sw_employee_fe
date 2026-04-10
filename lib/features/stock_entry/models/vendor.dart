import 'package:flutter/foundation.dart';

@immutable
class Vendor {
  const Vendor({required this.id, required this.name, required this.address});

  final String id;
  final String name;
  final String address;
}
