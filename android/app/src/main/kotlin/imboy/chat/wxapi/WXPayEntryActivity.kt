package imboy.chat.wxapi

import com.jarvan.fluwx.wxapi.FluwxWXEntryActivity

/**
 * 微信支付回调入口。
 *
 * 微信 SDK 约定支付结果必须回调到 `<applicationId>.wxapi.WXPayEntryActivity`
 * （此处即 `imboy.chat.wxapi.WXPayEntryActivity`）。继承 fluwx 的
 * [FluwxWXEntryActivity]，由 fluwx 把回调 intent 转回 Flutter 引擎并经平台通道
 * 分发给 Dart 侧 `addSubscriber` 监听者。请勿改包名/类名（微信硬性约定）。
 */
class WXPayEntryActivity : FluwxWXEntryActivity()
