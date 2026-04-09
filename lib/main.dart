import 'dart:math' as math;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants/colors.dart';
import 'providers/game_state.dart';
import 'models/piece_model.dart';
import 'widgets/board_widget.dart';
import 'widgets/dice_widget.dart';
import 'services/audio_manager.dart';
import 'screens/online_auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await AudioManager().init();
  runApp(
    ChangeNotifierProvider(create: (_) => GameState(), child: const LudoApp()),
  );
}

class LudoApp extends StatelessWidget {
  const LudoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ludo Board',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.outfitTextTheme(),
        scaffoldBackgroundColor: GameColors.background,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Freeform Gradient Background (Four colors)
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.5, -0.5),
                radius: 1.5,
                colors: [
                  GameColors.red.withOpacity(0.05),
                  GameColors.green.withOpacity(0.05),
                  GameColors.yellow.withOpacity(0.05),
                  GameColors.blue.withOpacity(0.05),
                  Colors.white,
                ],
                stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
            ),
          ),
          // 2. Scattered Floating Pieces
          ...List.generate(12, (index) {
            final random = math.Random(index);
            final type = PlayerType.values[index % 4];
            final pieceAsset = 'assets/icon/${type.name}_piece.png';

            // Random positions around the screen
            final double left =
                random.nextDouble() * MediaQuery.of(context).size.width;
            final double top =
                random.nextDouble() * MediaQuery.of(context).size.height;
            final double scale = 0.5 + random.nextDouble() * 0.5;
            final double rotation = random.nextDouble() * 2 * math.pi;

            return Positioned(
              left: left,
              top: top,
              child: Transform.rotate(
                angle: rotation,
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: 0.15,
                    child: Image.asset(pieceAsset, width: 60),
                  ),
                ),
              ),
            );
          }),
          // 3. Center Splash Icon
          Center(
            child: ScaleTransition(
              scale: _animation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon with shadow
                  Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // Shadow
                      Positioned(
                        bottom: -40,
                        child: Container(
                          width: 80,
                          height: 20,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Main Icon
                      Image.asset(
                        'assets/icon/splash_icon.png',
                        width: 180,
                        errorBuilder: (_, __, ___) => Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: GameColors.red,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Icon(
                            Icons.casino,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
                  SizedBox(
                    width: 320, // Baseline width for the text block
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.fitWidth,
                          child: Text(
                            "Ludo Board",
                            style: GoogleFonts.greatVibes(
                              fontSize: 120, // Base size before fitting
                              height: 0.8,
                              color: GameColors.boardStroke.withOpacity(0.9),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FittedBox(
                          fit: BoxFit.fitWidth,
                          child: Text(
                            "THE CLASSIC GAME, BEAUTIFULLY REIMAGINED",
                            style: GoogleFonts.montserrat(
                              fontSize: 20, // Base size before fitting
                              fontWeight: FontWeight.w600,
                              height: 1.0,
                              color: GameColors.boardStroke.withOpacity(0.9),
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AudioManager().startBgm();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      AudioManager().pauseBgm();
    } else if (state == AppLifecycleState.resumed) {
      AudioManager().resumeBgm();
    }
  }

  int _currentIndex = 0;

  final List<Widget> _screens = [const HomeScreen(), const SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: _AnimatedBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _AnimatedBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _AnimatedBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Indicator Pill
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            left: currentIndex == 0
                ? 0
                : MediaQuery.of(context).size.width / 2 - 24,
            width: (MediaQuery.of(context).size.width - 48) / 2,
            height: 70,
            child: Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: GameColors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          // Buttons
          Row(
            children: [
              _NavItem(
                isSelected: currentIndex == 0,
                icon: currentIndex == 0 ? Icons.home : Icons.home_outlined,
                label: "Home",
                onTap: () => onTap(0),
              ),
              _NavItem(
                isSelected: currentIndex == 1,
                icon: currentIndex == 1
                    ? Icons.settings
                    : Icons.settings_outlined,
                label: "Settings",
                onTap: () => onTap(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final bool isSelected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.isSelected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          AudioManager().playClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          scale: isSelected ? 1.2 : 1.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? GameColors.red : Colors.grey.shade400,
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? GameColors.red : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text(
                "LUDO\nBOARD",
                style: GoogleFonts.outfit(
                  fontSize: 48,
                  height: 0.9,
                  fontWeight: FontWeight.w900,
                  color: GameColors.boardStroke.withOpacity(0.8),
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 50),
              const SizedBox(height: 30),
              _MenuButton(
                title: "VS AI",
                icon: Icons.psychology,
                color: GameColors.red,
                onTap: () => _startConfig(context, "ai"),
              ),
              const SizedBox(height: 16),
              _MenuButton(
                title: "MULTIPLAYER",
                icon: Icons.people,
                color: GameColors.green,
                onTap: () => _startConfig(context, "multiplayer"),
              ),
              const SizedBox(height: 16),
              _MenuButton(
                title: "ONLINE",
                icon: Icons.public,
                color: GameColors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OnlineAuthScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startConfig(BuildContext context, String mode) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ConfigScreen(mode: mode)),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLocked;

  const _MenuButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        AudioManager().playClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            if (isLocked)
              Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

class ConfigScreen extends StatefulWidget {
  final String mode;
  const ConfigScreen({super.key, required this.mode});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  PlayerType _selectedColor = PlayerType.red;
  Map<PlayerType, PlayerMode> _playerModes = {
    PlayerType.red: PlayerMode.human,
    PlayerType.green: PlayerMode.human,
    PlayerType.yellow: PlayerMode.human,
    PlayerType.blue: PlayerMode.human,
  };
  @override
  void initState() {
    super.initState();
    if (widget.mode == "ai") {
      _playerModes = {
        PlayerType.red: PlayerMode.human,
        PlayerType.green: PlayerMode.ai,
        PlayerType.yellow: PlayerMode.ai,
        PlayerType.blue: PlayerMode.ai,
      };
    } else {
      _playerModes = {
        PlayerType.red: PlayerMode.human,
        PlayerType.green: PlayerMode.human,
        PlayerType.yellow: PlayerMode.human,
        PlayerType.blue: PlayerMode.human,
      };
    }
  }

  void _toggleRole(PlayerType type) {
    if (widget.mode == "ai") return;
    setState(() {
      _playerModes[type] = (_playerModes[type] == PlayerMode.human)
          ? PlayerMode.ai
          : PlayerMode.human;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isAiMode = widget.mode == "ai";

    return Scaffold(
      appBar: AppBar(
        title: Text(isAiMode ? "VS AI" : "MULTIPLAYER"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAiMode) ...[
              const Text(
                "CHOOSE YOUR COLOR",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                "Select the color you want to play as. The AI will control all other players.",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: PlayerType.values.map((type) {
                  Color c = _getColor(type);
                  return GestureDetector(
                    onTap: () {
                      AudioManager().playClick();
                      setState(() {
                        _selectedColor = type;
                        for (var t in PlayerType.values) {
                          _playerModes[t] = (t == type)
                              ? PlayerMode.human
                              : PlayerMode.ai;
                        }
                      });
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedColor == type
                              ? Colors.black
                              : Colors.transparent,
                          width: 4,
                        ),
                      ),
                      child: _selectedColor == type
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),
              const Text(
                "OTHERS WILL BE AI PLAYERS",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ] else ...[
              const Text(
                "PLAYER ASSIGNMENT",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                "Tap to change to AI",
                style: TextStyle(
                  color: GameColors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.1,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: PlayerType.values.map((type) {
                    bool isAi = _playerModes[type] == PlayerMode.ai;
                    Color pColor = _getColor(type);

                    return GestureDetector(
                      onTap: () {
                        AudioManager().playClick();
                        _toggleRole(type);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isAi ? Colors.grey.shade900 : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isAi ? pColor : pColor.withOpacity(0.1),
                            width: isAi ? 3 : 2,
                          ),
                          boxShadow: isAi
                              ? [
                                  BoxShadow(
                                    color: pColor.withOpacity(0.3),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                  ),
                                ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isAi
                                    ? pColor.withOpacity(0.2)
                                    : pColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isAi ? Icons.smart_toy : Icons.person,
                                color: isAi ? pColor : Colors.grey.shade400,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              type.name.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: isAi ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isAi ? "AI ENABLED" : "HUMAN",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isAi ? pColor : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                AudioManager().playClick();
                final state = Provider.of<GameState>(context, listen: false);
                state.setupGame(modes: _playerModes, gameRules: state.rules);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GameScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60),
                backgroundColor: GameColors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "START MATCH",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColor(PlayerType type) {
    switch (type) {
      case PlayerType.red:
        return GameColors.red;
      case PlayerType.green:
        return GameColors.green;
      case PlayerType.yellow:
        return GameColors.yellow;
      case PlayerType.blue:
        return GameColors.blue;
    }
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GameState>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("SETTINGS"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _RuleTile(
            title: "App Music",
            subtitle: "Enable/Disable background music",
            value: state.musicEnabled,
            onChanged: (v) => state.toggleMusic(),
          ),
          _RuleTile(
            title: "Game Sounds",
            subtitle: "Dice, Move, and Capture sounds",
            value: state.sfxEnabled,
            onChanged: (v) => state.toggleSfx(),
          ),
          const Divider(height: 40),
          _RuleTile(
            title: "Re-dice on 1",
            subtitle: "Rolling 1 gives an extra turn",
            value: state.rules.rediceOnOne,
            onChanged: (v) {
              state.rules.rediceOnOne = v;
              state.updateRules(state.rules);
            },
          ),
          _RuleTile(
            title: "Must Capture to Finish",
            subtitle: "Must kill an opponent to enter home path",
            value: state.rules.mustKillToEnterHome,
            onChanged: (v) {
              state.rules.mustKillToEnterHome = v;
              state.updateRules(state.rules);
            },
          ),
          _RuleTile(
            title: "Quick Mode",
            subtitle: "Only 2 pieces needed to reach home",
            value: state.rules.quickMode,
            onChanged: (v) {
              state.rules.quickMode = v;
              state.updateRules(state.rules);
            },
          ),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final Function(bool) onChanged;

  const _RuleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        activeColor: GameColors.red,
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameState _gameState;

  @override
  void initState() {
    super.initState();
    _gameState = Provider.of<GameState>(context, listen: false);
    // Stop BGM when match starts
    AudioManager().stopBgm();
  }

  @override
  void dispose() {
    // CRITICAL: Kill all AI background activity before anything else
    _gameState.quitMatch();
    // Clean up all SFX and Resume BGM when exiting match
    AudioManager().stopAllSfx();
    AudioManager().startBgm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _HeaderSection(),
            const Spacer(),
            // Board and Dice Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CornerDice(player: PlayerType.red, textAtTop: true),
                      CornerDice(player: PlayerType.green, textAtTop: true),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const LudoBoard(),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CornerDice(player: PlayerType.blue, textAtTop: false),
                      CornerDice(player: PlayerType.yellow, textAtTop: false),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            _ResetButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ResetButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GameState>(context);
    if (state.status != GameStatus.finished) {
      return TextButton.icon(
        onPressed: () {
          AudioManager().playClick();
          _confirmQuit(context);
        },
        icon: const Icon(Icons.arrow_back, color: Colors.grey),
        label: const Text(
          "QUIT MATCH",
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: ElevatedButton(
        onPressed: () {
          AudioManager().playClick();
          state.resetGame();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: GameColors.red,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          side: BorderSide(color: GameColors.red, width: 2),
        ),
        child: const Center(
          child: Text(
            "START OVER",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  void _confirmQuit(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: Center(
          child: Text(
            "QUIT MATCH?",
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
        content: const Text(
          "Are you sure you want to end this game? Your progress will be lost.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    AudioManager().playClick();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "STAY",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    AudioManager().playClick();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameColors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "QUIT",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "LUDO BOARD",
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: GameColors.boardStroke.withOpacity(0.8),
                  letterSpacing: 4,
                ),
              ),
              Container(
                width: 30,
                height: 3,
                decoration: BoxDecoration(
                  color: GameColors.boardStroke.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              AudioManager().playClick();
              _showPauseMenu(context);
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(Icons.pause, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _showPauseMenu(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const _PauseDialog(),
    );
  }
}

class _PauseDialog extends StatelessWidget {
  const _PauseDialog();

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<GameState>(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "GAME PAUSED",
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(height: 12),
              // Audio Options
              _PauseOption(
                icon: state.musicEnabled ? Icons.music_note : Icons.music_off,
                title: "Music",
                value: state.musicEnabled,
                onToggle: () => state.toggleMusic(),
              ),
              _PauseOption(
                icon: state.sfxEnabled ? Icons.volume_up : Icons.volume_off,
                title: "SFX",
                value: state.sfxEnabled,
                onToggle: () => state.toggleSfx(),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  AudioManager().playClick();
                  Navigator.pop(context);
                },
                child: Text(
                  "RESUME",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    color: GameColors.green,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  AudioManager().playClick();
                  Navigator.pop(context);
                  _confirmQuit(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameColors.red.withOpacity(0.1),
                  foregroundColor: GameColors.red,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "QUIT MATCH",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmQuit(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: Center(
          child: Text(
            "QUIT MATCH?",
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
        content: const Text(
          "Are you sure you want to end this game? Your progress will be lost.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    AudioManager().playClick();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "STAY",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    AudioManager().playClick();
                    Provider.of<GameState>(context, listen: false).quitMatch();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameColors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "QUIT",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PauseOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final VoidCallback onToggle;

  const _PauseOption({
    required this.icon,
    required this.title,
    required this.value,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: Switch(
        value: value,
        onChanged: (v) => onToggle(),
        activeColor: GameColors.red,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}
