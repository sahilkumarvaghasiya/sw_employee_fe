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

  factory Vendor.fromJson(Map<String, dynamic> json) {
    String str(Object? v) => v?.toString().trim() ?? '';

    final name = str(json['name'] ?? json['vendor_name'] ?? json['vendorName']);
    final phone = str(json['phone'] ?? json['phone_number'] ?? json['mobile']);
    final idRaw = str(json['id'] ?? json['vendor_id'] ?? json['vendorId']);
    final gst = str(json['gst'] ?? json['gst_number'] ?? json['gstNo']);

    final emailRaw = str(json['email']);
    final addressRaw = str(json['address']);

    return Vendor(
      // Some vendor list APIs don't return a numeric id; avoid collapsing
      // all vendors into "0" which breaks selection and history routing.
      id: idRaw.isNotEmpty
          ? idRaw
          : (name.isNotEmpty ? name : (phone.isNotEmpty ? phone : 'unknown')),
      name: name,
      phone: phone,
      gst: gst,
      email: emailRaw.isEmpty ? null : emailRaw,
      address: addressRaw.isEmpty ? null : addressRaw,
    );
  }

  final String id;
  final String name;
  final String phone;
  final String gst;
  final String? email;
  final String? address;
}
