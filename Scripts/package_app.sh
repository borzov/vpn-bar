#!/bin/bash

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Пути
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="VPNBarApp"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

BUILD_DIR="$PROJECT_DIR/.build/release"
BIN_DIR=$(cd "$PROJECT_DIR" && swift build -c release --arch arm64 --arch x86_64 --show-bin-path 2>/dev/null)
if [ -n "$BIN_DIR" ] && [ -f "$BIN_DIR/$APP_NAME" ]; then
  BUILD_DIR="$BIN_DIR"
else
  BIN_DIR=$(cd "$PROJECT_DIR" && swift build -c release --show-bin-path 2>/dev/null)
  if [ -n "$BIN_DIR" ] && [ -f "$BIN_DIR/$APP_NAME" ]; then
    BUILD_DIR="$BIN_DIR"
  elif [ ! -f "$BUILD_DIR/$APP_NAME" ]; then
    EXEC_PATH=$(find "$PROJECT_DIR/.build" -type f -name "$APP_NAME" 2>/dev/null | head -1)
    if [ -n "$EXEC_PATH" ]; then
      BUILD_DIR=$(dirname "$EXEC_PATH")
    fi
  fi
fi

echo -e "${GREEN}Создание .app bundle для $APP_NAME...${NC}"

if [ ! -f "$BUILD_DIR/$APP_NAME" ]; then
    echo -e "${RED}Ошибка: Исполняемый файл не найден. Сначала выполните: swift build -c release${NC}"
    exit 1
fi

# Удаляем старый bundle если существует
if [ -d "$APP_BUNDLE" ]; then
    echo -e "${YELLOW}Удаление старого .app bundle...${NC}"
    rm -rf "$APP_BUNDLE"
fi

# Создаем структуру директорий
echo -e "${GREEN}Создание структуры .app bundle...${NC}"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Копируем исполняемый файл
echo -e "${GREEN}Копирование исполняемого файла...${NC}"
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Копируем иконку если есть
if [ -f "$PROJECT_DIR/VPNBarApp.icns" ]; then
    echo -e "${GREEN}Копирование иконки...${NC}"
    cp "$PROJECT_DIR/VPNBarApp.icns" "$RESOURCES_DIR/"
fi

# Копируем локализованные ресурсы
SOURCE_RESOURCES_DIR="$PROJECT_DIR/Sources/VPNBarApp/Resources"
if [ -d "$SOURCE_RESOURCES_DIR" ]; then
    echo -e "${GREEN}Копирование локализованных ресурсов...${NC}"
    # Копируем все .lproj директории из исходников
    find "$SOURCE_RESOURCES_DIR" -type d -name "*.lproj" -exec cp -R {} "$RESOURCES_DIR/" \;
    echo -e "${GREEN}Скопировано локализаций: $(find "$RESOURCES_DIR" -type d -name "*.lproj" | wc -l | tr -d ' ')${NC}"
else
    echo -e "${YELLOW}Предупреждение: Директория ресурсов не найдена: $SOURCE_RESOURCES_DIR${NC}"
fi

# Создаем entitlements если нужно
if [ ! -f "$CONTENTS_DIR/Entitlements.plist" ]; then
    echo -e "${GREEN}Создание Entitlements.plist...${NC}"
    cat > "$CONTENTS_DIR/Entitlements.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.personal-information.location</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
EOF
fi

# Создаем Info.plist (всегда пересоздаем)
echo -e "${GREEN}Создание Info.plist...${NC}"
rm -f "$CONTENTS_DIR/Info.plist"
cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.borzov.VPNBar</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>VPN Bar</string>
    <key>CFBundleDisplayName</key>
    <string>VPN Bar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.8.1</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>ru</string>
        <string>zh-Hans</string>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025</string>
    <key>CFBundleIconFile</key>
    <string>VPNBarApp</string>
    <key>NSUserNotificationAlertStyle</key>
    <string>banner</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSExceptionDomains</key>
        <dict>
            <key>ip-api.com</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
            </dict>
        </dict>
    </dict>
</dict>
</plist>
EOF

echo -e "${GREEN}✓ .app bundle создан: $APP_BUNDLE${NC}"
echo -e "${GREEN}Можно запустить: open $APP_BUNDLE${NC}"

