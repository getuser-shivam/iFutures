import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

enum BinanceApiScope { spot, futures }

enum BinanceFuturesPositionMode { oneWay, hedge, unknown }

enum BinanceExecutionStatus { notApplicable, rejected, unknown }

class BinanceApiService {
  final String apiKey;
  final String apiSecret;
  final bool isTestnet;
  final bool allowOrderMutations;
  final Duration requestTimeout;
  final Duration symbolRulesCacheTtl;

  final http.Client _client;
  final DateTime Function() _now;
  final Map<String, BinanceSymbolRules> _symbolRulesCache = {};
  final Map<String, DateTime> _symbolRulesCachedAt = {};
  final Map<BinanceApiScope, int> _timestampOffsetsMs = {
    BinanceApiScope.spot: 0,
    BinanceApiScope.futures: 0,
  };

  String get baseUrl => _baseUrlFor(BinanceApiScope.futures);

  BinanceApiService({
    required this.apiKey,
    required this.apiSecret,
    this.isTestnet = true,
    this.allowOrderMutations = true,
    this.requestTimeout = const Duration(seconds: 15),
    this.symbolRulesCacheTtl = const Duration(minutes: 5),
    http.Client? client,
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       _now = now ?? DateTime.now;

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
            ? 'https://demo-fapi.binance.com'
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
    }

    final queryString = _buildQueryString(requestParams);
    final baseUrl = _baseUrlFor(scope);
    final headers = <String, String>{
      'X-MBX-APIKEY': apiKey,
      'Content-Type': 'application/x-www-form-urlencoded',
    };
    final upperMethod = method.toUpperCase();
    final requestUri = Uri.parse(
      queryString.isEmpty ? '$baseUrl$path' : '$baseUrl$path?$queryString',
    );
    final safeRequestUri = _redactRequestUri(requestUri);
    final clientOrderId =
        requestParams['newClientOrderId']?.toString() ??
        requestParams['clientAlgoId']?.toString() ??
        requestParams['origClientOrderId']?.toString();

    try {
      late final Future<http.Response> responseFuture;
      switch (upperMethod) {
        case 'GET':
          responseFuture = _client.get(requestUri, headers: headers);
          break;
        case 'POST':
          responseFuture = _client.post(requestUri, headers: headers);
          break;
        case 'PUT':
          responseFuture = _client.put(requestUri, headers: headers);
          break;
        case 'DELETE':
          responseFuture = _client.delete(requestUri, headers: headers);
          break;
        default:
          throw UnsupportedError('Unsupported HTTP method: $method');
      }
      final response = await responseFuture.timeout(requestTimeout);

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
        final exceptionRequestUri = _redactRequestUri(
          response.request?.url ?? requestUri,
        );
        if (_isMutationMethod(upperMethod) &&
            response.statusCode >= 500 &&
            response.statusCode <= 599) {
          throw BinanceRequestOutcomeUnknownException(
            statusCode: response.statusCode,
            body: response.body,
            method: upperMethod,
            path: path,
            scope: scope,
            requestUri: exceptionRequestUri,
            headers: response.headers,
            clientOrderId: clientOrderId,
          );
        }
        throw BinanceApiException(
          statusCode: response.statusCode,
          body: response.body,
          method: upperMethod,
          path: path,
          scope: scope,
          requestUri: exceptionRequestUri,
          headers: response.headers,
          clientOrderId: clientOrderId,
        );
      }

      return jsonDecode(response.body) as T;
    } on BinanceApiException {
      rethrow;
    } on TimeoutException catch (error, stackTrace) {
      if (_isMutationMethod(upperMethod)) {
        throw BinanceRequestOutcomeUnknownException(
          statusCode: 0,
          body: '',
          method: upperMethod,
          path: path,
          scope: scope,
          requestUri: safeRequestUri,
          headers: const {},
          clientOrderId: clientOrderId,
          cause: error,
          causeStackTrace: stackTrace,
          timedOut: true,
        );
      }
      throw BinanceTransportException(
        method: upperMethod,
        path: path,
        scope: scope,
        requestUri: safeRequestUri,
        clientOrderId: clientOrderId,
        cause: error,
        causeStackTrace: stackTrace,
        timedOut: true,
      );
    } on http.ClientException catch (error, stackTrace) {
      if (_isMutationMethod(upperMethod)) {
        throw BinanceRequestOutcomeUnknownException(
          statusCode: 0,
          body: '',
          method: upperMethod,
          path: path,
          scope: scope,
          requestUri: safeRequestUri,
          headers: const {},
          clientOrderId: clientOrderId,
          cause: error,
          causeStackTrace: stackTrace,
        );
      }
      throw BinanceTransportException(
        method: upperMethod,
        path: path,
        scope: scope,
        requestUri: safeRequestUri,
        clientOrderId: clientOrderId,
        cause: error,
        causeStackTrace: stackTrace,
      );
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
      rethrow;
    }
  }

  static bool _isMutationMethod(String method) =>
      method == 'POST' || method == 'PUT' || method == 'DELETE';

  static Uri _redactRequestUri(Uri uri) {
    if (!uri.queryParameters.containsKey('signature')) {
      return uri;
    }
    final safeQuery = Map<String, String>.from(uri.queryParameters)
      ..remove('signature');
    return uri.replace(queryParameters: safeQuery);
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

  Future<String> startUserDataStream() async {
    final response = await _sendRequest<Map<String, dynamic>>(
      'POST',
      '/fapi/v1/listenKey',
    );
    final listenKey = response['listenKey']?.toString() ?? '';
    if (listenKey.isEmpty) {
      throw StateError(
        'Binance did not return a Futures user-data listen key.',
      );
    }
    return listenKey;
  }

  Future<void> keepAliveUserDataStream(String listenKey) async {
    await _sendRequest<Map<String, dynamic>>(
      'PUT',
      '/fapi/v1/listenKey',
      params: <String, dynamic>{'listenKey': listenKey},
    );
  }

  Future<void> closeUserDataStream(String listenKey) async {
    await _sendRequest<Map<String, dynamic>>(
      'DELETE',
      '/fapi/v1/listenKey',
      params: <String, dynamic>{'listenKey': listenKey},
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

  Future<BinanceSymbolRules?> getSymbolRules(
    String symbol, {
    bool forceRefresh = false,
  }) async {
    final normalized = symbol.toUpperCase();
    final cached = _symbolRulesCache[normalized];
    final cachedAt = _symbolRulesCachedAt[normalized];
    final cacheIsFresh =
        !forceRefresh &&
        cached != null &&
        cachedAt != null &&
        symbolRulesCacheTtl > Duration.zero &&
        _now().difference(cachedAt) < symbolRulesCacheTtl;
    if (cacheIsFresh) {
      return cached;
    }

    final payload = await getExchangeInfo();
    final symbols = payload['symbols'];
    if (symbols is! List) {
      return null;
    }

    for (final entry in symbols) {
      if (entry is! Map) {
        continue;
      }
      if ('${entry['symbol'] ?? ''}'.toUpperCase() != normalized) {
        continue;
      }

      double? tickSize;
      double? stepSize;
      double? minQty;
      double? maxQty;
      double? marketStepSize;
      double? marketMinQty;
      double? marketMaxQty;
      double? minNotional;
      final filters = entry['filters'];
      if (filters is List) {
        for (final filter in filters) {
          if (filter is! Map) {
            continue;
          }
          final filterType = '${filter['filterType'] ?? ''}'.toUpperCase();
          switch (filterType) {
            case 'PRICE_FILTER':
              tickSize = _asDouble(filter['tickSize']);
              break;
            case 'LOT_SIZE':
              stepSize = _asDouble(filter['stepSize']);
              minQty = _asDouble(filter['minQty']);
              maxQty = _asDouble(filter['maxQty']);
              break;
            case 'MARKET_LOT_SIZE':
              marketStepSize = _asDouble(filter['stepSize']);
              marketMinQty = _asDouble(filter['minQty']);
              marketMaxQty = _asDouble(filter['maxQty']);
              break;
            case 'MIN_NOTIONAL':
              minNotional = _asDouble(
                filter['notional'] ?? filter['minNotional'],
              );
              break;
            case 'NOTIONAL':
              minNotional = _asDouble(
                filter['notional'] ?? filter['minNotional'],
              );
              break;
          }
        }
      }

      final rules = BinanceSymbolRules(
        symbol: normalized,
        status: '${entry['status'] ?? ''}'.toUpperCase(),
        contractType: '${entry['contractType'] ?? ''}'.toUpperCase(),
        quantityPrecision: _asInt(entry['quantityPrecision']),
        pricePrecision: _asInt(entry['pricePrecision']),
        tickSize: tickSize,
        stepSize: stepSize,
        minQty: minQty,
        maxQty: maxQty,
        marketStepSize: marketStepSize,
        marketMinQty: marketMinQty,
        marketMaxQty: marketMaxQty,
        minNotional: minNotional,
      );
      _symbolRulesCache[normalized] = rules;
      _symbolRulesCachedAt[normalized] = _now();
      return rules;
    }

    _symbolRulesCache.remove(normalized);
    _symbolRulesCachedAt.remove(normalized);
    return null;
  }

  Future<Map<String, dynamic>> placeOrder({
    required String symbol,
    required String side,
    required String type,
    String? quantity,
    String? price,
    String? stopPrice,
    String? timeInForce,
    String? positionSide,
    bool? closePosition,
    bool? reduceOnly,
    String? newClientOrderId,
    String? newOrderRespType,
    Map<String, dynamic>? extraParams,
  }) async {
    _requireOrderMutationsAllowed();
    final params = <String, dynamic>{
      'symbol': symbol.toUpperCase(),
      'side': side.toUpperCase(),
      'type': type.toUpperCase(),
      ...?extraParams,
    };
    if (quantity != null) params['quantity'] = quantity;
    if (price != null) params['price'] = price;
    if (stopPrice != null) params['stopPrice'] = stopPrice;
    if (timeInForce != null) params['timeInForce'] = timeInForce;
    if (positionSide != null) params['positionSide'] = positionSide;
    if (closePosition != null) {
      params['closePosition'] = closePosition.toString();
    }
    if (reduceOnly != null) params['reduceOnly'] = reduceOnly.toString();
    if (newClientOrderId != null) {
      params['newClientOrderId'] = newClientOrderId;
    }
    if (newOrderRespType != null) {
      params['newOrderRespType'] = newOrderRespType;
    }

    return _sendRequest<Map<String, dynamic>>(
      'POST',
      '/fapi/v1/order',
      params: params,
      signed: true,
    );
  }

  Future<Map<String, dynamic>> placeAlgoOrder({
    required String symbol,
    required String side,
    required String type,
    required String triggerPrice,
    String? positionSide,
    bool closePosition = true,
    String workingType = 'MARK_PRICE',
    bool priceProtect = true,
    String? clientAlgoId,
    String newOrderRespType = 'ACK',
  }) async {
    _requireOrderMutationsAllowed();
    final params = <String, dynamic>{
      'algoType': 'CONDITIONAL',
      'symbol': symbol.toUpperCase(),
      'side': side.toUpperCase(),
      'type': type.toUpperCase(),
      'triggerPrice': triggerPrice,
      'closePosition': closePosition.toString(),
      'workingType': workingType.toUpperCase(),
      'priceProtect': priceProtect.toString(),
      'newOrderRespType': newOrderRespType.toUpperCase(),
    };
    if (positionSide != null) params['positionSide'] = positionSide;
    if (clientAlgoId != null) params['clientAlgoId'] = clientAlgoId;

    return _sendRequest<Map<String, dynamic>>(
      'POST',
      '/fapi/v1/algoOrder',
      params: params,
      signed: true,
    );
  }

  Future<Map<String, dynamic>> setLeverage({
    required String symbol,
    required int leverage,
  }) async {
    _requireOrderMutationsAllowed();
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
    _requireOrderMutationsAllowed();
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

  Future<List<dynamic>> getOpenOrders({String? symbol}) async {
    final params = <String, dynamic>{};
    if (symbol != null && symbol.trim().isNotEmpty) {
      params['symbol'] = symbol.toUpperCase();
    }

    return _sendRequest<List<dynamic>>(
      'GET',
      '/fapi/v1/openOrders',
      params: params,
      signed: true,
    );
  }

  Future<Map<String, dynamic>> getOrderByClientOrderId({
    required String symbol,
    required String origClientOrderId,
  }) async {
    final normalizedSymbol = symbol.trim().toUpperCase();
    final normalizedClientOrderId = origClientOrderId.trim();
    if (normalizedSymbol.isEmpty) {
      throw ArgumentError.value(symbol, 'symbol', 'Must not be empty.');
    }
    if (normalizedClientOrderId.isEmpty) {
      throw ArgumentError.value(
        origClientOrderId,
        'origClientOrderId',
        'Must not be empty.',
      );
    }

    return _sendRequest<Map<String, dynamic>>(
      'GET',
      '/fapi/v1/order',
      params: <String, dynamic>{
        'symbol': normalizedSymbol,
        'origClientOrderId': normalizedClientOrderId,
      },
      signed: true,
    );
  }

  Future<List<dynamic>> getOpenAlgoOrders({String? symbol}) async {
    final params = <String, dynamic>{'algoType': 'CONDITIONAL'};
    if (symbol != null && symbol.trim().isNotEmpty) {
      params['symbol'] = symbol.toUpperCase();
    }

    return _sendRequest<List<dynamic>>(
      'GET',
      '/fapi/v1/openAlgoOrders',
      params: params,
      signed: true,
    );
  }

  Future<Map<String, dynamic>> cancelOrder({
    required String symbol,
    required String orderId,
  }) async {
    _requireOrderMutationsAllowed();
    return _sendRequest<Map<String, dynamic>>(
      'DELETE',
      '/fapi/v1/order',
      params: <String, dynamic>{
        'symbol': symbol.toUpperCase(),
        'orderId': orderId,
      },
      signed: true,
    );
  }

  Future<Map<String, dynamic>> cancelAlgoOrder({required String algoId}) async {
    _requireOrderMutationsAllowed();
    return _sendRequest<Map<String, dynamic>>(
      'DELETE',
      '/fapi/v1/algoOrder',
      params: <String, dynamic>{'algoId': algoId},
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

  Future<BinanceFuturesPositionMode> getPositionMode() async {
    final payload = await _sendRequest<Map<String, dynamic>>(
      'GET',
      '/fapi/v1/positionSide/dual',
      signed: true,
    );
    final dualSide = payload['dualSidePosition'];
    return switch (dualSide) {
      true => BinanceFuturesPositionMode.hedge,
      false => BinanceFuturesPositionMode.oneWay,
      String value => switch (value.trim().toLowerCase()) {
        'true' || '1' => BinanceFuturesPositionMode.hedge,
        'false' || '0' => BinanceFuturesPositionMode.oneWay,
        _ => BinanceFuturesPositionMode.unknown,
      },
      num value when value == 1 => BinanceFuturesPositionMode.hedge,
      num value when value == 0 => BinanceFuturesPositionMode.oneWay,
      _ => BinanceFuturesPositionMode.unknown,
    };
  }

  bool _isTimestampDriftErrorBody(String message) {
    return message.contains('-1021') ||
        message.toLowerCase().contains('timestamp for this request');
  }

  void _requireOrderMutationsAllowed() {
    if (allowOrderMutations) {
      return;
    }
    throw StateError(
      'Order mutations are disabled in this environment. Use the desktop app for live trading or switch to Binance demo mode.',
    );
  }

  static double? _asDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  static int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }
}

class BinanceSymbolRules {
  final String symbol;
  final String status;
  final String contractType;
  final int? quantityPrecision;
  final int? pricePrecision;
  final double? tickSize;
  final double? stepSize;
  final double? minQty;
  final double? maxQty;
  final double? marketStepSize;
  final double? marketMinQty;
  final double? marketMaxQty;
  final double? minNotional;

  const BinanceSymbolRules({
    required this.symbol,
    required this.status,
    required this.contractType,
    this.quantityPrecision,
    this.pricePrecision,
    this.tickSize,
    this.stepSize,
    this.minQty,
    this.maxQty,
    this.marketStepSize,
    this.marketMinQty,
    this.marketMaxQty,
    this.minNotional,
  });

  bool get isTradablePerpetual =>
      status == 'TRADING' && contractType == 'PERPETUAL';

  double? normalizeQuantity(double quantity, {bool market = false}) {
    final effectiveStep = market ? (marketStepSize ?? stepSize) : stepSize;
    final effectiveMin = market ? (marketMinQty ?? minQty) : minQty;
    final effectiveMax = market ? (marketMaxQty ?? maxQty) : maxQty;
    var normalized = quantity;
    if (effectiveStep != null && effectiveStep > 0) {
      normalized = (quantity / effectiveStep).floorToDouble() * effectiveStep;
    }
    if (quantityPrecision != null && quantityPrecision! >= 0) {
      normalized = _truncate(normalized, quantityPrecision!);
    }
    if (effectiveMin != null && normalized < effectiveMin) {
      return null;
    }
    if (effectiveMax != null && effectiveMax > 0 && normalized > effectiveMax) {
      return null;
    }
    return normalized > 0 ? normalized : null;
  }

  double? normalizePrice(double price) {
    var normalized = price;
    if (tickSize != null && tickSize! > 0) {
      normalized = (price / tickSize!).floorToDouble() * tickSize!;
    }
    if (pricePrecision != null && pricePrecision! >= 0) {
      normalized = _truncate(normalized, pricePrecision!);
    }
    return normalized > 0 ? normalized : null;
  }

  double? minimumQuantityForPrice(double price) {
    if (price <= 0) {
      return minQty;
    }

    var requiredQuantity = minQty ?? 0.0;
    if (minNotional != null && minNotional! > 0) {
      final notionalQuantity = minNotional! / price;
      if (notionalQuantity > requiredQuantity) {
        requiredQuantity = notionalQuantity;
      }
    }

    if (requiredQuantity <= 0) {
      return null;
    }
    return _ceilQuantity(requiredQuantity);
  }

  String formatQuantity(double quantity, {bool market = false}) {
    final effectiveStep = market ? (marketStepSize ?? stepSize) : stepSize;
    final normalized = normalizeQuantity(quantity, market: market) ?? quantity;
    final precision =
        quantityPrecision ?? _precisionFromStep(effectiveStep) ?? 6;
    return _trimTrailingZeros(normalized.toStringAsFixed(precision));
  }

  String formatPrice(double price) {
    final normalized = normalizePrice(price) ?? price;
    final precision = pricePrecision ?? _precisionFromStep(tickSize) ?? 6;
    return _trimTrailingZeros(normalized.toStringAsFixed(precision));
  }

  static double _truncate(double value, int precision) {
    final factor = precision <= 0 ? 1.0 : _pow10(precision);
    return (value * factor).floorToDouble() / factor;
  }

  double _ceilQuantity(double quantity) {
    var normalized = quantity;
    if (stepSize != null && stepSize! > 0) {
      normalized = (quantity / stepSize!).ceilToDouble() * stepSize!;
    }
    if (quantityPrecision != null && quantityPrecision! >= 0) {
      final factor = _pow10(quantityPrecision!);
      normalized = (normalized * factor).ceilToDouble() / factor;
    }
    if (minQty != null && normalized < minQty!) {
      normalized = minQty!;
    }
    return normalized;
  }

  static double _pow10(int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  static int? _precisionFromStep(double? step) {
    if (step == null || step <= 0) {
      return null;
    }
    final text = _trimTrailingZeros(step.toStringAsFixed(12));
    final decimalIndex = text.indexOf('.');
    if (decimalIndex == -1) {
      return 0;
    }
    return text.length - decimalIndex - 1;
  }

  static String _trimTrailingZeros(String value) {
    if (!value.contains('.')) {
      return value;
    }
    return value.replaceFirst(RegExp(r'\.?0+$'), '');
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
  final String? clientOrderId;

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
    this.clientOrderId,
  });

  bool get isMutation =>
      method == 'POST' || method == 'PUT' || method == 'DELETE';

  BinanceExecutionStatus get executionStatus {
    if (!isMutation) {
      return BinanceExecutionStatus.notApplicable;
    }
    if (statusCode >= 500 && statusCode <= 599) {
      return BinanceExecutionStatus.unknown;
    }
    if (statusCode >= 400 && statusCode <= 499) {
      return BinanceExecutionStatus.rejected;
    }
    return BinanceExecutionStatus.notApplicable;
  }

  bool get isExecutionStatusUnknown =>
      executionStatus == BinanceExecutionStatus.unknown;

  bool get isDefiniteReject =>
      executionStatus == BinanceExecutionStatus.rejected;

  bool get requiresReconciliation => isExecutionStatusUnknown;

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
    return 'BinanceApiException(status=$statusCode$codeText$messageText, method=$method, path=$path, scope=$scope, execution=$executionStatus)';
  }
}

class BinanceTransportException extends BinanceApiException {
  final Object cause;
  final StackTrace? causeStackTrace;
  final bool timedOut;

  BinanceTransportException({
    required super.method,
    required super.path,
    required super.scope,
    required super.requestUri,
    required this.cause,
    this.causeStackTrace,
    this.timedOut = false,
    super.clientOrderId,
  }) : super(statusCode: 0, body: '', headers: const {});

  @override
  String toString() =>
      'BinanceTransportException(method=$method, path=$path, scope=$scope, timedOut=$timedOut, cause=$cause)';
}

class BinanceRequestOutcomeUnknownException extends BinanceApiException {
  final Object? cause;
  final StackTrace? causeStackTrace;
  final bool timedOut;

  BinanceRequestOutcomeUnknownException({
    required super.statusCode,
    required super.body,
    required super.method,
    required super.path,
    required super.scope,
    required super.requestUri,
    required super.headers,
    super.clientOrderId,
    this.cause,
    this.causeStackTrace,
    this.timedOut = false,
  });

  @override
  BinanceExecutionStatus get executionStatus => BinanceExecutionStatus.unknown;

  @override
  String toString() =>
      'BinanceRequestOutcomeUnknownException(status=$statusCode, method=$method, path=$path, scope=$scope, timedOut=$timedOut, clientOrderId=${clientOrderId ?? '--'})';
}
