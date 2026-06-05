import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/settings_screen.dart';
import 'services/tracking_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShadowTrackApp());
}

class ShadowTrackApp extends StatelessWidget {
  const ShadowTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Device Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const _screens = <Widget>[
    HomeScreen(),
    SettingsScreen(),
    LogsScreen(),
  ];

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(TrackingService.initialize());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Logs',
          ),
        ],
      ),
    );
  }
}
