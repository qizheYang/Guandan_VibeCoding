import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:guandan_shared/protocol/protocol.dart';

class WsClient {
  WebSocketChannel? _channel;
  final _messageController = StreamController<ServerMsg>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  bool _connected = false;

  Stream<ServerMsg> get messages => _messageController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;
  bool get isConnected => _connected;

  void connect(String url) {
    disconnect();
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _connected = true;
      _connectionController.add(true);

      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final msg = ServerMsg.fromJson(json);
            _messageController.add(msg);
          } catch (e) {
            print('Failed to parse server message: $e');
          }
        },
        onDone: () {
          _connected = false;
          _connectionController.add(false);
        },
        onError: (e) {
          print('WebSocket error: $e');
          _connected = false;
          _connectionController.add(false);
        },
      );
    } catch (e) {
      print('Failed to connect: $e');
      _connected = false;
      _connectionController.add(false);
    }
  }

  void send(ClientMsg msg) {
    if (_channel != null && _connected) {
      _channel!.sink.add(jsonEncode(msg.toJson()));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _connected = false;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}
