import 'position.dart';

enum ManualOrderAction { openLong, openShort, closeLong, closeShort }

extension ManualOrderActionX on ManualOrderAction {
  String get label => switch (this) {
    ManualOrderAction.openLong => 'Open Long',
    ManualOrderAction.openShort => 'Open Short',
    ManualOrderAction.closeLong => 'Close Long',
    ManualOrderAction.closeShort => 'Close Short',
  };

  bool get isOpenAction => switch (this) {
    ManualOrderAction.openLong || ManualOrderAction.openShort => true,
    _ => false,
  };

  bool get isCloseAction => !isOpenAction;

  PositionSide get positionSide => switch (this) {
    ManualOrderAction.openLong ||
    ManualOrderAction.closeLong => PositionSide.long,
    ManualOrderAction.openShort ||
    ManualOrderAction.closeShort => PositionSide.short,
  };
}

enum ManualOrderType { market, limit, postOnly, scaled }

extension ManualOrderTypeX on ManualOrderType {
  String get label => switch (this) {
    ManualOrderType.market => 'Market',
    ManualOrderType.limit => 'Limit',
    ManualOrderType.postOnly => 'Post Only',
    ManualOrderType.scaled => 'Scaled',
  };
}

class ManualOrderRequest {
  final ManualOrderAction action;
  final ManualOrderType orderType;
  final double quantity;
  final double? price;
  final double? scaleEndPrice;
  final int scaleSteps;

  const ManualOrderRequest({
    required this.action,
    required this.orderType,
    required this.quantity,
    this.price,
    this.scaleEndPrice,
    this.scaleSteps = 1,
  });
}

class PendingManualOrder {
  final String id;
  final String symbol;
  final ManualOrderAction action;
  final ManualOrderType orderType;
  final double quantity;
  final double targetPrice;
  final DateTime createdAt;
  final int? scaleIndex;
  final int? scaleSteps;

  const PendingManualOrder({
    required this.id,
    required this.symbol,
    required this.action,
    required this.orderType,
    required this.quantity,
    required this.targetPrice,
    required this.createdAt,
    this.scaleIndex,
    this.scaleSteps,
  });

  String get summary {
    final scaleLabel = scaleIndex == null || scaleSteps == null
        ? ''
        : ' ${scaleIndex! + 1}/$scaleSteps';
    return '${action.label}$scaleLabel @ ${targetPrice.toStringAsFixed(6)}';
  }
}

class ManualOrderSubmissionResult {
  final bool accepted;
  final String message;
  final int queuedOrders;
  final int executedOrders;

  const ManualOrderSubmissionResult({
    required this.accepted,
    required this.message,
    this.queuedOrders = 0,
    this.executedOrders = 0,
  });
}
