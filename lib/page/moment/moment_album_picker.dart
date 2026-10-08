import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

Future<List<AssetEntity>?> pickMomentAlbum(
  BuildContext context, {
  required int maxAssets,
}) async {
  try {
    return await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: maxAssets,
        requestType: RequestType.common,
        specialPickerType: SpecialPickerType.wechatMoment,
      ),
    );
  } on StateError catch (error) {
    // The picker documents permission denial as StateError, not Exception.
    // Other state errors must still propagate instead of becoming cancellation.
    if (!error.message.toString().startsWith(
      'Permission state error with PermissionState.',
    )) {
      rethrow;
    }
    if (context.mounted) {
      unawaited(
        AppLoading.showInfo(context.t.common.permissionAcquisitionFailed),
      );
    }
    return null;
  }
}
