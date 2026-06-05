import 'package:shared_preferences/shared_preferences.dart';

class EmergencyProfile {
  const EmergencyProfile({
    required this.name,
    required this.birthYear,
    required this.guardianName,
    required this.guardianPhone,
    required this.notes,
    required this.updatedTime,
  });

  final String name;
  final String birthYear;
  final String guardianName;
  final String guardianPhone;
  final String notes;
  final DateTime? updatedTime;
}

class EmergencyProfileService {
  static const _nameKey = 'emergency_profile_name';
  static const _birthYearKey = 'emergency_profile_birth_year';
  static const _guardianNameKey = 'emergency_profile_guardian_name';
  static const _guardianPhoneKey = 'emergency_profile_guardian_phone';
  static const _notesKey = 'emergency_profile_notes';
  static const _updatedTimeKey = 'emergency_profile_updated_time';
  static const _galleryConsentKey = 'gallery_consent';

  static Future<void> recordGalleryConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_galleryConsentKey, true);
  }

  static Future<bool> hasGalleryConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_galleryConsentKey) ?? false;
  }

  static Future<EmergencyProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return EmergencyProfile(
      name: prefs.getString(_nameKey) ?? '',
      birthYear: prefs.getString(_birthYearKey) ?? '',
      guardianName: prefs.getString(_guardianNameKey) ?? '',
      guardianPhone: prefs.getString(_guardianPhoneKey) ?? '',
      notes: prefs.getString(_notesKey) ?? '',
      updatedTime: DateTime.tryParse(prefs.getString(_updatedTimeKey) ?? ''),
    );
  }

  static Future<void> save(EmergencyProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, profile.name);
    await prefs.setString(_birthYearKey, profile.birthYear);
    await prefs.setString(_guardianNameKey, profile.guardianName);
    await prefs.setString(_guardianPhoneKey, profile.guardianPhone);
    await prefs.setString(_notesKey, profile.notes);
    await prefs.setString(_updatedTimeKey, DateTime.now().toIso8601String());
  }
}
