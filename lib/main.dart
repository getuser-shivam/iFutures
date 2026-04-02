import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: IFuturesApp()));
}

class IFuturesApp extends StatelessWidget {
  const IFuturesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iFutures Bot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const DashboardScreen(),
    );
  }
}
