#!/bin/bash
set -e

# ==============================================================================
# Hakoniwa (箱庭) - 精美 DMG 安装镜像一键构建与打包脚本
# ==============================================================================

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
OUTPUT_DIR="${PROJECT_DIR}/dist"

SCHEME_NAME="Hakoniwa"
APP_NAME="Hakoniwa"

echo "=========================================="
echo "  🚀 开始构建并打包精美 DMG: ${APP_NAME}..."
echo "=========================================="

# 0. 卸载可能已存在的挂载卷
hdiutil detach "/Volumes/${APP_NAME}" -quiet 2>/dev/null || true
hdiutil detach "/Volumes/${APP_NAME} 1" -quiet 2>/dev/null || true

# 1. 清理并准备临时目录
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
mkdir -p "${OUTPUT_DIR}"

# 2. 自动通过 PixelEngine 渲染箱庭同款 3D 像素透视背景图 (零手动干预，无文字图形化指引)
echo "🎨 正在通过 PixelEngine 渲染箱庭同款 3D 像素全景背景图..."
swiftc -O "${PROJECT_DIR}/Hakoniwa/Core/MathUtils.swift" \
          "${PROJECT_DIR}/Hakoniwa/Core/PixelEngine.swift" \
          "${PROJECT_DIR}/Scripts/generate_dmg_background.swift" \
          -o "${BUILD_DIR}/generate_dmg_background"
"${BUILD_DIR}/generate_dmg_background" "${PROJECT_DIR}"

# 3. 确保 AppIcon.icns 存在 (如缺失则通过原生 sips/iconutil 自动全量生成)
if [ ! -f "${PROJECT_DIR}/Hakoniwa/AppIcon.icns" ]; then
    echo "🎨 正在生成全套分辨率 AppIcon.icns..."
    mkdir -p /tmp/Hakoniwa.iconset
    SRC_ICON="${PROJECT_DIR}/Hakoniwa/Assets.xcassets/AppIcon.appiconset/app_icon_512@2x.png"
    sips -z 16 16     "${SRC_ICON}" --out /tmp/Hakoniwa.iconset/icon_16x16.png >/dev/null
    sips -z 32 32     "${SRC_ICON}" --out /tmp/Hakoniwa.iconset/icon_16x16@2x.png >/dev/null
    sips -z 32 32     "${SRC_ICON}" --out /tmp/Hakoniwa.iconset/icon_32x32.png >/dev/null
    sips -z 64 64     "${SRC_ICON}" --out /tmp/Hakoniwa.iconset/icon_32x32@2x.png >/dev/null
    sips -z 128 128   "${SRC_ICON}" --out /tmp/Hakoniwa.iconset/icon_128x128.png >/dev/null
    sips -z 256 256   "${SRC_ICON}" --out /tmp/Hakoniwa.iconset/icon_128x128@2x.png >/dev/null
    sips -z 256 256   "${SRC_ICON}" --out /tmp/Hakoniwa.iconset/icon_256x256.png >/dev/null
    sips -z 512 512   "${SRC_ICON}" --out /tmp/Hakoniwa.iconset/icon_256x256@2x.png >/dev/null
    sips -z 512 512   "${SRC_ICON}" --out /tmp/Hakoniwa.iconset/icon_512x512.png >/dev/null
    sips -z 1024 1024 "${SRC_ICON}" --out /tmp/Hakoniwa.iconset/icon_512x512@2x.png >/dev/null
    iconutil -c icns /tmp/Hakoniwa.iconset -o "${PROJECT_DIR}/Hakoniwa/AppIcon.icns"
    rm -rf /tmp/Hakoniwa.iconset
fi

# 4. 执行 Xcode Release 编译
echo "📦 正在编译 Release 版本 (优化级别 -O)..."
xcodebuild -scheme "${SCHEME_NAME}" \
           -configuration Release \
           -destination "platform=macOS" \
           CONFIGURATION_BUILD_DIR="${BUILD_DIR}/Release" \
           clean build \
           -quiet

APP_PATH="${BUILD_DIR}/Release/${APP_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
    echo "❌ 错误: 未找到编译生成的 ${APP_PATH}"
    exit 1
fi

