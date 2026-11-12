/// A person, as the database gives it (my_profile, profiles): the same fields the site uses.
class Profile {
  Profile({
    required this.id,
    required this.name,
    this.surname,
    this.username,
    this.avatarUrl,
    this.coverUrl,
    this.city,
    this.bio,
    this.hue = 200,
    this.coins = 0,
    this.onboarded = false,
    this.verified = false,
    this.lastSeen,
  });

  final String id;
  final String name;
  final String? surname, username, avatarUrl, coverUrl, city, bio;
  final int hue;
  final int coins;
  final bool onboarded, verified;
  final DateTime? lastSeen;

  String get fullName => [name, surname].where((x) => x != null && x.trim().isNotEmpty).join(' ');

  /// seen in the last three minutes, as the site counts "online"
  bool get online => lastSeen != null && DateTime.now().difference(lastSeen!) < const Duration(minutes: 3);

  static int _int(Object? v, int d) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? d;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: '${j['id']}',
        name: (j['name'] as String?) ?? '',
        surname: j['surname'] as String?,
        username: j['username'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        coverUrl: j['cover_url'] as String?,
        city: j['city'] as String?,
        bio: j['bio'] as String?,
        hue: _int(j['hue'], 200),
        coins: _int(j['coins'], 0),
        onboarded: j['onboarded'] == true,
        verified: j['verified'] == true,
        lastSeen: DateTime.tryParse('${j['last_seen'] ?? ''}')?.toLocal(),
      );
}
