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
    this.role,
    this.banned = false,
    this.rating,
    this.nameday,
    this.namedayLabel,
    this.homePlace,
    this.edu = const [],
    this.guest = false,
  });

  final String id;
  final String name;
  final String? surname, username, avatarUrl, coverUrl, city, bio;
  final int hue;
  final int coins;
  final bool onboarded, verified;
  final DateTime? lastSeen;

  /// 'admin', 'moderator' or nothing
  final String? role;
  final bool banned;

  /// the games rating (1500 to start, as on the site)
  final int? rating;

  /// the angel's day chosen by hand ('MM-DD') and its saint; otherwise the calendar decides by the first name
  final String? nameday, namedayLabel;

  /// the village or town they come from
  final String? homePlace;

  /// schools and universities: {k: 'school'|'uni', n, key, f, y0, y1, cls}
  final List<Map<String, dynamic>> edu;

  /// my own setting: visiting others without showing up among their guests
  final bool guest;

  /// the name as written ("სახელი და გვარი" on the site); the surname is kept apart only for the surname group
  String get fullName => name;

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
        role: j['role'] as String?,
        banned: j['banned'] == true,
        rating: j['rating'] == null ? null : _int(j['rating'], 1500),
        nameday: (j['nameday'] as String?)?.isEmpty == true ? null : j['nameday'] as String?,
        namedayLabel: j['nameday_label'] as String?,
        homePlace: j['home_place'] as String?,
        edu: [for (final e in (j['edu'] is List ? j['edu'] as List : const [])) if (e is Map) Map<String, dynamic>.from(e)],
        guest: j['privacy'] is Map && (j['privacy'] as Map)['guest'] == true,
      );
}
