class Kline {
  final DateTime openTime;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final DateTime closeTime;

  Kline({
    required this.openTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.closeTime,
  });

  factory Kline.fromJson(List<dynamic> json) {
    return Kline(
      openTime: DateTime.fromMillisecondsSinceEpoch(json[0] as int),
      open: double.parse(json[1].toString()),
      high: double.parse(json[2].toString()),
      low: double.parse(json[3].toString()),
      close: double.parse(json[4].toString()),
      volume: double.parse(json[5].toString()),
      closeTime: DateTime.fromMillisecondsSinceEpoch(json[6] as int),
    );
  }

  factory Kline.fromWsJson(Map<String, dynamic> json) {
    final k = json['k'];
    return Kline(
      openTime: DateTime.fromMillisecondsSinceEpoch(k['t'] as int),
      open: double.parse(k['o'].toString()),
      high: double.parse(k['h'].toString()),
      low: double.parse(k['l'].toString()),
      close: double.parse(k['c'].toString()),
      volume: double.parse(k['v'].toString()),
      closeTime: DateTime.fromMillisecondsSinceEpoch(k['T'] as int),
    );
  }
}
