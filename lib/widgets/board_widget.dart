import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/path_constants.dart';
import '../providers/game_state.dart';
import '../models/piece_model.dart';

class LudoBoard extends StatelessWidget {
  const LudoBoard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GameState>(context);
    bool isRoyal = state.currentTheme == BoardTheme.royal;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double size = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        
        // If royal, we need some padding for the ornate frame
        // Adjusted board area to avoid frame clipping
        final double boardSize = isRoyal ? size * 0.87 : size;
        final double cellSize = boardSize / 15;

        return Center(
          child: Container(
            width: size,
            height: size,
            decoration: isRoyal ? null : BoxDecoration(
              color: GameColors.background,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: boardSize,
                  height: boardSize,
                  decoration: BoxDecoration(
                    color: isRoyal ? Colors.white : GameColors.background,
                    border: isRoyal ? Border.all(color: Colors.black.withOpacity(0.06), width: 1.0) : null,
                  ),
                  child: Stack(
                    children: [
                      ..._buildGrid(cellSize, isRoyal),
                      ..._buildBases(cellSize, context),
                      _buildHomeCenter(cellSize, isRoyal),
                      ..._buildPieces(cellSize, context),
                    ],
                  ),
                ),
                if (isRoyal) IgnorePointer(child: _RoyalBoardFrame(size: size)),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildGrid(double cellSize, bool isRoyal) {
    List<Widget> grid = [];
    for (int r = 0; r < 15; r++) {
      for (int c = 0; c < 15; c++) {
        if (_isPathCell(r, c)) {
          bool isSafe = _isSafeCell(r, c);
          grid.add(Positioned(
            left: c * cellSize,
            top: r * cellSize,
            child: Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                border: Border.all(color: isRoyal ? Colors.black12 : GameColors.boardStroke.withOpacity(0.3), width: 0.5),
                color: _getCellColor(r, c),
              ),
              child: isSafe ? Center(child: Icon(Icons.star_rounded, size: cellSize * 0.7, color: _isStartCell(r, c) ? Colors.white : (isRoyal ? Colors.grey : GameColors.boardStroke))) : null,
            ),
          ));
        }
      }
    }
    return grid;
  }

  bool _isSafeCell(int r, int c) {
    return _isStartCell(r, c) || 
           (r == 8 && c == 2) || (r == 2 && c == 6) || (r == 6 && c == 12) || (r == 12 && c == 8);
  }

  bool _isStartCell(int r, int c) {
    if (r == 6 && c == 1) return true; // Red Start
    if (r == 1 && c == 8) return true; // Green Start
    if (r == 8 && c == 13) return true; // Yellow Start
    if (r == 13 && c == 6) return true; // Blue Start
    return false;
  }

  bool _isPathCell(int r, int c) {
    if (r < 6 && c < 6) return false;
    if (r < 6 && c > 8) return false;
    if (r > 8 && c < 6) return false;
    if (r > 8 && c > 8) return false;
    if (r >= 6 && r <= 8 && c >= 6 && c <= 8) return false;
    return true;
  }

  Color _getCellColor(int r, int c) {
    if (r == 7 && c >= 1 && c <= 5) return GameColors.redLight.withOpacity(0.8);
    if (r == 6 && c == 1) return GameColors.redLight; 
    
    if (r >= 1 && r <= 5 && c == 7) return GameColors.greenLight.withOpacity(0.8);
    if (r == 1 && c == 8) return GameColors.greenLight;

    if (r == 7 && c >= 9 && c <= 13) return GameColors.yellowLight.withOpacity(0.8);
    if (r == 8 && c == 13) return GameColors.yellowLight;

    if (r >= 9 && r <= 13 && c == 7) return GameColors.blueLight.withOpacity(0.8);
    if (r == 13 && c == 6) return GameColors.blueLight;

    return Colors.transparent;
  }

