import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

class BinanceApiService {
  final String apiKey;
  final String apiSecret;
  final bool isTestnet;

  late final Dio _dio;

  String get baseUrl => isTestnet
      ? 'https://testnet.binancefuture.com'
      : 'https://fapi.binance.com';

  BinanceApiService({
    required this.apiKey,
    required this.apiSecret,
    this.isTestnet = true,
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {
        'X-MBX-APIKEY': apiKey,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    ));
  }

  String _generateSignature(String queryString) {
    final key = utf8.encode(apiSecret);
    final bytes = utf8.encode(queryString);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString();
  }

  Future<Map<String, dynamic>> _sendRequest(
    String method,
    String path, {
    Map<String, dynamic>? params,
    bool signed = false,
  }) async {
    params ??= {};
    if (signed) {
      params['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      final queryString = _buildQueryString(params);
      params['signature'] = _generateSignature(queryString);
    }

    try {
      final response = await _dio.request(
        path,
        queryParameters: params,
        options: Options(method: method),
      );
      return response.data;
    } on DioException catch (e) {
      print('Dio error: ${e.response?.data ?? e.message}');
      rethrow;
    }
  }

  String _buildQueryString(Map<String, dynamic> params) {
    return params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
  }

  // --- API Methods ---

  Future<Map<String, dynamic>> getAccountInfo() async {
    return _sendRequest('GET', '/fapi/v2/account', signed: true);
  }

  Future<Map<String, dynamic>> getBalance() async {
    return _sendRequest('GET', '/fapi/v2/balance', signed: true);
  }

  Future<Map<String, dynamic>> getExchangeInfo() async {
    return _sendRequest('GET', '/fapi/v1/exchangeInfo');
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

    return _sendRequest('POST', '/fapi/v1/order', params: params, signed: true);
  }

  Future<Map<String, dynamic>> setLeverage({
    required String symbol,
    required int leverage,
  }) async {
    final Map<String, dynamic> params = {
      'symbol': symbol.toUpperCase(),
      'leverage': leverage,
    };
    return _sendRequest('POST', '/fapi/v1/leverage', params: params, signed: true);
  }

  Future<Map<String, dynamic>> setMarginType({
    required String symbol,
    required String marginType, // ISOLATED, CROSSED
  }) async {
    final params = {
      'symbol': symbol.toUpperCase(),
      'marginType': marginType.toUpperCase(),
    };
    return _sendRequest('POST', '/fapi/v1/marginType', params: params, signed: true);
  }

  Future<List<dynamic>> getKlines({
    required String symbol,
    String interval = '1m',
    int? limit,
  }) async {
    final Map<String, dynamic> params = {
      'symbol': symbol.toUpperCase(),
      'interval': interval,
    };
    if (limit != null) params['limit'] = limit;

    final response = await _sendRequest('GET', '/fapi/v1/klines', params: params);
    return response as List<dynamic>;
  }
}
