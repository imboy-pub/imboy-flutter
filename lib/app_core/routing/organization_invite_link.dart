import 'package:imboy/config/const.dart' show webBaseUrl;

/// Shared invitation contract for sharing, scanning and native navigation.
String? normalizeOrganizationInviteCode(String value) {
  final code = value.trim().toUpperCase();
  return RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(code) ? code : null;
}

String organizationInviteUrl(String code) {
  final base = Uri.parse(webBaseUrl);
  if (base.scheme != 'https' ||
      base.host.isEmpty ||
      base.userInfo.isNotEmpty ||
      base.hasQuery ||
      base.hasFragment ||
      (base.path.isNotEmpty && base.path != '/')) {
    throw StateError('WEB_BASE_URL must be an HTTPS origin');
  }
  final normalized = normalizeOrganizationInviteCode(code);
  if (normalized == null) throw ArgumentError.value(code, 'code');
  return base.replace(path: '/invite/org/$normalized').toString();
}

String? organizationInviteCode(String? raw) {
  try {
    final uri = Uri.tryParse(raw?.trim() ?? '');
    if (uri == null || uri.userInfo.isNotEmpty || uri.hasFragment) return null;
    if (uri.scheme == 'imboy' &&
        uri.host.toLowerCase() == 'org' &&
        uri.path.toLowerCase() == '/join' &&
        !uri.hasPort) {
      final codes = uri.queryParametersAll.entries
          .where((e) => {'c', 'code'}.contains(e.key.toLowerCase()))
          .expand((e) => e.value)
          .toList();
      return codes.length == 1
          ? normalizeOrganizationInviteCode(codes.single)
          : null;
    }
    final base = Uri.tryParse(webBaseUrl);
    if (base == null || uri.scheme != 'https' || uri.port != base.port) {
      return null;
    }
    final hosts = {base.host};
    if (base.host == 'imboy.pub' || base.host == 'www.imboy.pub') {
      hosts.addAll({'imboy.pub', 'www.imboy.pub'});
    }
    if (!hosts.contains(uri.host) || uri.hasQuery) return null;
    final parts = uri.pathSegments;
    if (parts.length != 3 || parts[0] != 'invite' || parts[1] != 'org') {
      return null;
    }
    return normalizeOrganizationInviteCode(parts[2]);
  } on FormatException {
    return null;
  }
}

String? organizationInviteLocation(String? raw) {
  final code = organizationInviteCode(raw);
  return code == null ? null : '/organization/picker?autoJoin=1&code=$code';
}
