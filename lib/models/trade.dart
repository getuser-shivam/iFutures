class Trade {
  final String symbol;
  final String side; // 'BUY' or 'SELL'
  final double price;
  final double quantity;
  final DateTime timestamp;
  final String? orderId;
  final String status; // 'pending', 'filled', 'cancelled', 'simulated'
  final double? fee;
  final String strategy; // 'ALGO' or 'AI'
  final String kind; // 'ENTRY' or 'EXIT'
  final double? realizedPnl;
  final String? orderType;
  final double? requestedPrice;
  final String?
  reason; // 'strategy', 'stop_loss', 'take_profit', 'manual_stop', 'reversal'

  Trade({
    required this.symbol,
    required this.side,
    required this.price,
    required this.quantity,
    required this.timestamp,
    this.orderId,
    this.status = 'pending',
    this.fee,
    required this.strategy,
    this.kind = 'ENTRY',
    this.realizedPnl,
    this.orderType,
    this.requestedPrice,
    this.reason,
  });

  // Calculate P&L for closed positions
  double? get pnl {
    // This would need to be calculated based on entry/exit prices
    // For now, return null as we don't have exit prices yet
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'side': side,
      'price': price,
      'quantity': quantity,
      'timestamp': timestamp.toIso8601String(),
      'orderId': orderId,
      'status': status,
      'fee': fee,
      'strategy': strategy,
      'kind': kind,
      'realizedPnl': realizedPnl,
      'orderType': orderType,
      'requestedPrice': requestedPrice,
      'reason': reason,
    };
  }

  factory Trade.fromJson(Map<String, dynamic> json) {
    return Trade(
      symbol: json['symbol'],
      side: json['side'],
      price: json['price'],
      quantity: json['quantity'],
      timestamp: DateTime.parse(json['timestamp']),
      orderId: json['orderId'],
      status: json['status'] ?? 'pending',
      fee: json['fee'],
      strategy: json['strategy'],
      kind: json['kind'] ?? 'ENTRY',
      realizedPnl: json['realizedPnl'],
      orderType: json['orderType'],
      requestedPrice: json['requestedPrice'],
      reason: json['reason'],
    );
  }
}
