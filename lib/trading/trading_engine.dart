import 'dart:async';
import '../models/kline.dart';
import '../models/trade.dart';
import '../models/risk_settings.dart';
import '../models/position.dart';
import '../models/connection_status.dart';
import '../services/binance_api.dart';
import '../services/binance_ws.dart';
import 'strategy.dart';

class TradingEngine {
  final BinanceApiService apiService;
  final BinanceWebSocketService wsService;
  final TradingStrategy strategy;
  final RiskSettings riskSettings;
  final String symbol;

  List<Kline> _klines = [];
  List<Trade> _trades = [];
  bool _isAutoTradingEnabled = false;
  bool _isStreaming = false;
  Position? _openPosition;
  StreamSubscription? _wsSubscription;
  Timer? _connectionTimer;
  DateTime? _lastMessageAt;
  int? _lastLatencyMs;
  TradingSignal? _lastSignal;
  
  final _klineController = StreamController<List<Kline>>.broadcast();
  final _tradeController = StreamController<List<Trade>>.broadcast();
  final _positionController = StreamController<Position?>.broadcast();
  final _connectionController = StreamController<ConnectionStatus>.broadcast();
  final _signalController = StreamController<TradingSignal?>.broadcast();
  
  Stream<List<Kline>> get klineStream => _klineController.stream;
  Stream<List<Trade>> get tradeStream => _tradeController.stream;
  Stream<Position?> get positionStream => _positionController.stream;
  Stream<ConnectionStatus> get connectionStream => _connectionController.stream;
  Stream<TradingSignal?> get signalStream => _signalController.stream;

  TradingEngine({
    required this.apiService,
    required this.wsService,
    required this.strategy,
    required this.riskSettings,
    required this.symbol,
  });

  bool get isStreaming => _isStreaming;
  bool get isTradingEnabled => _isAutoTradingEnabled;
  Position? get openPosition => _openPosition;
  List<Kline> get klines => _klines;
  List<Trade> get trades => _trades;
  TradingSignal? get lastSignal => _lastSignal;

