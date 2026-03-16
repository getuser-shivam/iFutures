import 'dart:async';
import '../models/kline.dart';
import '../models/trade.dart';
import '../services/binance_api.dart';
import '../services/binance_ws.dart';
import 'strategy.dart';

class TradingEngine {
  final BinanceApiService apiService;
  final BinanceWebSocketService wsService;
  final TradingStrategy strategy;
  final String symbol;

  List<Kline> _klines = [];
  List<Trade> _trades = [];
  bool _isRunning = false;
  StreamSubscription? _wsSubscription;
  
  final _klineController = StreamController<List<Kline>>.broadcast();
  final _tradeController = StreamController<List<Trade>>.broadcast();
  
  Stream<List<Kline>> get klineStream => _klineController.stream;
  Stream<List<Trade>> get tradeStream => _tradeController.stream;

  TradingEngine({
    required this.apiService,
    required this.wsService,
    required this.strategy,
    required this.symbol,
  });

  bool get isRunning => _isRunning;
  List<Kline> get klines => _klines;
  List<Trade> get trades => _trades;

  Future<void> start() async {
    // 1. Fetch historical data
    try {
      final historicalData = await apiService.getKlines(symbol: symbol, limit: 100);
      _klines = historicalData.map((e) => Kline.fromJson(e)).toList();
      _klineController.add(_klines);
    } catch (e) {
      print('Failed to fetch historical data: $e');
    }

    // 2. Subscribe to real-time updates
    _wsSubscription = wsService.subscribeToKlines(symbol).listen((event) {
      final kline = Kline.fromWsJson(event);
      _updateKlines(kline);
      
      // If candle is closed, evaluate strategy
      if (event['k']['x'] == true) {
        _evaluateStrategy();
      }
    }, onError: (e) {
      print('WS subscription error: $e');
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
      if (_klines.isEmpty) {
        print('No price data available for trade execution');
        return;
      }

      final currentPrice = _klines.last.close;
      final quantity = 0.01; // Example quantity - in real implementation, this would be calculated

      // Create trade record
      final trade = Trade(
        symbol: symbol,
        side: side,
        price: currentPrice,
        quantity: quantity,
        timestamp: DateTime.now(),
        status: 'simulated', // Since we're not actually placing orders yet
        strategy: strategy.name,
      );

      _trades.add(trade);
      _tradeController.add(_trades);

      print('Recorded $side trade: ${trade.symbol} @ ${trade.price} (${trade.strategy})');
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
    _klineController.close();
    _tradeController.close();
    _wsSubscription?.cancel();
  }
}
