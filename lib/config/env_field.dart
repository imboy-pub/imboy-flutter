
/// Both DebugEnv and ReleaseEnv must implement all these values
abstract interface class EnvField {
  abstract final String apiBaseUrl;
  abstract final String iosAppId;
  abstract final String solidifiedKey;
  abstract final String solidifiedKeyIv;
  abstract final String aMapIosKey;
  abstract final String aMapAndroidKey;
  abstract final String aMapWebKey;
  abstract final String jiguangAppKey;
}
