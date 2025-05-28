#!/bin/bash

# 使用方法: ./rename_package.sh <新包名>
# 示例: ./rename_package.sh pub.imboy.apk

# 脚本功能
#1. 修改包名目录结构（Java/Kotlin 源码路径）
#2. 修改 AndroidManifest.xml
#3. 修改 build.gradle.kts 和 app/build.gradle.kts
#4. 修改 MainActivity.kt 和 MainActivity.java
#5. 修改 android/app/src/profile/AndroidManifest.xml（如果有）
#6. 修改 android/app/src/debug/AndroidManifest.xml（如果有）
#7. 修改 android/app/src/main/AndroidManifest.xml 中 tools:replace="android:label"

set -e

# ========== 参数校验 ==========
if [ -z "$1" ]; then
    echo "❌ 错误: 请输入新的包名参数，例如 pub.imboy.apk"
    echo "✅ 用法: ./rename_package.sh pub.imboy.apk"
    exit 1
fi

NEW_PKG="$1"
PROJECT_DIR="$(pwd)"
ANDROID_DIR="$PROJECT_DIR/android"
APP_DIR="$ANDROID_DIR/app"

# sed 跨平台封装：兼容 macOS / Linux
function sed_inplace() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$1" "$2"
  else
    sed -i "$1" "$2"
  fi
}

# ========== 获取旧包名 ==========
BUILD_GRADLE_KTS_FILE="$APP_DIR/build.gradle.kts"
OLD_PKG=$(grep -o 'applicationId = "[^"]*"' "$BUILD_GRADLE_KTS_FILE" | cut -d '"' -f2)

if [ -z "$OLD_PKG" ]; then
    OLD_PKG=$(grep -o 'package="[^"]*"' "$APP_DIR/src/main/AndroidManifest.xml" | cut -d '"' -f2)
fi

if [ -z "$OLD_PKG" ]; then
    echo "❌ 无法识别旧包名，脚本终止"
    exit 1
fi

echo "🔁 正在将包名从 [$OLD_PKG] 修改为 [$NEW_PKG]"

# ========== 替换 applicationId & namespace ==========
echo "📝 更新 build.gradle.kts"
sed_inplace "s|applicationId = \".*\"|applicationId = \"$NEW_PKG\"|g" "$BUILD_GRADLE_KTS_FILE"
sed_inplace "s|namespace = \".*\"|namespace = \"$NEW_PKG\"|g" "$BUILD_GRADLE_KTS_FILE"

# ========== 替换所有 Manifest ==========
MANIFEST_FILES=(
    "$APP_DIR/src/main/AndroidManifest.xml"
    "$APP_DIR/src/debug/AndroidManifest.xml"
    "$APP_DIR/src/profile/AndroidManifest.xml"
)

for FILE in "${MANIFEST_FILES[@]}"; do
    if [ -f "$FILE" ]; then
        echo "📝 更新 $FILE"
        sed_inplace "s|package=\"[^\"]*\"|package=\"$NEW_PKG\"|g" "$FILE"
        sed_inplace "s|tools:replace=\"[^\"]*\"|tools:replace=\"android:label,android:name\"|g" "$FILE"
    fi
done

# ========== 替换源文件中的包声明 ==========
echo "🔧 替换 Kotlin/Java 文件中的 package 声明..."

find "$APP_DIR" \( -name "*.kt" -o -name "*.java" \) -print0 | while IFS= read -r -d '' file; do
    grep -q "$OLD_PKG" "$file" && {
        echo "  ✏️ 替换 $file"
        sed_inplace "s|$OLD_PKG|$NEW_PKG|g" "$file"
    }
done

# ========== 移动目录结构 ==========
echo "📁 移动源码目录..."

OLD_PKG_DIR=$(echo "$OLD_PKG" | tr '.' '/')
NEW_PKG_DIR=$(echo "$NEW_PKG" | tr '.' '/')

SRC_DIRS=(
    "$APP_DIR/src/main/java"
    "$APP_DIR/src/main/kotlin"
    "$APP_DIR/src/debug/java"
    "$APP_DIR/src/debug/kotlin"
    "$APP_DIR/src/profile/java"
    "$APP_DIR/src/profile/kotlin"
)

for SRC_DIR in "${SRC_DIRS[@]}"; do
    if [ -d "$SRC_DIR/$OLD_PKG_DIR" ]; then
        mkdir -p "$SRC_DIR/$(dirname "$NEW_PKG_DIR")"
        mv "$SRC_DIR/$OLD_PKG_DIR" "$SRC_DIR/$NEW_PKG_DIR"
        echo "  ✅ 移动 $SRC_DIR/$OLD_PKG_DIR → $SRC_DIR/$NEW_PKG_DIR"
    fi
done

# ========== 清理构建缓存 ==========
echo "🧹 flutter clean & gradle clean"
cd "$PROJECT_DIR"
flutter clean
flutter pub get
cd "$ANDROID_DIR"
./gradlew clean

echo "🎉 包名替换完成：$OLD_PKG → $NEW_PKG"
