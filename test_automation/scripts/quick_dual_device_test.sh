#!/bin/bash

# 双设备聊天测试 - 快速启动脚本
#
# 使用方法:
#   ./quick_dual_device_test.sh [chrome|macos|ios]
#
# 参数说明:
#   chrome  - 启动 Chrome Web 端 (默认)
#   macos   - 启动第二个 macOS 窗口
#   ios     - 启动 iOS 模拟器

set -e

PROJECT_DIR="/Users/leeyi/project/imboy.pub/imboyapp"
LOG_DIR="${PROJECT_DIR}/test_automation/logs"
REPORT_DIR="${PROJECT_DIR}/test_automation/reports"

# 创建必要的目录
mkdir -p "$LOG_DIR"
mkdir -p "$REPORT_DIR"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
双设备聊天测试 - 快速启动脚本

使用方法:
  $0 [chrome|macos|ios|help]

参数说明:
  chrome  - 启动 Chrome Web 端作为第二设备 (默认)
  macos   - 启动第二个 macOS 窗口作为第二设备
  ios     - 启动 iOS 模拟器作为第二设备
  help    - 显示此帮助信息

测试账号:
  设备 1 (macOS): 108@imboy.pub / admin888
  设备 2 (第二设备): 118@imboy.pub / admin888

测试步骤:
  1. 两个设备分别登录
  2. 设备 1 发送消息给设备 2
  3. 验证设备 2 收到消息
  4. 设备 2 回复消息
  5. 验证设备 1 收到回复

详细文档:
  - 测试报告: $REPORT_DIR/03_dual_device_chat_test_report.md
  - 执行摘要: $REPORT_DIR/03_execution_summary.md

EOF
}

# 检查后端服务
check_backend() {
    log "检查后端服务..."
    if pgrep -f "imboy" > /dev/null; then
        log "✅ 后端服务运行中"
        return 0
    else
        error "❌ 后端服务未运行"
        warn "请先启动后端服务:"
        warn "  cd /Users/leeyi/project/imboy.pub/imboy"
        warn "  IMBOYENV=local make run"
        return 1
    fi
}

# 检查 macOS 应用
check_macos_app() {
    log "检查 macOS 应用..."
    if pgrep -f "IMBoy.app" > /dev/null; then
        log "✅ macOS 应用运行中"
        return 0
    else
        warn "⚠️  macOS 应用未运行"
        warn "正在启动 macOS 应用..."
        open "$PROJECT_DIR/build/macos/Build/Products/Debug/IMBoy.app"
        sleep 5
        return 0
    fi
}

# 启动 Chrome Web 端
start_chrome() {
    log "启动 Chrome Web 端..."

    cd "$PROJECT_DIR"

    # 查找可用端口
    PORT=9999
    while lsof -i :$PORT > /dev/null 2>&1; do
        PORT=$((PORT + 1))
    done

    info "使用端口: $PORT"

    # 启动 Chrome 应用
    nohup flutter run -d chrome --web-port=$PORT \
        > "$LOG_DIR/chrome_app.log" 2>&1 &
    CHROME_PID=$!
    echo $CHROME_PID > "$LOG_DIR/chrome.pid"

    log "Chrome 应用启动中... PID: $CHROME_PID"
    info "日志文件: $LOG_DIR/chrome_app.log"

    # 等待启动
    log "等待 Chrome 应用启动 (约 30 秒)..."
    for i in {1..30}; do
        if grep -q "Flutter run key commands" "$LOG_DIR/chrome_app.log" 2>/dev/null; then
            log "✅ Chrome 应用启动成功!"
            break
        fi
        sleep 1
        echo -n "."
    done
    echo ""

    info "Chrome 应用访问地址: http://localhost:$PORT"
}

# 启动第二个 macOS 窗口
start_macos_window() {
    log "启动第二个 macOS 窗口..."

    APP_PATH="$PROJECT_DIR/build/macos/Build/Products/Debug/IMBoy.app"

    if [ ! -d "$APP_PATH" ]; then
        error "找不到 macOS 应用: $APP_PATH"
        warn "请先构建应用:"
        warn "  cd $PROJECT_DIR"
        warn "  flutter build macos"
        return 1
    fi

    open -n "$APP_PATH"

    log "✅ 第二个 macOS 窗口已启动"
}

# 启动 iOS 模拟器
start_ios() {
    log "启动 iOS 模拟器..."

    cd "$PROJECT_DIR"

    # 启动模拟器
    flutter emulators --launch apple_ios_simulator
    sleep 15

    # 查找 iOS 设备
    IOS_DEVICE=$(flutter devices | grep -E "ios|iPhone" | head -1 | awk '{print $1}')

    if [ -z "$IOS_DEVICE" ]; then
        error "找不到 iOS 设备"
        return 1
    fi

    info "使用 iOS 设备: $IOS_DEVICE"

    # 启动应用
    nohup flutter run -d "$IOS_DEVICE" \
        > "$LOG_DIR/ios_app.log" 2>&1 &
    IOS_PID=$!
    echo $IOS_PID > "$LOG_DIR/ios.pid"

    log "iOS 应用启动中... PID: $IOS_PID"
    info "日志文件: $LOG_DIR/ios_app.log"

    # 等待启动
    log "等待 iOS 应用启动 (约 60 秒)..."
    for i in {1..60}; do
        if grep -q "Flutter run key commands" "$LOG_DIR/ios_app.log" 2>/dev/null; then
            log "✅ iOS 应用启动成功!"
            break
        fi
        sleep 1
        echo -n "."
    done
    echo ""
}

# 显示测试步骤
show_test_steps() {
    cat << EOF

${GREEN}========== 双设备聊天测试 ==========${NC}

${BLUE}测试账号:${NC}
  设备 1 (macOS):     ${YELLOW}108@imboy.pub / admin888${NC}
  设备 2 (第二设备):  ${YELLOW}118@imboy.pub / admin888${NC}

${BLUE}测试步骤:${NC}
  1. 在设备 1 登录账号: 108@imboy.pub
  2. 在设备 2 登录账号: 118@imboy.pub
  3. 设备 1 发送消息: "Hello from macOS!"
  4. 验证设备 2 收到消息
  5. 设备 2 回复: "Hello from Device2!"
  6. 验证设备 1 收到回复

${BLUE}验证点:${NC}
  ✅ 消息内容正确
  ✅ 发送者信息正确
  ✅ 时间戳正确
  ✅ 消息延迟 < 3 秒

${BLUE}详细文档:${NC}
  - 测试报告: $REPORT_DIR/03_dual_device_chat_test_report.md
  - 执行摘要: $REPORT_DIR/03_execution_summary.md

${GREEN}======================================${NC}

EOF
}

# 清理函数
cleanup() {
    log "清理临时文件..."
    # 保持应用运行,不清理
}

# 捕获退出信号
trap cleanup EXIT INT TERM

# 主程序
main() {
    local device_type="${1:-chrome}"

    case "$device_type" in
        help|--help|-h)
            show_help
            exit 0
            ;;
        chrome)
            check_backend || exit 1
            check_macos_app || exit 1
            start_chrome
            ;;
        macos)
            check_backend || exit 1
            check_macos_app || exit 1
            start_macos_window
            ;;
        ios)
            check_backend || exit 1
            check_macos_app || exit 1
            start_ios
            ;;
        *)
            error "未知参数: $device_type"
            show_help
            exit 1
            ;;
    esac

    show_test_steps

    log "测试环境准备完成!"
    info "按 Ctrl+C 退出..."
    wait
}

# 运行主程序
main "$@"
