import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

enum BinanceApiScope { spot, futures }

class BinanceApiService {
  final String apiKey;
  final String apiSecret;
  final bool isTestnet;

  late final http.Client _client;
  final Map<BinanceApiScope, int> _timestampOffsetsMs = {
    BinanceApiScope.spot: 0,
    BinanceApiScope.futures: 0,
  };

  String get baseUrl => _baseUrlFor(BinanceApiScope.futures);

  BinanceApiService({
    required this.apiKey,
    required this.apiSecret,
    this.isTestnet = true,
  }) {
    _client = http.Client();
  }

  bool get hasCredentials =>
      apiKey.trim().isNotEmpty && apiSecret.trim().isNotEmpty;

  String _baseUrlFor(BinanceApiScope scope) {
    return switch (scope) {
      BinanceApiScope.spot =>
        isTestnet
            ? 'https://testnet.binance.vision'
            : 'https://api.binance.com',
      BinanceApiScope.futures =>
        isTestnet
            ? 'https://testnet.binancefuture.com'
            : 'https://fapi.binance.com',
    };
  }

  String _generateSignature(String queryString) {
    return signPayload(queryString, apiSecret);
  }

  static String signPayload(String queryString, String apiSecret) {
    final key = utf8.encode(apiSecret);
    final bytes = utf8.encode(queryString);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString();
  }

  Future<T> _sendRequest<T>(
    String method,
    String path, {
    Map<String, dynamic>? params,
    bool signed = false,
    BinanceApiScope scope = BinanceApiScope.futures,
    int retryCount = 0,
  }) async {
    final requestParams = <String, dynamic>{...?params};
    if (signed) {
      requestParams.putIfAbsent('recvWindow', () => 5000);
      final timestamp =
          DateTime.now().millisecondsSinceEpoch + _timestampOffsetsMs[scope]!;
      requestParams['timestamp'] = timestamp;
      final queryString = _buildQueryString(requestParams);
      requestParams['signature'] = _generateSignature(queryString);

      print('--- BINANCE SIGNED REQUEST ---');
      print('Scope: $scope, Mode: ${isTestnet ? "TESTNET" : "LIVE"}');
      print(
        'API Key: ${apiKey.substring(0, 4)}...${apiKey.substring(apiKey.length - 4)} (Length: ${apiKey.length})',
      );
      print('Timestamp: $timestamp');
      print('Query: $queryString');
    }

    final queryString = _buildQueryString(requestParams);
    final baseUrl = _baseUrlFor(scope);
    final headers = <String, String>{
      'X-MBX-APIKEY': apiKey,
      'Content-Type': 'application/x-www-form-urlencoded',
    };
    final upperMethod = method.toUpperCase();

    try {
      late final http.Response response;
      late final Uri requestUri;
      switch (upperMethod) {
        case 'GET':
          requestUri = Uri.parse(
            queryString.isEmpty
                ? '$baseUrl$path'
                : '$baseUrl$path?$queryString',
          );
          response = await _client.get(requestUri, headers: headers);
          break;
        case 'POST':
          requestUri = Uri.parse(
            queryString.isEmpty
                ? '$baseUrl$path'
                : '$baseUrl$path?$queryString',
          );
          response = await _client.post(requestUri, headers: headers);
          break;
        default:
          throw UnsupportedError('Unsupported HTTP method: $method');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (signed &&
            retryCount == 0 &&
            _isTimestampDriftErrorBody(response.body)) {
          await syncServerTime(scope: scope);
          return _sendRequest<T>(
            method,
            path,
            params: params,
            signed: signed,
            scope: scope,
            retryCount: retryCount + 1,
          );
        }
        throw BinanceApiException(
          statusCode: response.statusCode,
          body: response.body,
          method: upperMethod,
          path: path,
          scope: scope,
          requestUri: response.request?.url ?? requestUri,
          headers: response.headers,
        );
      }

      return jsonDecode(response.body) as T;
    } on BinanceApiException {
      rethrow;
    } catch (e) {
      if (signed && retryCount == 0 && _isTimestampDriftErrorBody('$e')) {
        await syncServerTime(scope: scope);
        return _sendRequest<T>(
          method,
          path,
          params: params,
          signed: signed,
          scope: scope,
          retryCount: retryCount + 1,
        );
      }
      print('HTTP client error: $e');
      rethrow;
    }
  }