  List<Widget> _buildBases(double cellSize, BuildContext context) {
    final state = Provider.of<GameState>(context);
    return [
      _BaseWidget(cellSize: cellSize, color: GameColors.red, r: 0, c: 0, type: PlayerType.red, rank: state.winners.indexOf(PlayerType.red) + 1),
      _BaseWidget(cellSize: cellSize, color: GameColors.green, r: 0, c: 9, type: PlayerType.green, rank: state.winners.indexOf(PlayerType.green) + 1),
      _BaseWidget(cellSize: cellSize, color: GameColors.yellow, r: 9, c: 9, type: PlayerType.yellow, rank: state.winners.indexOf(PlayerType.yellow) + 1),
      _BaseWidget(cellSize: cellSize, color: GameColors.blue, r: 9, c: 0, type: PlayerType.blue, rank: state.winners.indexOf(PlayerType.blue) + 1),
    ];
  }

  Widget _buildHomeCenter(double cellSize, bool isRoyal) {
    return Positioned(
      left: 6 * cellSize,
      top: 6 * cellSize,
      child: Container(
        width: cellSize * 3,
        height: cellSize * 3,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: isRoyal ? Colors.black26 : GameColors.boardStroke),
        ),
        child: CustomPaint(
          painter: HomeCenterPainter(),
        ),
      ),
    );
  }

  List<Widget> _buildPieces(double cellSize, BuildContext context) {
    final state = Provider.of<GameState>(context);
    
    // Stacking priority logic: Correct-turn player pieces should be on top
    List<PieceModel> sortedPieces = List.from(state.pieces);
    sortedPieces.sort((a, b) {
      if (a.type == state.currentPlayer && b.type != state.currentPlayer) return 1;
      if (b.type == state.currentPlayer && a.type != state.currentPlayer) return -1;
      return 0;
    });

    return sortedPieces.map((piece) {
      Offset gridPos = _getPieceGridPos(piece);
      return AnimatedPositioned(
        key: ValueKey("${piece.type}_${piece.id}"),
        duration: const Duration(milliseconds: 200),
        left: gridPos.dx * cellSize,
        top: gridPos.dy * cellSize,
        child: PieceWidget(piece: piece, cellSize: cellSize),
      );
    }).toList();
  }

  Offset _getPieceGridPos(PieceModel piece) {
    if (piece.progress == -1) {
      return PathConstants.getBasePositions(piece.type)[piece.id];
    }
    
    // Standard Ludo Path Logic:
    // Path is 51 steps around, then 6 steps in the home path.
    // Index 50 is the last cell before entering home path.
    if (piece.progress >= 51) {
      int homeIdx = piece.progress - 51;
      // Clamp to max home path index (5)
      if (homeIdx > 5) homeIdx = 5;
      return PathConstants.getHomePath(piece.type)[homeIdx];
    }
    
    // Circular path (0 to 50 relative steps)
    // Red starts at 1, goes till index 51. Skipping index 0 (which is the cell behind Red start).
    int startIdx = PathConstants.getStartIdx(piece.type);
    int globalIdx = (startIdx + piece.progress) % 52;
    return PathConstants.fullPath[globalIdx];
  }
}

class _BaseWidget extends StatelessWidget {
  final double cellSize;
  final Color color;
  final int r, c, rank;
  final PlayerType type;

  const _BaseWidget({required this.cellSize, required this.color, required this.r, required this.c, required this.type, required this.rank});

