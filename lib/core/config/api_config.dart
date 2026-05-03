import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig._();

  // For Android emulator
  static const String _androidEmulatorBaseUrl = 'https://swbillingemployeebe-production.up.railway.app/api';

  // For iOS simulator / macOS / local web
  static const String _localhostBaseUrl = 'http://127.0.0.1:8000/api';

  // For physical phone on same Wi‑Fi as your backend machine.
  // static const String _physicalDeviceBaseUrl = 'http://192.168.1.15:8000/api';
  static const String _physicalDeviceBaseUrl = 'https://c847-2401-4900-790b-280b-9c9-b8d3-c460-a709.ngrok-free.app/api';

  // Set true when running on a real device.
  static const bool usePhysicalDeviceBaseUrl = false;

  static String get baseUrl {
    if (usePhysicalDeviceBaseUrl) return _physicalDeviceBaseUrl;

    if (kIsWeb) return _localhostBaseUrl;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidEmulatorBaseUrl;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return _localhostBaseUrl;
    }
  }

}