  String _buildQueryString(Map<String, dynamic> params) {
    return params.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value.toString())}',
        )
        .join('&');
  }

  // --- API Methods ---

  Future<int> getServerTime({
    BinanceApiScope scope = BinanceApiScope.futures,
  }) async {
    final response = await _sendRequest<Map<String, dynamic>>(
      'GET',
      scope == BinanceApiScope.futures ? '/fapi/v1/time' : '/api/v3/time',
      scope: scope,
    );
    final serverTime = response['serverTime'];
    if (serverTime is int) {
      return serverTime;
    }
    if (serverTime is num) {
      return serverTime.toInt();
    }
    return int.parse(serverTime.toString());
  }

  Future<void> syncServerTime({
    BinanceApiScope scope = BinanceApiScope.futures,
  }) async {
    final serverTime = await getServerTime(scope: scope);
    _timestampOffsetsMs[scope] =
        serverTime - DateTime.now().millisecondsSinceEpoch;
  }

  Future<Map<String, dynamic>> getSpotAccountInfo() async {
    return _sendRequest<Map<String, dynamic>>(
      'GET',
      '/api/v3/account',
      signed: true,
      scope: BinanceApiScope.spot,
    );
  }

  Future<Map<String, dynamic>> getSpotApiRestrictions() async {
    return _sendRequest<Map<String, dynamic>>(
      'GET',
      '/sapi/v1/account/apiRestrictions',
      signed: true,
      scope: BinanceApiScope.spot,
    );
  }

  Future<Map<String, dynamic>> getAccountInfo() async {
    return _sendRequest<Map<String, dynamic>>(
      'GET',
      '/fapi/v2/account',
      signed: true,
    );
  }

  Future<Map<String, dynamic>> getBalance() async {
    return _sendRequest<Map<String, dynamic>>(
      'GET',
      '/fapi/v2/balance',
      signed: true,
    );
  }

  Future<Map<String, dynamic>> getExchangeInfo() async {
    return _sendRequest<Map<String, dynamic>>('GET', '/fapi/v1/exchangeInfo');
  }

  Future<Map<String, dynamic>> placeOrder({
    required String symbol,
    required String side,
    required String type,
    String? quantity,
    String? price,
    String? stopPrice,
  }) async {
    final params = {
      'symbol': symbol.toUpperCase(),
      'side': side.toUpperCase(),
      'type': type.toUpperCase(),
    };
    if (quantity != null) params['quantity'] = quantity;
    if (price != null) params['price'] = price;
    if (stopPrice != null) params['stopPrice'] = stopPrice;

    return _sendRequest<Map<String, dynamic>>(
      'POST',
      '/fapi/v1/order',
      params: params,
      signed: true,
    );
  }

  Future<Map<String, dynamic>> setLeverage({
    required String symbol,
    required int leverage,
  }) async {
    final params = <String, dynamic>{
      'symbol': symbol.toUpperCase(),
      'leverage': leverage,
    };
    return _sendRequest<Map<String, dynamic>>(
      'POST',
      '/fapi/v1/leverage',
      params: params,
      signed: true,
    );
  }

  Future<Map<String, dynamic>> setMarginType({
    required String symbol,
    required String marginType, // ISOLATED, CROSSED
  }) async {
    final params = {
      'symbol': symbol.toUpperCase(),
      'marginType': marginType.toUpperCase(),
    };
    return _sendRequest<Map<String, dynamic>>(
      'POST',
      '/fapi/v1/marginType',
      params: params,
      signed: true,
    );
  }

  Future<List<dynamic>> getKlines({
    required String symbol,
    String interval = '1m',
    int? limit,
  }) async {
    final params = <String, dynamic>{
      'symbol': symbol.toUpperCase(),
      'interval': interval,
    };
    if (limit != null) params['limit'] = limit;

    return _sendRequest<List<dynamic>>(
      'GET',
      '/fapi/v1/klines',
      params: params,
    );
  }

  Future<Map<String, dynamic>> getOrderBook({
    required String symbol,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'symbol': symbol.toUpperCase(),
      'limit': limit,
    };

    return _sendRequest<Map<String, dynamic>>(
      'GET',
      '/fapi/v1/depth',
      params: params,
    );
  }

  Future<List<dynamic>> getUserTrades({
    required String symbol,
    int limit = 100,
  }) async {
    final params = <String, dynamic>{
      'symbol': symbol.toUpperCase(),
      'limit': limit,
    };

    return _sendRequest<List<dynamic>>(
      'GET',
      '/fapi/v1/userTrades',
      params: params,
      signed: true,
    );
  }

  Future<List<dynamic>> getPositionRisk({String? symbol}) async {
    final params = <String, dynamic>{};
    if (symbol != null && symbol.trim().isNotEmpty) {
      params['symbol'] = symbol.toUpperCase();
    }

    try {
      return _sendRequest<List<dynamic>>(
        'GET',
        '/fapi/v3/positionRisk',
        params: params,
        signed: true,
      );
    } on BinanceApiException {
      return _sendRequest<List<dynamic>>(
        'GET',
        '/fapi/v2/positionRisk',
        params: params,
        signed: true,
      );
    }
  }

  bool _isTimestampDriftErrorBody(String message) {
    return message.contains('-1021') ||
        message.toLowerCase().contains('timestamp for this request');
  }
}

class BinanceApiException implements Exception {
  final int statusCode;
  final String body;
  final String method;
  final String path;
  final BinanceApiScope scope;
  final Uri requestUri;
  final Map<String, String> headers;

  late final int? errorCode = _parseErrorCode(body);
  late final String? errorMessage = _parseErrorMessage(body);

  BinanceApiException({
    required this.statusCode,
    required this.body,
    required this.method,
    required this.path,
    required this.scope,
    required this.requestUri,
    required this.headers,
  });

  static int? _parseErrorCode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final code = decoded['code'];
        if (code is int) return code;
        if (code is num) return code.toInt();
        return int.tryParse('$code');
      }
    } catch (_) {}
    return null;
  }

  static String? _parseErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['msg'];
        return message?.toString();
      }
    } catch (_) {}
    return null;
  }

  @override
  String toString() {
    final codeText = errorCode == null ? '' : ', code=$errorCode';
    final messageText = errorMessage == null ? '' : ', msg=$errorMessage';
    return 'BinanceApiException(status=$statusCode$codeText$messageText, method=$method, path=$path, scope=$scope)';
  }
}
