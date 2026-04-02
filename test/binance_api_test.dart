import 'package:flutter_test/flutter_test.dart';
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
}
