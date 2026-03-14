import 'dart:async';
import '../models/kline.dart';
import '../services/binance_api.dart';
import '../services/binance_ws.dart';
import 'strategy.dart';

class TradingEngine {
  final BinanceApiService api;
  final BinanceWebSocketService ws;
  final String symbol;

  TradingStrategy? _currentStrategy;
  final List<Kline> _history = [];
  bool _isRunning = false;
  
  StreamSubscription? _wsSubscription;

  TradingEngine({
    required this.api,
    required this.ws,
    this.symbol = 'GALAUSDT',
  });

  void setStrategy(TradingStrategy strategy) {
    _currentStrategy = strategy;
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    _wsSubscription = ws.subscribeToKlines(symbol).listen((data) async {
      final isFinal = data['k']['x'] == true;
      if (isFinal) {
        final kline = Kline.fromWsJson(data);
        _history.add(kline);
        if (_history.length > 100) _history.removeAt(0);
        
        await _evaluate();
      }
    });
  }

  void stop() {
    _isRunning = false;
    _wsSubscription?.cancel();
  }

  Future<void> _evaluate() async {
    if (_currentStrategy == null || _history.isEmpty) return;

    final signal = await _currentStrategy!.evaluate(_history);
    
    if (signal == TradingSignal.buy) {
      print('BUY Signal detected from ${_currentStrategy!.name}');
      // Logic to place order via api.placeOrder(...)
    } else if (signal == TradingSignal.sell) {
      print('SELL Signal detected from ${_currentStrategy!.name}');
      // Logic to place order via api.placeOrder(...)
    }
  }
}
