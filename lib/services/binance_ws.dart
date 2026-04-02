import 'dart:convert';

import '../models/connection_status.dart';
import 'reconnecting_websocket.dart';

class BinanceWebSocketService {
  final bool isTestnet;

  String get baseWsUrl => isTestnet
      ? 'wss://fstream.binancefuture.com/ws'
      : 'wss://fstream.binance.com/ws';

  BinanceWebSocketService({this.isTestnet = true});

  Stream<dynamic> subscribeToKlines(
    String symbol, {
    String interval = '1m',
    void Function(ConnectionStatus status)? onStatusChanged,
  }) {
    final channelName = '${symbol.toLowerCase()}@kline_$interval';
    final url = Uri.parse('$baseWsUrl/$channelName');
    final connection = ReconnectingWebSocket(
      url: url,
      onStatusChanged: onStatusChanged,
    );
    return connection.stream.map((event) => jsonDecode(event as String));
  }

  Stream<dynamic> subscribeToTicker(
    String symbol, {
    void Function(ConnectionStatus status)? onStatusChanged,
  }) {
    final channelName = '${symbol.toLowerCase()}@ticker';
    final url = Uri.parse('$baseWsUrl/$channelName');
    final connection = ReconnectingWebSocket(
      url: url,
      onStatusChanged: onStatusChanged,
    );
    return connection.stream.map((event) => jsonDecode(event as String));
  }
}
