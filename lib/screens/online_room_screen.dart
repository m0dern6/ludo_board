import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../models/online_models.dart';
import '../models/piece_model.dart';
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

  static const _allColors = ['red', 'green', 'yellow', 'blue'];

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

  Future<void> _toggleFillWithAi(GameRules currentRules) async {
    final updated = GameRules(
      rediceOnOne: currentRules.rediceOnOne,
      mustKillToEnterHome: currentRules.mustKillToEnterHome,
      quickMode: currentRules.quickMode,
      fillWithAi: !currentRules.fillWithAi,
    );
    try {
      await _svc.updateRules(widget.roomCode, updated);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not update rules: $e');
    }
  }

  /// Returns the list of colors the local player may pick.
  /// - 2 players: can pick any of the 4 colors (the other auto-follows diagonal).
  /// - 3+ players: all colors not already taken by others.
  List<String> _availableColors(Map<String, OnlinePlayer> players, String localColor) {
    if (players.length == 2) {
      return _allColors;
    }
    final taken = players.values
        .where((p) => p.uid != widget.localUid)
        .map((p) => p.color)
        .toSet();
    return _allColors.where((c) => c == localColor || !taken.contains(c)).toList();
  }

  Future<void> _changeColor(String newColor) async {
    final err = await _svc.changePlayerColor(
      code: widget.roomCode,
      uid: widget.localUid,
      newColor: newColor,
    );
    if (err != null && mounted) setState(() => _error = err);
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
            final localPlayer = players[widget.localUid];
            final localColor = localPlayer?.color ?? 'red';
            final availableColors = _availableColors(players, localColor);

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
                        availableColors: p.uid == widget.localUid ? availableColors : null,
                        onColorChange: p.uid == widget.localUid ? _changeColor : null,
                      ),
                    ),

                    // Empty slots
                    ...List.generate(4 - players.length, (i) {
                      return const _EmptySlotTile();
                    }),

                    const Spacer(),

                    // AI fill toggle (host only, when there are empty slots)
                    if (isHost && players.length < 4) ...[
                      _AiFillToggle(
                        fillWithAi: room.rules.fillWithAi,
                        onToggle: () => _toggleFillWithAi(room.rules),
                      ),
                      const SizedBox(height: 12),
                    ],

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
                                      room.rules.fillWithAi
                                          ? 'Empty slots will be filled by AI'
                                          : 'Playing with ${players.length} player(s) only',
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
  /// Colors the local player may switch to. Null means no color picker shown.
  final List<String>? availableColors;
  final Future<void> Function(String)? onColorChange;

  const _PlayerTile({
    required this.player,
    required this.isLocalPlayer,
    required this.isHost,
    required this.colorLabel,
    required this.color,
    this.availableColors,
    this.onColorChange,
  });

  static const _colorMap = {
    'red': GameColors.red,
    'green': GameColors.green,
    'yellow': GameColors.yellow,
    'blue': GameColors.blue,
  };

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          // Color picker for the local player
          if (isLocalPlayer && availableColors != null && onColorChange != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Change color:',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(width: 8),
                ...availableColors!.map((c) {
                  final isSelected = c == player.color;
                  final col = _colorMap[c] ?? GameColors.red;
                  return GestureDetector(
                    onTap: isSelected ? null : () => onColorChange!(c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 6),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black54 : Colors.transparent,
                          width: isSelected ? 2.5 : 0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: col.withOpacity(0.35),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                  );
                }),
              ],
            ),
          ],
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

// ──────────────────────────────────────────────────────────────────────────────
// AI fill toggle (host-only, shown when there are empty slots)
// ──────────────────────────────────────────────────────────────────────────────

class _AiFillToggle extends StatelessWidget {
  final bool fillWithAi;
  final VoidCallback onToggle;

  const _AiFillToggle({required this.fillWithAi, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: fillWithAi
              ? GameColors.green.withOpacity(0.3)
              : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            fillWithAi ? Icons.smart_toy_outlined : Icons.people_outline,
            color: fillWithAi ? GameColors.green : Colors.grey,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fill empty slots with AI',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: fillWithAi ? Colors.black87 : Colors.grey,
                  ),
                ),
                Text(
                  fillWithAi
                      ? 'AI will play for empty slots'
                      : 'Only joined players will play',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Switch(
            value: fillWithAi,
            onChanged: (_) => onToggle(),
            activeColor: GameColors.green,
          ),
        ],
      ),
    );
  }
}