# 5. 确保 AppIcon.icns 注入进 App Bundle 的 Resources 目录
cp -f "${PROJECT_DIR}/Hakoniwa/AppIcon.icns" "${APP_PATH}/Contents/Resources/AppIcon.icns"

# 6. 读取版本号
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || echo "1.0.0")
DMG_NAME="${APP_NAME}-v${VERSION}.dmg"
DMG_OUTPUT_PATH="${OUTPUT_DIR}/${DMG_NAME}"

echo "📋 应用版本: v${VERSION}"

# 7. 创建临时可读写 DMG 镜像
echo "📂 正在挂载临时 DMG 并定制 Finder 视觉外观与精准对齐..."
TMP_DMG="${BUILD_DIR}/temp.dmg"
rm -f "${TMP_DMG}"
hdiutil create -size 120m -fs HFS+ -volname "${APP_NAME}" -ov "${TMP_DMG}" -quiet

ATTACH_OUTPUT=$(hdiutil attach "${TMP_DMG}" -readwrite -noverify -noautoopen)
DEVICE=$(echo "${ATTACH_OUTPUT}" | grep "/Volumes/" | head -n 1 | awk '{print $1}')
MOUNT_DIR=$(echo "${ATTACH_OUTPUT}" | grep "/Volumes/" | head -n 1 | awk '{print $3}')
DISK_NAME=$(basename "${MOUNT_DIR}")

echo "   挂载设备: ${DEVICE} -> ${MOUNT_DIR} (卷名: ${DISK_NAME})"

# 8. 拷贝内容至 DMG
cp -R "${APP_PATH}" "${MOUNT_DIR}/"
ln -s /Applications "${MOUNT_DIR}/Applications"

# 拷贝背景图至隐藏目录
mkdir -p "${MOUNT_DIR}/.background"
cp -f "${PROJECT_DIR}/Scripts/dmg_background.png" "${MOUNT_DIR}/.background/background.png"

# 写入 DMG 卷宗自定义图标 (使加载的磁盘在桌面和访达侧边栏显示箱庭专属图标)
cp -f "${PROJECT_DIR}/Hakoniwa/AppIcon.icns" "${MOUNT_DIR}/.VolumeIcon.icns"
SetFile -c icnC "${MOUNT_DIR}/.VolumeIcon.icns" 2>/dev/null || true
SetFile -a C "${MOUNT_DIR}" 2>/dev/null || true

# 9. 通过 AppleScript 配置访达视觉布局、图标绝对对齐以及彻底移开隐藏文件
osascript <<EOF
tell application "Finder"
    tell disk "${DISK_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 560} -- 660 x 440
        set opts to the icon view options of container window
        tell opts
            set icon size to 120
            set text size to 12
            set arrangement to not arranged
        end tell
        set background picture of opts to file ".background:background.png"
        
        -- 将全部项目先移至窗口视口外部 (x:2000, y:2000)
        -- 解决用户开启“显示隐藏文件”时 .background、.VolumeIcon.icns 等杂项文件出现在画面的问题
        set position of every item of container window to {2000, 2000}
        
        -- 精确定位两个核心项目与背景基座及发光箭头完美对齐
        set position of item "${APP_NAME}.app" of container window to {175, 175}
        set position of item "Applications" of container window to {485, 175}
        
        close
        open
        delay 1
        tell container window
            set the bounds to {200, 120, 859, 559}
        end tell
        delay 0.5
        tell container window
            set the bounds to {200, 120, 860, 560}
        end tell
        delay 2
        close
    end tell
end tell
EOF

# 10. 卸载临时磁盘
sync
hdiutil detach "${DEVICE}" -quiet

# 11. 最终压缩转换成高度压缩的只读 UDZO 镜像
echo "💿 正在压制最终发布版 DMG 镜像文件..."
rm -f "${DMG_OUTPUT_PATH}"
hdiutil convert "${TMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_OUTPUT_PATH}" -ov -quiet
rm -f "${TMP_DMG}"

echo "=========================================="
echo "  🎉 精美定制版 DMG 打包成功！"
echo "  📦 DMG 镜像文件: ${DMG_OUTPUT_PATH}"
echo "  📊 文件大小: $(du -sh "${DMG_OUTPUT_PATH}" | awk '{print $1}')"
echo "=========================================="
