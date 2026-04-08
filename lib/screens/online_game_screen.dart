import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../models/online_models.dart';
import '../models/piece_model.dart';
import '../providers/game_state.dart';
import '../providers/online_game_state.dart';
import '../services/chat_service.dart';
import '../services/online_service.dart';
import '../services/audio_manager.dart';
import '../widgets/board_widget.dart';
import '../widgets/dice_widget.dart';

/// Online game screen — wraps the existing [LudoBoard] in an
/// [OnlineGameState] provider so all board rendering reuses the existing code.
class OnlineGameScreen extends StatefulWidget {
  final String roomCode;
  final String localUid;
  final OnlineRoom initialRoom;

  const OnlineGameScreen({
    super.key,
    required this.roomCode,
    required this.localUid,
    required this.initialRoom,
  });

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen> {
  late final OnlineGameState _gameState;
  bool _chatOpen = false;

  @override
  void initState() {
    super.initState();
    final room = widget.initialRoom;
    final isHost = room.hostUid == widget.localUid;

    // Determine local player color
    final localPlayer = room.players[widget.localUid];
    final localColor = PlayerType.values.firstWhere(
      (t) => t.name == (localPlayer?.color ?? 'red'),
      orElse: () => PlayerType.red,
    );

    _gameState = OnlineGameState(
      roomCode: widget.roomCode,
      localUid: widget.localUid,
      localColor: localColor,
      isHost: isHost,
      roomPlayers: room.players,
    );
    _gameState.initFromRoom(room.players, room.rules);

    AudioManager().stopBgm();
  }

  @override
  void dispose() {
    _gameState.quitMatch();
    AudioManager().stopAllSfx();
    AudioManager().startBgm();
    super.dispose();
  }

  void _toggleChat() => setState(() => _chatOpen = !_chatOpen);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameState>.value(
      value: _gameState,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              _OnlineHeader(
                roomCode: widget.roomCode,
                onChatToggle: _toggleChat,
                chatOpen: _chatOpen,
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _OnlineCornerDice(
                          player: PlayerType.red,
                          textAtTop: true,
                          localColor: _gameState.localColor,
                        ),
                        _OnlineCornerDice(
                          player: PlayerType.green,
                          textAtTop: true,
                          localColor: _gameState.localColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const LudoBoard(),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _OnlineCornerDice(
                          player: PlayerType.blue,
                          textAtTop: false,
                          localColor: _gameState.localColor,
                        ),
                        _OnlineCornerDice(
                          player: PlayerType.yellow,
                          textAtTop: false,
                          localColor: _gameState.localColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _OnlineQuitButton(
                roomCode: widget.roomCode,
                localUid: widget.localUid,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // Chat overlay
        bottomSheet: _chatOpen
            ? _ChatPanel(
                roomCode: widget.roomCode,
                localUid: widget.localUid,
                localName: widget.initialRoom.players[widget.localUid]?.name ??
                    'Player',
                localAvatar:
                    widget.initialRoom.players[widget.localUid]?.avatar ?? 0,
              )
            : null,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Header
// ──────────────────────────────────────────────────────────────────────────────

class _OnlineHeader extends StatelessWidget {
  final String roomCode;
  final VoidCallback onChatToggle;
  final bool chatOpen;

  const _OnlineHeader({
    required this.roomCode,
    required this.onChatToggle,
    required this.chatOpen,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GameState>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            'ONLINE',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              color: GameColors.boardStroke.withOpacity(0.8),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: GameColors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              roomCode,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: GameColors.blue,
                letterSpacing: 3,
              ),
            ),
          ),
          const Spacer(),
          if (state.status == GameStatus.finished)
            const SizedBox()
          else
            IconButton(
              onPressed: onChatToggle,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: chatOpen
                      ? GameColors.blue.withOpacity(0.15)
                      : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  chatOpen ? Icons.chat : Icons.chat_bubble_outline,
                  color: chatOpen ? GameColors.blue : Colors.black87,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Online-aware dice widget (only tappable for local player's turn)
// ──────────────────────────────────────────────────────────────────────────────

class _OnlineCornerDice extends StatelessWidget {
  final PlayerType player;
  final bool textAtTop;
  final PlayerType localColor;

  const _OnlineCornerDice({
    required this.player,
    required this.textAtTop,
    required this.localColor,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GameState>(context);
    final bool isMyTurn = state.currentPlayer == player;

    // Hide if not current player's turn
    return Opacity(
      opacity: isMyTurn ? 1.0 : 0.0,
      child: IgnorePointer(
        // Only interactive when it's LOCAL player's turn (or AI handled by host)
        ignoring: !isMyTurn ||
            (player != localColor &&
                state.playerModes[player] != PlayerMode.ai),
        child: CornerDice(player: player, textAtTop: textAtTop),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Quit button
// ──────────────────────────────────────────────────────────────────────────────

class _OnlineQuitButton extends StatelessWidget {
  final String roomCode;
  final String localUid;

  const _OnlineQuitButton({
    required this.roomCode,
    required this.localUid,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GameState>(context);
    if (state.status == GameStatus.finished) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: ElevatedButton(
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: GameColors.red,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: const BorderSide(color: GameColors.red, width: 2),
            ),
          ),
          child: const Text(
            'BACK TO MENU',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ),
      );
    }
    return TextButton.icon(
      onPressed: () => _confirmQuit(context),
      icon: const Icon(Icons.arrow_back, color: Colors.grey),
      label: const Text(
        'QUIT MATCH',
        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _confirmQuit(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Center(
          child: Text(
            'QUIT MATCH?',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ),
        content: const Text(
          'You will leave the online game. This cannot be undone.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('STAY',
                      style: TextStyle(
                          color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await OnlineService()
                        .leaveRoom(roomCode, localUid);
                    if (context.mounted) {
                      Navigator.of(context)
                          .popUntil((route) => route.isFirst);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameColors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('QUIT',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Chat panel
// ──────────────────────────────────────────────────────────────────────────────

class _ChatPanel extends StatefulWidget {
  final String roomCode;
  final String localUid;
  final String localName;
  final int localAvatar;

  const _ChatPanel({
    required this.roomCode,
    required this.localUid,
    required this.localName,
    required this.localAvatar,
  });

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final _chat = ChatService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  String? _sendError;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
      _sendError = null;
    });

    final err = await _chat.sendMessage(
      roomCode: widget.roomCode,
      uid: widget.localUid,
      name: widget.localName,
      avatar: widget.localAvatar,
      text: text,
    );

    if (!mounted) return;
    if (err != null) {
      setState(() {
        _sendError = err;
        _isSending = false;
      });
    } else {
      _textController.clear();
      setState(() => _isSending = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'CHAT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                color: Colors.grey,
              ),
            ),
          ),
          const Divider(height: 1),

          // Messages
          Expanded(
            child: StreamBuilder(
              stream: _chat.chatStream(widget.roomCode),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: Text('No messages yet.',
                          style: TextStyle(color: Colors.grey)));
                }
                final msgs = _chat.parseChatMessages(
                    snapshot.data!.snapshot.value);
                if (msgs.isEmpty) {
                  return const Center(
                      child: Text('No messages yet.',
                          style: TextStyle(color: Colors.grey, fontSize: 13)));
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final msg = msgs[i];
                    final isMe = msg.uid == widget.localUid;
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.7,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? GameColors.blue.withOpacity(0.12)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: Radius.circular(isMe ? 14 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 14),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  avatarEmoji(msg.avatar),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  msg.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isMe
                                        ? GameColors.blue
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              msg.text,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Error line
          if (_sendError != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Text(
                _sendError!,
                style:
                    const TextStyle(color: Colors.red, fontSize: 11),
              ),
            ),

          // Input row
          Padding(
            padding:
                const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    maxLength: ChatService.maxLength,
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Say something…',
                      hintStyle: const TextStyle(fontSize: 13),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isSending ? null : _send,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: GameColors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
