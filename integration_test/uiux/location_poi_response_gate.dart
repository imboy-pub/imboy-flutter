import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Delays one actual AMap response; TLS, bytes and every other request stay native.
class LocationPoiResponseGate extends HttpOverrides {
  String? _keyword;
  Completer<void>? _observed;
  Completer<void>? _release;
  int held = 0;
  int released = 0;
  int consumed = 0;
  int searches = 0;
  int aroundRequests = 0;
  int aroundResponses = 0;
  final _clients = <HttpClient>[];
  Future<void> get observed => _observed!.future;

  void arm(String keyword) {
    if (_release != null) throw StateError('POI response already held');
    _keyword = keyword;
    _observed = Completer<void>();
    _release = Completer<void>();
  }

  void release() {
    _keyword = null;
    final pending = _release;
    _release = null;
    if (pending != null && !pending.isCompleted) {
      released++;
      pending.complete();
    }
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final native = super.createHttpClient(context);
    _clients.add(native);
    return _Client(native, this);
  }

  void close() {
    release();
    for (final client in _clients) {
      client.close(force: true);
    }
    _clients.clear();
  }

  HttpClientRequest wrap(Uri uri, HttpClientRequest request) {
    if (uri.scheme == 'https' &&
        uri.host == 'restapi.amap.com' &&
        uri.path == '/v5/place/around') {
      aroundRequests++;
      if (aroundRequests > 20) {
        request.abort();
        throw StateError('UX01 around request budget exceeded');
      }
      return _AroundRequest(request, this);
    }
    if (uri.scheme != 'https' ||
        uri.host != 'restapi.amap.com' ||
        uri.path != '/v5/place/text') {
      return request;
    }
    searches++;
    if (searches > 40) throw StateError('UX01 POI request budget exceeded');
    if (uri.queryParameters['keywords'] != _keyword) return request;
    _keyword = null;
    return _Request(request, this, _release!.future);
  }
}

class _AroundRequest extends _Request {
  _AroundRequest(HttpClientRequest native, LocationPoiResponseGate gate)
    : super(native, gate, Future<void>.value());
  @override
  Future<HttpClientResponse> close() async {
    final response = await native.close();
    final bytes = await response.fold<List<int>>(
      [],
      (out, part) => out..addAll(part),
    );
    final Object? payload;
    try {
      payload = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw StateError('UX01 actual around response was not valid JSON');
    }
    if (response.statusCode != 200 ||
        payload is! Map ||
        payload['status']?.toString() != '1' ||
        payload['pois'] is! List) {
      throw StateError('UX01 actual around response was not successful');
    }
    return _Response(response, bytes, () => gate.aroundResponses++);
  }
}

class _Client implements HttpClient {
  _Client(this.native, this.gate);
  final HttpClient native;
  final LocationPoiResponseGate gate;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      gate.wrap(url, await native.openUrl(method, url));
  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);
  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);
  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);
  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) => native.open(method, host, port, path);
  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      native.get(host, port, path);
  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      native.post(host, port, path);
  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      native.put(host, port, path);
  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      native.delete(host, port, path);
  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      native.patch(host, port, path);
  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      native.head(host, port, path);
  @override
  int? get maxConnectionsPerHost => native.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) => native.maxConnectionsPerHost = value;
  @override
  set authenticate(Future<bool> Function(Uri, String, String?)? value) =>
      native.authenticate = value;
  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) => native.addCredentials(url, realm, credentials);
  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(Uri, String?, int?)? value,
  ) => native.connectionFactory = value;
  @override
  set findProxy(String Function(Uri)? value) => native.findProxy = value;
  @override
  set authenticateProxy(
    Future<bool> Function(String, int, String, String?)? value,
  ) => native.authenticateProxy = value;
  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) => native.addProxyCredentials(host, port, realm, credentials);
  @override
  set badCertificateCallback(
    bool Function(X509Certificate, String, int)? value,
  ) => native.badCertificateCallback = value;
  @override
  set keyLog(void Function(String)? value) => native.keyLog = value;
  @override
  Duration? get connectionTimeout => native.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => native.connectionTimeout = value;
  @override
  Duration get idleTimeout => native.idleTimeout;
  @override
  set idleTimeout(Duration value) => native.idleTimeout = value;
  @override
  bool get autoUncompress => native.autoUncompress;
  @override
  set autoUncompress(bool value) => native.autoUncompress = value;
  @override
  void close({bool force = false}) => native.close(force: force);
  @override
  String? get userAgent => native.userAgent;
  @override
  set userAgent(String? value) => native.userAgent = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unsupported UX01 HttpClient operation: ${invocation.memberName}',
  );
}

