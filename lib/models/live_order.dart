class LiveOrder {
  static final RegExp _scopedOwnerIdPattern = RegExp(r'^[a-z0-9]{8}$');

  final String symbol;
  final String orderId;
  final String? clientOrderId;
  final bool isAlgo;
  final String side;
  final String type;
  final double price;
  final double? stopPrice;
  final double quantity;
  final bool reduceOnly;
  final bool closePosition;
  final String? positionSide;
  final String? timeInForce;
  final DateTime updatedAt;

  const LiveOrder({
    required this.symbol,
    required this.orderId,
    this.clientOrderId,
    this.isAlgo = false,
    required this.side,
    required this.type,
    required this.price,
    this.stopPrice,
    required this.quantity,
    required this.reduceOnly,
    this.closePosition = false,
    this.positionSide,
    required this.updatedAt,
    this.timeInForce,
  });

  bool get isProtectionOrder =>
      type.toUpperCase() == 'STOP_MARKET' ||
      type.toUpperCase() == 'TAKE_PROFIT_MARKET' ||
      closePosition;

  bool get isBotOwned =>
      clientOrderId != null && clientOrderId!.startsWith('ifut-');

  bool get isBotEntryOrder =>
      clientOrderId != null && clientOrderId!.startsWith('ifut-entry-');

  bool get isBotExitOrder =>
      clientOrderId != null && clientOrderId!.startsWith('ifut-exit-');

  /// Whether this order uses the installation-scoped iFutures client ID
  /// format and belongs to [ownerId].
  bool isOwnedBy(String ownerId) => _ownedRole(ownerId) != null;

  /// Whether this is an entry order belonging to [ownerId].
  bool isEntryOrderOwnedBy(String ownerId) => _ownedRole(ownerId) == 'entry';

  /// Whether this is an exit order belonging to [ownerId].
  bool isExitOrderOwnedBy(String ownerId) => _ownedRole(ownerId) == 'exit';

  String? _ownedRole(String ownerId) {
    if (!_scopedOwnerIdPattern.hasMatch(ownerId)) return null;
    final segments = clientOrderId?.split('-');
    if (segments == null ||
        segments.length != 5 ||
        segments[0] != 'ifut' ||
        segments[1].isEmpty ||
        segments[2] != ownerId ||
        segments[3].isEmpty ||
        segments[4].isEmpty) {
      return null;
    }
    return segments[1];
  }

  double? get triggerPrice => stopPrice != null && stopPrice! > 0
      ? stopPrice
      : (price > 0 ? price : null);

  String get summary {
    final trigger = triggerPrice;
    final triggerLabel = trigger == null
        ? ''
        : '@ ${trigger.toStringAsFixed(trigger >= 100 ? 2 : 6)}';
    final closeAllLabel = closePosition ? ' Close-All' : '';
    final modeLabel = positionSide == null ? '' : ' [$positionSide]';
    final ownershipLabel = isBotOwned ? ' [iFutures]' : '';
    return '$side $symbol ${type.toUpperCase()}$closeAllLabel$modeLabel$ownershipLabel $triggerLabel'
        .trim();
  }
}
