import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

class TrackingService {
  static const MethodChannel _channel = MethodChannel('android_helper');
  static const backgroundLocationTask = 'guardian_location_periodic_share';
  static const _backgroundTaskUniqueName = 'guardian_location_periodic_share';
  static const _serviceActiveKey = 'location_sharing_active';
  static const _locationConsentKey = 'location_sharing_consent';
  static const _backendEndpointsKey = 'guardian_backend_endpoints';
  static const _guardianPortKey = 'guardian_admin_port';
  static const _latestLocationKey = 'latest_location_sample';
  static const Map<String, int> collectionIntervals = {
    'location': 15,
  };

  static bool _isTracking = false;
  static Timer? _locationTimer;
  static HttpServer? _adminServer;

  static bool get isTracking => _isTracking;
  static int? get guardianAdminPort => _adminServer?.port;

  static Future<void> initialize() async {
    try {
      await _channel.invokeMethod<void>('initialize');
    } on MissingPluginException {
      debugPrint('Native channel unavailable; continuing with Dart services.');
    } catch (error) {
      debugPrint('TrackingService initialization failed: $error');
    }

    final prefs = await SharedPreferences.getInstance();
    _isTracking = prefs.getBool(_serviceActiveKey) ?? false;
    if (_isTracking) {
      _startLocationTimer();
      await _startGuardianAdminServer();
    }
  }

