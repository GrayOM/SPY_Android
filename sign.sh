#!/bin/bash

# 🔥 NOX 에뮬레이터 호환 APK 빌드 스크립트
echo "🎯 Building APK for NOX Emulator..."

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

set -e

echo -e "${BLUE}🧹 Cleaning previous builds...${NC}"
flutter clean
rm -rf android/.gradle/
rm -rf android/build/
rm -rf build/

echo -e "${BLUE}📦 Getting dependencies...${NC}"
flutter pub get

echo -e "${BLUE}⚙️  Configuring for NOX compatibility...${NC}"

# NOX 호환을 위한 Gradle 설정
cat > android/gradle.properties << 'EOF'
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G
org.gradle.daemon=true
org.gradle.parallel=false
android.useAndroidX=true
android.enableJetifier=true
android.enableR8=false
EOF

echo -e "${BLUE}🔧 Building debug APK (NOX compatible)...${NC}"
flutter build apk \
    --debug \
    --target-platform android-arm,android-x86 \
    --no-shrink \
    --no-obfuscate

echo -e "${BLUE}📱 Building release APK (NOX compatible)...${NC}"
flutter build apk \
    --release \
    --target-platform android-arm,android-x86 \
    --no-shrink \
    --no-obfuscate

# APK 파일 정리
OUTPUT_DIR="build/nox_apks"
mkdir -p "$OUTPUT_DIR"

# 디버그 APK 복사
if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
    cp "build/app/outputs/flutter-apk/app-debug.apk" "$OUTPUT_DIR/SpyAndroid_NOX_Debug.apk"
    echo -e "${GREEN}✅ Debug APK: $OUTPUT_DIR/SpyAndroid_NOX_Debug.apk${NC}"
fi

# 릴리즈 APK 복사  
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    cp "build/app/outputs/flutter-apk/app-release.apk" "$OUTPUT_DIR/SpyAndroid_NOX_Release.apk"
    echo -e "${GREEN}✅ Release APK: $OUTPUT_DIR/SpyAndroid_NOX_Release.apk${NC}"
fi

echo -e "${BLUE}📊 APK Information:${NC}"
for apk in "$OUTPUT_DIR"/*.apk; do
    if [ -f "$apk" ]; then
        size=$(du -h "$apk" | cut -f1)
        echo -e "${YELLOW}  📱 $(basename "$apk") - Size: $size${NC}"
    fi
done

# NOX 설치 가이드
cat > "$OUTPUT_DIR/NOX_INSTALLATION_GUIDE.md" << 'EOF'
# 🎯 NOX 에뮬레이터 설치 가이드

## 📱 APK 파일 설명

### SpyAndroid_NOX_Debug.apk
- NOX 에뮬레이터 최적화된 디버그 버전
- 안정성 우선, 디버깅 정보 포함
- 권장 설치 파일

### SpyAndroid_NOX_Release.apk
- 릴리즈 버전 (크기 최적화)

## 🔧 NOX 설정

### 1. NOX 에뮬레이터 설정
```
- Android 버전: Android 7 (API 24) 이상
- RAM: 4GB 이상 권장
- CPU: 4코어 이상
- Graphics: DirectX/OpenGL 호환 모드
```

### 2. 설치 전 NOX 설정
1. NOX 설정 → 고급 설정
2. "알 수 없는 소스 허용" 체크
3. "USB 디버깅 허용" 체크
4. 가상화 기술 활성화

### 3. 설치 방법

#### 방법 1: 드래그 앤 드롭
1. APK 파일을 NOX 창으로 드래그
2. "설치" 버튼 클릭
3. 설치 완료 대기

#### 방법 2: APK 설치 도구
1. NOX 우측 도구모음에서 "APK 설치" 클릭
2. APK 파일 선택
3. 설치 진행

#### 방법 3: ADB 명령어
```bash
# NOX ADB 연결 (NOX가 실행된 상태에서)
adb connect 127.0.0.1:62001

# APK 설치
adb install SpyAndroid_NOX_Debug.apk

# 권한 자동 부여
adb shell pm grant com.example.spy_android android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.example.spy_android android.permission.READ_EXTERNAL_STORAGE
```

## 🚨 문제 해결

### "앱 설치 불가" 오류
1. NOX 재시작
2. "알 수 없는 소스" 설정 재확인
3. 다른 APK 파일 시도 (Debug → Release)
4. NOX Android 버전 확인 (7.0 이상)

### "앱이 실행되지 않음"
1. NOX RAM 설정 4GB 이상 증가
2. 가상화 기술 (VT) 활성화 확인
3. NOX 버전 업데이트

### "권한 오류"
1. 앱 설정 → 권한에서 수동 허용
2. ADB 명령어로 권한 부여
3. NOX 설정에서 "모든 권한 허용" 활성화

## ⚙️ 최적화 설정

### NOX 성능 최적화
```
CPU: 4코어
RAM: 4GB
Graphics: 호환 모드
해상도: 1280x720 (16:9)
DPI: 240
```

---
생성일: $(date)
대상 에뮬레이터: NOX Player
호환 Android 버전: 7.0+ (API 24+)
EOF

echo -e "${GREEN}🎉 NOX 호환 APK 빌드 완료!${NC}"
echo -e "${YELLOW}📁 출력 디렉토리: $OUTPUT_DIR${NC}"
echo -e "${YELLOW}📖 설치 가이드: $OUTPUT_DIR/NOX_INSTALLATION_GUIDE.md${NC}"

echo -e "${BLUE}🔧 다음 단계:${NC}"
echo -e "  1. NOX에서 '알 수 없는 소스' 허용"
echo -e "  2. APK를 NOX로 드래그 앤 드롭"
echo -e "  3. 설치 완료 후 권한 허용"
echo -e "  4. 앱 실행 및 모니터링 시작"