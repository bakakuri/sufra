// The notifications put together as Facebook and Instagram do: many people on one post become one line ("მარიამი,
// ლუკა და კიდევ 3 ❤️ შენს პოსტზე"), one person on many posts too ("გიორგი ❤️ შენს 5 პოსტზე"), and everything in parts
// of time — new, today, yesterday, this week, earlier. Each kind has its own small sign on the picture.
import '../data/models.dart';
import 'note_text.dart';

/// Notifications shown as one line.
class NoteGroup {
  NoteGroup(this.kind, this.items);
  final String kind;

  /// newest first
  final List<Notif> items;

  /// one person on many things (their posts, comments, photos), not many people on one thing
  bool manyThings = false;

  Notif get latest => items.first;
  DateTime get at => latest.createdAt;

  /// the people, the most recent first, each once
  List<String> get actors {
    final out = <String>[];
    for (final n in items) {
      if (n.actor != null && !out.contains(n.actor)) out.add(n.actor!);
    }
    return out;
  }

  /// the emojis given, the most used first
  String get emojis {
    final cnt = <String, int>{};
    for (final n in items) {
      final e = '${n.ref['emoji'] ?? ''}';
      final k = e.isEmpty ? (kind == 'react' ? '👍' : '❤️') : e;
      cnt[k] = (cnt[k] ?? 0) + 1;
    }
    return (cnt.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(3).map((e) => e.key).join();
  }

  /// how many different things (posts, comments…) the one person touched
  int get things => {for (final n in items) noteTarget(n)}.length;
}

/// What a notification is about, for putting them together (null: it stands alone).
String? noteTarget(Notif n) {
  final r = n.ref;
  String v(String k) => '${r[k] ?? ''}';
  switch (n.kind) {
    case 'react':
    case 'comment':
    case 'grade_plus':
    case 'repost':
      return v('post').isEmpty ? null : 'p${v('post')}';
    case 'comment_like':
      return 'c${v('comment').isEmpty ? v('post') : v('comment')}';
    case 'story_react':
      return 's${v('story')}';
    case 'album_photo':
      return v('album').isEmpty ? null : 'a${v('album')}';
    case 'msg_react':
      return v('conv').isEmpty ? null : 'v${v('conv')}';
    case 'friend_ok':
      return 'f';
  }
  return null;
}

/// the kinds one person may do to many things at once ("გიორგი ❤️ შენს 5 პოსტზე")
const _onManyThings = {'react', 'comment_like', 'grade_plus', 'story_react'};

/// The parts of time, in order.
const noteSections = ['ახალი', 'დღეს', 'გუშინ', 'ამ კვირაში', 'ადრე'];

String noteSection(Notif n, bool isNew, DateTime now) {
  if (isNew) return noteSections[0];
  final d0 = DateTime(now.year, now.month, now.day), t = n.createdAt;
  if (!t.isBefore(d0)) return noteSections[1];
  if (!t.isBefore(d0.subtract(const Duration(days: 1)))) return noteSections[2];
  if (!t.isBefore(d0.subtract(const Duration(days: 6)))) return noteSections[3];
  return noteSections[4];
}

/// The notifications, in their parts of time, each part's lines put together.
List<(String, List<NoteGroup>)> groupNotes(List<Notif> list, Set<int> fresh, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final bySec = <String, List<Notif>>{};
  for (final n in list) {
    (bySec[noteSection(n, fresh.contains(n.id), at)] ??= []).add(n);
  }
  final out = <(String, List<NoteGroup>)>[];
  for (final sec in noteSections) {
    final l = bySec[sec];
    if (l == null || l.isEmpty) continue;
    l.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // many people on one thing
    final byKey = <String, NoteGroup>{};
    final order = <String>[];
    for (final n in l) {
      final t = noteTarget(n), key = t == null ? '#${n.id}' : '${n.kind}|$t';
      final g = byKey[key];
      if (g == null) {
        byKey[key] = NoteGroup(n.kind, [n]);
        order.add(key);
      } else {
        g.items.add(n);
      }
    }
    // one person on many things
    final merged = <NoteGroup>[];
    final byActor = <String, NoteGroup>{};
    for (final key in order) {
      final g = byKey[key]!;
      final a = g.actors;
      if (_onManyThings.contains(g.kind) && a.length == 1) {
        final k = '${g.kind}|${a.first}';
        final into = byActor[k];
        if (into != null) {
          into.items.addAll(g.items);
          into.items.sort((x, y) => y.createdAt.compareTo(x.createdAt));
          into.manyThings = true;
          continue;
        }
        byActor[k] = g;
      }
      merged.add(g);
    }
    merged.sort((a, b) => b.at.compareTo(a.at));
    out.add((sec, merged));
  }
  return out;
}

/// "მარიამი", "მარიამი და ლუკა", "მარიამი, ლუკა და კიდევ 3"
String namesLine(List<String> names) {
  if (names.isEmpty) return '';
  if (names.length == 1) return names.first;
  if (names.length == 2) return '${names[0]} და ${names[1]}';
  return '${names[0]}, ${names[1]} და კიდევ ${names.length - 2}';
}

/// What a line says after the names.
String groupText(NoteGroup g) {
  final n = g.latest, r = n.ref, many = g.actors.length > 1;
  String q(String k) => '${r[k] ?? ''}';
  if (g.manyThings) {
    final k = g.things;
    switch (g.kind) {
      case 'react':
        return '${g.emojis} შენს $k პოსტზე';
      case 'comment_like':
        return 'მოიწონა შენი $k კომენტარი';
      case 'grade_plus':
        return 'შენს $k ფოტოს „5+“ დაუწერა';
      case 'story_react':
        return '${g.emojis} შენს $k ისტორიაზე';
    }
  }
  if (!many) return noteText(n.kind, r);
  switch (g.kind) {
    case 'react':
      return '${g.emojis} შენს პოსტზე';
    case 'comment':
      return 'დაწერეს კომენტარები შენს პოსტზე: ${q('text')}';
    case 'comment_like':
      return 'მოიწონეს შენი კომენტარი: ${q('text')}';
    case 'grade_plus':
      return 'შენს ფოტოს „5+“ დაუწერეს';
    case 'repost':
      return 'გააზიარეს შენი პოსტი';
    case 'friend_ok':
      return 'დაადასტურეს მეგობრობა';
    case 'story_react':
      return '${g.emojis} შენს ისტორიაზე';
    case 'album_photo':
      return 'ფოტოები დაამატეს ალბომში „${q('title')}“';
    case 'msg_react':
      return '${g.emojis} შენს მესიჯებზე';
  }
  return noteText(n.kind, r);
}

/// The small sign on the picture: its icon and its two colours.
(String, int, int) noteSign(String kind) {
  if (const {'react', 'story_react', 'msg_react', 'comment_like', 'match', 'super'}.contains(kind)) return ('heartfill', 0xFFF43F5E, 0xFFEC4899);
  if (const {'comment', 'comment_reply', 'mention', 'story_mention'}.contains(kind)) return ('comment', 0xFF10B981, 0xFF0EA5E9);
  if (const {'friend_req', 'friend_ok', 'kin_req', 'kin_ok'}.contains(kind)) return ('uadd', 0xFF3B82F6, 0xFF6366F1);
  if (const {'grade_plus', 'admin_coins', 'gift', 'bet_won', 'shop_done'}.contains(kind)) return ('star', 0xFFF59E0B, 0xFFF97316);
  if (kind == 'jk_invite') return ('cards', 0xFF8B5CF6, 0xFF6D28D9);
  if (kind == 'repost') return ('repost', 0xFF14B8A6, 0xFF0D9488);
  if (const {'birthday', 'nameday', 'birthday_me', 'nameday_me'}.contains(kind)) return ('gift', 0xFFEC4899, 0xFFF97316);
  if (kind.startsWith('group_')) return ('users', 0xFF6366F1, 0xFF4F46E5);
  if (kind.startsWith('event_') || kind == 'lesson_soon' || kind == 'deadline_soon' || kind == 'study_deadline') return ('cal', 0xFFF59E0B, 0xFFEAB308);
  if (kind.startsWith('album_')) return ('image', 0xFFA855F7, 0xFFEC4899);
  if (kind == 'verified' || kind == 'verify_rejected') return ('shield', 0xFF4F46E5, 0xFF3B82F6);
  if (kind.startsWith('ride_')) return ('route', 0xFF3B82F6, 0xFF0EA5E9);
  if (kind.startsWith('job_')) return ('work', 0xFF334155, 0xFF64748B);
  if (kind.startsWith('help_')) return ('help', 0xFFF43F5E, 0xFFFB7185);
  if (kind == 'live_start' || kind == 'room_invite') return ('live', 0xFFE11D48, 0xFFF43F5E);
  if (kind.startsWith('shop_')) return ('store', 0xFFEAB308, 0xFFF97316);
  return ('bell', 0xFF6366F1, 0xFF8B5CF6);
}

/// the filters at the top: what each shows
const noteFilters = [('all', 'ყველა'), ('new', 'ახალი'), ('reacts', 'რეაქციები'), ('comments', 'კომენტარები'), ('people', 'ხალხი')];

bool noteInFilter(Notif n, String f, Set<int> fresh) => switch (f) {
      'new' => fresh.contains(n.id),
      'reacts' => const {'react', 'story_react', 'msg_react', 'comment_like', 'grade_plus', 'repost'}.contains(n.kind),
      'comments' => const {'comment', 'comment_reply', 'mention', 'story_mention'}.contains(n.kind),
      'people' => const {'friend_req', 'friend_ok', 'kin_req', 'kin_ok', 'birthday', 'nameday', 'match', 'super'}.contains(n.kind),
      _ => true,
    };
