import 'package:intl/intl.dart';

enum PriceAlertDirection { above, below }

const Object _unset = Object();

extension PriceAlertDirectionX on PriceAlertDirection {
  String get label => switch (this) {
    PriceAlertDirection.above => 'Above',
    PriceAlertDirection.below => 'Below',
  };
}

class PriceAlert {
  final String id;
  final String symbol;
  final PriceAlertDirection direction;
  final double threshold;
  final DateTime createdAt;
  final bool enabled;
  final DateTime? triggeredAt;

  const PriceAlert({
    required this.id,
    required this.symbol,
    required this.direction,
    required this.threshold,
    required this.createdAt,
    this.enabled = true,
    this.triggeredAt,
  });

  bool get isTriggered => triggeredAt != null;

  bool get isActive => enabled && !isTriggered;

  bool matches(double price) {
    return switch (direction) {
      PriceAlertDirection.above => price >= threshold,
      PriceAlertDirection.below => price <= threshold,
    };
  }

  PriceAlert trigger(DateTime timestamp) {
    return copyWith(enabled: false, triggeredAt: timestamp);
  }

  PriceAlert rearm() {
    return copyWith(enabled: true, triggeredAt: null);
  }

  PriceAlert copyWith({
    String? id,
    String? symbol,
    PriceAlertDirection? direction,
    double? threshold,
    DateTime? createdAt,
    bool? enabled,
    Object? triggeredAt = _unset,
  }) {
    return PriceAlert(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      direction: direction ?? this.direction,
      threshold: threshold ?? this.threshold,
      createdAt: createdAt ?? this.createdAt,
      enabled: enabled ?? this.enabled,
      triggeredAt: identical(triggeredAt, _unset)
          ? this.triggeredAt
          : triggeredAt as DateTime?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'direction': direction.name,
      'threshold': threshold,
      'createdAt': createdAt.toIso8601String(),
      'enabled': enabled,
      'triggeredAt': triggeredAt?.toIso8601String(),
    };
  }

  factory PriceAlert.fromJson(Map<String, dynamic> json) {
    final directionValue = json['direction']?.toString().toLowerCase();
    final direction = directionValue == 'below'
        ? PriceAlertDirection.below
        : PriceAlertDirection.above;

    return PriceAlert(
      id:
          json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      symbol: json['symbol']?.toString() ?? '',
      direction: direction,
      threshold: double.tryParse(json['threshold']?.toString() ?? '') ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      enabled: json['enabled'] as bool? ?? true,
      triggeredAt: DateTime.tryParse(json['triggeredAt']?.toString() ?? ''),
    );
  }
}

String formatPriceValue(double value) {
  return NumberFormat('#,##0.######', 'en_US').format(value);
}
