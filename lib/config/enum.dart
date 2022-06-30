enum ButtonType { voice, more }

enum MsgType { c2c, group, voice }

enum GroupInfoType { remark, name, cardName }

// 编码中依赖了枚举顺序，请不要随意修改顺序
enum NewFriendStatus {
  waiting_for_validation, // 待验证
  added, // 已添加
  expired, // 已过期
}
