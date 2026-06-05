import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/tracking_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _endpointsController = TextEditingController();

  PermissionStatus? _locationStatus;
  PermissionStatus? _backgroundLocationStatus;
  PermissionStatus? _galleryStatus;
  PackageInfo? _packageInfo;
  Map<String, Object?> _deviceInfo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _endpointsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait<Object?>([
      Permission.locationWhenInUse.status,
      Permission.locationAlways.status,
      Platform.isAndroid ? Permission.photos.status : Permission.storage.status,
      PackageInfo.fromPlatform(),
      _loadDeviceInfo(),
      TrackingService.getBackendEndpoints(),
    ]);

    if (!mounted) return;
    setState(() {
      _locationStatus = results[0] as PermissionStatus;
      _backgroundLocationStatus = results[1] as PermissionStatus;
      _galleryStatus = results[2] as PermissionStatus;
      _packageInfo = results[3] as PackageInfo;
      _deviceInfo = results[4] as Map<String, Object?>;
      _endpointsController.text = (results[5] as List<String>).join('\n');
      _isLoading = false;
    });
  }

  Future<Map<String, Object?>> _loadDeviceInfo() async {
    if (!Platform.isAndroid) {
      return {'Platform': Platform.operatingSystem};
    }

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    return {
      'Brand': androidInfo.brand,
      'Model': androidInfo.model,
      'Manufacturer': androidInfo.manufacturer,
      'Android Version': androidInfo.version.release,
      'SDK Version': androidInfo.version.sdkInt,
    };
  }

  Future<void> _saveEndpoints() async {
    await TrackingService.saveBackendEndpoints(_endpointsController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backend endpoints saved')),
    );
  }

  String _permissionText(PermissionStatus? status) {
    if (status == null) return 'Unknown';
    if (status.isGranted) return 'Granted';
    if (status.isLimited) return 'Limited';
    if (status.isPermanentlyDenied) return 'Denied in settings';
    if (status.isRestricted) return 'Restricted';
    return 'Denied';
  }

  Color _permissionColor(PermissionStatus? status) {
    if (status?.isGranted == true || status?.isLimited == true) return Colors.green;
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
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile(String title, PermissionStatus? status) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.verified_user_outlined, color: _permissionColor(status)),
      title: Text(title),
      subtitle: Text(_permissionText(status)),
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
                    title: 'Permission Dashboard',
                    icon: Icons.security,
                    children: [
                      _buildPermissionTile('Location while app is in use', _locationStatus),
                      _buildPermissionTile('Background location', _backgroundLocationStatus),
                      _buildPermissionTile('Gallery', _galleryStatus),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: openAppSettings,
                          icon: const Icon(Icons.settings_applications),
                          label: const Text('Open Android Settings'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'Guardian Backend Points',
                    icon: Icons.cloud_upload_outlined,
                    children: [
                      TextField(
                        controller: _endpointsController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'HTTPS endpoints',
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _saveEndpoints,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Endpoints'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'Conservation Policy',
                    icon: Icons.privacy_tip_outlined,
                    children: const [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Location'),
                        subtitle: Text('Latest samples are stored locally and sent only to configured backend points after consent.'),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Protected information'),
                        subtitle: Text('Saved values are encrypted on this device. The web admin page does not display plaintext.'),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Excluded data'),
                        subtitle: Text('No camera, microphone, SMS, calls, contacts, screen content, accessibility, device manager, app-list, or overlay capture.'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'Local Guardian Web Page',
                    icon: Icons.language_outlined,
                    children: [
                      _buildInfoTile(
                        'Address',
                        TrackingService.guardianAdminPort == null
                            ? 'Starts when sharing is on'
                            : 'http://device-ip:${TrackingService.guardianAdminPort}',
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
                        _buildInfoTile('Version', '${_packageInfo!.version} (${_packageInfo!.buildNumber})'),
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
                ],
              ),
            ),
    );
  }
}