  Future<void> startMarketData() async {
    if (_isStreaming) return;
    _isStreaming = true;
    _positionController.add(_openPosition);
    _connectionController.add(ConnectionStatus.connecting());
    _signalController.add(_lastSignal);
    _startConnectionTicker();

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
      _recordMessageTimestamp(event);
      final kline = Kline.fromWsJson(event);
      _updateKlines(kline);
      _checkRisk(kline.close);
      
      // If candle is closed, evaluate strategy regardless of auto execution
      if (event['k']['x'] == true) {
        _evaluateStrategy();
      }
    }, onError: (e) {
      print('WS subscription error: $e');
      _isStreaming = false;
      _emitConnectionStatus(forceDisconnected: true);
    });
  }

  Future<void> start() async {
    return startMarketData();
  }

  Future<void> enableTrading() async {
    _isAutoTradingEnabled = true;
    if (!_isStreaming) {
      await startMarketData();
    }
  }

  void disableTrading({String reason = 'manual_stop'}) {
    _isAutoTradingEnabled = false;
    if (_openPosition != null && _klines.isNotEmpty) {
      _closePosition(_klines.last.close, reason);
    }
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
    _lastSignal = signal;
    _signalController.add(signal);
    if (!_isAutoTradingEnabled) return;
    
    if (signal == TradingSignal.buy) {
      _handleSignal(PositionSide.long);
    } else if (signal == TradingSignal.sell) {
      _handleSignal(PositionSide.short);
    }
  }

  void _handleSignal(PositionSide desiredSide) {
    _handleSignalWithReason(desiredSide, 'strategy');
  }

  Future<void> manualEnterLong() async {
    await _ensureMarketData();
    _handleSignalWithReason(PositionSide.long, 'manual');
  }

  Future<void> manualEnterShort() async {
    await _ensureMarketData();
    _handleSignalWithReason(PositionSide.short, 'manual');
  }

  Future<void> manualClose() async {
    await _ensureMarketData();
    if (_openPosition != null && _klines.isNotEmpty) {
      _closePosition(_klines.last.close, 'manual');
    }
  }

  Future<void> _ensureMarketData() async {
    if (!_isStreaming) {
      await startMarketData();
    }
  }

  void _handleSignalWithReason(PositionSide desiredSide, String reason) {
    if (_klines.isEmpty) {
      print('No price data available for trade execution');
      return;
    }

    final currentPrice = _klines.last.close;
    final quantity = riskSettings.tradeQuantity;

    if (quantity <= 0) {
      print('Trade quantity must be greater than zero');
      return;
    }

    if (_openPosition == null) {
      _openPosition = Position(
        symbol: symbol,
        side: desiredSide,
        entryPrice: currentPrice,
        quantity: quantity,
        entryTime: DateTime.now(),
      );
      _positionController.add(_openPosition);
      _recordEntryTrade(desiredSide, currentPrice, quantity, reason);
      return;
    }

    if (_openPosition!.side == desiredSide) {
      return;
    }

    final closeReason = reason == 'strategy' ? 'reversal' : reason;
    _closePosition(currentPrice, closeReason);
    _openPosition = Position(
      symbol: symbol,
      side: desiredSide,
      entryPrice: currentPrice,
      quantity: quantity,
      entryTime: DateTime.now(),
    );
    _positionController.add(_openPosition);
    _recordEntryTrade(desiredSide, currentPrice, quantity, reason);
  }

  void _recordEntryTrade(PositionSide side, double price, double quantity, String reason) {
    final trade = Trade(
      symbol: symbol,
      side: side == PositionSide.long ? 'BUY' : 'SELL',
      price: price,
      quantity: quantity,
      timestamp: DateTime.now(),
      status: 'simulated',
      strategy: strategy.name,
      kind: 'ENTRY',
      reason: reason,
    );

    _trades.add(trade);
    _tradeController.add(_trades);
    print('Recorded ENTRY ${trade.side}: ${trade.symbol} @ ${trade.price} (${trade.strategy})');
  }

  void _closePosition(double price, String reason) {
    final position = _openPosition;
    if (position == null) return;

    final exitSide = position.isLong ? 'SELL' : 'BUY';
    final pnl = position.isLong
        ? (price - position.entryPrice) * position.quantity
        : (position.entryPrice - price) * position.quantity;

    final trade = Trade(
      symbol: symbol,
      side: exitSide,
      price: price,
      quantity: position.quantity,
      timestamp: DateTime.now(),
      status: 'simulated',
      strategy: strategy.name,
      kind: 'EXIT',
      realizedPnl: pnl,
      reason: reason,
    );

    _trades.add(trade);
    _tradeController.add(_trades);
    _openPosition = null;
    _positionController.add(_openPosition);

    print('Recorded EXIT $exitSide: ${trade.symbol} @ ${trade.price} PnL=$pnl (${trade.reason})');
  }

  void _checkRisk(double currentPrice) {
    final position = _openPosition;
    if (position == null) return;

    if (riskSettings.hasStopLoss) {
      final stopLoss = position.stopLossPrice(riskSettings.stopLossPercent);
      if (position.isLong && currentPrice <= stopLoss) {
        _closePosition(currentPrice, 'stop_loss');
        return;
      }
      if (!position.isLong && currentPrice >= stopLoss) {
        _closePosition(currentPrice, 'stop_loss');
        return;
      }
    }

    if (riskSettings.hasTakeProfit) {
      final takeProfit = position.takeProfitPrice(riskSettings.takeProfitPercent);
      if (position.isLong && currentPrice >= takeProfit) {
        _closePosition(currentPrice, 'take_profit');
        return;
      }
      if (!position.isLong && currentPrice <= takeProfit) {
        _closePosition(currentPrice, 'take_profit');
        return;
      }
    }
  }

  void stopMarketData() {
    _isStreaming = false;
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _stopConnectionTicker();
    _emitConnectionStatus(forceDisconnected: true);
  }

  void stop() {
    disableTrading();
    stopMarketData();
  }

  void dispose() {
    _klineController.close();
    _tradeController.close();
    _positionController.close();
    _connectionController.close();
    _signalController.close();
    stopMarketData();
  }

  void _recordMessageTimestamp(Map<String, dynamic> event) {
    _lastMessageAt = DateTime.now();
    final eventTime = event['E'] ?? (event['k'] is Map ? event['k']['T'] : null);
    if (eventTime is int) {
      _lastLatencyMs = (_lastMessageAt!.millisecondsSinceEpoch - eventTime).abs();
    } else if (eventTime is String) {
      final parsed = int.tryParse(eventTime);
      if (parsed != null) {
        _lastLatencyMs = (_lastMessageAt!.millisecondsSinceEpoch - parsed).abs();
      }
    }
    _emitConnectionStatus();
  }

  void _startConnectionTicker() {
    _connectionTimer?.cancel();
    _connectionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _emitConnectionStatus();
    });
  }

  void _stopConnectionTicker() {
    _connectionTimer?.cancel();
    _connectionTimer = null;
  }

  void _emitConnectionStatus({bool forceDisconnected = false}) {
    if (_connectionController.isClosed) return;

    if (forceDisconnected || !_isStreaming) {
      _connectionController.add(ConnectionStatus.disconnected(lastMessageAt: _lastMessageAt));
      return;
    }

    if (_lastMessageAt == null) {
      _connectionController.add(ConnectionStatus.connecting());
      return;
    }

    final ageSeconds = DateTime.now().difference(_lastMessageAt!).inSeconds;
    final state = ageSeconds <= 3
        ? MarketConnectionState.connected
        : ageSeconds <= 15
            ? MarketConnectionState.stale
            : MarketConnectionState.disconnected;

    _connectionController.add(
      ConnectionStatus(
        state: state,
        latencyMs: _lastLatencyMs,
        lastMessageAt: _lastMessageAt,
      ),
    );
  }
}
