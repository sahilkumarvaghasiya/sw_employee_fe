import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig._();

  // For Android emulator
  // static const String _androidEmulatorBaseUrl = 'https://d699-2401-4900-aafb-626f-7491-31fb-efd0-9340.ngrok-free.app/api';
  static const String _androidEmulatorBaseUrl = 'https://swbillingemployeebe-production.up.railway.app/api/';

  // For iOS simulator / macOS / local web
  static const String _localhostBaseUrl = 'https://swbillingemployeebe-production.up.railway.app/api/';

  // For physical phone on same Wi‑Fi as your backend machine.
  // Example: http://192.168.0.10:8000/api
  static const String _physicalDeviceBaseUrl = 'https://swbillingemployeebe-production.up.railway.app/api/';
  // static const String _physicalDeviceBaseUrl = 'https://d699-2401-4900-aafb-626f-7491-31fb-efd0-9340.ngrok-free.app/api';

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
