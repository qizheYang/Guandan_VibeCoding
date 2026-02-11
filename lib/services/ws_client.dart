import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:guandan_shared/protocol/protocol.dart';

class WsClient {
  WebSocketChannel? _channel;
  final _messageController = StreamController<ServerMsg>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  bool _connected = false;
  String? _url;
  bool _disposed = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  Stream<ServerMsg> get messages => _messageController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;
  bool get isConnected => _connected;

  Future<void> connect(String url) async {
    _url = url;
    _disposed = false;
    await _doConnect(url);
  }

  Future<void> _doConnect(String url) async {
    _disconnect();
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      // Wait for the WebSocket handshake to actually complete
      await _channel!.ready;

      _connected = true;
      _reconnectAttempts = 0;
      _connectionController.add(true);
      print('[WsClient] Connected to $url');

      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final msg = ServerMsg.fromJson(json);
            _messageController.add(msg);
          } catch (e) {
            print('[WsClient] Failed to parse server message: $e');
          }
        },
        onDone: () {
          print('[WsClient] Connection closed');
          _connected = false;
          _connectionController.add(false);
          _scheduleReconnect();
        },
        onError: (e) {
          print('[WsClient] WebSocket error: $e');
          _connected = false;
          _connectionController.add(false);
          _scheduleReconnect();
        },
      );
    } catch (e) {
      print('[WsClient] Failed to connect: $e');
      _connected = false;
      _connectionController.add(false);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _url == null) return;
    _reconnectTimer?.cancel();

    // Exponential backoff: 1s, 2s, 4s, 8s, max 15s
    final delay = Duration(
      seconds: (_reconnectAttempts < 4) ? (1 << _reconnectAttempts) : 15,
    );
    _reconnectAttempts++;
    print('[WsClient] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(delay, () {
      if (!_disposed && _url != null) {
        _doConnect(_url!);
      }
    });
  }

  void send(ClientMsg msg) {
    if (_channel != null && _connected) {
      _channel!.sink.add(jsonEncode(msg.toJson()));
    } else {
      print('[WsClient] Cannot send: not connected');
    }
  }

  void _disconnect() {
    _reconnectTimer?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _connected = false;
  }

  void disconnect() {
    _disconnect();
    _connectionController.add(false);
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _disconnect();
    _messageController.close();
    _connectionController.close();
  }
}
