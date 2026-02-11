import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../build_info.dart';
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

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _createRoom() {
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
