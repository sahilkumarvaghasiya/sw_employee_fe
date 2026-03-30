import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/providers/theme_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/stock_entry/providers/stock_entry_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadToken()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => StockEntryProvider()),
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
        final lightScheme = ColorScheme.fromSeed(seedColor: Colors.teal);
        final darkScheme = ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        );

        return MaterialApp(
          title: 'RetailPilot',
          themeMode: theme.themeMode,
          theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
          darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
          home: auth.isAuthenticated ? const HomeScreen() : const LoginScreen(),
        );
      },
    );
  }
}
