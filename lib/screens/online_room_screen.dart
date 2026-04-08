import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../models/online_models.dart';
import '../services/online_service.dart';
import 'online_game_screen.dart';

/// Waiting-room screen: shows all joined players, room code, and lets
/// the host start the match.
class OnlineRoomScreen extends StatefulWidget {
  final String roomCode;
  final String localUid;

  const OnlineRoomScreen({
    super.key,
    required this.roomCode,
    required this.localUid,
  });

  @override
  State<OnlineRoomScreen> createState() => _OnlineRoomScreenState();
}

class _OnlineRoomScreenState extends State<OnlineRoomScreen> {
  final _svc = OnlineService();
  bool _isStarting = false;
  String? _error;

  static const _colorNames = {
    'red': 'Red',
    'green': 'Green',
    'yellow': 'Yellow',
    'blue': 'Blue',
  };

  static const _colorMap = {
    'red': GameColors.red,
    'green': GameColors.green,
    'yellow': GameColors.yellow,
    'blue': GameColors.blue,
  };

  Future<void> _startMatch(Map<String, OnlinePlayer> players) async {
    setState(() {
      _isStarting = true;
      _error = null;
    });
    try {
      await _svc.startGame(widget.roomCode);
      // Navigation handled by the stream listener (status → playing)
    } catch (e) {
      setState(() {
        _isStarting = false;
        _error = 'Failed to start: $e';
      });
    }
  }

  Future<void> _leaveRoom() async {
    await _svc.leaveRoom(widget.roomCode, widget.localUid);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _leaveRoom();
        return false;
      },
      child: Scaffold(
        backgroundColor: GameColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black,
          title: const Text('WAITING ROOM'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _leaveRoom,
          ),
        ),
        body: StreamBuilder<DatabaseEvent>(
          stream: _svc.roomStream(widget.roomCode),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: GameColors.red));
            }
            if (!snapshot.hasData || !snapshot.data!.snapshot.exists) {
              return const Center(child: Text('Room not found or was deleted.'));
            }

            final raw =
                snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            final room = OnlineRoom.fromMap(widget.roomCode, raw);

            // Room transitioned to playing → navigate to game
            if (room.status == 'playing') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OnlineGameScreen(
                        roomCode: widget.roomCode,
                        localUid: widget.localUid,
                        initialRoom: room,
                      ),
                    ),
                  );
                }
              });
            }

            final isHost = room.hostUid == widget.localUid;
            final players = room.players;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Room code card
                    _RoomCodeCard(code: widget.roomCode),
                    const SizedBox(height: 28),

                    // Players
                    Text(
                      'PLAYERS (${players.length}/4)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 2,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...players.values.map(
                      (p) => _PlayerTile(
                        player: p,
                        isLocalPlayer: p.uid == widget.localUid,
                        isHost: p.uid == room.hostUid,
                        colorLabel: _colorNames[p.color] ?? p.color,
                        color: _colorMap[p.color] ?? GameColors.red,
                      ),
                    ),

                    // Empty slots
                    ...List.generate(4 - players.length, (i) {
                      return const _EmptySlotTile();
                    }),

                    const Spacer(),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ),

                    if (isHost)
                      ElevatedButton(
                        onPressed: _isStarting
                            ? null
                            : () => _startMatch(players),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GameColors.green,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isStarting
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'START MATCH',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  if (players.length < 4)
                                    Text(
                                      'Empty slots will be filled by AI',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: GameColors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Waiting for host to start…',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ──────────────────────────────────────────────────────────────────────────────

class _RoomCodeCard extends StatelessWidget {
  final String code;
  const _RoomCodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GameColors.blue.withOpacity(0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ROOM CODE',
            style: TextStyle(
                fontSize: 11, color: Colors.grey, letterSpacing: 2),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                code,
                style: GoogleFonts.outfit(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  color: GameColors.blue,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, color: GameColors.blue),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied!')),
                  );
                },
              ),
            ],
          ),
          Text(
            'Share this code with friends to join.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final OnlinePlayer player;
  final bool isLocalPlayer;
  final bool isHost;
  final String colorLabel;
  final Color color;

  const _PlayerTile({
    required this.player,
    required this.isLocalPlayer,
    required this.isHost,
    required this.colorLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isLocalPlayer
            ? Border.all(color: color.withOpacity(0.4), width: 2)
            : null,
      ),
      child: Row(
        children: [
          Text(avatarEmoji(player.avatar),
              style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      player.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (isLocalPlayer) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'YOU',
                          style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    if (isHost) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.star, color: GameColors.yellow, size: 14),
                    ],
                  ],
                ),
                Text(
                  colorLabel,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: player.isOnline ? GameColors.green : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySlotTile extends StatelessWidget {
  const _EmptySlotTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.grey.shade200, width: 1.5, style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Icon(Icons.person_add_outlined, color: Colors.grey.shade400, size: 28),
          const SizedBox(width: 12),
          Text(
            'Waiting for player…',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
