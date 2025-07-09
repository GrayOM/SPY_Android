import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<Permission, PermissionStatus> _permissionStatuses = {};
  PackageInfo? _packageInfo;
  Map<String, dynamic> _deviceInfo = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _checkPermissions();
    await _loadPackageInfo();
    await _loadDeviceInfo();
  }

  Future<void> _checkPermissions() async {
    final permissions = [
      Permission.location,
      Permission.locationAlways,
      Permission.sms,
      Permission.storage,
      Permission.manageExternalStorage,
      Permission.contacts,
      Permission.camera,
      Permission.microphone,
      Permission.phone,
    ];

    Map<Permission, PermissionStatus> statuses = {};
    for (final permission in permissions) {
      statuses[permission] = await permission.status;
    }

    setState(() {
      _permissionStatuses = statuses;
    });
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = packageInfo;
    });
  }

  Future<void> _loadDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      setState(() {
        _deviceInfo = {
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'manufacturer': androidInfo.manufacturer,
          'androidVersion': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
          'id': androidInfo.id,
        };
      });
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    final status = await permission.request();
    setState(() {
      _permissionStatuses[permission] = status;
    });

    if (status.isDenied || status.isPermanentlyDenied) {
      _showPermissionDialog(permission, status);
    }
  }

  void _showPermissionDialog(Permission permission, PermissionStatus status) {
    final isPermanentlyDenied = status == PermissionStatus.permanentlyDenied;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permission ${isPermanentlyDenied ? "Permanently " : ""}Denied'),
        content: Text(
          isPermanentlyDenied
              ? 'This permission has been permanently denied. Please enable it in app settings.'
              : 'This permission is required for proper functionality.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (isPermanentlyDenied)
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
        return 'Location';
      case Permission.locationAlways:
        return 'Background Location';
      case Permission.sms:
        return 'SMS';
      case Permission.storage:
        return 'Storage';
      case Permission.manageExternalStorage:
        return 'Manage External Storage';
      case Permission.contacts:
        return 'Contacts';
      case Permission.camera:
        return 'Camera';
      case Permission.microphone:
        return 'Microphone';
      case Permission.phone:
        return 'Phone';
      default:
        return permission.toString().split('.').last;
    }
  }

  IconData _getPermissionIcon(Permission permission) {
    switch (permission) {
      case Permission.location:
      case Permission.locationAlways:
        return Icons.location_on;
      case Permission.sms:
        return Icons.message;
      case Permission.storage:
      case Permission.manageExternalStorage:
        return Icons.storage;
      case Permission.contacts:
        return Icons.contacts;
      case Permission.camera:
        return Icons.camera_alt;
      case Permission.microphone:
        return Icons.mic;
      case Permission.phone:
        return Icons.phone;
      default:
        return Icons.security;
    }
  }

  Color _getStatusColor(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return Colors.green;
      case PermissionStatus.denied:
        return Colors.orange;
      case PermissionStatus.permanentlyDenied:
        return Colors.red;
      case PermissionStatus.restricted:
        return Colors.red;
      case PermissionStatus.limited:
        return Colors.yellow;
      case PermissionStatus.provisional:
        return Colors.blue;
    }
  }

  String _getStatusText(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Granted';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.permanentlyDenied:
        return 'Permanently Denied';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      case PermissionStatus.provisional:
        return 'Provisional';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 권한 섹션
            _buildSection(
              title: 'Permissions',
              icon: Icons.security,
              children: [
                const Text(
                  'App permissions are required for proper monitoring functionality.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ..._permissionStatuses.entries.map((entry) =>
                    _buildPermissionTile(entry.key, entry.value)
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 앱 정보 섹션
            _buildSection(
              title: 'App Information',
              icon: Icons.info,
              children: [
                if (_packageInfo != null) ...[
                  _buildInfoTile('App Name', _packageInfo!.appName),
                  _buildInfoTile('Package Name', _packageInfo!.packageName),
                  _buildInfoTile('Version', '${_packageInfo!.version} (${_packageInfo!.buildNumber})'),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // 디바이스 정보 섹션
            _buildSection(
              title: 'Device Information',
              icon: Icons.phone_android,
              children: [
                if (_deviceInfo.isNotEmpty) ...[
                  _buildInfoTile('Model', '${_deviceInfo['brand']} ${_deviceInfo['model']}'),
                  _buildInfoTile('Manufacturer', _deviceInfo['manufacturer']),
                  _buildInfoTile('Android Version', _deviceInfo['androidVersion']),
                  _buildInfoTile('SDK Version', _deviceInfo['sdkInt'].toString()),
                  _buildInfoTile('Physical Device', _deviceInfo['isPhysicalDevice'] ? 'Yes' : 'No'),
                  _buildInfoTile('Device ID', _deviceInfo['id']),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // 고급 설정 섹션
            _buildSection(
              title: 'Advanced Settings',
              icon: Icons.tune,
              children: [
                ListTile(
                  leading: const Icon(Icons.settings_applications),
                  title: const Text('Open App Settings'),
                  subtitle: const Text('Configure app permissions in system settings'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => openAppSettings(),
                ),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Refresh Permissions'),
                  subtitle: const Text('Check current permission status'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: _checkPermissions,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 위험 구역
            _buildSection(
              title: 'Danger Zone',
              icon: Icons.warning,
              color: Colors.red,
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Delete all collected monitoring data'),
                  onTap: _showClearDataDialog,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color ?? Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile(Permission permission, PermissionStatus status) {
    return ListTile(
      leading: Icon(
        _getPermissionIcon(permission),
        color: _getStatusColor(status),
      ),
      title: Text(_getPermissionName(permission)),
      subtitle: Text(_getStatusText(status)),
      trailing: status == PermissionStatus.granted
          ? Icon(Icons.check_circle, color: Colors.green[600])
          : ElevatedButton(
        onPressed: () => _requestPermission(permission),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
        ),
        child: const Text('Grant'),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'Are you sure you want to delete all collected monitoring data? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearAllData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllData() async {
    // TODO: 실제 데이터 삭제 로직 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All monitoring data has been cleared'),
        backgroundColor: Colors.green,
      ),
    );
  }
}