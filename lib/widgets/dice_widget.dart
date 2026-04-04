import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../providers/game_state.dart';
import '../models/piece_model.dart';
import '../constants/colors.dart';

class CornerDice extends StatelessWidget {
  final PlayerType player;
  final bool textAtTop;

  const CornerDice({super.key, required this.player, this.textAtTop = true});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GameState>(context);
    final bool isMyTurn = state.currentPlayer == player;
    final bool isBot = state.playerModes[player] == PlayerMode.ai;

    // We use Opacity and IgnorePointer to maintain the board's centering
    // instead of shrinking the widget footprint.
    return Opacity(
      opacity: isMyTurn ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !isMyTurn,
        child: _buildDiceBody(context, state, isBot),
      ),
    );
  }

  Widget _buildDiceBody(BuildContext context, GameState state, bool isBot) {

    Color diceColor;
    String labelText;
    switch (player) {
      case PlayerType.red: diceColor = GameColors.red; break;
      case PlayerType.green: diceColor = GameColors.green; break;
      case PlayerType.yellow: diceColor = GameColors.yellow; break;
      case PlayerType.blue: diceColor = GameColors.blue; break;
    }

    if (isBot) {
      labelText = "AI THINKING...";
    } else {
      labelText = state.status == GameStatus.rolling ? "TAP TO ROLL" : "SELECT PIECE";
    }

    final diceSquare = Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: diceColor.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: diceColor.withOpacity(0.5), width: 2),
      ),
      child: _ActiveDiceInternal(state: state, color: diceColor, isBot: isBot),
    );

    final textWidget = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        labelText,
        style: TextStyle(
          color: diceColor,
          fontWeight: FontWeight.bold,
          fontSize: 10,
          letterSpacing: 1,
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (textAtTop) textWidget,
        diceSquare,
        if (!textAtTop) textWidget,
      ],
    );
  }
}

class _ActiveDiceInternal extends StatefulWidget {
  final GameState state;
  final Color color;
  final bool isBot;

  const _ActiveDiceInternal({required this.state, required this.color, required this.isBot});

  @override
  __ActiveDiceInternalState createState() => __ActiveDiceInternalState();
}

class __ActiveDiceInternalState extends State<_ActiveDiceInternal> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    if (widget.state.isDiceRolling) _controller.repeat();
  }

  @override
  void didUpdateWidget(_ActiveDiceInternal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.isDiceRolling && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.state.isDiceRolling && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: widget.isBot,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (widget.state.status == GameStatus.rolling && !widget.state.isDiceRolling) {
            widget.state.rollDice();
          }
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: _controller.value * 2 * math.pi,
              child: Center(
                child: widget.state.isDiceRolling
                  ? Icon(Icons.casino, size: 40, color: widget.color)
                  : _DiceFace(value: widget.state.diceValue, color: widget.color),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DiceFace extends StatelessWidget {
  final int value;
  final Color color;

  const _DiceFace({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    if (value == 0) {
      return Text(
        "¿", 
        style: TextStyle(
          fontSize: 40, 
          fontWeight: FontWeight.bold, 
          color: color.withOpacity(0.8),
        ),
      );
    }

    return CustomPaint(
      size: const Size(45, 45),
      painter: DicePainter(value: value, color: color),
    );
  }
}

class DicePainter extends CustomPainter {
  final int value;
  final Color color;

  DicePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final double r = size.width * 0.12;
    final double center = size.width / 2;
    final double left = size.width * 0.25;
    final double right = size.width * 0.75;
    final double top = size.height * 0.25;
    final double bottom = size.height * 0.75;

    void drawDot(double x, double y) {
      canvas.drawCircle(Offset(x, y), r, paint);
    }

    if (value == 1 || value == 3 || value == 5) drawDot(center, center);
    if (value >= 2) {
      drawDot(left, top);
      drawDot(right, bottom);
    }
    if (value >= 4) {
      drawDot(right, top);
      drawDot(left, bottom);
    }
    if (value == 6) {
      drawDot(left, center);
      drawDot(right, center);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
