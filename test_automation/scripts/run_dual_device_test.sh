#!/bin/bash

# 双设备聊天测试脚本
# 测试场景：03_dual_device_chat.yaml

set -e

PROJECT_DIR="/Users/leeyi/project/imboy.pub/imboyapp"
LOG_DIR="${PROJECT_DIR}/test_automation/logs"
SCREENSHOT_DIR="${PROJECT_DIR}/test_automation/screenshots"

# 创建必要的目录
mkdir -p "$LOG_DIR"
mkdir -p "$SCREENSHOT_DIR"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 检查设备
check_devices() {
    log "检查可用设备..."
    cd "$PROJECT_DIR"
    flutter devices > "$LOG_DIR/devices.log" 2>&1
    cat "$LOG_DIR/devices.log"
}

# 启动 macOS 应用
start_macos_app() {
    log "在 macOS 上启动应用（账号：108@imboy.pub）..."
    cd "$PROJECT_DIR"
    nohup flutter run -d macos > "$LOG_DIR/macos_app.log" 2>&1 &
    MACOS_PID=$!
    echo $MACOS_PID > "$LOG_DIR/macos.pid"
    log "macOS 应用已启动，PID: $MACOS_PID"
    sleep 5
}

# 启动 iOS 应用
start_ios_app() {
    log "在 iOS 上启动应用（账号：118@imboy.pub）..."
    cd "$PROJECT_DIR"

    # 检查 iOS 设备
    IOS_DEVICE=$(flutter devices | grep -E "ios|iPhone" | head -1 | awk '{print $1}')

    if [ -z "$IOS_DEVICE" ]; then
        error "未找到 iOS 设备，尝试启动模拟器..."
        flutter emulators --launch apple_ios_simulator
        sleep 10
        IOS_DEVICE=$(flutter devices | grep -E "ios|iPhone" | head -1 | awk '{print $1}')
    fi

    if [ -z "$IOS_DEVICE" ]; then
        error "无法找到 iOS 设备"
        return 1
    fi

    log "使用 iOS 设备: $IOS_DEVICE"
    nohup flutter run -d "$IOS_DEVICE" > "$LOG_DIR/ios_app.log" 2>&1 &
    IOS_PID=$!
    echo $IOS_PID > "$LOG_DIR/ios.pid"
    log "iOS 应用已启动，PID: $IOS_PID"
    sleep 5
}

# 等待应用启动
wait_for_app() {
    local app_name=$1
    local log_file=$2
    local timeout=300  # 5 分钟超时
    local elapsed=0

    log "等待 $app_name 应用启动..."
    while [ $elapsed -lt $timeout ]; do
        if grep -q "Flutter run key commands" "$log_file" 2>/dev/null; then
            log "$app_name 应用启动成功！"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        echo -n "."
    done
    echo ""
    error "$app_name 应用启动超时"
    return 1
}

# 主测试流程
main() {
    log "========== 开始双设备聊天测试 =========="
    log "测试场景: 03_dual_device_chat.yaml"

    # 检查设备
    check_devices

    # 启动 macOS 应用
    start_macos_app

    # 启动 iOS 应用
    # start_ios_app  # 暂时跳过 iOS，先测试 macOS

    # 等待应用启动
    wait_for_app "macOS" "$LOG_DIR/macos_app.log"
    # wait_for_app "iOS" "$LOG_DIR/ios_app.log"

    log "========== 应用启动完成 =========="
    log "macOS 应用日志: $LOG_DIR/macos_app.log"
    log "iOS 应用日志: $LOG_DIR/ios_app.log"
    log ""
    log "请手动执行以下步骤："
    log "1. 在 macOS 应用上登录账号：108@imboy.pub / admin888"
    log "2. 在 iOS 应用上登录账号：118@imboy.pub / admin888"
    log "3. macOS 发送消息给 iOS"
    log "4. iOS 回复消息"
    log "5. 验证消息接收"
    log ""
    log "按 Ctrl+C 退出测试..."

    # 保持运行
    wait
}

# 清理函数
cleanup() {
    log "清理进程..."
    if [ -f "$LOG_DIR/macos.pid" ]; then
        kill $(cat "$LOG_DIR/macos.pid") 2>/dev/null || true
    fi
    if [ -f "$LOG_DIR/ios.pid" ]; then
        kill $(cat "$LOG_DIR/ios.pid") 2>/dev/null || true
    fi
    log "清理完成"
}

# 捕获退出信号
trap cleanup EXIT INT TERM

# 运行主程序
main
