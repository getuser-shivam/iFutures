import 'dart:async';
import '../models/kline.dart';
import '../services/binance_api.dart';
import '../services/binance_ws.dart';
import 'strategy.dart';

class TradingEngine {
  final BinanceApiService apiService;
  final BinanceWebSocketService wsService;
  final TradingStrategy strategy;
  final String symbol;

  List<Kline> _klines = [];
  bool _isRunning = false;
  StreamSubscription? _wsSubscription;
  
  final _klineController = StreamController<List<Kline>>.broadcast();
  Stream<List<Kline>> get klineStream => _klineController.stream;

  TradingEngine({
    required this.apiService,
    required this.wsService,
    required this.strategy,
    required this.symbol,
  });

  bool get isRunning => _isRunning;
  List<Kline> get klines => _klines;

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    // 1. Fetch historical data
    final historicalData = await apiService.getKlines(symbol: symbol, limit: 100);
    _klines = historicalData.map((e) => Kline.fromJson(e)).toList();
    _klineController.add(_klines);

    // 2. Subscribe to real-time updates
    _wsSubscription = wsService.subscribeToKlines(symbol).listen((event) {
      final kline = Kline.fromWsJson(event);
      _updateKlines(kline);
      
      // If candle is closed, evaluate strategy
      if (event['k']['x'] == true) {
        _evaluateStrategy();
      }
    });
  }

  void _updateKlines(Kline newKline) {
    if (_klines.isEmpty) {
      _klines.add(newKline);
    } else {
      final last = _klines.last;
      if (last.openTime == newKline.openTime) {
        _klines[_klines.length - 1] = newKline;
      } else {
        _klines.add(newKline);
        if (_klines.length > 500) _klines.removeAt(0);
      }
    }
    _klineController.add(_klines);
  }

  Future<void> _evaluateStrategy() async {
    final signal = await strategy.evaluate(_klines);
    print('Strategy signal: $signal');
    
    if (signal == TradingSignal.buy) {
      await _executeTrade('BUY');
    } else if (signal == TradingSignal.sell) {
      await _executeTrade('SELL');
    }
  }

  Future<void> _executeTrade(String side) async {
    try {
      // For now, just print and maybe place a small test order
      print('Executing $side order for $symbol');
      // final result = await apiService.placeOrder(
      //   symbol: symbol,
      //   side: side,
      //   type: 'MARKET',
      //   quantity: '0.01', // Example quantity
      // );
      // print('Order result: $result');
    } catch (e) {
      print('Trade execution error: $e');
    }
  }

  void stop() {
    _isRunning = false;
    _wsSubscription?.cancel();
    _wsSubscription = null;
  }

  void dispose() {
    stop();
    _klineController.close();
  }
}
