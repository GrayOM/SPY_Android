import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spy_android/services/tracking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('tracking_service_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saveBackendEndpoints writes endpoints and appends logs.json event', () async {
    await TrackingService.saveBackendEndpoints(
      'https://guardian.example/location\nhttps://backup.example/location',
    );

    expect(
      await TrackingService.getBackendEndpoints(),
      [
        'https://guardian.example/location',
        'https://backup.example/location',
      ],
    );

    final logs = await TrackingService.getEventLogs();
    expect(logs, hasLength(1));
    expect(logs.single['type'], 'backend_endpoints_updated');
    expect(logs.single['message'], '2 endpoint(s) configured.');
    expect(DateTime.tryParse(logs.single['timestamp'].toString()), isNotNull);

    final logsFile = File('${tempDir.path}/logs/logs.json');
    expect(await logsFile.exists(), isTrue);
    expect(jsonDecode(await logsFile.readAsString()), isA<List>());
  });

  test('getCollectedData, getLocationData, and getEventData share parsed records', () async {
    final logsDir = Directory('${tempDir.path}/logs');
    await logsDir.create(recursive: true);
    await File('${logsDir.path}/location_data.json').writeAsString(
      '${jsonEncode({
            'latitude': 37.1,
            'longitude': 127.2,
            'timestamp': '2026-06-05T02:00:00.000Z',
          })}\n',
    );
    await File('${logsDir.path}/logs.json').writeAsString(
      jsonEncode([
        {
          'timestamp': '2026-06-05T03:00:00.000Z',
          'type': 'sharing_started',
          'message': 'Location sharing started.',
        }
      ]),
    );

    final all = await TrackingService.getCollectedData();
    final locations = await TrackingService.getLocationData();
    final events = await TrackingService.getEventData();

    expect(all, hasLength(2));
    expect(locations, hasLength(1));
    expect(locations.single['latitude'], 37.1);
    expect(events, hasLength(1));
    expect(events.single['type'], 'sharing_started');
  });

  test('guardian admin token is stable, validatable, and rotatable', () async {
    final first = await TrackingService.getGuardianAdminToken();
    final second = await TrackingService.getGuardianAdminToken();

    expect(first, isNotEmpty);
    expect(second, first);
    expect(await TrackingService.isGuardianAdminTokenValid(first), isTrue);
    expect(await TrackingService.isGuardianAdminTokenValid('wrong-token'), isFalse);
    expect(await TrackingService.isGuardianAdminTokenValid(null), isFalse);

    final rotated = await TrackingService.rotateGuardianAdminToken();
    expect(rotated, isNot(first));
    expect(await TrackingService.isGuardianAdminTokenValid(rotated), isTrue);
    expect(await TrackingService.isGuardianAdminTokenValid(first), isFalse);
  });

  test('clearAllData removes prior records and writes clear event', () async {
    final logsDir = Directory('${tempDir.path}/logs');
    await logsDir.create(recursive: true);
    await File('${logsDir.path}/location_data.json').writeAsString(
      '${jsonEncode({
            'latitude': 37.1,
            'longitude': 127.2,
            'timestamp': '2026-06-05T02:00:00.000Z',
          })}\n',
    );

    await TrackingService.clearAllData();

    final locations = await TrackingService.getLocationData();
    final events = await TrackingService.getEventLogs();

    expect(locations, isEmpty);
    expect(events, hasLength(1));
    expect(events.single['type'], 'data_cleared');
  });
}
