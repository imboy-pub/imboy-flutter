/// Same-origin, current-account requests for the JWT-protected media gateway.
library;

import 'package:imboy/component/http/http_client.dart' show defaultHeaders;
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/config/env.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class TalkRecordPlaybackRequest {
  const TalkRecordPlaybackRequest(this.uri, this.headers);
  final Uri uri;
  final Map<String, String> headers;
}

Uri talkRecordPlaybackUri(String input, Uri base, {String? recordId}) {
  final uri = base.resolve(input);
  final match = RegExp(
    r'^/api/v1/talk-records/([1-9][0-9]*)/playback/(?:stream|parts/(?:0|[1-9][0-9]*))$',
  ).firstMatch(uri.path);
  if (!{'http', 'https'}.contains(base.scheme) ||
      base.host.isEmpty ||
      uri.origin != base.origin ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      match == null ||
      (recordId != null && match.group(1) != recordId) ||
      uri.queryParametersAll.length != 1 ||
      uri.queryParametersAll['ticket']?.length != 1 ||
      (uri.queryParameters['ticket']?.isEmpty ?? true)) {
    throw StateError('Invalid controlled playback endpoint');
  }
  return uri;
}

class TalkRecordPlaybackRequestResolver {
  TalkRecordPlaybackRequestResolver({
    required this.baseUri,
    required this.accountId,
    required this.authenticationHeaders,
  });

  factory TalkRecordPlaybackRequestResolver.production() =>
      TalkRecordPlaybackRequestResolver(
        baseUri: () => Uri.parse(Env().apiBaseUrl),
        accountId: () => UserRepoLocal.to.isAuthTransitioning
            ? ''
            : UserRepoLocal.to.currentUid,
        authenticationHeaders: () async {
          final headers = await defaultHeaders();
          final token = await UserRepoLocal.to.accessToken;
          if (token.isEmpty) {
            throw StateError('Playback authentication unavailable');
          }
          return {
            for (final entry in headers.entries)
              entry.key: entry.value.toString(),
            Keys.tokenKey: token,
          };
        },
      );

  final Uri Function() baseUri;
  final String Function() accountId;
  final Future<Map<String, String>> Function() authenticationHeaders;
  String? _boundAccount;

  String get accountKey => '${baseUri().origin}|${accountId()}';

  Future<TalkRecordPlaybackRequest> resolve(String url) async {
    final account = accountKey;
    if (accountId().isEmpty ||
        (_boundAccount != null && _boundAccount != account)) {
      throw StateError('Playback account changed');
    }
    _boundAccount = account;
    final uri = talkRecordPlaybackUri(url, baseUri());
    final headers = await authenticationHeaders();
    if (account != accountKey || accountId().isEmpty) {
      throw StateError('Playback account changed');
    }
    if ((headers[Keys.tokenKey]?.isEmpty ?? true)) {
      throw StateError('Playback authentication unavailable');
    }
    return TalkRecordPlaybackRequest(uri, Map.unmodifiable(headers));
  }
}
