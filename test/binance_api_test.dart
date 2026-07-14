import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ifutures/services/binance_api.dart';

void main() {
  group('BinanceApiService signature tests', () {
    test('matches the official Binance HMAC example payload', () {
      const payload =
          'symbol=LTCBTC&side=BUY&type=LIMIT&timeInForce=GTC&quantity=1&price=0.1&recvWindow=5000&timestamp=1499827319559';
      const secret =
          'NhqPtmdSJYdKjVHjA7PZj4Mge3R5YNiP1e3UZjInClVN65XAbvqqM6A7H5fATj0j';
      const expected =
          'c8db56825ae71d6d79447849e617115f4a920fa2acdcab2b053c4b2838bd6b71';

      final signature = BinanceApiService.signPayload(payload, secret);

      expect(signature, expected);
    });

    test('parses binance error code and message from the raw response body', () {
      final error = BinanceApiException(
        statusCode: 401,
        body:
            '{"code":-2015,"msg":"Invalid API-key, IP, or permissions for action"}',
        method: 'GET',
        path: '/api/v3/account',
        scope: BinanceApiScope.spot,
        requestUri: Uri.parse('https://api.binance.com/api/v3/account'),
        headers: const {},
      );

      expect(error.errorCode, -2015);
      expect(
        error.errorMessage,
        'Invalid API-key, IP, or permissions for action',
      );
    });
  });

  group('BinanceApiService order mutation guard', () {
    test('blocks every futures order mutation before network access', () async {
      final service = BinanceApiService(
        apiKey: 'live-key',
        apiSecret: 'live-secret',
        isTestnet: false,
        allowOrderMutations: false,
      );

      final mutations = <Future<dynamic> Function()>[
        () => service.placeOrder(
          symbol: 'ARIAUSDT',
          side: 'BUY',
          type: 'MARKET',
          quantity: '1',
        ),
        () => service.placeAlgoOrder(
          symbol: 'ARIAUSDT',
          side: 'SELL',
          type: 'STOP_MARKET',
          triggerPrice: '0.10',
        ),
        () => service.setLeverage(symbol: 'ARIAUSDT', leverage: 2),
        () => service.setMarginType(symbol: 'ARIAUSDT', marginType: 'ISOLATED'),
        () => service.cancelOrder(symbol: 'ARIAUSDT', orderId: '123'),
        () => service.cancelAlgoOrder(algoId: '456'),
      ];

      for (final mutation in mutations) {
        await expectLater(mutation(), throwsStateError);
      }
    });
  });

  group('BinanceApiService historical futures data', () {
    test('kline query forwards the closed-sample time window', () async {
      http.Request? capturedRequest;
      final service = BinanceApiService(
        apiKey: '',
        apiSecret: '',
        isTestnet: false,
        allowOrderMutations: false,
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response('[]', 200, request: request);
        }),
      );

      await service.getKlines(
        symbol: 'ariausdt',
        interval: '5m',
        limit: 1500,
        startTime: 1000,
        endTime: 2000,
      );

      final request = capturedRequest!;
      expect(request.method, 'GET');
      expect(request.url.host, 'fapi.binance.com');
      expect(request.url.path, '/fapi/v1/klines');
      expect(request.url.queryParameters, containsPair('symbol', 'ARIAUSDT'));
      expect(request.url.queryParameters, containsPair('interval', '5m'));
      expect(request.url.queryParameters, containsPair('limit', '1500'));
      expect(request.url.queryParameters, containsPair('startTime', '1000'));
      expect(request.url.queryParameters, containsPair('endTime', '2000'));
    });

    test('funding history uses the public production endpoint', () async {
      http.Request? capturedRequest;
      final service = BinanceApiService(
        apiKey: '',
        apiSecret: '',
        isTestnet: false,
        allowOrderMutations: false,
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response('[]', 200, request: request);
        }),
      );

      await service.getFundingRateHistory(
        symbol: 'btcusdt',
        startTime: 3000,
        endTime: 4000,
        limit: 1000,
      );

      final request = capturedRequest!;
      expect(request.method, 'GET');
      expect(request.url.path, '/fapi/v1/fundingRate');
      expect(request.url.queryParameters, containsPair('symbol', 'BTCUSDT'));
      expect(request.url.queryParameters, containsPair('startTime', '3000'));
      expect(request.url.queryParameters, containsPair('endTime', '4000'));
      expect(request.url.queryParameters, containsPair('limit', '1000'));
      expect(request.headers, isNot(contains('X-MBX-APIKEY')));
    });

    test(
      'historical endpoint limits are validated before network access',
      () async {
        final service = BinanceApiService(apiKey: '', apiSecret: '');

        await expectLater(
          service.getKlines(symbol: 'ARIAUSDT', limit: 1501),
          throwsArgumentError,
        );
        await expectLater(
          service.getFundingRateHistory(symbol: 'ARIAUSDT', limit: 1001),
          throwsArgumentError,
        );
      },
    );
  });

  group('BinanceApiService order reconciliation', () {
    test(
      'placeOrder timeout reports an unknown outcome and sends once',
      () async {
        var callCount = 0;
        final pendingResponse = Completer<http.Response>();
        final service = BinanceApiService(
          apiKey: 'api-key',
          apiSecret: 'secret',
          requestTimeout: const Duration(milliseconds: 1),
          client: MockClient((request) {
            callCount += 1;
            return pendingResponse.future;
          }),
        );

        try {
          await service.placeOrder(
            symbol: 'ariausdt',
            side: 'BUY',
            type: 'LIMIT',
            quantity: '10',
            price: '0.05',
            timeInForce: 'GTC',
            newClientOrderId: 'ifut-entry-timeout',
          );
          fail('Expected an unknown order outcome.');
        } on BinanceRequestOutcomeUnknownException catch (error) {
          expect(error.timedOut, isTrue);
          expect(error.requiresReconciliation, isTrue);
          expect(error.clientOrderId, 'ifut-entry-timeout');
          expect(error.path, '/fapi/v1/order');
          expect(
            error.requestUri.queryParameters.containsKey('signature'),
            isFalse,
          );
        }

        expect(callCount, 1);
      },
    );

    test('placeOrder 503 reports an unknown outcome and sends once', () async {
      var callCount = 0;
      final service = BinanceApiService(
        apiKey: 'api-key',
        apiSecret: 'secret',
        client: MockClient((request) async {
          callCount += 1;
          return http.Response(
            '{"code":-1000,"msg":"Execution status unknown."}',
            503,
            request: request,
          );
        }),
      );

      try {
        await service.placeOrder(
          symbol: 'ARIAUSDT',
          side: 'BUY',
          type: 'MARKET',
          quantity: '10',
          newClientOrderId: 'ifut-entry-503',
        );
        fail('Expected an unknown order outcome.');
      } on BinanceRequestOutcomeUnknownException catch (error) {
        expect(error.statusCode, 503);
        expect(error.timedOut, isFalse);
        expect(error.executionStatus, BinanceExecutionStatus.unknown);
        expect(error.clientOrderId, 'ifut-entry-503');
      }

      expect(callCount, 1);
    });

    test('placeOrder 400 remains a definite API rejection', () async {
      final service = BinanceApiService(
        apiKey: 'api-key',
        apiSecret: 'secret',
        client: MockClient(
          (request) async => http.Response(
            '{"code":-1013,"msg":"Invalid quantity."}',
            400,
            request: request,
          ),
        ),
      );

      try {
        await service.placeOrder(
          symbol: 'ARIAUSDT',
          side: 'BUY',
          type: 'MARKET',
          quantity: '0',
          newClientOrderId: 'ifut-entry-rejected',
        );
        fail('Expected Binance to reject the order.');
      } on BinanceApiException catch (error) {
        expect(error, isNot(isA<BinanceRequestOutcomeUnknownException>()));
        expect(error.isDefiniteReject, isTrue);
        expect(error.requiresReconciliation, isFalse);
        expect(error.errorCode, -1013);
      }
    });

    test('GET order 500 is not classified as an ambiguous placement', () async {
      final service = BinanceApiService(
        apiKey: 'api-key',
        apiSecret: 'secret',
        client: MockClient(
          (request) async => http.Response(
            '{"code":-1000,"msg":"Internal error."}',
            500,
            request: request,
          ),
        ),
      );

      try {
        await service.getOrderByClientOrderId(
          symbol: 'ARIAUSDT',
          origClientOrderId: 'ifut-entry-query',
        );
        fail('Expected the query to fail.');
      } on BinanceApiException catch (error) {
        expect(error, isNot(isA<BinanceRequestOutcomeUnknownException>()));
        expect(error.isMutation, isFalse);
        expect(error.requiresReconciliation, isFalse);
      }
    });

    test(
      'client-order lookup is signed and allowed in read-only mode',
      () async {
        http.Request? capturedRequest;
        final service = BinanceApiService(
          apiKey: 'api-key',
          apiSecret: 'secret',
          allowOrderMutations: false,
          client: MockClient((request) async {
            capturedRequest = request;
            return http.Response(
              '{"symbol":"ARIAUSDT","status":"NEW"}',
              200,
              request: request,
            );
          }),
        );
        const clientOrderId = 'ifut-entry/a:b.c_1';

        final response = await service.getOrderByClientOrderId(
          symbol: 'ariausdt',
          origClientOrderId: clientOrderId,
        );

        expect(response['status'], 'NEW');
        final request = capturedRequest!;
        expect(request.method, 'GET');
        expect(request.url.host, 'demo-fapi.binance.com');
        expect(request.url.path, '/fapi/v1/order');
        expect(request.url.queryParameters['symbol'], 'ARIAUSDT');
        expect(request.url.queryParameters['origClientOrderId'], clientOrderId);
        expect(request.headers['X-MBX-APIKEY'], 'api-key');
        expect(request.url.queryParameters['recvWindow'], '5000');
        expect(request.url.queryParameters['timestamp'], isNotEmpty);

        final query = request.url.query;
        final signatureMarker = query.lastIndexOf('&signature=');
        expect(signatureMarker, greaterThan(0));
        final unsignedQuery = query.substring(0, signatureMarker);
        final transmittedSignature = Uri.decodeQueryComponent(
          query.substring(signatureMarker + '&signature='.length),
        );
        expect(
          transmittedSignature,
          BinanceApiService.signPayload(unsignedQuery, 'secret'),
        );
      },
    );
  });

  group('BinanceApiService futures position mode', () {
    test('returns unknown for missing or malformed dualSidePosition', () async {
      for (final body in <String>[
        '{}',
        '{"dualSidePosition":"unexpected"}',
        '{"dualSidePosition":2}',
      ]) {
        final service = BinanceApiService(
          apiKey: 'api-key',
          apiSecret: 'secret',
          client: MockClient(
            (request) async => http.Response(body, 200, request: request),
          ),
        );

        expect(
          await service.getPositionMode(),
          BinanceFuturesPositionMode.unknown,
        );
      }
    });

    test('parses strict one-way and hedge values', () async {
      Future<BinanceFuturesPositionMode> parse(String body) {
        return BinanceApiService(
          apiKey: 'api-key',
          apiSecret: 'secret',
          client: MockClient(
            (request) async => http.Response(body, 200, request: request),
          ),
        ).getPositionMode();
      }

      expect(
        await parse('{"dualSidePosition":false}'),
        BinanceFuturesPositionMode.oneWay,
      );
      expect(
        await parse('{"dualSidePosition":"true"}'),
        BinanceFuturesPositionMode.hedge,
      );
    });
  });

  group('BinanceApiService symbol-rule cache', () {
    test('refreshes exchange filters after the configured TTL', () async {
      var now = DateTime.utc(2026, 7, 14, 12);
      var requests = 0;
      final service = BinanceApiService(
        apiKey: '',
        apiSecret: '',
        symbolRulesCacheTtl: const Duration(minutes: 5),
        now: () => now,
        client: MockClient((request) async {
          requests += 1;
          final stepSize = requests == 1 ? '0.01' : '0.02';
          return http.Response(
            '{"symbols":[{"symbol":"ARIAUSDT","status":"TRADING","contractType":"PERPETUAL","quantityPrecision":2,"pricePrecision":4,"filters":[{"filterType":"PRICE_FILTER","tickSize":"0.0001"},{"filterType":"LOT_SIZE","stepSize":"$stepSize","minQty":"1","maxQty":"1000"}]}]}',
            200,
            request: request,
          );
        }),
      );

      final first = await service.getSymbolRules('ariausdt');
      final cached = await service.getSymbolRules('ARIAUSDT');
      now = now.add(const Duration(minutes: 6));
      final refreshed = await service.getSymbolRules('ARIAUSDT');

      expect(first?.stepSize, 0.01);
      expect(cached?.stepSize, 0.01);
      expect(refreshed?.stepSize, 0.02);
      expect(requests, 2);
    });
  });
}
