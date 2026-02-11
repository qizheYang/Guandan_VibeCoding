import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../build_info.dart';
import '../../services/ws_client.dart';
import '../../state/room_state.dart';
import 'room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nameController = TextEditingController(text: '');
  final _codeController = TextEditingController();
  String? _error;
  bool _wsConnected = false;
  StreamSubscription<bool>? _connSub;

  @override
  void initState() {
    super.initState();
    final ws = context.read<WsClient>();
    _wsConnected = ws.isConnected;
    _connSub = ws.connectionStatus.listen((connected) {
      if (mounted) setState(() => _wsConnected = connected);
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _createRoom() {
    if (!_wsConnected) {
      setState(() => _error = '正在连接服务器...');
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入昵称');
      return;
    }
    final room = context.read<RoomState>();
    room.createRoom(name);
    _navigateToRoom();
  }

  void _joinRoom() {
    if (!_wsConnected) {
      setState(() => _error = '正在连接服务器...');
      return;
    }
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入昵称');
      return;
    }
    if (code.length != 4) {
      setState(() => _error = '请输入4位房间号');
      return;
    }
    final room = context.read<RoomState>();
    room.joinRoom(code, name);
    _navigateToRoom();
  }

  void _navigateToRoom() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RoomScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B5E20), Color(0xFF0D3B0F)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '掼蛋',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Guan Dan',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withValues(alpha: 0.7),
                      letterSpacing: 4,
                    ),
                  ),
                  if (!_wsConnected) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '连接服务器中...',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 48),

                  // Name input
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: '昵称',
                      labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7)),
                      prefixIcon: const Icon(Icons.person,
                          color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white38),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Create room button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _createRoom,
                      icon: const Icon(Icons.add),
                      label: const Text('创建房间',
                          style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8F00),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.3))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('或加入房间',
                            style: TextStyle(
                                color:
                                    Colors.white.withValues(alpha: 0.6))),
                      ),
                      Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.3))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Room code input
                  TextField(
                    controller: _codeController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      letterSpacing: 12,
                    ),
                    textAlign: TextAlign.center,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '房间号',
                      labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7)),
                      counterText: '',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white38),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _joinRoom,
                      icon: const Icon(Icons.login),
                      label: const Text('加入房间',
                          style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!,
                        style: const TextStyle(color: Colors.redAccent)),
                  ],

                  // Listen for errors from server
                  Consumer<RoomState>(
                    builder: (_, room, _) {
                      if (room.errorMessage != null) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            room.errorMessage!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  const SizedBox(height: 32),
                  if (kIsWeb) ...[
                    Text(
                      '下载桌面版',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _DownloadChip(
                          icon: Icons.apple,
                          label: 'macOS',
                          url:
                              'https://github.com/qizheYang/Guandan_VibeCoding/releases/latest/download/guandan-macos.zip',
                        ),
                        const SizedBox(width: 12),
                        _DownloadChip(
                          icon: Icons.window,
                          label: 'Windows',
                          url:
                              'https://github.com/qizheYang/Guandan_VibeCoding/releases/latest/download/guandan-windows.zip',
                        ),
                        const SizedBox(width: 12),
                        _DownloadChip(
                          icon: Icons.desktop_windows,
                          label: 'Linux',
                          url:
                              'https://github.com/qizheYang/Guandan_VibeCoding/releases/latest/download/guandan-linux.tar.gz',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'v$appVersion${buildTime == 'dev' ? '' : ' · $buildTime'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;

  const _DownloadChip({
    required this.icon,
    required this.label,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: Colors.white70),
      label: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }
}
