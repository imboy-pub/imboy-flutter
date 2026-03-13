#!/bin/bash
# 联系人列表测试辅助脚本
# 执行 05_contact_list.yaml 测试场景

set -e

PROJECT_DIR="/Users/leeyi/project/imboy.pub/imboyapp"
SCENARIO_FILE="$PROJECT_DIR/test_automation/scenarios/05_contact_list.yaml"
REPORT_DIR="$PROJECT_DIR/test_automation/reports"
SCREENSHOT_DIR="$REPORT_DIR/screenshots"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$REPORT_DIR/05_contact_list_report_$TIMESTAMP.md"

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  联系人列表测试 (05_contact_list)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 创建必要目录
mkdir -p "$SCREENSHOT_DIR"

# 步骤 1: 环境检查
echo -e "${YELLOW}[步骤 1/8] 环境检查${NC}"
echo "检查 Flutter 环境..."
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}错误: Flutter 未安装${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Flutter: $(flutter --version | head -1)${NC}"

echo "检查设备..."
DEVICES=$(flutter devices)
if echo "$DEVICES" | grep -q "macos"; then
    echo -e "${GREEN}✓ macOS 设备可用${NC}"
else
    echo -e "${RED}错误: 未找到 macOS 设备${NC}"
    exit 1
fi

# 步骤 2: 显示测试信息
echo ""
echo -e "${YELLOW}[步骤 2/8] 测试信息${NC}"
echo "测试场景: $(grep '^name:' "$SCENARIO_FILE" | cut -d'"' -f2)"
echo "测试描述: $(grep '^description:' "$SCENARIO_FILE" | cut -d'"' -f2)"
echo "测试账号: $(grep 'phone:' "$SCENARIO_FILE" | awk '{print $2}' | tr -d '"')"
echo "搜索关键词: $(grep 'search_keyword:' "$SCENARIO_FILE" | awk '{print $2}' | tr -d '"')"
echo "测试联系人: $(grep 'contact_name:' "$SCENARIO_FILE" | awk '{print $2}' | tr -d '"')"
echo ""

# 步骤 3: 启动应用
echo -e "${YELLOW}[步骤 3/8] 启动应用${NC}"
echo "正在启动 IMBoy 应用..."
cd "$PROJECT_DIR"

# 检查应用是否已运行
if pgrep -f "IMBoy.app/Contents/MacOS/IMBoy" > /dev/null; then
    echo -e "${GREEN}✓ 应用已在运行${NC}"
else
    echo "请手动启动应用："
    echo "  open $PROJECT_DIR/build/macos/Build/Products/Debug/IMBoy.app"
    echo "或者运行："
    echo "  cd $PROJECT_DIR && flutter run -d macos"
    echo ""
    read -p "按回车键继续（确认应用已启动）..."
fi

# 步骤 4: 显示测试步骤
echo ""
echo -e "${YELLOW}[步骤 4/8] 测试步骤${NC}"
echo "================================"
echo "阶段 1: 登录应用"
echo "  1. 点击 '登录' 按钮"
echo "  2. 输入手机号: 13800138000"
echo "  3. 输入密码: Test123456"
echo "  4. 点击 '登录' 按钮"
echo "  5. 等待登录成功 (约5秒)"
echo ""
echo "阶段 2: 进入联系人页面"
echo "  6. 点击底部导航栏 '联系人' 标签"
echo "  7. 等待页面加载"
echo ""
echo "阶段 3: 验证页面结构"
echo "  8. 检查页面标题显示 '联系人'"
echo "  9. 检查列表视图存在"
echo "  10. 检查是否有联系人"
echo ""
echo "阶段 4: 滚动联系人列表"
echo "  11. 向下滚动列表"
echo "  12. 向上滚动回到顶部"
echo ""
echo "阶段 5: 搜索联系人"
echo "  13. 点击搜索框"
echo "  14. 输入搜索关键词: 测试"
echo "  15. 等待搜索结果"
echo "  16. 清除搜索"
echo ""
echo "阶段 6: 查看联系人详情"
echo "  17. 点击联系人 '测试用户'"
echo "  18. 等待详情页加载"
echo "  19. 验证头像和按钮显示"
echo ""
echo "阶段 7: 返回列表"
echo "  20. 点击返回按钮"
echo "  21. 验证返回到列表页"
echo "================================"
echo ""

# 步骤 5: 生成报告模板
echo -e "${YELLOW}[步骤 5/8] 生成测试报告${NC}"
cat > "$REPORT_FILE" << EOF
# 联系人列表测试报告

**测试场景**: 05_contact_list.yaml
**执行日期**: $(date +"%Y-%m-%d %H:%M:%S")
**执行方式**: 手动测试 + 辅助脚本
**测试结果**: ⏳ 进行中

---

## 测试信息

| 项目 | 值 |
|------|-----|
| 测试账号 | 13800138000 |
| 测试密码 | Test123456 |
| 搜索关键词 | 测试 |
| 测试联系人 | 测试用户 |
| 最少联系人数 | 1 |

---

## 测试步骤执行结果

### 阶段 1: 登录应用

| 步骤 | 操作 | 预期结果 | 实际结果 | 状态 |
|------|------|---------|---------|------|
| 1 | 点击登录按钮 | 进入登录页 | - | ⏳ |
| 2 | 输入手机号 | 显示手机号 | - | ⏳ |
| 3 | 输入密码 | 显示密码 | - | ⏳ |
| 4 | 提交登录 | 进入主界面 | - | ⏳ |
| 5 | 等待登录成功 | 显示会话列表 | - | ⏳ |

### 阶段 2: 进入联系人页面

| 步骤 | 操作 | 预期结果 | 实际结果 | 状态 |
|------|------|---------|---------|------|
| 6 | 点击联系人标签 | 进入联系人页面 | - | ⏳ |
| 7 | 等待页面加载 | 显示联系人列表 | - | ⏳ |

### 阶段 3: 验证页面结构

| 步骤 | 操作 | 预期结果 | 实际结果 | 状态 |
|------|------|---------|---------|------|
| 8 | 检查页面标题 | 显示"联系人" | - | ⏳ |
| 9 | 检查列表视图 | ListView 存在 | - | ⏳ |
| 10 | 检查联系人 | 有至少1个联系人 | - | ⏳ |

### 阶段 4: 滚动联系人列表

| 步骤 | 操作 | 预期结果 | 实际结果 | 状态 |
|------|------|---------|---------|------|
| 11 | 向下滚动 | 列表向下移动 | - | ⏳ |
| 12 | 向上滚动 | 列表回到顶部 | - | ⏳ |

### 阶段 5: 搜索联系人

| 步骤 | 操作 | 预期结果 | 实际结果 | 状态 |
|------|------|---------|---------|------|
| 13 | 点击搜索框 | 搜索框获得焦点 | - | ⏳ |
| 14 | 输入搜索词 | 显示匹配结果 | - | ⏳ |
| 15 | 等待结果 | 显示过滤后的列表 | - | ⏳ |
| 16 | 清除搜索 | 显示完整列表 | - | ⏳ |

### 阶段 6: 查看联系人详情

| 步骤 | 操作 | 预期结果 | 实际结果 | 状态 |
|------|------|---------|---------|------|
| 17 | 点击联系人 | 进入详情页 | - | ⏳ |
| 18 | 等待加载 | 显示详情 | - | ⏳ |
| 19 | 验证元素 | 头像和按钮显示 | - | ⏳ |

### 阶段 7: 返回列表

| 步骤 | 操作 | 预期结果 | 实际结果 | 状态 |
|------|------|---------|---------|------|
| 20 | 点击返回 | 返回列表页 | - | ⏳ |
| 21 | 验证返回 | 显示联系人列表 | - | ⏳ |

---

## 截图记录

| 截图 | 说明 | 文件名 |
|------|------|--------|
| 初始页面 | 联系人列表初始状态 | 05_contact_list_initial.png |
| 滚动后 | 滚动后的列表状态 | 05_contact_list_after_scroll.png |
| 搜索结果 | 搜索结果页面 | 05_contact_list_search_result.png |
| 联系人详情 | 联系人详情页面 | 05_contact_detail.png |
| 最终状态 | 最终返回列表状态 | 05_contact_list_final.png |

---

## 问题记录

### 遇到的问题

1. _（记录测试中遇到的问题）_

### 解决方案

1. _（记录问题的解决方案）_

---

## 测试结论

### 通过项目

- [ ] 登录功能正常
- [ ] 联系人列表显示正常
- [ ] 列表滚动功能正常
- [ ] 搜索功能正常
- [ ] 联系人详情显示正常
- [ ] 返回导航正常

### 失败项目

- _（列出失败的功能点）_

### 整体评估

_（填写整体测试评估）_

---

## 建议

### 功能改进

1. _（记录功能改进建议）_

### 测试改进

1. _（记录测试改进建议）_

---

**报告生成时间**: $(date +"%Y-%m-%d %H:%M:%S")
**测试人员**: 手动测试
**报告版本**: v1.0
EOF

echo -e "${GREEN}✓ 报告模板已生成: $REPORT_FILE${NC}"

# 步骤 6: 显示截图指南
echo ""
echo -e "${YELLOW}[步骤 6/8] 截图指南${NC}"
echo "在测试过程中，请使用以下快捷键截图："
echo "  - 全屏截图: Command + Shift + 3"
echo "  - 选择区域: Command + Shift + 4"
echo "  - 截图保存位置: $SCREENSHOT_DIR"
echo ""
echo "建议的截图时机："
echo "  1. 进入联系人页面后 (05_contact_list_initial.png)"
echo "  2. 滚动列表后 (05_contact_list_after_scroll.png)"
echo "  3. 显示搜索结果后 (05_contact_list_search_result.png)"
echo "  4. 进入联系人详情后 (05_contact_detail.png)"
echo "  5. 返回列表后 (05_contact_list_final.png)"
echo ""

# 步骤 7: 开始测试
echo -e "${YELLOW}[步骤 7/8] 准备开始测试${NC}"
echo "================================"
echo "应用应该已经启动并显示在屏幕上"
echo ""
echo "请按照上述步骤手动执行测试，并："
echo "  1. 记录每个步骤的执行结果"
echo "  2. 在关键步骤截图"
echo "  3. 遇到问题记录下来"
echo "  4. 完成后填写报告: $REPORT_FILE"
echo ""

# 步骤 8: 打开报告
echo -e "${YELLOW}[步骤 8/8] 测试总结${NC}"
echo "================================"
echo -e "${GREEN}准备工作完成！${NC}"
echo ""
echo "后续操作："
echo "  1. 执行测试步骤（参考上方步骤列表）"
echo "  2. 保存截图到: $SCREENSHOT_DIR"
echo "  3. 填写测试报告: $REPORT_FILE"
echo "  4. 查看报告: cat $REPORT_FILE"
echo "  5. 编辑报告: nano $REPORT_FILE 或 vim $REPORT_FILE"
echo ""

# 询问是否打开报告
read -p "是否打开报告文件？(y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v code &> /dev/null; then
        code "$REPORT_FILE"
    else
        open "$REPORT_FILE"
    fi
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  测试准备完成，祝测试顺利！${NC}"
echo -e "${BLUE}========================================${NC}"
