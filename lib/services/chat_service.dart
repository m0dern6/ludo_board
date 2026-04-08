import 'package:firebase_database/firebase_database.dart';
import '../models/online_models.dart';

/// Chat service with:
/// - 100 character message limit
/// - Rate limit: 3 messages in 5 seconds → 60-second ban + 10-second per-message cooldown
/// - Basic bad-word filter
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // Per-session rate-limit tracking (uid → state)
  final Map<String, _RateLimit> _limits = {};

  static const int maxLength = 100;
  static const int _windowMs = 5000; // 5 seconds
  static const int _maxInWindow = 3; // messages allowed before ban
  static const int _banDurationMs = 60000; // 60 seconds
  static const int _cooldownMs = 10000; // 10 seconds after ban lifts

  // ──────────────────────────────────────────────
  // Bad word list (extend as needed)
  // ──────────────────────────────────────────────
  static const List<String> _badWords = [
    'fuck', 'shit', 'ass', 'bitch', 'cunt', 'damn', 'bastard',
    'dick', 'cock', 'pussy', 'nigger', 'faggot', 'retard',
    'idiot', 'moron', 'stupid', 'kill yourself', 'kys',
  ];

  // ──────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────

  /// Send a message to the given room.
  /// Returns an error string or null on success.
  Future<String?> sendMessage({
    required String roomCode,
    required String uid,
    required String name,
    required int avatar,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Message cannot be empty.';
    if (trimmed.length > maxLength) {
      return 'Message is too long (max $maxLength characters).';
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    final limit = _limits.putIfAbsent(uid, () => _RateLimit());

    // Check if banned
    if (limit.bannedUntil != null && now < limit.bannedUntil!) {
      final remaining =
          ((limit.bannedUntil! - now) / 1000).ceil();
      return 'You are muted for $remaining more second(s).';
    }

    // After ban lifted, enforce per-message cooldown
    if (limit.bannedUntil != null && now >= limit.bannedUntil!) {
      if (limit.lastMessageAt != null &&
          now - limit.lastMessageAt! < _cooldownMs) {
        final remaining =
            ((_cooldownMs - (now - limit.lastMessageAt!)) / 1000).ceil();
        return 'Please wait $remaining more second(s) before sending.';
      }
    }

    // Slide the window
    limit.timestamps.removeWhere((t) => now - t > _windowMs);
    if (limit.timestamps.length >= _maxInWindow) {
      limit.bannedUntil = now + _banDurationMs;
      limit.timestamps.clear();
      return 'You sent too many messages. Muted for 60 seconds.';
    }

    // Bad word filter
    final filtered = _filterText(trimmed);

    limit.timestamps.add(now);
    limit.lastMessageAt = now;

    await _db.ref('rooms/$roomCode/chat').push().set({
      'uid': uid,
      'name': name,
      'avatar': avatar,
      'text': filtered,
      'timestamp': ServerValue.timestamp,
    });
    return null;
  }

  Stream<DatabaseEvent> chatStream(String roomCode) =>
      _db.ref('rooms/$roomCode/chat').orderByChild('timestamp').onValue;

  List<ChatMessage> parseChatMessages(dynamic rawValue) {
    if (rawValue == null) return [];
    final map = rawValue as Map<dynamic, dynamic>;
    final msgs = map.entries.map((e) {
      final v = e.value as Map<dynamic, dynamic>;
      return ChatMessage.fromMap(v);
    }).toList();
    msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return msgs;
  }

  // ──────────────────────────────────────────────
  // Bad-word filter
  // ──────────────────────────────────────────────

  String _filterText(String text) {
    String result = text.toLowerCase();
    for (final word in _badWords) {
      result = result.replaceAll(
        RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false),
        '*' * word.length,
      );
    }
    return result;
  }

  /// Returns remaining mute seconds for [uid], or 0 if not muted.
  int mutedSecondsRemaining(String uid) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final limit = _limits[uid];
    if (limit?.bannedUntil != null && now < limit!.bannedUntil!) {
      return ((limit.bannedUntil! - now) / 1000).ceil();
    }
    return 0;
  }
}

class _RateLimit {
  final List<int> timestamps = [];
  int? bannedUntil;
  int? lastMessageAt;
}