class _Request implements HttpClientRequest {
  _Request(this.native, this.gate, this.release);
  final HttpClientRequest native;
  final LocationPoiResponseGate gate;
  final Future<void> release;
  @override
  Future<HttpClientResponse> close() async {
    final response = await native.close();
    final bytes = await response.fold<List<int>>(
      [],
      (out, part) => out..addAll(part),
    );
    gate.held++;
    gate._observed!.complete();
    await release.timeout(const Duration(seconds: 30));
    return _Response(response, bytes, () => gate.consumed++);
  }

  @override
  HttpHeaders get headers => native.headers;
  @override
  bool get followRedirects => native.followRedirects;
  @override
  set followRedirects(bool value) => native.followRedirects = value;
  @override
  int get maxRedirects => native.maxRedirects;
  @override
  set maxRedirects(int value) => native.maxRedirects = value;
  @override
  bool get persistentConnection => native.persistentConnection;
  @override
  set persistentConnection(bool value) => native.persistentConnection = value;
  @override
  int get contentLength => native.contentLength;
  @override
  set contentLength(int value) => native.contentLength = value;
  @override
  Encoding get encoding => native.encoding;
  @override
  set encoding(Encoding value) => native.encoding = value;
  @override
  void add(List<int> data) => native.add(data);
  @override
  Future<void> addStream(Stream<List<int>> stream) => native.addStream(stream);
  @override
  Future<void> flush() => native.flush();
  @override
  void abort([Object? exception, StackTrace? stackTrace]) =>
      native.abort(exception, stackTrace);
  @override
  Future<HttpClientResponse> get done => native.done;
  @override
  bool get bufferOutput => native.bufferOutput;
  @override
  set bufferOutput(bool value) => native.bufferOutput = value;
  @override
  String get method => native.method;
  @override
  Uri get uri => native.uri;
  @override
  List<Cookie> get cookies => native.cookies;
  @override
  HttpConnectionInfo? get connectionInfo => native.connectionInfo;
  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      native.addError(error, stackTrace);
  @override
  void write(Object? object) => native.write(object);
  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      native.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => native.writeCharCode(charCode);
  @override
  void writeln([Object? object = '']) => native.writeln(object);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Unsupported UX01 request operation: ${invocation.memberName}',
  );
}

/// Original native response metadata and bytes, delivered once after the gate.
class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.native, List<int> bytes, this.onConsumed)
    : bytes = Uint8List.fromList(bytes);
  final HttpClientResponse native;
  final Uint8List bytes;
  final void Function() onConsumed;
  late final Stream<List<int>> _stream = _deliver();

  Stream<List<int>> _deliver() async* {
    yield bytes;
    onConsumed();
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  int get statusCode => native.statusCode;
  @override
  String get reasonPhrase => native.reasonPhrase;
  @override
  int get contentLength => native.contentLength;
  @override
  HttpClientResponseCompressionState get compressionState =>
      native.compressionState;
  @override
  bool get persistentConnection => native.persistentConnection;
  @override
  bool get isRedirect => native.isRedirect;
  @override
  List<RedirectInfo> get redirects => native.redirects;
  @override
  HttpHeaders get headers => native.headers;
  @override
  List<Cookie> get cookies => native.cookies;
  @override
  X509Certificate? get certificate => native.certificate;
  @override
  HttpConnectionInfo? get connectionInfo => native.connectionInfo;
  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) => native.redirect(method, url, followLoops);
  @override
  Future<Socket> detachSocket() => native.detachSocket();
}
