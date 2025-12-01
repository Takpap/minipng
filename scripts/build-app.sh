#!/bin/bash

# MiniPNG 打包脚本
# 生成 .app bundle 和 DMG 安装包

set -e

APP_NAME="MiniPNG"
VERSION="1.0.0"
BUNDLE_ID="com.minipng.app"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_DIR="$PROJECT_DIR/dist/$APP_NAME.app"
DMG_DIR="$PROJECT_DIR/dist"

echo "🔨 开始构建 $APP_NAME v$VERSION ..."

# 1. Release 构建
echo "📦 编译 Release 版本..."
cd "$PROJECT_DIR"
swift build -c release

# 2. 创建 .app bundle 结构
echo "📁 创建 App Bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 3. 复制可执行文件
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/"

# 4. 复制压缩工具
echo "🔧 复制压缩工具..."
mkdir -p "$APP_DIR/Contents/Resources/bin"
cp "$PROJECT_DIR/Sources/Resources/bin/"* "$APP_DIR/Contents/Resources/bin/" 2>/dev/null || true

# 5. 创建 Info.plist
echo "📝 创建 Info.plist..."
cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>png</string>
                <string>jpg</string>
                <string>jpeg</string>
                <string>gif</string>
                <string>webp</string>
            </array>
            <key>CFBundleTypeName</key>
            <string>Image</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
        </dict>
    </array>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# 6. 创建 PkgInfo
echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

# 7. 生成应用图标
echo "🎨 生成应用图标..."
swift "$PROJECT_DIR/scripts/generate-icon.swift" 2>/dev/null
iconutil -c icns /tmp/MiniPNG.iconset -o "$APP_DIR/Contents/Resources/AppIcon.icns"

# 8. 设置可执行权限
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/Resources/bin/"* 2>/dev/null || true

echo "✅ App Bundle 创建完成: $APP_DIR"

# 8. 创建 DMG
echo "💿 创建 DMG 安装包..."
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$DMG_DIR/$DMG_NAME"

rm -f "$DMG_PATH"

# 创建临时目录
TMP_DMG_DIR=$(mktemp -d)
cp -r "$APP_DIR" "$TMP_DMG_DIR/"

# 创建 Applications 链接
ln -s /Applications "$TMP_DMG_DIR/Applications"

# 创建 DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$TMP_DMG_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

# 清理
rm -rf "$TMP_DMG_DIR"

echo ""
echo "🎉 打包完成!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📱 App Bundle: $APP_DIR"
echo "💿 DMG 安装包: $DMG_PATH"
echo ""
echo "发送给用户后，双击 DMG 文件，将 $APP_NAME 拖到 Applications 文件夹即可安装。"