  @override
  Widget build(BuildContext context) {
    bool isRoyal = Provider.of<GameState>(context).currentTheme == BoardTheme.royal;
    
    return Positioned(
      left: c * cellSize,
      top: r * cellSize,
      child: Container(
        width: cellSize * 6,
        height: cellSize * 6,
        decoration: BoxDecoration(
          color: isRoyal ? color.withOpacity(0.4) : color.withOpacity(0.25),
          border: Border.all(
            color: isRoyal ? Colors.black.withOpacity(0.1) : color.withOpacity(0.4), 
            width: isRoyal ? 2 : 1.5
          ),
          gradient: isRoyal ? LinearGradient(
            colors: [color.withOpacity(0.6), color.withOpacity(0.3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          boxShadow: isRoyal ? [
            BoxShadow(color: Colors.black.withOpacity(0.08), offset: const Offset(2, 2), blurRadius: 4),
          ] : null,
        ),
        child: Stack(
          children: [
            if (isRoyal) _RoyalBaseInner(size: cellSize * 6),
            Padding(
              padding: EdgeInsets.all(cellSize * 1.3),
              child: Container(
                decoration: BoxDecoration(
                  color: isRoyal ? Colors.black12 : Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(isRoyal ? 10 : 20),
                  boxShadow: isRoyal ? [] : [
                    BoxShadow(color: color.withOpacity(0.2), blurRadius: 20)
                  ]
                ),
              ),
            ),
            if (rank > 0)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: Text(
                    _getRankText(rank),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoyalBaseInner extends StatelessWidget {
  final double size;
  const _RoyalBaseInner({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _RoyalCornerPainter(),
    );
  }
}

class _RoyalCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    double offset = size.width * 0.15;
    // Top-left
    path.moveTo(0, offset);
    path.lineTo(offset, 0);
    // Top-right
    path.moveTo(size.width - offset, 0);
    path.lineTo(size.width, offset);
    // Bottom-left
    path.moveTo(0, size.height - offset);
    path.lineTo(offset, size.height);
    // Bottom-right
    path.moveTo(size.width - offset, size.height);
    path.lineTo(size.width, size.height - offset);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoyalBoardFrame extends StatelessWidget {
  final double size;
  const _RoyalBoardFrame({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 15))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(0), // Removed radius
        child: Image.asset(
          'assets/board/royal/frame.png',
          width: size,
          height: size,
          fit: BoxFit.fill,
          errorBuilder: (context, error, stackTrace) {
            // Fallback in case asset is missing
            return Container(
              color: const Color(0xFFE0E0E0),
              child: const Center(child: Text("Frame Asset Not Found", style: TextStyle(color: Colors.black54, fontSize: 10))),
            );
          },
        ),
      ),
    );
  }
}

String _getRankText(int rank) {
  switch (rank) {
    case 1: return "1st";
    case 2: return "2nd";
    case 3: return "3rd";
    case 4: return "4th";
    default: return "";
  }
}

class HomeCenterPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    paint.color = GameColors.red;
    var path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height / 2);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);

    paint.color = GameColors.green;
    path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height / 2);
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, paint);

    paint.color = GameColors.yellow;
    path = Path();
    path.moveTo(size.width, 0);
    path.lineTo(size.width / 2, size.height / 2);
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);

    paint.color = GameColors.blue;
    path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width / 2, size.height / 2);
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PieceWidget extends StatefulWidget {
  final PieceModel piece;
  final double cellSize;

  const PieceWidget({super.key, required this.piece, required this.cellSize});

  @override
  State<PieceWidget> createState() => _PieceWidgetState();
}

class _PieceWidgetState extends State<PieceWidget> with SingleTickerProviderStateMixin {
  late AnimationController _hopController;
  late Animation<double> _jumpAnimation;
  late Animation<double> _scaleAnimation;
  int _lastProgress = -1;

