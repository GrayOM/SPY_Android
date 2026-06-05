import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PermissionStatus? _locationStatus;
  PackageInfo? _packageInfo;
  Map<String, Object?> _deviceInfo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait<Object?>([
      Permission.locationWhenInUse.status,
      PackageInfo.fromPlatform(),
      _loadDeviceInfo(),
    ]);

    if (!mounted) return;
    setState(() {
      _locationStatus = results[0] as PermissionStatus;
      _packageInfo = results[1] as PackageInfo;
      _deviceInfo = results[2] as Map<String, Object?>;
      _isLoading = false;
    });
  }

  Future<Map<String, Object?>> _loadDeviceInfo() async {
    if (!Platform.isAndroid) {
      return {'platform': Platform.operatingSystem};
    }

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    return {
      'Brand': androidInfo.brand,
      'Model': androidInfo.model,
      'Manufacturer': androidInfo.manufacturer,
      'Android Version': androidInfo.version.release,
      'SDK Version': androidInfo.version.sdkInt,
      'Physical Device': androidInfo.isPhysicalDevice ? 'Yes' : 'No',
    };
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (!mounted) return;
    setState(() => _locationStatus = status);

    if (status.isPermanentlyDenied) {
      _showSettingsDialog();
    }
  }

  void _showSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Settings'),
        content: const Text(
          'Location permission has been permanently denied. Enable it in Android settings to use monitoring.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
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

  String _permissionText(PermissionStatus? status) {
    if (status == null) return 'Unknown';
    if (status.isGranted) return 'Granted';
    if (status.isLimited) return 'Limited';
    if (status.isPermanentlyDenied) return 'Permanently denied';
    if (status.isRestricted) return 'Restricted';
    return 'Denied';
  }

  Color _permissionColor(PermissionStatus? status) {
    if (status?.isGranted == true) return Colors.green;
    if (status?.isPermanentlyDenied == true) return Colors.red;
    return Colors.orange;
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, Object? value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value?.toString() ?? 'Unknown'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSection(
                    title: 'Permissions',
                    icon: Icons.security,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.location_on_outlined,
                          color: _permissionColor(_locationStatus),
                        ),
                        title: const Text('Location while app is in use'),
                        subtitle: Text(_permissionText(_locationStatus)),
                        trailing: _locationStatus?.isGranted == true
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : FilledButton(
                                onPressed: _requestLocationPermission,
                                child: const Text('Grant'),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'App Information',
                    icon: Icons.info_outline,
                    children: [
                      if (_packageInfo != null) ...[
                        _buildInfoTile('App Name', _packageInfo!.appName),
                        _buildInfoTile('Package Name', _packageInfo!.packageName),
                        _buildInfoTile(
                          'Version',
                          '${_packageInfo!.version} (${_packageInfo!.buildNumber})',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'Device Information',
                    icon: Icons.phone_android,
                    children: _deviceInfo.entries
                        .map((entry) => _buildInfoTile(entry.key, entry.value))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'System Settings',
                    icon: Icons.tune,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.settings_applications),
                        title: const Text('Open App Settings'),
                        subtitle: const Text('Manage app permissions in Android'),
                        onTap: openAppSettings,
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
