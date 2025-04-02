
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/func.dart';



void main() {
  group('hiddenPhone 方法测试', () {
    // 1. 标准中国手机号测试
    test('标准11位手机号', () {
      expect(hiddenPhone('13812345678'), equals('138****5678'));
    });

    test('15开头的手机号', () {
      expect(hiddenPhone('15012345678'), equals('150****5678'));
    });

    test('18开头的手机号', () {
      expect(hiddenPhone('18612345678'), equals('186****5678'));
    });

    test('19开头的手机号', () {
      expect(hiddenPhone('19212345678'), equals('192****5678'));
    });

    test('带+86前缀的手机号', () {
      expect(hiddenPhone('+8613812345678'), equals('+86138****5678'));
    });

    test('带0086前缀的手机号', () {
      expect(hiddenPhone('008613812345678'), equals('0086138****5678'));
    });

    test('带空格格式的手机号', () {
      expect(hiddenPhone('138 1234 5678'), equals('138****5678'));
    });

    test('带横线格式的手机号', () {
      expect(hiddenPhone('138-1234-5678'), equals('138****5678'));
    });

    test('带括号格式的手机号', () {
      expect(hiddenPhone('(138)1234-5678'), equals('138****5678'));
    });

    // 2. 国际号码测试
    test('英国长号码', () {
      expect(hiddenPhone('+447911123456'), equals('+4479****3456'));
    });

    test('美国号码', () {
      expect(hiddenPhone('+12025551234'), equals('+120****1234'));
    });

    test('香港号码', () {
      expect(hiddenPhone('+85291234567'), equals('+852****4567'));
    });

    test('日本号码', () {
      expect(hiddenPhone('+819012345678'), equals('+8190****5678'));
    });

    test('韩国号码', () {
      expect(hiddenPhone('+821012345678'), equals('+8210****5678'));
    });

    test('俄罗斯号码', () {
      expect(hiddenPhone('+79161234567'), equals('+791****4567'));
    });

    test('德国号码', () {
      expect(hiddenPhone('+491701234567'), equals('+4917****4567'));
    });

    test('法国号码', () {
      expect(hiddenPhone('+33612345678'), equals('+336****5678'));
    });

    test('澳大利亚号码', () {
      expect(hiddenPhone('+61412345678'), equals('+614****5678'));
    });

    test('加拿大号码', () {
      expect(hiddenPhone('+14161234567'), equals('+141****4567'));
    });

    test('超长国际号码', () {

      expect(hiddenPhone('+390123456789012'), equals('+3901*******9012'));
    });

    test('短国际号码', () {
      expect(hiddenPhone('+1234567'), equals('+12***67'));
    });

    test('带空格国际号', () {
      expect(hiddenPhone('+44 7911 123456'), equals('+4479****3456'));
    });

    test('带横线国际号', () {
      expect(hiddenPhone('+1-416-123-4567'), equals('+141****4567'));
    });

    // 3. 边界情况测试
    test('最短有效号码(8位)', () {
      expect(hiddenPhone('12345678'), equals('123*5678'));
    });
    test('最短有效号码(7位)', () {
      // expect(hiddenPhone('1234567'), equals('123****567'));
      expect(hiddenPhone('1234567'), equals('1*****7'));
    });

    test('刚好11位非1开头', () {
      expect(hiddenPhone('23456789012'), equals('234****9012'));
    });

    test('12位号码', () {
      expect(hiddenPhone('123456789012'), equals('1234****9012'));
    });

    test('带特殊字符的号码', () {
      expect(hiddenPhone('+(86)138-1234-5678'), equals('+86138****5678'));
    });

    test('带多个特殊字符的号码', () {
      expect(hiddenPhone('+1 (416) 123-4567'), equals('+141****4567'));
    });

    test('6位号码', () {
      expect(hiddenPhone('123456'), equals('1****6'));
    });

    test('5位号码', () {
      expect(hiddenPhone('12345'), equals('1***5'));
    });

    test('4位号码', () {
      expect(hiddenPhone('1234'), equals('1**4'));
    });

    test('3位号码', () {
      expect(hiddenPhone('123'), equals('1****'));
    });

    test('2位号码', () {
      expect(hiddenPhone('12'), equals('1****'));
    });

    test('1位号码', () {
      expect(hiddenPhone('1'), equals('1****'));
    });

    // 4. 异常情况测试
    test('空字符串', () {
      expect(hiddenPhone(''), equals(''));
    });

    // test('纯特殊字符', () {
    //   expect(hiddenPhone('+- ()'), equals(''));
    // });

    test('非号码字符串', () {
      expect(hiddenPhone('abcdefg'), equals(''));
    });

    test('混合字母数字', () {
      expect(hiddenPhone('abc13812345678def'), equals('138****5678'));
    });

    // test('null输入', () {
    //   expect(hiddenPhone(null), equals(''));
    // });

    test('大量空格', () {
      expect(hiddenPhone('  1 3 8 1 2 3 4 5 6 7 8  '), equals('138****5678'));
    });

    test('全角数字', () {
      expect(hiddenPhone('１３８１２３４５６７８'), equals('138****5678'));
    });

    test('混合全角半角', () {
      expect(hiddenPhone('+８613812345678'), equals('+８613****5678'));
    });
  });

}
