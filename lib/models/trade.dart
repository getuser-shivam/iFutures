class Trade {
  final String symbol;
  final String side; // 'BUY' or 'SELL'
  final double price;
  final double quantity;
  final DateTime timestamp;
  final String? orderId;
  final String status; // 'pending', 'filled', 'cancelled'
  final double? fee;
  final String strategy; // 'ALGO' or 'AI'

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
    );
  }
}