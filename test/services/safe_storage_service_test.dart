import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spy_android/services/safe_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const androidHelperChannel = MethodChannel('android_helper');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(androidHelperChannel, (call) async {
      final arguments = call.arguments as Map<Object?, Object?>? ?? {};
      switch (call.method) {
        case 'encryptSecret':
          return 'encrypted:${arguments['plaintext']}';
        case 'decryptSecret':
          final payload = arguments['payload'].toString();
          return payload.replaceFirst('encrypted:', '');
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(androidHelperChannel, null);
  });

  test('recordConsent persists safe storage consent', () async {
    expect(await SafeStorageService.hasConsent(), isFalse);

    await SafeStorageService.recordConsent();

    expect(await SafeStorageService.hasConsent(), isTrue);
  });

  test('saveItem requires consent', () async {
    await expectLater(
      SafeStorageService.saveItem(
        title: 'Bank safe note',
        category: 'Finance',
        plaintext: '1234',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('saveItem encrypts via MethodChannel and stores encrypted metadata', () async {
    await SafeStorageService.recordConsent();

    await SafeStorageService.saveItem(
      title: 'Asset reminder',
      category: 'Finance',
      plaintext: 'private-key',
    );

    final items = await SafeStorageService.getItems();
    expect(items, hasLength(1));
    expect(items.single.title, 'Asset reminder');
    expect(items.single.category, 'Finance');
    expect(items.single.encryptedPayload, 'encrypted:private-key');
    expect(items.single.isEncrypted, isTrue);
  });

  test('decryptItemWithConsent decrypts through MethodChannel', () async {
    await SafeStorageService.recordConsent();
    final item = SafeStorageItem(
      id: '1',
      title: 'Recovery phrase',
      category: 'Finance',
      encryptedPayload: 'encrypted:phrase',
      updatedTime: DateTime(2026),
    );

    final plaintext = await SafeStorageService.decryptItemWithConsent(item);

    expect(plaintext, 'phrase');
  });

  test('native crypto errors are exposed as StateError', () async {
    await SafeStorageService.recordConsent();
    messenger.setMockMethodCallHandler(androidHelperChannel, (call) async {
      throw PlatformException(
        code: 'KEYSTORE_UNAVAILABLE',
        message: 'Android Keystore is unavailable on this device.',
      );
    });

    await expectLater(
      SafeStorageService.saveItem(
        title: 'Item',
        category: 'Personal',
        plaintext: 'secret',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('KEYSTORE_UNAVAILABLE'),
        ),
      ),
    );
  });

  test('getItems skips malformed stored rows and sorts newest first', () async {
    SharedPreferences.setMockInitialValues({
      'safe_storage_items': [
        'not-json',
        jsonEncode({
          'id': 'old',
          'title': 'Old',
          'category': 'Personal',
          'encryptedPayload': 'encrypted:old',
          'updatedTime': '2026-06-04T00:00:00.000Z',
        }),
        jsonEncode({
          'id': 'new',
          'title': 'New',
          'category': 'Personal',
          'encryptedPayload': 'encrypted:new',
          'updatedTime': '2026-06-05T00:00:00.000Z',
        }),
      ],
    });

    final items = await SafeStorageService.getItems();

    expect(items.map((item) => item.id), ['new', 'old']);
  });

  test('deleteItem removes only matching item', () async {
    SharedPreferences.setMockInitialValues({
      'safe_storage_items': [
        jsonEncode({
          'id': 'keep',
          'title': 'Keep',
          'category': 'Personal',
          'encryptedPayload': 'encrypted:keep',
          'updatedTime': '2026-06-05T00:00:00.000Z',
        }),
        jsonEncode({
          'id': 'delete',
          'title': 'Delete',
          'category': 'Personal',
          'encryptedPayload': 'encrypted:delete',
          'updatedTime': '2026-06-04T00:00:00.000Z',
        }),
      ],
    });

    await SafeStorageService.deleteItem('delete');

    final items = await SafeStorageService.getItems();
    expect(items, hasLength(1));
    expect(items.single.id, 'keep');
  });
}
