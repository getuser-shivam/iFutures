import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class BinanceApiService {
  final String apiKey;
  final String apiSecret;
  final bool isTestnet;

  late final http.Client _client;
  int _timestampOffsetMs = 0;

  String get baseUrl => isTestnet
      ? 'https://testnet.binancefuture.com'
      : 'https://fapi.binance.com';

  BinanceApiService({
    required this.apiKey,
    required this.apiSecret,
    this.isTestnet = true,
  }) {
    _client = http.Client();
  }

  bool get hasCredentials =>
      apiKey.trim().isNotEmpty && apiSecret.trim().isNotEmpty;

  String _generateSignature(String queryString) {
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
    int retryCount = 0,
  }) async {
    final requestParams = <String, dynamic>{...?params};
    if (signed) {
      requestParams.putIfAbsent('recvWindow', () => 5000);
      requestParams['timestamp'] =
          DateTime.now().millisecondsSinceEpoch + _timestampOffsetMs;
      requestParams['signature'] = _generateSignature(
        _buildQueryString(requestParams),
      );
    }

    final queryString = _buildQueryString(requestParams);
    final headers = <String, String>{
      'X-MBX-APIKEY': apiKey,
      'Content-Type': 'application/x-www-form-urlencoded',
    };
    final upperMethod = method.toUpperCase();

    try {
      late final http.Response response;
      switch (upperMethod) {
        case 'GET':
          final uri = Uri.parse(
            queryString.isEmpty
                ? '$baseUrl$path'
                : '$baseUrl$path?$queryString',
          );
          response = await _client.get(uri, headers: headers);
          break;
        case 'POST':
          final uri = Uri.parse('$baseUrl$path');
          response = await _client.post(
            uri,
            headers: headers,
            body: queryString,
          );
          break;
        default:
          throw UnsupportedError('Unsupported HTTP method: $method');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (signed &&
            retryCount == 0 &&
            _isTimestampDriftErrorBody(response.body)) {
          await syncServerTime();
          return _sendRequest<T>(
            method,
            path,
            params: params,
            signed: signed,
            retryCount: retryCount + 1,
          );
        }
        print('HTTP error: ${response.body}');
        throw BinanceApiException(response.statusCode, response.body);
      }

      return jsonDecode(response.body) as T;
    } on BinanceApiException {
      rethrow;
    } catch (e) {
      if (signed && retryCount == 0 && _isTimestampDriftErrorBody('$e')) {
        await syncServerTime();
        return _sendRequest<T>(
          method,
          path,
          params: params,
          signed: signed,
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

  Future<int> getServerTime() async {
    final response = await _sendRequest<Map<String, dynamic>>(
      'GET',
      '/fapi/v1/time',
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

  Future<void> syncServerTime() async {
    final serverTime = await getServerTime();
    _timestampOffsetMs = serverTime - DateTime.now().millisecondsSinceEpoch;
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

  BinanceApiException(this.statusCode, this.body);

  @override
  String toString() => 'BinanceApiException($statusCode): $body';
}
