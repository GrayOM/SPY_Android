import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SafeStorageItem {
  const SafeStorageItem({
    required this.id,
    required this.title,
    required this.category,
    required this.encryptedPayload,
    required this.updatedTime,
  });

  final String id;
  final String title;
  final String category;
  final String encryptedPayload;
  final DateTime updatedTime;

  bool get isEncrypted => encryptedPayload.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'encryptedPayload': encryptedPayload,
      'updatedTime': updatedTime.toIso8601String(),
    };
  }

  static SafeStorageItem fromJson(Map<String, dynamic> json) {
    return SafeStorageItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      encryptedPayload: json['encryptedPayload']?.toString() ?? '',
      updatedTime: DateTime.tryParse(json['updatedTime']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class SafeStorageService {
  static const MethodChannel _channel = MethodChannel('android_helper');
  static const _itemsKey = 'safe_storage_items';
  static const _consentKey = 'safe_storage_consent';

  static Future<void> recordConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, true);
  }

  static Future<bool> hasConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  }

  static Future<List<SafeStorageItem>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getStringList(_itemsKey) ?? const [];
    return encoded.map(_decodeItem).whereType<SafeStorageItem>().toList()
      ..sort((a, b) => b.updatedTime.compareTo(a.updatedTime));
  }

  static Future<void> saveItem({
    required String title,
    required String category,
    required String plaintext,
  }) async {
    if (!await hasConsent()) {
      throw StateError('Safe storage consent is required.');
    }

    final encryptedPayload = await _invokeNativeCrypto(
      'encryptSecret',
      {'plaintext': plaintext},
    );
    if (encryptedPayload == null || encryptedPayload.isEmpty) {
      throw StateError('Encryption failed.');
    }

    final items = await getItems();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    items.insert(
      0,
      SafeStorageItem(
        id: id,
        title: title,
        category: category,
        encryptedPayload: encryptedPayload,
        updatedTime: DateTime.now(),
      ),
    );
    await _writeItems(items);
  }

  static Future<String> decryptItemWithConsent(SafeStorageItem item) async {
    if (!await hasConsent()) {
      throw StateError('Safe storage consent is required.');
    }

    final plaintext = await _invokeNativeCrypto(
      'decryptSecret',
      {'payload': item.encryptedPayload},
    );
    if (plaintext == null) {
      throw StateError('Unable to decrypt this item.');
    }
    return plaintext;
  }

  static Future<void> deleteItem(String id) async {
    final items = await getItems();
    items.removeWhere((item) => item.id == id);
    await _writeItems(items);
  }

  static Future<void> _writeItems(List<SafeStorageItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _itemsKey,
      items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  static SafeStorageItem? _decodeItem(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map) {
        return SafeStorageItem.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<String?> _invokeNativeCrypto(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      return _channel.invokeMethod<String>(method, arguments);
    } on PlatformException catch (error) {
      throw StateError(
        '${error.code}: ${error.message ?? 'Native safe-storage operation failed.'}',
      );
    }
  }
}
