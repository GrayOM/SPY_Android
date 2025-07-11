# PowerShell에서 실행
cd C:\Users\PSM\StudioProjects\spy_android

# 1. gradle.properties 완전 재생성
@"
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G
org.gradle.daemon=true
org.gradle.parallel=false
android.useAndroidX=true
android.enableJetifier=true
"@ | Out-File -FilePath "android\gradle.properties" -Encoding UTF8

# 2. 모든 캐시 삭제
Remove-Item -Recurse -Force "android\.gradle" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "android\build" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "build" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "android\app\build" -ErrorAction SilentlyContinue

# 3. Gradle 캐시도 정리
Remove-Item -Recurse -Force "$env:USERPROFILE\.gradle\caches" -ErrorAction SilentlyContinue

# 4. Flutter 클린
flutter clean

# 5. pub 캐시 정리
flutter pub cache clean -f
flutter pub get

# 6. 빌드 재시도
flutter build apk --debug