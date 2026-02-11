import 'dart:io';
import 'dart:convert';

import 'package:guandan_server/room_manager.dart';
import 'package:guandan_server/client_connection.dart';

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ??
      (args.isNotEmpty ? int.parse(args[0]) : 8080);

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('掼蛋 server listening on ws://localhost:$port');

  final roomManager = RoomManager();

  await for (final request in server) {
    // CORS headers for Flutter web
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      continue;
    }

    if (WebSocketTransformer.isUpgradeRequest(request)) {
      try {
        final socket = await WebSocketTransformer.upgrade(request);
        final connection = ClientConnection(socket, roomManager);
        connection.listen();
        print('New WebSocket connection');
      } catch (e) {
        print('WebSocket upgrade failed: $e');
      }
    } else {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'status': 'ok', 'game': '掼蛋'}));
      await request.response.close();
    }
  }
}
