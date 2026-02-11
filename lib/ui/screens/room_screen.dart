import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:guandan_shared/models/player.dart';

import '../../state/room_state.dart';
import '../../state/game_state_notifier.dart';
import '../../services/ws_client.dart';
import 'game_screen.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  bool _navigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final room = context.watch<RoomState>();
    if (room.gameStarted && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startGame(room);
      });
    }
  }

  void _startGame(RoomState room) {
    final ws = context.read<WsClient>();
    final gameState = GameStateNotifier(
      ws: ws,
      mySeatIndex: room.mySeatIndex!,
      myPlayerId: room.myPlayerId!,
    );
    gameState.initFromRoomState(
      hand: room.initialHand!,
      levelValue: room.currentLevelValue!,
      levels: room.teamLevels!,
      flip: room.flipCard!,
      firstPlayer: room.firstPlayer!,
      infos: room.playerInfos!,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: gameState,
          child: const GameScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomState>();
    final code = room.roomCode ?? '----';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B5E20), Color(0xFF0D3B0F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Room code
              Text('房间号',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('房间号已复制'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.copy,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('点击复制房间号分享给好友',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12)),
              const SizedBox(height: 40),

              // Seats layout (diamond shape)
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 360,
                    height: 360,
                    child: Stack(
                      children: [
                        // Top (seat partner of creator)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Center(
                              child: _SeatWidget(
                                  seat: 2,
                                  player: room.players[2],
                                  isReady: room.readyStatus[2],
                                  isMe: room.mySeatIndex == 2)),
                        ),
                        // Left
                        Positioned(
                          top: 120,
                          left: 0,
                          child: _SeatWidget(
                              seat: 3,
                              player: room.players[3],
                              isReady: room.readyStatus[3],
                              isMe: room.mySeatIndex == 3),
                        ),
                        // Right
                        Positioned(
                          top: 120,
                          right: 0,
                          child: _SeatWidget(
                              seat: 1,
                              player: room.players[1],
                              isReady: room.readyStatus[1],
                              isMe: room.mySeatIndex == 1),
                        ),
                        // Bottom (creator)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Center(
                              child: _SeatWidget(
                                  seat: 0,
                                  player: room.players[0],
                                  isReady: room.readyStatus[0],
                                  isMe: room.mySeatIndex == 0)),
                        ),
                        // Team labels
                        Positioned(
                          top: 160,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Column(
                              children: [
                                _teamLabel('队伍A', const Color(0xFF1565C0),
                                    [0, 2]),
                                const SizedBox(height: 4),
                                _teamLabel('队伍B', const Color(0xFFD84315),
                                    [1, 3]),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Ready button
              Padding(
                padding: const EdgeInsets.all(32),
                child: SizedBox(
                  width: 200,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: room.readyStatus[room.mySeatIndex ?? 0]
                        ? null
                        : () => room.setReady(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8F00),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      room.readyStatus[room.mySeatIndex ?? 0]
                          ? '等待其他玩家...'
                          : '准备',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teamLabel(String name, Color color, List<int> seats) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(name,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
        Text(' (座位 ${seats.join(",")})',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
      ],
    );
  }
}

class _SeatWidget extends StatelessWidget {
  final int seat;
  final Player? player;
  final bool isReady;
  final bool isMe;

  const _SeatWidget({
    required this.seat,
    required this.player,
    required this.isReady,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final teamColor =
        seat % 2 == 0 ? const Color(0xFF1565C0) : const Color(0xFFD84315);
    final isEmpty = player == null;

    return Container(
      width: 120,
      height: 100,
      decoration: BoxDecoration(
        color: isEmpty
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe ? Colors.amber : teamColor.withValues(alpha: 0.5),
          width: isMe ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isEmpty ? Icons.person_outline : Icons.person,
            color: isEmpty ? Colors.white30 : teamColor,
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            isEmpty ? '等待加入...' : player!.name,
            style: TextStyle(
              color: isEmpty ? Colors.white30 : Colors.white,
              fontSize: 13,
              fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (isReady)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text('✓ 已准备',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
            ),
          if (isMe)
            const Text('(你)',
                style: TextStyle(color: Colors.amber, fontSize: 10)),
        ],
      ),
    );
  }
}
