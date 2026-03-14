import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: IFuturesApp(),
    ),
  );
}

class IFuturesApp extends StatelessWidget {
  const IFuturesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iFutures Bot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blueGrey,
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
