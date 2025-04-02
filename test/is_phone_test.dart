
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/func.dart';




void main() {
group('Phone Number Validation - Comprehensive Tests', () {

// ================= 基础验证 =================
test('Null or empty should be invalid', () {
expect(isPhone(null), isFalse);
expect(isPhone(''), isFalse);
expect(isPhone(' '), isFalse);
});

// ================= 中国号码验证 =================
test('Valid China mobile numbers', () {

  expect(isPhone('19292076183'), isTrue);
  expect(isPhone('+8619292076183'), isTrue);

// 标准格式
expect(isPhone('13912345678'), isTrue);
expect(isPhone('15012345678'), isTrue);
expect(isPhone('18012345678'), isTrue);
expect(isPhone('19912345678'), isTrue);

// 带国际前缀
expect(isPhone('+8613912345678'), isTrue);
expect(isPhone('008613912345678'), isTrue);
expect(isPhone('8613912345678'), isTrue);

// 带分隔符
expect(isPhone('139-1234-5678'), isTrue);
expect(isPhone('139 1234 5678'), isTrue);
expect(isPhone('+86 139 1234 5678'), isTrue);
});

test('Invalid China mobile numbers', () {
// 错误开头
expect(isPhone('12912345678'), isFalse); // 12开头无效
expect(isPhone('10123456789'), isFalse); // 10开头无效
expect(isPhone('91123456789'), isFalse); // 9开头无效

// 长度错误
expect(isPhone('1391234567'), isFalse); // 少1位
expect(isPhone('139123456789'), isFalse); // 多1位

// 无效前缀
expect(isPhone('+8513912345678'), isFalse); // +85无效
expect(isPhone('009613912345678'), isFalse); // 0096无效
});

// ================= 国际号码验证 =================
test('Valid international numbers', () {
// 美国/加拿大
expect(isPhone('+12025550123'), isTrue);
expect(isPhone('+16175550123'), isTrue);

// 英国
expect(isPhone('+442072222222'), isTrue);
expect(isPhone('+447912345678'), isTrue); // 移动

// 德国
expect(isPhone('+493012345678'), isTrue);
expect(isPhone('+4915123456789'), isTrue); // 移动

// 日本
expect(isPhone('+81312345678'), isTrue);
expect(isPhone('+819012345678'), isTrue); // 移动

// 澳大利亚
expect(isPhone('+61234567890'), isTrue);

// 最小/最大长度
expect(isPhone('+12345'), isTrue); // 最小5位
expect(isPhone('+123456789012345'), isTrue); // 最大15位
});

test('Invalid international numbers', () {
// 长度错误
expect(isPhone('+1234'), isFalse); // 少于5位
expect(isPhone('+1234567890123456'), isFalse); // 多于15位

// 格式错误
expect(isPhone('1234567890'), isFalse); // 缺少+
expect(isPhone('++1234567890'), isFalse); // 多个+
expect(isPhone('+ 1234567890'), isFalse); // 包含空格

// 无效字符
expect(isPhone('+123-456-7890'), isFalse); // 包含连字符
expect(isPhone('+123.456.7890'), isFalse); // 包含点
});

// ================= 格式处理验证 =================
test('Formatted numbers should be valid after cleaning', () {
// 美国格式
expect(isPhone('+1 (202) 555-0123'), isTrue);
expect(isPhone('+1.202.555.0123'), isTrue);

// 英国格式
expect(isPhone('+44 20 7222 2222'), isTrue);
expect(isPhone('+44(0)2072222222'), isTrue);

// 德国格式
expect(isPhone('+49 30 12345678'), isTrue);
expect(isPhone('+49 (0) 30 / 12345678'), isTrue);

// 中国格式
expect(isPhone('+86 (10) 1234 5678'), isTrue);
expect(isPhone('0086-139-1234-5678'), isTrue);
});

// ================= 全角字符验证 =================
test('Full-width characters should be handled', () {
// 全角数字
expect(isPhone('＋８６１３９１２３４５６７８'), isTrue);
expect(isPhone('１３９１２３４５６７８'), isTrue);
expect(isPhone('＋１２０２５５５０１２３'), isTrue);

// 混合全角半角
expect(isPhone('+８６139１２３４５６７８'), isTrue);
expect(isPhone('＋86139-1234-5678'), isTrue);
});

// ================= 边界情况验证 =================
test('Edge cases', () {
// 超大输入
expect(isPhone('+1234567890' * 20), isFalse); // 清理后仍超长

// 混合内容
expect(isPhone('Call me at +8613912345678 please'), isTrue);
expect(isPhone('My number is 139-1234-5678'), isTrue);
expect(isPhone('Invalid: 12345678901'), isFalse);

// 重复+
expect(isPhone('++8613912345678'), isFalse);
expect(isPhone('+86+13912345678'), isFalse);

// 特殊字符
expect(isPhone('#+8613912345678#'), isTrue);
expect(isPhone('+86@139@1234@5678'), isFalse);
});

// ================= 性能测试 =================
test('Performance with long inputs', () {
// 长但有效
expect(isPhone('+123456789012345'), isTrue); // 正好15位

// 超长无效
expect(isPhone('+1234567890123456'), isFalse); // 16位
expect(isPhone('+12345' * 10), isFalse); // 50字符
});

// ================= 特定国家验证 =================
test('Specific country cases', () {
// 印度 (10位)
expect(isPhone('+919876543210'), isTrue);
expect(isPhone('+911202555012'), isTrue);
expect(isPhone('+91987654321'), isFalse); // 9位

// 巴西 (可变长度)
expect(isPhone('+551112345678'), isTrue);
expect(isPhone('+5521987654321'), isTrue);
expect(isPhone('+55123'), isFalse);

// 俄罗斯 (10位)
expect(isPhone('+74951234567'), isTrue);
expect(isPhone('+79161234567'), isTrue);
expect(isPhone('+7900123456'), isFalse); // 9位

// 南非 (9位)
expect(isPhone('+27123456789'), isTrue);
expect(isPhone('+27831234567'), isTrue);
expect(isPhone('+27123456'), isFalse); // 过短

// 韩国 (8-11位)
expect(isPhone('+821012345678'), isTrue);
expect(isPhone('+8221234567'), isTrue);
expect(isPhone('+821123'), isFalse);
});

// ================= 异常输入验证 =================
test('Non-phone inputs', () {
expect(isPhone('abcdefg'), isFalse);
expect(isPhone('123-abc-456'), isFalse);
expect(isPhone('+abc123'), isFalse);
expect(isPhone('!@#\$%^&*()'), isFalse);
expect(isPhone('email@example.com'), isFalse);
expect(isPhone('http://example.com'), isFalse);
});

// ================= 新号段验证 =================
test('New China number segments', () {
// 16x号段
expect(isPhone('16212345678'), isTrue);
expect(isPhone('16512345678'), isTrue);
expect(isPhone('16712345678'), isTrue);

// 19x号段
expect(isPhone('19112345678'), isTrue);
expect(isPhone('19212345678'), isTrue);
expect(isPhone('19812345678'), isTrue);

// 14x号段 (虚拟运营商)
expect(isPhone('14112345678'), isTrue);
expect(isPhone('14512345678'), isTrue);
});

// ================= 国际号码详细验证 =================
test('Detailed international validation', () {
// 法国
expect(isPhone('+33123456789'), isTrue);
expect(isPhone('+33612345678'), isTrue); // 移动
expect(isPhone('+331'), isFalse);

// 意大利
expect(isPhone('+393471234567'), isTrue);
expect(isPhone('+3906123456789'), isTrue);
expect(isPhone('+3945123'), isFalse);

// 墨西哥
expect(isPhone('+525512345678'), isTrue);
expect(isPhone('+521234567890'), isFalse); // 过长

// 沙特阿拉伯
expect(isPhone('+966512345678'), isTrue);
expect(isPhone('+96611234567'), isFalse); // 无效开头

// 印尼
expect(isPhone('+6281712345678'), isTrue);
expect(isPhone('+622112345'), isTrue);
expect(isPhone('+62112345'), isFalse);
});

// ================= 混合内容验证 =================
test('Mixed content validation', () {
expect(isPhone('电话：+8613912345678'), isTrue);
expect(isPhone('紧急联系人：0086 139 1234 5678'), isTrue);
expect(isPhone('客服热线：400-123-4567'), isFalse); // 400号码
expect(isPhone('请拨打：+44 20 7222 2222 转123'), isTrue);
expect(isPhone('我的号码是：１３９１２３４５６７８'), isTrue);
});

// ================= 特殊号码验证 =================
test('Special numbers', () {
// 短号码 (通常无效)
expect(isPhone('110'), isFalse); // 中国报警
expect(isPhone('911'), isFalse); // 美国报警
expect(isPhone('999'), isFalse); // 英国报警

// 服务号码 (通常无效)
expect(isPhone('10086'), isFalse); // 中国移动客服
expect(isPhone('12345'), isFalse); // 政府服务
expect(isPhone('8001234567'), isFalse); // 美国免费电话
});
});
}