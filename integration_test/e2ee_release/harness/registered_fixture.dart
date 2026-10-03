import '../fixture_contract.dart';

/// Registered identities supplied by an authorized seed operation.
/// This validates binding structure only, not registration or authorization.
class RegisteredDevice {
  const RegisteredDevice({
    required this.alias,
    required this.accountAlias,
    required this.accountId,
    required this.did,
    required this.platform,
    required this.tokenReference,
  });

  final String alias;
  final String accountAlias;
  final String accountId;
  final String did;
  final String platform;
  // An environment variable name, never an access token value.
  final String tokenReference;
}

class RegisteredFixture {
  RegisteredFixture._(this.runTag, this.devices, this.groupIds);

  final String runTag;
  final Map<String, RegisteredDevice> devices;
  final Map<String, String> groupIds;

  factory RegisteredFixture.bind({
    required FixtureSet fixture,
    required String runTag,
    required List<RegisteredDevice> devices,
    required Map<String, String> groupIds,
  }) {
    if (!isValidRunTag(runTag) || runTag != fixture.runTag) {
      throw const FormatException('fixture run mismatch');
    }
    final expected = _expectedDevices(fixture);
    final bound = <String, RegisteredDevice>{};
    final dids = <String>{};
    final accountIds = <String, String>{};
    final idOwners = <String, String>{};
    for (final device in devices) {
      _validateDevice(device, expected);
      if (bound.containsKey(device.alias) || !dids.add(device.did)) {
        throw const FormatException('duplicate device binding');
      }
      final oldId = accountIds[device.accountAlias];
      final oldOwner = idOwners[device.accountId];
      if ((oldId != null && oldId != device.accountId) ||
          (oldOwner != null && oldOwner != device.accountAlias)) {
        throw const FormatException('account binding conflict');
      }
      accountIds[device.accountAlias] = device.accountId;
      idOwners[device.accountId] = device.accountAlias;
      bound[device.alias] = device;
    }
    if (bound.length != expected.length) {
      throw const FormatException('missing device binding');
    }
    _validateGroups(fixture, groupIds);
    return RegisteredFixture._(
      runTag,
      Map.unmodifiable(bound),
      Map.unmodifiable(groupIds),
    );
  }
}

Map<String, (String, String)> _expectedDevices(FixtureSet fixture) {
  final result = <String, (String, String)>{};
  final accounts = <String>{};
  for (final account in fixture.accounts) {
    if (!accounts.add(account.uid) || account.devices.isEmpty) {
      throw const FormatException('invalid fixture account');
    }
    for (final device in account.devices) {
      if (result.containsKey(device.deviceId)) {
        throw const FormatException('duplicate fixture device');
      }
      result[device.deviceId] = (account.uid, device.platform);
    }
  }
  if (result.isEmpty) throw const FormatException('empty fixture');
  return result;
}

void _validateDevice(
  RegisteredDevice device,
  Map<String, (String, String)> expected,
) {
  final owner = expected[device.alias];
  if (owner == null ||
      owner.$1 != device.accountAlias ||
      owner.$2 != device.platform ||
      !const {'android', 'ios', 'macos'}.contains(device.platform) ||
      !_validId(device.accountId) ||
      device.did.trim().isEmpty ||
      device.did != device.did.trim() ||
      !RegExp(r'^[A-Z][A-Z0-9_]{1,127}$').hasMatch(device.tokenReference)) {
    throw const FormatException('invalid registered device binding');
  }
}

bool _validId(String value) {
  if (!RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(value)) return false;
  return BigInt.parse(value) <= BigInt.parse('9223372036854775807');
}

void _validateGroups(FixtureSet fixture, Map<String, String> groups) {
  final aliases = fixture.groups.map((group) => group.gid).toSet();
  if (aliases.length != fixture.groups.length ||
      groups.length != aliases.length ||
      groups.keys.any((alias) => !aliases.contains(alias)) ||
      groups.values.any((id) => !_validId(id)) ||
      groups.values.toSet().length != groups.length) {
    throw const FormatException('invalid group binding');
  }
}
