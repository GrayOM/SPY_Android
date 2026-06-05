import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

class TrackingService {
  static const MethodChannel _channel = MethodChannel('shadow_track');
  static const Map<String, int> collectionIntervals = {
    'location': 10,
    'diagnostics': 15,
  };

  static bool _isTracking = false;
  static Timer? _locationTimer;
  static Timer? _diagnosticsTimer;

  static bool get isTracking => _isTracking;

  static Future<void> initialize() async {
    try {
      await _channel.invokeMethod<void>('initialize');
    } on MissingPluginException {
      debugPrint('Native channel unavailable; continuing with Dart services.');
    } catch (error) {
      debugPrint('TrackingService initialization failed: $error');
    }
  }

  static Future<void> startTracking() async {
    if (_isTracking) return;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        permission == LocationPermission.unableToDetermine) {
      throw StateError('Location permission has not been granted.');
    }

    _isTracking = true;
    _startLocationTimer();
    _startDiagnosticsTimer();
    await _logEvent('tracking_started', 'Monitoring started by the user.');
  }

  static Future<void> stopTracking() async {
    if (!_isTracking) return;

    _isTracking = false;
    _locationTimer?.cancel();
    _locationTimer = null;
    _diagnosticsTimer?.cancel();
    _diagnosticsTimer = null;

    await _logEvent('tracking_stopped', 'Monitoring stopped by the user.');
  }

  static Future<void> forceDataCollection() async {
    if (!_isTracking) {
      throw StateError('Monitoring is not active.');
    }

    await Future.wait([
      _collectLocationData(),
      _collectDiagnostics(),
    ]);
    await _logEvent('manual_collection', 'Manual collection completed.');
  }

  static Map<String, dynamic> getServiceStatus() {
    return {
      'is_tracking': _isTracking,
      'location_timer_active': _locationTimer?.isActive ?? false,
      'diagnostics_timer_active': _diagnosticsTimer?.isActive ?? false,
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

  static void _startDiagnosticsTimer() {
    _diagnosticsTimer?.cancel();
    _diagnosticsTimer = Timer.periodic(
      Duration(minutes: collectionIntervals['diagnostics']!),
      (_) => _collectDiagnostics(),
    );
    unawaited(_collectDiagnostics());
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

      await _appendJsonLine('location_data.json', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      await _logEvent('location_error', 'Failed to collect location: $error');
    }
  }

  static Future<void> _collectDiagnostics() async {
    try {
      Map<String, dynamic> deviceInfo = {};

      try {
        final nativeInfo = await _channel.invokeMapMethod<String, dynamic>(
          'getDeviceInfo',
        );
        deviceInfo = nativeInfo ?? {};
      } on MissingPluginException {
        deviceInfo = {};
      }

      await _appendJsonLine('diagnostics.json', {
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion,
        'device_info': deviceInfo,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      await _logEvent('diagnostics_error', 'Failed to collect diagnostics: $error');
    }
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
    final diagnosticsData = allData.where((record) {
      return record['source_file'] == 'diagnostics.json';
    }).length;

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
      'diagnostics_count': diagnosticsData,
      'total_data_files': files,
      'last_update': DateTime.now().toIso8601String(),
    };
  }

  static Future<void> clearAllData() async {
    final logsDir = await _logsDirectory(create: false);
    if (await logsDir.exists()) {
      await logsDir.delete(recursive: true);
    }
    await _logEvent('data_cleared', 'Local monitoring data was cleared.');
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
