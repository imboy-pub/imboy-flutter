import 'dart:io';
import 'package:yaml/yaml.dart';

const Map<String, String> keyToNamespace = {
  'accept': 'common', 'cancel': 'common', 'ok': 'common', 'save': 'common', 'reset': 'common', 'clear': 'common', 'close': 'common', 'confirm': 'common', 'continue': 'common', 'copy': 'common', 'delete': 'common', 'edit': 'common', 'back': 'common', 'next': 'common', 'retry': 'common', 'submit': 'common', 'success': 'common', 'failed': 'common', 'loading': 'common', 'processing': 'common', 'done': 'common', 'search': 'common', 'add': 'common', 'remove': 'common', 'update': 'common', 'all': 'common', 'none': 'common', 'yes': 'common', 'no': 'common', 'on': 'common', 'off': 'common', 'enabled': 'common', 'disabled': 'common', 'button': 'common', 'tip': 'common', 'warning': 'common', 'error': 'common', 'info': 'common', 'details': 'common', 'more': 'common', 'options': 'common', 'settings': 'common', 'language': 'common', 'version': 'common', 'about': 'common', 'feedback': 'common', 'help': 'common', 'share': 'common', 'upload': 'common', 'download': 'common', 'saveSuccess': 'common', 'saveFailed': 'common', 'operationSuccessful': 'common', 'operationSuccess': 'common', 'operationFailed': 'common', 'comingSoon': 'common', 'featureComingSoon': 'common', 'featureInDevelopment': 'common', 'featureNotImplemented': 'common', 'understood': 'common', 'noProblem': 'common', 'onMyWay': 'common', 'today': 'common', 'yesterday': 'common', 'tomorrow': 'common', 'now': 'common', 'justNow': 'common', 'minutesAgo': 'common', 'hoursAgo': 'common', 'daysAgo': 'common', 'timeJustNow': 'common', 'timeMinutesAgo': 'common', 'timeHoursAgo': 'common', 'timeDaysAgo': 'common', 'timeToday': 'common', 'timeYesterday': 'common',
  'chat': 'chat', 'message': 'chat', 'send': 'chat', 'receive': 'chat', 'voice': 'chat', 'video': 'chat', 'image': 'chat', 'file': 'chat', 'location': 'chat', 'contact': 'chat', 'card': 'chat', 'revoke': 'chat', 'revoked': 'chat', 'reply': 'chat', 'forward': 'chat', 'history': 'chat', 'typing': 'chat', 'online': 'chat', 'offline': 'chat', 'mute': 'chat', 'unmute': 'chat', 'pin': 'chat', 'unpin': 'chat', 'burn': 'chat', 'read': 'chat', 'unread': 'chat', 'mention': 'chat', 'at': 'chat',
  'account': 'account', 'profile': 'account', 'nickname': 'account', 'avatar': 'account', 'gender': 'account', 'birthday': 'account', 'region': 'account', 'signature': 'account', 'qrCode': 'account', 'myQRCode': 'account', 'login': 'account', 'logout': 'account', 'register': 'account', 'signup': 'account', 'password': 'account', 'email': 'account', 'mobile': 'account', 'phone': 'account', 'security': 'account', 'device': 'account', 'wallet': 'account', 'balance': 'account', 'recharge': 'account', 'withdraw': 'account',
  'friend': 'contact', 'contacts': 'contact', 'newFriend': 'contact', 'apply': 'contact', 'verification': 'contact', 'remark': 'contact', 'tag': 'contact', 'tags': 'contact', 'denylist': 'contact', 'blocked': 'contact', 'blackList': 'contact',
  'group': 'group', 'members': 'group', 'announcement': 'group', 'admin': 'group', 'owner': 'group', 'creator': 'group', 'join': 'group', 'leave': 'group', 'dissolve': 'group', 'management': 'group',
  'discover': 'discovery', 'moments': 'discovery', 'moment': 'discovery', 'nearby': 'discovery', 'shake': 'discovery', 'scan': 'discovery', 'channel': 'discovery',
  'network': 'error', 'connection': 'error', 'timeout': 'error', 'invalid': 'error', 'required': 'error', 'notFound': 'error', 'serverError': 'error', 'accessDenied': 'error', 'notAuthorized': 'error',
};

const List<String> forcedNamespaces = ['splash', 'channel', 'passport', 'groupVote', 'groupSchedule', 'groupTask', 'groupCategory', 'groupTag', 'mention', 'momentNotify', 'momentFriendPicker', 'welcome', 'complaint'];

