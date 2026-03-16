enum PositionSide { long, short }

class Position {
  final String symbol;
  final PositionSide side;
  final double entryPrice;
  final double quantity;
  final DateTime entryTime;

  Position({
    required this.symbol,
    required this.side,
    required this.entryPrice,
    required this.quantity,
    required this.entryTime,
  });

  bool get isLong => side == PositionSide.long;

  double stopLossPrice(double percent) {
    if (percent <= 0) return entryPrice;
    return isLong
        ? entryPrice * (1 - (percent / 100))
        : entryPrice * (1 + (percent / 100));
  }

  double takeProfitPrice(double percent) {
    if (percent <= 0) return entryPrice;
    return isLong
        ? entryPrice * (1 + (percent / 100))
        : entryPrice * (1 - (percent / 100));
  }
}
