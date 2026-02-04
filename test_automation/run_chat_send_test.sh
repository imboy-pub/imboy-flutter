#!/bin/bash

# IM Boy 发送消息测试执行脚本
# 测试场景: 04_chat_send.yaml
# 设备: macOS

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目路径
PROJECT_DIR="/Users/leeyi/project/imboy.pub/imboyapp"
REPORT_DIR="$PROJECT_DIR/test_automation/reports"
SCREENSHOT_DIR="$REPORT_DIR/screenshots"

# 测试数据
SENDER_PHONE="13800138000"
SENDER_PASSWORD="Test123456"
RECEIVER_NAME="测试用户"
TEXT_MESSAGE="这是一条测试消息"
EMOJI_MESSAGE="👍Hello! 🎉"

# 设备ID
DEVICE_ID="macos"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 打印标题
print_title() {
    echo ""
    echo "========================================"
    echo "  $1"
    echo "========================================"
    echo ""
}

# 检查环境
check_environment() {
    print_title "检查测试环境"

    # 检查 Flutter
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter 未安装"
        exit 1
    fi
    log_info "Flutter 版本: $(flutter --version | head -1)"

    # 检查项目目录
    if [ ! -d "$PROJECT_DIR" ]; then
        log_error "项目目录不存在: $PROJECT_DIR"
        exit 1
    fi
    log_info "项目目录: $PROJECT_DIR"

    # 检查设备
    cd "$PROJECT_DIR"
    if ! flutter devices | grep -q "$DEVICE_ID"; then
        log_error "设备不可用: $DEVICE_ID"
        flutter devices
        exit 1
    fi
    log_info "测试设备: $DEVICE_ID"

    # 创建报告目录
    mkdir -p "$SCREENSHOT_DIR"
    log_info "报告目录: $REPORT_DIR"
    log_info "截图目录: $SCREENSHOT_DIR"
}

# 启动应用
start_app() {
    print_title "启动 IM Boy 应用"

    log_info "正在启动应用..."
    log_info "设备: $DEVICE_ID"
    log_info "工作目录: $PROJECT_DIR"

    cd "$PROJECT_DIR"

    # 检查是否已有应用在运行
    if pgrep -f "flutter run" > /dev/null; then
        log_warn "检测到已有 Flutter 应用在运行"
        read -p "是否终止现有应用并重新启动? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            pkill -f "flutter run"
            sleep 2
        else
            log_info "使用现有应用实例"
            return 0
        fi
    fi

    # 启动应用
    log_info "开始编译和启动应用（首次构建可能需要 3-5 分钟）..."

    # 使用 nohup 在后台启动
    nohup flutter run --print-dtd --machine --device-id "$DEVICE_ID" \
        > "$REPORT_DIR/flutter_run.log" 2>&1 &

    FLUTTER_PID=$!
    log_info "Flutter 进程 PID: $FLUTTER_PID"

    # 等待应用启动
    log_info "等待应用启动..."
    sleep 10

    # 检查进程
    if ps -p $FLUTTER_PID > /dev/null; then
        log_info "应用正在启动中..."
        log_info "查看日志: tail -f $REPORT_DIR/flutter_run.log"
    else
        log_error "应用启动失败，查看日志:"
        cat "$REPORT_DIR/flutter_run.log"
        exit 1
    fi

    # 等待 DTD 连接
    log_info "等待 Dart Tooling Daemon 连接..."
    for i in {1..60}; do
        if grep -q "daemon.connected" "$REPORT_DIR/flutter_run.log" 2>/dev/null; then
            log_info "✅ Dart Tooling Daemon 已连接"
            break
        fi
        if [ $i -eq 60 ]; then
            log_warn "等待 DTD 连接超时，请检查日志"
        fi
        sleep 5
    done
}

# 等待应用完全启动
wait_for_app() {
    print_title "等待应用完全启动"

    log_info "应用正在编译中，请稍候..."
    log_info "您可以在新终端窗口查看日志: tail -f $REPORT_DIR/flutter_run.log"

    read -p "应用是否已完全启动并显示主界面? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warn "请等待应用启动完成后继续"
        exit 0
    fi

    log_info "✅ 应用已启动"
}

# 打印测试步骤
print_test_steps() {
    print_title "测试步骤说明"

    cat << 'EOF'
📋 测试步骤:

【阶段 1: 登录】
  1. 点击"登录"按钮
  2. 输入手机号: 13800138000
  3. 输入密码: Test123456
  4. 点击"登录"按钮
  5. 等待登录成功

【阶段 2: 进入会话列表】
  6. 验证页面标题显示"会话"
  7. 验证底部导航栏显示正常

【阶段 3: 选择聊天】
  8. 在会话列表中找到"测试用户"
  9. 点击进入聊天页面

【阶段 4: 发送文本消息】
  10. 点击消息输入框
  11. 输入: "这是一条测试消息"
  12. 点击"发送"按钮
  13. 等待消息发送完成

【阶段 5: 发送 Emoji 消息】
  14. 再次点击输入框
  15. 输入: "👍Hello! 🎉"
  16. 点击"发送"按钮
  17. 验证 Emoji 显示正常

【阶段 6: 验证和截图】
  18. 验证两条消息都显示在聊天中
  19. 保存截图（使用 Cmd+Shift+4）

EOF
}

# 生成测试报告
generate_report() {
    print_title "生成测试报告"

    REPORT_FILE="$REPORT_DIR/chat_send_manual_test_report.md"

    cat > "$REPORT_FILE" << EOF
# 发送消息手动测试报告

**测试时间**: $(date '+%Y-%m-%d %H:%M:%S')
**测试设备**: $DEVICE_ID
**执行方式**: 手动执行

## 测试数据
- 发送者账号: $SENDER_PHONE
- 接收者名称: $RECEIVER_NAME
- 文本消息: $TEXT_MESSAGE
- Emoji 消息: $EMOJI_MESSAGE

## 测试结果

### 登录测试
- [ ] 登录成功
- [ ] 进入会话列表

### 消息发送测试
- [ ] 发送文本消息成功
- [ ] 文本消息显示正常
- [ ] 发送 Emoji 消息成功
- [ ] Emoji 消息显示正常

### 问题记录
（记录测试过程中遇到的问题）

### 截图
（保存截图到: $SCREENSHOT_DIR）

---
报告生成时间: $(date '+%Y-%m-%d %H:%M:%S')
EOF

    log_info "✅ 测试报告已生成: $REPORT_FILE"
    log_info "请编辑报告文件填写测试结果"
}

# 主函数
main() {
    print_title "IM Boy 发送消息测试"

    log_info "测试场景: 04_chat_send.yaml"
    log_info "测试设备: $DEVICE_ID"
    log_info "执行方式: 手动测试辅助脚本"

    # 检查环境
    check_environment

    # 询问是否启动应用
    echo ""
    read -p "是否需要启动应用? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        start_app
        wait_for_app
    fi

    # 打印测试步骤
    print_test_steps

    # 生成报告模板
    generate_report

    print_title "准备就绪"

    log_info "✅ 环境准备完成"
    log_info "✅ 测试步骤已说明"
    log_info "✅ 报告模板已生成"
    echo ""
    log_info "现在可以按照上述步骤手动执行测试"
    log_info "测试完成后请填写报告: $REPORT_DIR/chat_send_manual_test_report.md"
    echo ""
}

# 执行主函数
main
