/// The signed-in person, as the database's my_profile gives it (the same fields the site uses).
class Profile {
  Profile({
    required this.id,
    required this.name,
    this.surname,
    this.username,
    this.avatarUrl,
    this.city,
    this.hue = 200,
    this.coins = 0,
    this.onboarded = false,
    this.verified = false,
  });

  final String id;
  final String name;
  final String? surname, username, avatarUrl, city;
  final int hue;
  final int coins;
  final bool onboarded, verified;

  String get fullName => [name, surname].where((x) => x != null && x.trim().isNotEmpty).join(' ');

  static int _int(Object? v, int d) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? d;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: '${j['id']}',
        name: (j['name'] as String?) ?? '',
        surname: j['surname'] as String?,
        username: j['username'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        city: j['city'] as String?,
        hue: _int(j['hue'], 200),
        coins: _int(j['coins'], 0),
        onboarded: j['onboarded'] == true,
        verified: j['verified'] == true,
      );
}
