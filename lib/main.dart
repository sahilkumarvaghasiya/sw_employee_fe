import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/navigation/app_lifecycle_manager.dart';
import 'core/navigation/session_cleanup_handler.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/providers/home_dashboard_provider.dart';
import 'features/home/screens/home_screen.dart';
import 'features/stock_alerts/providers/stock_alerts_provider.dart';
import 'features/stock_entry/providers/stock_entry_provider.dart';
import 'core/navigation/app_navigator.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadToken()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => HomeDashboardProvider()),
        ChangeNotifierProvider(create: (_) => StockEntryProvider()),
        ChangeNotifierProvider(create: (_) => StockAlertsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ThemeProvider>(
      builder: (context, auth, theme, _) {
        return SessionCleanupHandler(
          child: AppLifecycleManager(
            child: MaterialApp(
              title: 'RetailPilot',
              themeMode: theme.themeMode,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              navigatorKey: AppNavigator.navigatorKey,
              scaffoldMessengerKey: AppNavigator.messengerKey,
              home: auth.isAuthenticated
                  ? const HomeScreen()
                  : const LoginScreen(),
            ),
          ),
        );
      },
    );
  }
}
