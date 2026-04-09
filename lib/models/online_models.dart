import 'piece_model.dart';

class OnlinePlayer {
  final String uid;
  final String name;
  final int avatar; // 0-7, maps to an emoji avatar
  final String color; // red/green/yellow/blue
  final bool isAi;
  final bool isOnline;

  OnlinePlayer({
    required this.uid,
    required this.name,
    required this.avatar,
    required this.color,
    this.isAi = false,
    this.isOnline = true,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'name': name,
    'avatar': avatar,
    'color': color,
    'isAi': isAi,
    'isOnline': isOnline,
  };

  factory OnlinePlayer.fromMap(String uid, Map<dynamic, dynamic> map) =>
      OnlinePlayer(
        uid: uid,
        name: map['name'] as String? ?? 'Player',
        avatar: (map['avatar'] as num?)?.toInt() ?? 0,
        color: map['color'] as String? ?? 'red',
        isAi: map['isAi'] as bool? ?? false,
        isOnline: map['isOnline'] as bool? ?? true,
      );
}

class OnlineRoom {
  final String code;
  final String hostUid;
  final String status; // waiting / playing / finished
  final Map<String, OnlinePlayer> players;
  final GameRules rules;
  final int createdAt;

  OnlineRoom({
    required this.code,
    required this.hostUid,
    required this.status,
    required this.players,
    required this.rules,
    required this.createdAt,
  });

  factory OnlineRoom.fromMap(String code, Map<dynamic, dynamic> map) {
    final rawPlayers = map['players'] as Map<dynamic, dynamic>? ?? {};
    final players = rawPlayers.map<String, OnlinePlayer>((k, v) {
      final uid = k.toString();
      return MapEntry(
        uid,
        OnlinePlayer.fromMap(uid, v as Map<dynamic, dynamic>),
      );
    });
    return OnlineRoom(
      code: code,
      hostUid: map['host'] as String? ?? '',
      status: map['status'] as String? ?? 'waiting',
      players: players,
      rules: GameRules.fromJson(
        (map['rules'] as Map<dynamic, dynamic>?)?.cast<String, dynamic>() ?? {},
      ),
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChatMessage {
  final String id;
  final String uid;
  final String name;
  final int avatar;
  final String text;
  final int timestamp;

  ChatMessage({
    this.id = '',
    required this.uid,
    required this.name,
    required this.avatar,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromMap(Map<dynamic, dynamic> map, {String id = ''}) =>
      ChatMessage(
        id: id,
        uid: map['uid'] as String? ?? '',
        name: map['name'] as String? ?? 'Player',
        avatar: (map['avatar'] as num?)?.toInt() ?? 0,
        text: map['text'] as String? ?? '',
        timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      );
}

// Avatar emojis (8 options)
const List<String> kAvatarEmojis = [
  '🎲',
  '🦁',
  '🐯',
  '🦊',
  '🐸',
  '🐼',
  '🐨',
  '🦋',
];

String avatarEmoji(int index) =>
    kAvatarEmojis[index.clamp(0, kAvatarEmojis.length - 1)];
