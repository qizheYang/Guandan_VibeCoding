import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/ws_client.dart';
import 'state/room_state.dart';
import 'ui/screens/home_screen.dart';

const String appVersion = String.fromEnvironment(
  'BUILD_VERSION',
  defaultValue: '1.0.0.0',
);
const String wsUrl = String.fromEnvironment(
  'WS_URL',
  defaultValue: 'ws://localhost:8080',
);

void main() {
  runApp(const GuanDanApp());
}

class GuanDanApp extends StatefulWidget {
  const GuanDanApp({super.key});

  @override
  State<GuanDanApp> createState() => _GuanDanAppState();
}

class _GuanDanAppState extends State<GuanDanApp> {
  late final WsClient _wsClient;

  @override
  void initState() {
    super.initState();
    _wsClient = WsClient();
    _wsClient.connect(wsUrl);
  }

  @override
  void dispose() {
    _wsClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<WsClient>.value(value: _wsClient),
        ChangeNotifierProvider(create: (_) => RoomState(_wsClient)),
      ],
      child: MaterialApp(
        title: '掼蛋',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