  static Future<void> startTracking() async {
    if (_isTracking) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_locationConsentKey) != true) {
      throw StateError('Location sharing consent is required.');
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        permission == LocationPermission.unableToDetermine) {
      throw StateError('Location permission has not been granted.');
    }

    _isTracking = true;
    await prefs.setBool(_serviceActiveKey, true);
    _startLocationTimer();
    await _registerBackgroundLocationTask();
    await _startGuardianAdminServer();
    await _logEvent('sharing_started', 'Location sharing started by the user.');
  }

  static Future<void> stopTracking() async {
    if (!_isTracking) return;

    _isTracking = false;
    _locationTimer?.cancel();
    _locationTimer = null;
    try {
      await Workmanager().cancelByUniqueName(_backgroundTaskUniqueName);
    } on MissingPluginException {
      debugPrint('Workmanager plugin unavailable; no background task to cancel.');
    }
    await _adminServer?.close(force: true);
    _adminServer = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_serviceActiveKey, false);
    await _logEvent('sharing_stopped', 'Location sharing stopped by the user.');
  }

  static Future<void> recordLocationConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_locationConsentKey, true);
    await _logEvent('location_consent', 'User agreed to share location with a guardian.');
  }

  static Future<bool> hasLocationConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_locationConsentKey) ?? false;
  }

  static Future<void> forceLocationShare() async {
    if (!_isTracking) {
      throw StateError('Location sharing is not active.');
    }

    await _collectLocationData();
    await _logEvent('manual_location_share', 'Manual location update completed.');
  }

  static Future<bool> runBackgroundLocationShare() async {
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool(_serviceActiveKey) ?? false;
    final hasConsent = prefs.getBool(_locationConsentKey) ?? false;
    if (!isActive || !hasConsent) return true;

    await _collectLocationData();
    await _logEvent('background_location_share', 'Periodic background location update completed.');
    return true;
  }

  static Map<String, dynamic> getServiceStatus() {
    return {
      'is_location_sharing': _isTracking,
      'location_timer_active': _locationTimer?.isActive ?? false,
      'guardian_admin_active': _adminServer != null,
      'guardian_admin_port': _adminServer?.port,
      'collection_intervals': collectionIntervals,
      'last_status_check': DateTime.now().toIso8601String(),
    };
  }

  static void _startLocationTimer() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      Duration(minutes: collectionIntervals['location']!),
      (_) => _collectLocationData(),
    );
    unawaited(_collectLocationData());
  }

  static Future<void> _registerBackgroundLocationTask() async {
    try {
      await Workmanager().registerPeriodicTask(
        _backgroundTaskUniqueName,
        backgroundLocationTask,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } on MissingPluginException {
      debugPrint('Workmanager plugin unavailable; periodic background sharing was not registered.');
    } catch (error) {
      await _logEvent('background_task_error', 'Unable to register periodic background sharing: $error');
    }
  }

  static Future<void> _collectLocationData() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await _logEvent('location_skipped', 'Location services are disabled.');
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _logEvent('location_skipped', 'Location permission is not granted.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 20),
      );

      final sample = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _saveLatestLocation(sample);
      await _appendJsonLine('location_data.json', sample);
      await _sendLocationToBackends(sample);
    } catch (error) {
      await _logEvent('location_error', 'Failed to collect location: $error');
    }
  }

  static Future<void> saveBackendEndpoints(String rawEndpoints) async {
    final endpoints = rawEndpoints
        .split(RegExp(r'[\n,]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_backendEndpointsKey, endpoints);
    await _logEvent('backend_endpoints_updated', '${endpoints.length} endpoint(s) configured.');
  }

  static Future<List<String>> getBackendEndpoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_backendEndpointsKey) ?? const [];
  }

  static Future<Map<String, dynamic>?> getLatestLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_latestLocationKey);
    if (encoded == null) return null;
    final decoded = jsonDecode(encoded);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  static Future<void> _saveLatestLocation(Map<String, dynamic> sample) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_latestLocationKey, jsonEncode(sample));
  }

  static Future<void> _sendLocationToBackends(Map<String, dynamic> sample) async {
    final endpoints = await getBackendEndpoints();
    if (endpoints.isEmpty) return;

    final payload = jsonEncode({
      'type': 'guardian_location_update',
      'app': 'Android_helper',
      'location': sample,
    });

    for (final endpoint in endpoints) {
      try {
        final uri = Uri.parse(endpoint);
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
        final request = await client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        request.write(payload);
        final response = await request.close().timeout(const Duration(seconds: 15));
        await response.drain<void>();
        client.close(force: true);
        await _logEvent('backend_location_sent', 'Location sent to ${uri.host}.');
      } catch (error) {
        await _logEvent('backend_location_error', 'Unable to send to $endpoint: $error');
      }
    }
  }

  static Future<void> _startGuardianAdminServer() async {
    if (_adminServer != null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final preferredPort = prefs.getInt(_guardianPortKey) ?? 8787;
      _adminServer = await HttpServer.bind(
        InternetAddress.anyIPv4,
        preferredPort,
        shared: true,
      );
      await prefs.setInt(_guardianPortKey, _adminServer!.port);
      unawaited(_serveGuardianAdmin());
      await _logEvent('guardian_admin_started', 'Local web admin page started on port ${_adminServer!.port}.');
    } catch (error) {
      await _logEvent('guardian_admin_error', 'Unable to start local web admin page: $error');
    }
  }

  static Future<void> _serveGuardianAdmin() async {
    final server = _adminServer;
    if (server == null) return;

    await for (final request in server) {
      try {
        final latest = await getLatestLocation();
        final safeItems = await _readSafeItemMetadata();
        final html = _buildGuardianHtml(latest, safeItems);
        request.response
          ..headers.contentType = ContentType.html
          ..write(html);
      } catch (error) {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..write('Unable to load guardian page.');
      } finally {
        await request.response.close();
      }
    }
  }

  static Future<List<Map<String, dynamic>>> _readSafeItemMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getStringList('safe_storage_items') ?? const [];
    return encoded
        .map((item) => jsonDecode(item))
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  static String _buildGuardianHtml(
    Map<String, dynamic>? latest,
    List<Map<String, dynamic>> safeItems,
  ) {
    final updated = latest?['timestamp']?.toString() ?? 'No location shared yet';
    final lat = latest?['latitude'];
    final lng = latest?['longitude'];
    final location = lat is num && lng is num
        ? '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'
        : 'No location shared yet';
    final rows = safeItems.map((item) {
      return '<tr><td>${_escapeHtml(item['title'])}</td><td>${_escapeHtml(item['category'])}</td><td>Encrypted</td><td>${_escapeHtml(item['updatedTime'])}</td></tr>';
    }).join();

    return '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Guardian Web Administration</title>
  <style>
    body{font-family:Arial,sans-serif;margin:0;background:#f6f8fb;color:#17202a}
    main{max-width:920px;margin:0 auto;padding:24px}
    section{background:white;border:1px solid #dbe3ec;border-radius:8px;padding:18px;margin-bottom:16px}
    h1{font-size:24px;margin:0 0 16px}
    h2{font-size:18px;margin:0 0 12px}
    table{width:100%;border-collapse:collapse}
    th,td{text-align:left;border-bottom:1px solid #e6ebf1;padding:10px}
    th{font-size:13px;color:#536273}
  </style>
</head>
<body>
  <main>
    <h1>Guardian Web Administration</h1>
    <section>
      <h2>Latest Location</h2>
      <p><strong>Location:</strong> ${_escapeHtml(location)}</p>
      <p><strong>Updated Time:</strong> ${_escapeHtml(updated)}</p>
    </section>
    <section>
      <h2>Protected Information</h2>
      <table>
        <thead><tr><th>Item title</th><th>Category</th><th>Encrypted Status</th><th>Updated Time</th></tr></thead>
        <tbody>${rows.isEmpty ? '<tr><td colspan="4">No protected items saved.</td></tr>' : rows}</tbody>
      </table>
    </section>
  </main>
</body>
</html>
''';
  }

  static String _escapeHtml(Object? value) {
    return value
        ?.toString()
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;') ??
        '';
  }

  static Future<List<Map<String, dynamic>>> getCollectedData() async {
    final logsDir = await _logsDirectory(create: false);
    if (!await logsDir.exists()) {
      return [];
    }

    final records = <Map<String, dynamic>>[];
    await for (final entity in logsDir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;

      final fileName = _fileName(entity.path);
      try {
        final lines = await entity.readAsLines();
        for (final line in lines) {
          if (line.trim().isEmpty) continue;

          try {
            final decoded = jsonDecode(line);
            if (decoded is Map<String, dynamic>) {
              records.add({...decoded, 'source_file': fileName});
            }
          } catch (_) {
            await _logEvent('parse_error', 'Skipped invalid JSON in $fileName.');
          }
        }
      } catch (error) {
        await _logEvent('read_error', 'Unable to read $fileName: $error');
      }
    }

    records.sort((a, b) {
      final aTime = DateTime.tryParse(a['timestamp']?.toString() ?? '');
      final bTime = DateTime.tryParse(b['timestamp']?.toString() ?? '');
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return records;
  }

  static Future<List<Map<String, dynamic>>> getLocationData() async {
    final data = await getCollectedData();
    return data.where((record) {
      return record['source_file'] == 'location_data.json' ||
          record.containsKey('latitude');
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getEventData() async {
    final data = await getCollectedData();
    return data.where((record) => record['event'] != null).toList();
  }

  static Future<Map<String, dynamic>> getCollectionStats() async {
    final allData = await getCollectedData();
    final locationData = allData.where((record) {
      return record['source_file'] == 'location_data.json' ||
          record.containsKey('latitude');
    }).length;
    final eventData = allData.where((record) => record['event'] != null).length;

    final logsDir = await _logsDirectory(create: false);
    final files = await logsDir.exists()
        ? await logsDir
            .list()
            .where((entity) => entity is File && entity.path.endsWith('.json'))
            .length
        : 0;

    return {
      'total_records': allData.length,
      'location_count': locationData,
      'event_count': eventData,
      'total_data_files': files,
      'last_update': DateTime.now().toIso8601String(),
    };
  }

  static Future<void> clearAllData() async {
    final logsDir = await _logsDirectory(create: false);
    if (await logsDir.exists()) {
      await logsDir.delete(recursive: true);
    }
    await _logEvent('data_cleared', 'Local sharing records were cleared.');
  }

  static Future<void> _logEvent(String event, String details) {
    return _appendJsonLine('service_events.json', {
      'event': event,
      'details': details,
      'timestamp': DateTime.now().toIso8601String(),
      'service': 'TrackingService',
    });
  }

  static Future<void> _appendJsonLine(
    String fileName,
    Map<String, dynamic> data,
  ) async {
    final logsDir = await _logsDirectory();
    final file = File('${logsDir.path}/$fileName');
    await file.writeAsString(
      '${jsonEncode(data)}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  static Future<Directory> _logsDirectory({bool create = true}) async {
    final directory = await getApplicationDocumentsDirectory();
    final logsDir = Directory('${directory.path}/logs');

    if (create && !await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }

    return logsDir;
  }

  static String _fileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }
}
