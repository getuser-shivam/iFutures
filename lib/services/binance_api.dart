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
}
