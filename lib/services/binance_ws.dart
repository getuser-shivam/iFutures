import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class BinanceWebSocketService {
  final bool isTestnet;
  WebSocketChannel? _channel;

  String get baseWsUrl => isTestnet
      ? 'wss://fstream.binancefuture.com/ws'
      : 'wss://fstream.binance.com/ws';

  BinanceWebSocketService({this.isTestnet = true});

  Stream<dynamic> subscribeToKlines(String symbol, {String interval = '1m'}) {
    final channelName = '${symbol.toLowerCase()}@kline_$interval';
    final url = '$baseWsUrl/$channelName';
    
    _channel = WebSocketChannel.connect(Uri.parse(url));
    return _channel!.stream.map((event) => jsonDecode(event));
  }

  Stream<dynamic> subscribeToTicker(String symbol) {
    final channelName = '${symbol.toLowerCase()}@ticker';
    final url = '$baseWsUrl/$channelName';
    
    _channel = WebSocketChannel.connect(Uri.parse(url));
    return _channel!.stream.map((event) => jsonDecode(event));
  }

  void disconnect() {
    _channel?.sink.close();
  }
}
