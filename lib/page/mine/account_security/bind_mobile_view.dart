import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import 'package:imboy/component/locales/locales.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/mine/language/language_logic.dart';
import 'package:imboy/page/passport/passport_logic.dart';
import 'package:imboy/store/provider/user_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// BindMobilePage
/// 绑定/修改手机号页面：
/// 1) 输入国际手机号
/// 2) 发送短信验证码（scene: bind_mobile）
/// 3) 输入验证码并提交绑定到后端
/// 成功后刷新本地用户手机号并返回上一页
class BindMobilePage extends StatefulWidget {
  const BindMobilePage({super.key});

  @override
  State<BindMobilePage> createState() => _BindMobilePageState();
}

class _BindMobilePageState extends State<BindMobilePage> {
  final LanguageLogic langLogic = Get.put(LanguageLogic());
  final PassportLogic passportLogic = Get.put(PassportLogic());

  // 表单状态
  String _mobile = '';
  bool _mobileValid = false;
  final TextEditingController _codeCtl = TextEditingController();

  // 发送验证码防抖/倒计时
  Timer? _timer;
  int _seconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtl.dispose();
    super.dispose();
  }

  /// 启动倒计时
  void _startCountdown() {
    _timer?.cancel();
    setState(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_seconds <= 1) {
        t.cancel();
        setState(() => _seconds = 0);
      } else {
        setState(() => _seconds -= 1);
      }
    });
  }

  /// 发送短信验证码（scene: bind_mobile）
  Future<void> _sendCode() async {
    if (!_mobileValid || _mobile.isEmpty) {
      passportLogic.snackBar('param_format_error'.trArgs(['mobile'.tr]));
      return;
    }
    String? res = await passportLogic.sendCode('mobile', _mobile, 'signup');
    if (res == null) {
      passportLogic.snackBar(
        Text(
          'code_sent_to_param'.trArgs([_mobile]),
          style: const TextStyle(color: Colors.green, fontSize: 18),
        ),
        icon: const Icon(Icons.check_circle, color: Colors.green),
      );
      _startCountdown();
    } else {
      passportLogic.snackBar(res.tr);
    }
  }

  /// 提交绑定（带验证码）
  Future<void> _submit() async {
    if (!_mobileValid || _mobile.isEmpty) {
      passportLogic.snackBar('param_format_error'.trArgs(['mobile'.tr]));
      return;
    }
    final code = _codeCtl.text.trim();
    if (code.isEmpty) {
      passportLogic.snackBar('confirm_code_error'.tr);
      return;
    }
    bool ok = await UserProvider().changeMobile(mobile: _mobile, code: code);
    if (ok) {
      // 刷新本地用户信息（最小化处理：直接覆盖当前缓存字段）
      final user = UserRepoLocal.to.current;
      user.mobile = _mobile;
      await UserRepoLocal.to.changeInfo(user.toMap());

      passportLogic.snackBar(
        Text(
          'tip_success'.trArgs([hiddenPhone(_mobile)]),
          style: const TextStyle(color: Colors.green, fontSize: 18),
        ),
        icon: const Icon(Icons.check_circle, color: Colors.green),
      );
      Get.back(); // 返回到账户安全页
    } else {
      passportLogic.snackBar('unknown'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'set_param'.trArgs(['mobile'.tr]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 手机号输入
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withValues(alpha: .2), width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: InternationalPhoneNumberInput(
                    locale: sysLang('intl_phone_number_input'),
                    countries: langLogic.regionCodeList('intl_phone_number_input'),
                    initialValue:  PhoneNumber(isoCode: 'CN'),
                    inputBorder: InputBorder.none,
                    selectorConfig: const SelectorConfig(
                      selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                      useBottomSheetSafeArea: true,
                      trailingSpace: false,
                      leadingPadding: 0,
                    ),
                    searchBoxDecoration: InputDecoration(labelText: 'region_search_tips'.tr),
                    inputDecoration: InputDecoration(
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      hintText: 'please_input_param'.trArgs(['mobile'.tr]),
                      hintStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    ),

                    ignoreBlank: false,
                    formatInput: true,
                    keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                    onInputChanged: (PhoneNumber number) {
                      _mobile = number.phoneNumber ?? '';
                      // 兜底校验，避免库误判中国大陆手机号
                      _mobileValid = isPhone(_mobile);
                      setState(() {});
                    },
                    onInputValidated: (bool value) {
                      // 与本地兜底校验叠加
                      _mobileValid = value || isPhone(_mobile);
                      setState(() {});
                    },
                    onSaved: (PhoneNumber number) {},
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 获取验证码按钮（带倒计时，禁用态可见）
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_mobileValid && _seconds == 0) ? _sendCode : null,
                style: lightGreenButtonStyle(null),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    _seconds > 0 ? '${'resend_code'.tr} (${_seconds}s)' : 'resend_code'.tr,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 验证码输入
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withValues(alpha: .2), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('confirm_code'.tr, style: TextStyle(color: cs.onSurface.withValues(alpha: .8))),
                  const SizedBox(height: 8),
                  PinCodeTextField(
                    appContext: context,
                    length: 6,
                    controller: _codeCtl,
                    animationType: AnimationType.fade,
                    cursorColor: cs.primary,
                    obscureText: false,
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(8),
                      fieldHeight: 48,
                      fieldWidth: 42,
                      activeFillColor: Colors.white,
                      inactiveFillColor: Colors.white,
                      selectedFillColor: Colors.white,
                      selectedColor: cs.primary,
                    ),
                    animationDuration: const Duration(milliseconds: 250),
                    enableActiveFill: true,
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 确认绑定
            RoundedElevatedButton(
              text: 'button_confirm'.tr,
              onPressed: (_mobileValid && _codeCtl.text.trim().isNotEmpty) ? _submit : null,
              highlighted: true,
              size: Size(Get.width - 32, 52),
              borderRadius: BorderRadius.circular(12.0),
            ),
          ],
        ),
      ),
    );
  }
}