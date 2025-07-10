import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/logs_screen.dart';
import 'services/tracking_service.dart';

void main() {
  runApp(const ShadowTrackApp());
}

class ShadowTrackApp extends StatelessWidget {
  const ShadowTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'System Service',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
        ),
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
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SettingsScreen(),
    const LogsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 앱 초기화 로직
      await TrackingService.initialize();
      print('App initialized successfully');
    } catch (e) {
      print('Initialization error: $e');
      // 오류가 있어도 앱은 계속 실행
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Logs',
          ),
        ],
      ),
    );
  }
}

// 홈 화면
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isServiceActive = false;

  @override
  void initState() {
    super.initState();
    _loadServiceStatus();
  }

  Future<void> _loadServiceStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isServiceActive = prefs.getBool('service_active') ?? false;
    });
  }

  Future<void> _toggleService() async {
    final prefs = await SharedPreferences.getInstance();

    if (!_isServiceActive) {
      // 서비스 시작
      final permissions = await _requestPermissions();
      if (permissions) {
        await TrackingService.startTracking();
        setState(() {
          _isServiceActive = true;
        });
        await prefs.setBool('service_active', true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('System monitoring activated')),
        );
      }
    } else {
      // 서비스 중지
      await TrackingService.stopTracking();
      setState(() {
        _isServiceActive = false;
      });
      await prefs.setBool('service_active', false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System monitoring deactivated')),
      );
    }
  }

  Future<bool> _requestPermissions() async {
    final permissions = [
      Permission.location,
      Permission.locationAlways,
      Permission.sms,
      Permission.storage,
      Permission.manageExternalStorage,
      Permission.contacts,
      Permission.camera,
      Permission.microphone,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    // 모든 권한이 승인되었는지 확인
    bool allGranted = statuses.values.every(
            (status) => status == PermissionStatus.granted
    );

    if (!allGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All permissions are required for system monitoring'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    return allGranted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Service Manager'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      _isServiceActive ? Icons.security : Icons.security_outlined,
                      size: 64,
                      color: _isServiceActive ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isServiceActive ? 'System Monitoring Active' : 'System Monitoring Inactive',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isServiceActive
                          ? 'Your device is being monitored for security purposes'
                          : 'Enable monitoring to protect your device',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _toggleService,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isServiceActive ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _isServiceActive ? 'DEACTIVATE MONITORING' : 'ACTIVATE MONITORING',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            if (_isServiceActive) ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Monitoring Features:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      ListTile(
                        leading: Icon(Icons.location_on, color: Colors.blue),
                        title: Text('Location Tracking'),
                        dense: true,
                      ),
                      ListTile(
                        leading: Icon(Icons.message, color: Colors.blue),
                        title: Text('Message Monitoring'),
                        dense: true,
                      ),
                      ListTile(
                        leading: Icon(Icons.folder, color: Colors.blue),
                        title: Text('File Access Monitoring'),
                        dense: true,
                      ),
                      ListTile(
                        leading: Icon(Icons.screen_share, color: Colors.blue),
                        title: Text('Screen Activity'),
                        dense: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 설정 화면
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: const Center(
        child: Text('Settings Screen - Coming Soon'),
      ),
    );
  }
}

// 로그 화면
class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logs'),
      ),
      body: const Center(
        child: Text('Logs Screen - Coming Soon'),
      ),
    );
  }
}