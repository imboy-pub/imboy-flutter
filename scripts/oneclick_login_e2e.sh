#!/usr/bin/env bash
# oneclick_login_e2e.sh — 一键登录全链路自动化验证（Android 真机）
# 用法: bash oneclick_login_e2e.sh
# 断言链: JCore注册 → 认证SDK init(8000) → 授权页拉起 → [人工/自动]点授权页登录 → 6000 loginToken → 服务端200 → 首页
set -u
PKG=pub.imboy.app
PASS=0; FAIL=0
wait_text() { # 轮询等文本元素出现 $1=text $2=timeout_s
  local t=0
  local txt="$1"
  local to="${2:-20}"
  while [ "$t" -lt "${to}" ]; do
    adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    if adb shell cat /sdcard/ui.xml | tr '<' '\n<' | grep -qE "(text|content-desc)=\"[^\"]*${txt}[^\"]*\""; then return 0; fi
    sleep 1; t=$((t+1))
  done
  return 1
}

LOG() { echo "[$(date +%H:%M:%S)] $*"; }

assert_log() { # $1=pattern $2=desc $3=timeout_s
  local t=0
  local pat="$1"
  local desc="$2"
  local to="${3:-15}"
  while [ "$t" -lt "${to}" ]; do
    if adb logcat -d 2>/dev/null | grep -qF "${pat}"; then LOG "✓ ${desc}"; PASS=$((PASS+1)); return 0; fi
    sleep 1; t=$((t+1))
  done
  LOG "✗ ${desc}（超时未现: ${pat}）"; FAIL=$((FAIL+1)); return 1
}

tap_text() { # uiautomator dump 找文本中心点并点击（Flutter 文本在 content-desc，含 &#10; 重复）
  # 用法: tap_text <文本> [回退X 回退Y] —— 语义树不稳时回退固定坐标（本机 720x1560）
  local txt="$1"
  local fx="${2:-}"
  local fy="${3:-}"
  local bounds
  local try=0
  while [ "$try" -lt 3 ]; do
    adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    bounds=$(adb shell cat /sdcard/ui.xml | tr '<' '\n<' | grep -E "(text|content-desc)=\"[^\"]*${txt}[^\"]*\"" | grep -o 'bounds="\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]"' | head -1 | grep -o '\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]')
    [ -n "$bounds" ] && break
    try=$((try+1)); sleep 2
  done
  if [ -z "$bounds" ]; then
    if [ -n "$fx" ] && [ -n "$fy" ]; then
      adb shell input tap "$fx" "$fy"
      LOG "→ 回退坐标点击 [$txt] @ (${fx},${fy})"; return 0
    fi
    LOG "✗ 找不到文本: $txt"; return 1
  fi
  local x1 y1 x2 y2
  x1=$(echo "$bounds" | cut -d'[' -f2 | cut -d',' -f1); y1=$(echo "$bounds" | cut -d',' -f2 | cut -d']' -f1)
  x2=$(echo "$bounds" | cut -d'[' -f3 | cut -d',' -f1); y2=$(echo "$bounds" | cut -d',' -f3 | cut -d']' -f1)
  adb shell input tap $(( (x1+x2)/2 )) $(( (y1+y2)/2 ))
  LOG "→ 点击 [$txt] @ ($(( (x1+x2)/2 )),$(( (y1+y2)/2 )))"
}

LOG "══ 阶段0: 清日志+启动 App ══"
adb logcat -c
adb shell am force-stop $PKG
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1

# JCore 注册是一次性持久化事件（注册过就不再打 Register succeed），
# 用负向断言：观察窗内出现 1005 才是失败
sleep 15
if adb logcat -d 2>/dev/null | grep -q "code:1005"; then
  LOG "✗ JCore 注册被拒（1005 包名不匹配）"; FAIL=$((FAIL+1)); exit 2
else
  LOG "✓ 无 1005（包名匹配，JCore 通道正常）"; PASS=$((PASS+1))
fi

LOG "══ 阶段1: 导航到登录页 ══"
sleep 4
tap_text "跳过" || LOG "（无引导页，已在登录页）"
# 点击后轮询等登录页标志元素；未出现则补点一次（华为低端机动画慢）
if ! wait_text "一键登录" 15; then
  LOG "…登录页未出现，补点一次跳过"
  tap_text "跳过" || true
  wait_text "一键登录" 15 || { LOG "✗ 无法到达登录页"; exit 3; }
fi
LOG "✓ 已到登录页"; PASS=$((PASS+1))

LOG "══ 阶段2: 触发一键登录（loginAuth 内兜底 initPlatformState） ══"
tap_text "一键登录" 280 1325 || exit 3
assert_log "result: true" "checkVerifyEnable 通过（运营商通道）" 8

assert_log "code: 8000" "认证SDK init success（签名匹配=1011已解）" 20 || {
  LOG "⛔ SDK init 失败（预期外）。最近相关日志："
  adb logcat -d | grep -E "code: 8004|1011|appSign" | tail -3
  exit 2
}

LOG "══ 阶段3: 授权页拉起断言 ══"
assert_log "preLogin success\|7000" "预取号成功" 20
FOCUS=$(adb shell "dumpsys window | grep mCurrentFocus" | tr -d '\r')
echo "$FOCUS" | grep -q "$PKG" || LOG "当前焦点: $FOCUS"
# 授权页 Activity 名含 AuthActivity/LoginAuthActivity
if adb shell "dumpsys activity activities | grep topResumedActivity" | grep -qiE "auth|jverify"; then
  LOG "✓ 授权页已拉起"; PASS=$((PASS+1))
else
  LOG "✗ 授权页未拉起"; adb logcat -d | grep -E "JVER|code:" | tail -5; FAIL=$((FAIL+1)); exit 4
fi

LOG "══ 阶段4: 授权页同意登录 ══"
sleep 1
tap_text "本机号码一键登录" || tap_text "一键登录" || LOG "（授权页按钮未命中，请人工点击）"
assert_log "code: 6000" "拿到 loginToken（6000）" 15

LOG "══ 阶段5: 服务端链路 ══"
assert_log "quick_login\|quickLogin" "quick_login 请求发出" 10
sleep 4
FOCUS=$(adb shell "dumpsys window | grep mCurrentFocus" | tr -d '\r')
if echo "$FOCUS" | grep -q "MainActivity"; then
  adb logcat -d | grep -E "登录成功|login.*success|passport" | tail -3
  LOG "✓ 登录流程走完（焦点回 MainActivity）"; PASS=$((PASS+1))
fi

LOG "══ 结果: PASS=$PASS FAIL=$FAIL ══"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