void main() async {
  final i18nDir = Directory('assets/i18n');
  final files = i18nDir.listSync().whereType<File>().where((f) => f.path.endsWith('.i18n.yaml')).toList();

  for (final file in files) {
    final locale = file.uri.pathSegments.last.split('.').first;
    final yaml = loadYaml(file.readAsStringSync()) as YamlMap;
    final namespaces = <String, Map<String, dynamic>>{};

    yaml.forEach((key, value) {
      String ns = 'main';
      String keyStr = key.toString();
      if (forcedNamespaces.contains(keyStr) || (value is Map && !keyToNamespace.containsKey(keyStr))) {
        ns = keyStr;
      } else {
        bool matched = false;
        if (keyToNamespace.containsKey(keyStr)) { ns = keyToNamespace[keyStr]!; matched = true; }
        else {
          for (final entry in keyToNamespace.entries) {
            if (keyStr.toLowerCase().contains(entry.key.toLowerCase())) { ns = entry.value; matched = true; break; }
          }
        }
      }
      
      final Map<String, dynamic> nsMap = namespaces.putIfAbsent(ns, () => {});
      
      // UNWRAP logic: If the key matches the namespace name, and it's a map, unwrap its contents
      if (keyStr == ns && value is Map) {
        value.forEach((k, v) {
          nsMap[k.toString()] = _convertYamlValue(v);
        });
      } else {
        nsMap[keyStr] = _convertYamlValue(value);
      }
    });

    for (var ns in namespaces.keys) { _updateLinksInNamespace(namespaces[ns]!, namespaces); }
    final outputDir = Directory('assets/i18n/$locale');
    if (outputDir.existsSync()) outputDir.deleteSync(recursive: true);
    outputDir.createSync(recursive: true);
    namespaces.forEach((ns, data) {
      if (data.isEmpty) return;
      final sink = File('assets/i18n/$locale/$ns.i18n.yaml').openWrite();
      _writeYaml(sink, data, 0);
      sink.close();
    });
  }
}

void _updateLinksInNamespace(dynamic node, Map<String, Map<String, dynamic>> allNamespaces) {
  if (node is Map) {
    for (var key in node.keys.toList()) {
      final value = node[key];
      if (value is String && value.startsWith('@:')) {
        final targetKey = value.substring(2);
        String? foundNs;
        for (var ns in allNamespaces.keys) {
           final nsData = allNamespaces[ns]!;
           if (nsData.containsKey(targetKey)) {
             foundNs = ns;
             break;
           }
        }
        if (foundNs != null) node[key] = '@:$foundNs.$targetKey';
      } else { _updateLinksInNamespace(value, allNamespaces); }
    }
  } else if (node is List) {
    for (var i = 0; i < node.length; i++) {
      final value = node[i];
      if (value is String && value.startsWith('@:')) {
        final targetKey = value.substring(2);
        String? foundNs;
        for (var ns in allNamespaces.keys) {
           if (allNamespaces[ns]!.containsKey(targetKey)) {
             foundNs = ns;
             break;
           }
        }
        if (foundNs != null) node[i] = '@:$foundNs.$targetKey';
      } else { _updateLinksInNamespace(value, allNamespaces); }
    }
  }
}

dynamic _convertYamlValue(dynamic value) {
  if (value is YamlMap) return value.map((k, v) => MapEntry(k.toString(), _convertYamlValue(v)));
  if (value is YamlList) return value.map((v) => _convertYamlValue(v)).toList();
  return value;
}

void _writeYaml(IOSink sink, Map<String, dynamic> data, int indent) {
  final spaces = '  ' * indent;
  data.forEach((key, value) {
    if (value is Map) { sink.writeln('$spaces$key:'); _writeYaml(sink, value as Map<String, dynamic>, indent + 1); }
    else if (value is List) { sink.writeln('$spaces$key:'); for (final item in value) sink.writeln('$spaces  - ${_escapeValue(item)}'); }
    else sink.writeln('$spaces$key: ${_escapeValue(value)}');
  });
}

String _escapeValue(dynamic value) {
  if (value == null) return 'null';
  final s = value.toString();
  final specialChars = [':', '#', '[', ']', '{', '}', '!', '*', '&', '|', '>', '<', '=', '%', '@', ',', '`'];
  if (s.isEmpty || s.startsWith(' ') || s.endsWith(' ') || s.startsWith('-') || s.startsWith('?') || s.contains('\n') || specialChars.any((char) => s.contains(char))) {
    return '"${s.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
  }
  return s;
}