  @override
  void initState() {
    super.initState();
    _lastProgress = widget.piece.progress;
    _hopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _jumpAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: -15).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: -15, end: 0).chain(CurveTween(curve: Curves.bounceOut)), weight: 50),
    ]).animate(_hopController);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
    ]).animate(_hopController);
  }

  @override
  void didUpdateWidget(covariant PieceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.piece.progress != _lastProgress) {
      _lastProgress = widget.piece.progress;
      _hopController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _hopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GameState>(context);
    bool isMovable = state.movablePieces.contains(widget.piece);

    bool isRoyal = state.currentTheme == BoardTheme.royal;

    Color pieceColor;
    switch (widget.piece.type) {
      case PlayerType.red: pieceColor = isRoyal ? const Color(0xFFD32F2F) : GameColors.red; break;
      case PlayerType.green: pieceColor = isRoyal ? const Color(0xFF2E7D32) : GameColors.green; break;
      case PlayerType.yellow: pieceColor = isRoyal ? const Color(0xFFFBC02D) : GameColors.yellow; break;
      case PlayerType.blue: pieceColor = isRoyal ? const Color(0xFF1976D2) : GameColors.blue; break;
    }

    return AnimatedBuilder(
      animation: _hopController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _jumpAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: IgnorePointer(
        ignoring: !isMovable,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => state.movePiece(widget.piece),
          child: SizedBox(
            width: widget.cellSize,
            height: widget.cellSize,
            child: Center(
              child: isRoyal 
                ? _RoyalPieceShape(color: pieceColor, size: widget.cellSize, isMovable: isMovable)
                : _ClassicPieceShape(color: pieceColor, size: widget.cellSize, isMovable: isMovable, hopValue: _hopController.value),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassicPieceShape extends StatelessWidget {
  final Color color;
  final double size;
  final bool isMovable;
  final double hopValue;

  const _ClassicPieceShape({required this.color, required this.size, required this.isMovable, required this.hopValue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 0.85,
      height: size * 0.85,
      decoration: BoxDecoration(
        color: color, 
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3 - (hopValue * 0.1)),
            blurRadius: 5 + (hopValue * 10),
            spreadRadius: 1 + (hopValue * 2),
            offset: Offset(0, 3 + (hopValue * 10))
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.08),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2), 
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
            gradient: RadialGradient(
              colors: [Colors.white.withOpacity(0.4), Colors.transparent],
              center: const Alignment(-0.35, -0.35),
              radius: 0.8,
            )
          ),
          child: isMovable ? _BlinkingIndicator(cellSize: size) : null,
        ),
      ),
    );
  }
}

class _RoyalPieceShape extends StatelessWidget {
  final Color color;
  final double size;
  final bool isMovable;

  const _RoyalPieceShape({required this.color, required this.size, required this.isMovable});

  @override
  Widget build(BuildContext context) {
    double scaleFactor = size / 30.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Shadow
        Positioned(
          bottom: 2 * scaleFactor,
          child: Container(
            width: 22 * scaleFactor,
            height: 8 * scaleFactor,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.all(Radius.elliptical(22 * scaleFactor, 8 * scaleFactor)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4 * scaleFactor)],
            ),
          ),
        ),
        // Base
        Positioned(
          bottom: 4 * scaleFactor,
          child: Container(
            width: 20 * scaleFactor,
            height: 6 * scaleFactor,
            decoration: BoxDecoration(
              color: color.withOpacity(0.8),
              borderRadius: BorderRadius.all(Radius.elliptical(20 * scaleFactor, 6 * scaleFactor)),
              border: Border.all(color: Colors.black.withOpacity(0.2), width: 0.5),
            ),
          ),
        ),
        // Body (Pawn shape)
        Positioned(
          bottom: 6 * scaleFactor,
          child: Container(
            width: 14 * scaleFactor,
            height: 12 * scaleFactor,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10 * scaleFactor),
                topRight: Radius.circular(10 * scaleFactor),
                bottomLeft: Radius.circular(4 * scaleFactor),
                bottomRight: Radius.circular(4 * scaleFactor),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), offset: const Offset(1, 1), blurRadius: 1)
              ],
            ),
          ),
        ),
        // Head
        Positioned(
          bottom: 15 * scaleFactor,
          child: Container(
            width: 12 * scaleFactor,
            height: 12 * scaleFactor,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.white.withOpacity(0.4), color, color.withOpacity(0.8)],
                stops: const [0.0, 0.4, 1.0],
                center: const Alignment(-0.3, -0.3),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), offset: const Offset(1, 1), blurRadius: 2)
              ],
            ),
          ),
        ),
        if (isMovable)
          Positioned(
            bottom: 15 * scaleFactor,
            child: SizedBox(
              width: 12 * scaleFactor,
              height: 12 * scaleFactor,
              child: _BlinkingIndicator(cellSize: size),
            ),
          ),
      ],
    );
  }
}

class _BlinkingIndicator extends StatefulWidget {
  final double cellSize;
  const _BlinkingIndicator({required this.cellSize});

  @override
  _BlinkingIndicatorState createState() => _BlinkingIndicatorState();
}

class _BlinkingIndicatorState extends State<_BlinkingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 1000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(_controller.value), width: 2),
          ),
        );
      },
    );
  }
}
