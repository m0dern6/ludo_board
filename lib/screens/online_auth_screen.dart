import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../models/online_models.dart';
import '../services/auth_service.dart';
import 'online_lobby_screen.dart';

/// First screen in the online flow.
///
/// • If not signed in → show Google Sign-In button.
/// • If signed in but no display name saved → show name + avatar picker.
/// • If fully set up → navigate directly to the lobby.
class OnlineAuthScreen extends StatefulWidget {
  const OnlineAuthScreen({super.key});

  @override
  State<OnlineAuthScreen> createState() => _OnlineAuthScreenState();
}

class _OnlineAuthScreenState extends State<OnlineAuthScreen> {
  final _auth = AuthService();
  bool _isLoading = false;
  String? _error;

  // Profile-setup step
  bool _showProfileSetup = false;
  final _nameController = TextEditingController();
  int _selectedAvatar = 0;

  @override
  void initState() {
    super.initState();
    if (_auth.isSignedIn) {
      final user = _auth.currentUser!;
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        _nameController.text = user.displayName!;
        // Fully set up — go straight to lobby after frame
        WidgetsBinding.instance.addPostFrameCallback((_) => _toLobby());
      } else {
        _showProfileSetup = true;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final user = await _auth.signInWithGoogle();
    if (!mounted) return;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _error = 'Sign-in cancelled.';
      });
      return;
    }
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      _toLobby();
    } else {
      setState(() {
        _isLoading = false;
        _showProfileSetup = true;
      });
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name.');
      return;
    }
    if (name.length > 20) {
      setState(() => _error = 'Name must be 20 characters or fewer.');
      return;
    }
    setState(() => _isLoading = true);
    await _auth.updateDisplayName(name);
    if (!mounted) return;
    _toLobby();
  }

  void _toLobby() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OnlineLobbyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      appBar: AppBar(
        title: const Text('ONLINE MODE'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: _showProfileSetup
            ? _ProfileSetup(
                nameController: _nameController,
                selectedAvatar: _selectedAvatar,
                isLoading: _isLoading,
                error: _error,
                onAvatarSelected: (i) => setState(() => _selectedAvatar = i),
                onSave: _saveProfile,
              )
            : _SignInView(
                isLoading: _isLoading,
                error: _error,
                onSignIn: _signInWithGoogle,
              ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Sign-In view
// ──────────────────────────────────────────────────────────────────────────────

class _SignInView extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final VoidCallback onSignIn;

  const _SignInView({
    required this.isLoading,
    required this.error,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PLAY ONLINE',
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: GameColors.boardStroke,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sign in with Google to create or join online rooms.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            if (isLoading)
              const CircularProgressIndicator(color: GameColors.red)
            else
              ElevatedButton.icon(
                onPressed: onSignIn,
                icon: Image.network(
                  'https://developers.google.com/identity/images/g-logo.png',
                  width: 20,
                  height: 20,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.login, size: 20),
                ),
                label: const Text('Sign in with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  elevation: 2,
                ),
              ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Profile setup view
// ──────────────────────────────────────────────────────────────────────────────

class _ProfileSetup extends StatelessWidget {
  final TextEditingController nameController;
  final int selectedAvatar;
  final bool isLoading;
  final String? error;
  final ValueChanged<int> onAvatarSelected;
  final VoidCallback onSave;

  const _ProfileSetup({
    required this.nameController,
    required this.selectedAvatar,
    required this.isLoading,
    required this.error,
    required this.onAvatarSelected,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SET UP PROFILE',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a display name and avatar that other players will see.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 32),

          // Name field
          const Text(
            'YOUR NAME',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            maxLength: 20,
            decoration: InputDecoration(
              hintText: 'e.g. Ludo King',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Avatar picker
          const Text(
            'CHOOSE AVATAR',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: kAvatarEmojis.length,
            itemBuilder: (_, i) {
              final selected = i == selectedAvatar;
              return GestureDetector(
                onTap: () => onAvatarSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected
                        ? GameColors.red.withOpacity(0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          selected ? GameColors.red : Colors.grey.shade200,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(kAvatarEmojis[i], style: const TextStyle(fontSize: 32)),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          if (error != null) ...[
            Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
          ],

          ElevatedButton(
            onPressed: isLoading ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: GameColors.red,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'CONTINUE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
