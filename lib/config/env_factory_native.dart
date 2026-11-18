import 'package:flutter/foundation.dart';

import 'env.dart';
import 'env_dev.dart';
import 'env_local.dart';
import 'env_local_home.dart';
import 'env_local_office.dart';
import 'env_pro.dart';

Map<String, Env> createEnvMap() => {
  'pro': EnvPro(),
  'dev': EnvDev(),
  'local': EnvLocal(),
  'local_home': EnvLocalHome(),
  'local_office': EnvLocalOffice(),
};

Env fallbackEnv() {
  if (kDebugMode) debugPrint('⚠️ [Env] 当前环境无效，使用默认生产环境配置');
  return EnvPro();
}
