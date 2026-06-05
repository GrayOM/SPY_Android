import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/emergency_profile_service.dart';
import '../services/safe_storage_service.dart';
import '../services/tracking_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _profileNameController = TextEditingController();
  final _birthYearController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _safeTitleController = TextEditingController();
  final _safeCategoryController = TextEditingController();
  final _safeValueController = TextEditingController();

  bool _isSharing = false;
  bool _hasLocationConsent = false;
  bool _hasGalleryConsent = false;
  bool _hasSafeStorageConsent = false;
  bool _isLoading = true;
  List<SafeStorageItem> _safeItems = [];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _profileNameController.dispose();
    _birthYearController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _notesController.dispose();
    _safeTitleController.dispose();
    _safeCategoryController.dispose();
    _safeValueController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await EmergencyProfileService.load();
    final safeItems = await SafeStorageService.getItems();
    if (!mounted) return;

    setState(() {
      _isSharing = prefs.getBool('location_sharing_active') ?? false;
      _hasLocationConsent = prefs.getBool('location_sharing_consent') ?? false;
      _hasGalleryConsent = prefs.getBool('gallery_consent') ?? false;
      _hasSafeStorageConsent = prefs.getBool('safe_storage_consent') ?? false;
      _profileNameController.text = profile.name;
      _birthYearController.text = profile.birthYear;
      _guardianNameController.text = profile.guardianName;
      _guardianPhoneController.text = profile.guardianPhone;
      _notesController.text = profile.notes;
      _safeItems = safeItems;
      _isLoading = false;
    });
  }

  Future<void> _enableLocationConsent() async {
    final accepted = await _showConsentDialog(
      title: 'Share Location With Guardian',
      body:
          'This app can periodically send your physical location to configured guardian backend points and show it on the local guardian web page. You can stop sharing from this screen.',
    );
    if (accepted != true) return;

    final hasPermission = await _requestLocationPermission();
    if (!hasPermission) return;

    await TrackingService.recordLocationConsent();
    if (!mounted) return;
    setState(() => _hasLocationConsent = true);
    _showSnackBar('Location sharing consent saved');
    await _enableGalleryConsent();
  }

  Future<void> _enableGalleryConsent() async {
    final accepted = await _showConsentDialog(
      title: 'Emergency Profile Photo Access',
      body:
          'Allow gallery access so an emergency profile card can include a photo when needed. Android controls the final permission.',
    );
    if (accepted != true) return;

    var status = Platform.isAndroid
        ? await Permission.photos.request()
        : await Permission.storage.request();
    if (Platform.isAndroid && !status.isGranted && !status.isLimited) {
      status = await Permission.storage.request();
    }
    if (!status.isGranted && !status.isLimited) {
      _showSnackBar('Gallery permission was not granted');
      return;
    }

    await EmergencyProfileService.recordGalleryConsent();
    if (!mounted) return;
    setState(() => _hasGalleryConsent = true);
  }

  Future<void> _enableSafeStorageConsent() async {
    final accepted = await _showConsentDialog(
      title: 'Encrypted Safe Storage',
      body:
          'Sensitive reminders are encrypted on this device. The guardian web page shows only title, category, encrypted status, and updated time. Decryption is only performed here after your consent.',
    );
    if (accepted != true) return;

    await SafeStorageService.recordConsent();
    if (!mounted) return;
    setState(() => _hasSafeStorageConsent = true);
  }

  Future<bool> _requestLocationPermission() async {
    var status = await Permission.locationWhenInUse.request();
    if (status.isGranted || status.isLimited) {
      final background = await Permission.locationAlways.request();
      if (!background.isGranted) {
        _showSnackBar('Background permission can be enabled in Android settings for periodic sharing');
      }
      return true;
    }

    if (status.isPermanentlyDenied && mounted) {
      await _showSettingsDialog();
    }
    return false;
  }

  Future<void> _toggleSharing() async {
    if (_isLoading) return;
    if (!_hasLocationConsent) {
      await _enableLocationConsent();
      if (!_hasLocationConsent) return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isSharing) {
        await TrackingService.stopTracking();
        if (!mounted) return;
        setState(() => _isSharing = false);
        _showSnackBar('Location sharing stopped');
      } else {
        await TrackingService.startTracking();
        if (!mounted) return;
        setState(() => _isSharing = true);
        _showSnackBar('Location sharing started');
      }
    } catch (error) {
      _showSnackBar('Unable to update sharing: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareNow() async {
    try {
      await TrackingService.forceLocationShare();
      _showSnackBar('Location update requested');
    } catch (error) {
      _showSnackBar('Unable to share now: $error');
    }
  }

  Future<void> _saveProfile() async {
    await EmergencyProfileService.save(
      EmergencyProfile(
        name: _profileNameController.text.trim(),
        birthYear: _birthYearController.text.trim(),
        guardianName: _guardianNameController.text.trim(),
        guardianPhone: _guardianPhoneController.text.trim(),
        notes: _notesController.text.trim(),
        updatedTime: DateTime.now(),
      ),
    );
    _showSnackBar('Emergency profile saved');
  }

  Future<void> _saveSafeItem() async {
    if (!_hasSafeStorageConsent) {
      await _enableSafeStorageConsent();
      if (!_hasSafeStorageConsent) return;
    }

    final title = _safeTitleController.text.trim();
    final value = _safeValueController.text;
    if (title.isEmpty || value.isEmpty) {
      _showSnackBar('Title and protected value are required');
      return;
    }

    try {
      await SafeStorageService.saveItem(
        title: title,
        category: _safeCategoryController.text.trim().isEmpty
            ? 'Personal'
            : _safeCategoryController.text.trim(),
        plaintext: value,
      );
      _safeTitleController.clear();
      _safeCategoryController.clear();
      _safeValueController.clear();
      final items = await SafeStorageService.getItems();
      if (!mounted) return;
      setState(() => _safeItems = items);
      _showSnackBar('Encrypted item saved');
    } catch (error) {
      _showSnackBar('Unable to save encrypted item: $error');
    }
  }

  Future<void> _revealSafeItem(SafeStorageItem item) async {
    final accepted = await _showConsentDialog(
      title: 'Decrypt This Item',
      body: 'Show this protected value on this device now?',
    );
    if (accepted != true) return;

    try {
      final plaintext = await SafeStorageService.decryptItemWithConsent(item);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(item.title),
          content: SelectableText(plaintext),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showSnackBar('Unable to decrypt item: $error');
    }
  }

  Future<bool?> _showConsentDialog({
    required String title,
    required String body,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Agree'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSettingsDialog() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Settings'),
        content: const Text('Enable location permission in Android settings to share location.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildConsentTile({
    required IconData icon,
    required String title,
    required bool granted,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: granted ? Colors.green : Colors.orange),
      title: Text(title),
      trailing: granted
          ? const Icon(Icons.check_circle, color: Colors.green)
          : TextButton(onPressed: onTap, child: const Text('Agree')),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Android_helper'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          _isSharing ? Icons.location_on : Icons.location_off_outlined,
                          size: 52,
                          color: _isSharing ? theme.colorScheme.primary : theme.disabledColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isSharing ? 'Sharing with guardian' : 'Location sharing is off',
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Share your latest location with configured guardian access. You can stop sharing at any time.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _toggleSharing,
                                icon: Icon(_isSharing ? Icons.stop : Icons.play_arrow),
                                label: Text(_isSharing ? 'Stop Sharing' : 'Start Sharing'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: _isSharing ? _shareNow : null,
                              icon: const Icon(Icons.my_location),
                              tooltip: 'Share now',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Consent', style: theme.textTheme.titleMedium),
                        _buildConsentTile(
                          icon: Icons.location_on_outlined,
                          title: 'Guardian location sharing',
                          granted: _hasLocationConsent,
                          onTap: _enableLocationConsent,
                        ),
                        _buildConsentTile(
                          icon: Icons.photo_library_outlined,
                          title: 'Gallery access for emergency card',
                          granted: _hasGalleryConsent,
                          onTap: _enableGalleryConsent,
                        ),
                        _buildConsentTile(
                          icon: Icons.lock_outline,
                          title: 'Encrypted safe storage',
                          granted: _hasSafeStorageConsent,
                          onTap: _enableSafeStorageConsent,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Emergency Profile Card', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _buildTextField(_profileNameController, 'Name'),
                        _buildTextField(
                          _birthYearController,
                          'Birth year',
                          keyboardType: TextInputType.number,
                        ),
                        _buildTextField(_guardianNameController, 'Guardian name'),
                        _buildTextField(
                          _guardianPhoneController,
                          'Guardian phone',
                          keyboardType: TextInputType.phone,
                        ),
                        _buildTextField(_notesController, 'Medical notes', maxLines: 3),
                        FilledButton.icon(
                          onPressed: _saveProfile,
                          icon: const Icon(Icons.badge_outlined),
                          label: const Text('Save Profile Card'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Encrypted Safe Storage', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _buildTextField(_safeTitleController, 'Item title'),
                        _buildTextField(_safeCategoryController, 'Category'),
                        _buildTextField(
                          _safeValueController,
                          'Protected value',
                          obscureText: true,
                        ),
                        FilledButton.icon(
                          onPressed: _saveSafeItem,
                          icon: const Icon(Icons.lock),
                          label: const Text('Encrypt and Save'),
                        ),
                        const SizedBox(height: 8),
                        ..._safeItems.map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.lock_outline),
                            title: Text(item.title),
                            subtitle: Text('${item.category} - Encrypted - ${item.updatedTime.toLocal()}'),
                            trailing: IconButton(
                              onPressed: () => _revealSafeItem(item),
                              icon: const Icon(Icons.visibility_outlined),
                              tooltip: 'Decrypt with consent',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
