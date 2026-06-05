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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServiceStatus();
  }

  Future<void> _loadServiceStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _isServiceActive = prefs.getBool('service_active') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _toggleService() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      if (_isServiceActive) {
        await TrackingService.stopTracking();
        await prefs.setBool('service_active', false);
        if (!mounted) return;
        setState(() => _isServiceActive = false);
        _showSnackBar('Monitoring stopped');
        return;
      }

      final hasPermission = await _requestLocationPermission();
      if (!hasPermission) {
        _showSnackBar('Location permission is required to start monitoring');
        return;
      }

      await TrackingService.startTracking();
      await prefs.setBool('service_active', true);
      if (!mounted) return;
      setState(() => _isServiceActive = true);
      _showSnackBar('Monitoring started');
    } catch (error) {
      _showSnackBar('Unable to update monitoring: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isPermanentlyDenied && mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
            'Location permission is disabled for this app. Open system settings to enable it.',
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

    return false;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Monitor'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    _isServiceActive
                        ? Icons.shield
                        : Icons.shield_outlined,
                    size: 56,
                    color: _isServiceActive
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isServiceActive
                        ? 'Monitoring is active'
                        : 'Monitoring is off',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This app records local service events and foreground location samples only after you start monitoring.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isLoading ? null : _toggleService,
            icon: _isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_isServiceActive ? Icons.stop : Icons.play_arrow),
            label: Text(_isServiceActive ? 'Stop Monitoring' : 'Start Monitoring'),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Active Capabilities',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  ListTile(
                    leading: Icon(Icons.location_on_outlined),
                    title: Text('Foreground location sampling'),
                    dense: true,
                  ),
                  ListTile(
                    leading: Icon(Icons.event_note_outlined),
                    title: Text('Local service event logs'),
                    dense: true,
                  ),
                  ListTile(
                    leading: Icon(Icons.phone_android_outlined),
                    title: Text('Basic app/device diagnostics'),
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
