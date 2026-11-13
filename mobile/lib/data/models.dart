import '../profile/profile.dart';

int asInt(Object? v, [int d = 0]) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? d;
double? asNum(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
DateTime asTime(Object? v) => (DateTime.tryParse('${v ?? ''}') ?? DateTime.now()).toLocal();
String? _web(Object? u) => u is String && RegExp(r'^https?://').hasMatch(u) ? u : null;
Map<String, dynamic>? _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;

/// A photo or a video of a post or a message, as the site stores it: the full file, a ~1080 copy (md) and a ~480 one (sm).
class Media {
  const Media({required this.url, this.type = 'image', this.w = 0, this.h = 0, this.md, this.sm, this.poster, this.dur});
  final String url, type;
  final int w, h;
  final String? md, sm, poster;

  /// a video's length in seconds, when known
  final double? dur;

  bool get isVideo => type == 'video';

  /// what a list shows
  String get mid => md ?? url;
  String get small => sm ?? md ?? url;

  /// the frame of a post follows the first photo, between 4:5 and 1.91:1; square when its size is unknown
  double get box => w > 0 && h > 0 ? (w / h).clamp(.8, 1.91).toDouble() : 1;

  static Media? fromJson(Object? v) {
    final j = _map(v);
    final u = _web(j?['url']);
    if (j == null || u == null) return null;
    return Media(
      url: u,
      type: j['type'] == 'video' ? 'video' : 'image',
      w: asInt(j['w']),
      h: asInt(j['h']),
      md: _web(j['md']),
      sm: _web(j['sm']),
      poster: _web(j['poster']),
      dur: asNum(j['dur']),
    );
  }

  static List<Media> listOf(Object? v) => v is List ? v.map(Media.fromJson).whereType<Media>().toList() : const [];

  Map<String, dynamic> toJson() => {
        'url': url,
        'type': type,
        if (w > 0) 'w': w,
        if (h > 0) 'h': h,
        if (md != null) 'md': md,
        if (sm != null) 'sm': sm,
        if (poster != null) 'poster': poster,
        if (dur != null) 'dur': dur,
      };
}

class Poll {
  const Poll(this.q, this.opts);
  final String q;
  final List<String> opts;
  static Poll? fromJson(Object? v) {
    final j = _map(v);
    final o = j?['opts'];
    if (j == null || o is! List || o.isEmpty) return null;
    return Poll('${j['q'] ?? ''}', o.map((x) => '$x').toList());
  }
}

/// One post of the feed (the site's POSTSEL), with the author or the page it was written as.
class Post {
  Post({
    required this.id,
    required this.author,
    required this.createdAt,
    required this.cursor,
    this.body = '',
    this.media = const [],
    this.poll,
    this.edited = false,
    this.repostOf,
    this.ap,
    this.pageName,
    this.groupName,
    this.placeName,
    this.hidden = false,
    this.pending = false,
    this.tags = const [],
  });

  final int id;
  final String author, body, cursor;
  final DateTime createdAt;
  final List<Media> media;
  final Poll? poll;
  final bool edited, hidden, pending;
  final int? repostOf;
  final List<String> tags;

  /// who wrote it: the person, or the page drawn as one (id "page:…")
  final Profile? ap;
  final String? pageName, groupName, placeName;

  /// the shared post, for reposts
  Post? original;

  bool get plainRepost => repostOf != null && body.trim().isEmpty;
  bool get byPage => pageName != null;

  factory Post.fromJson(Map<String, dynamic> j) {
    final page = _map(j['page']), ap = _map(j['ap']);
    Profile? who;
    if (page != null) {
      who = Profile(
        id: 'page:${page['id']}',
        name: '${page['name'] ?? ''}',
        avatarUrl: page['avatar_url'] as String?,
        hue: asInt(page['hue'], 200),
        verified: page['verified'] == true,
      );
    } else if (ap != null) {
      who = Profile.fromJson(ap);
    }
    return Post(
      id: asInt(j['id']),
      author: '${j['author'] ?? ''}',
      body: '${j['body'] ?? ''}',
      createdAt: asTime(j['created_at']),
      cursor: '${j['created_at'] ?? ''}',
      media: Media.listOf(j['media']),
      poll: Poll.fromJson(j['poll']),
      edited: j['edited_at'] != null,
      repostOf: j['repost_of'] == null ? null : asInt(j['repost_of']),
      ap: who,
      pageName: page == null ? null : '${page['name'] ?? ''}',
      groupName: _map(j['grp'])?['name'] as String?,
      placeName: _map(j['pl'])?['name'] as String?,
      hidden: j['hidden'] == true,
      pending: j['pending'] == true,
      tags: j['tags'] is List ? (j['tags'] as List).map((x) => '$x').toList() : const [],
    );
  }
}

/// The 💡 reaction is stored as 🍷 (the site's old wine glass)
const reactions = ['👍', '❤️', '😂', '😮', '😢', '😡', '🍷'];
String reactionGlyph(String e) => e == '🍷' ? '💡' : e;

/// Reactions, comments, the poll and "saved" for one post (feed_stats); changed in place when you react.
class PostStats {
  PostStats({Map<String, int>? reactions, this.mine, this.comments = 0, Map<int, int>? votes, this.myVote, this.saved = false})
      : reactions = reactions ?? {},
        votes = votes ?? {};

  final Map<String, int> reactions;
  String? mine;
  int comments;
  final Map<int, int> votes;
  int? myVote;
  bool saved;

  int get total => reactions.values.fold(0, (a, b) => a + b);
  int get voteTotal => votes.values.fold(0, (a, b) => a + b);
  List<String> get top {
    final e = reactions.entries.where((x) => x.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    return e.take(3).map((x) => x.key).toList();
  }

  void setReaction(String? e) {
    final old = mine;
    if (old != null) {
      final n = (reactions[old] ?? 1) - 1;
      if (n > 0) {
        reactions[old] = n;
      } else {
        reactions.remove(old);
      }
    }
    if (e != null) reactions[e] = (reactions[e] ?? 0) + 1;
    mine = e;
  }

  void setVote(int i) {
    final old = myVote;
    if (old == i) return;
    if (old != null) votes[old] = (votes[old] ?? 1) > 1 ? votes[old]! - 1 : 0;
    votes[i] = (votes[i] ?? 0) + 1;
    myVote = i;
  }

  factory PostStats.fromJson(Map<String, dynamic> j) {
    final r = _map(j['reactions']) ?? const {}, v = _map(j['votes']) ?? const {};
    return PostStats(
      reactions: {for (final e in r.entries) e.key: asInt(e.value)},
      mine: j['my_reaction'] as String?,
      comments: asInt(j['comments']),
      votes: {for (final e in v.entries) asInt(e.key): asInt(e.value)},
      myVote: j['my_vote'] == null ? null : asInt(j['my_vote']),
      saved: j['saved'] == true,
    );
  }
}

class Comment {
  Comment({required this.id, required this.postId, required this.author, required this.body, required this.createdAt, this.parentId, this.ap, this.likes = 0, this.media});
  final int id, postId;
  final String author, body;
  final DateTime createdAt;
  final int? parentId;
  final Profile? ap;
  final int likes;
  final Media? media;

  factory Comment.fromJson(Map<String, dynamic> j) {
    final m = j['media'];
    return Comment(
      id: asInt(j['id']),
      postId: asInt(j['post_id']),
      author: '${j['author'] ?? ''}',
      body: '${j['body'] ?? ''}',
      createdAt: asTime(j['created_at']),
      parentId: j['parent_id'] == null ? null : asInt(j['parent_id']),
      ap: _map(j['profiles']) == null ? null : Profile.fromJson(_map(j['profiles'])!),
      likes: asInt(j['likes']),
      media: m is List ? Media.listOf(m).firstOrNull : Media.fromJson(m),
    );
  }
}

/// One conversation of my_chats(): the others in it (members), the last message, unread count.
class Chat {
  Chat({
    required this.convId,
    this.isGroup = false,
    this.title,
    this.lastAt,
    this.lastBody,
    this.lastKind,
    this.lastSender,
    this.unread = 0,
    this.members = const [],
    this.mutedUntil,
    this.archived = false,
  });
  final int convId;
  final bool isGroup;
  final String? title, lastBody, lastKind, lastSender;
  final DateTime? lastAt, mutedUntil;
  int unread;
  final List<String> members;
  final bool archived;

  bool get muted => mutedUntil != null && mutedUntil!.isAfter(DateTime.now());
  String? get other => !isGroup && members.isNotEmpty ? members.first : null;

  /// the last line under the name (the site's lastTxt)
  String get lastText => switch (lastKind) {
        'voice' => '🎤 ხმოვანი',
        'image' => '📷 ფოტო',
        _ => (lastBody ?? '').isNotEmpty ? lastBody! : (lastKind == 'text' ? 'შეტყობინება წაიშალა' : ''),
      };

  factory Chat.fromJson(Map<String, dynamic> j) => Chat(
        convId: asInt(j['conv_id']),
        isGroup: j['is_group'] == true,
        title: j['title'] as String?,
        lastAt: j['last_message_at'] == null ? null : asTime(j['last_message_at']),
        lastBody: j['last_body'] as String?,
        lastKind: j['last_kind'] as String?,
        lastSender: j['last_sender'] as String?,
        unread: asInt(j['unread']),
        members: j['members'] is List ? (j['members'] as List).map((x) => '$x').toList() : const [],
        mutedUntil: j['muted_until'] == null ? null : asTime(j['muted_until']),
        archived: j['archived'] == true,
      );
}

class Message {
  Message({
    required this.id,
    required this.convId,
    required this.sender,
    required this.createdAt,
    this.body = '',
    this.kind = 'text',
    this.media,
    this.replyTo,
    this.edited = false,
    this.deleted = false,
    this.expiresAt,
    this.sending = false,
  });
  final int id, convId;
  final String sender, body, kind;
  final DateTime createdAt;
  final Map<String, dynamic>? media;
  final int? replyTo;
  final bool edited, deleted, sending;
  final DateTime? expiresAt;

  bool get gone => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  Media? get photo => kind == 'image' ? Media.fromJson(media) : null;

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: asInt(j['id']),
        convId: asInt(j['conv_id']),
        sender: '${j['sender'] ?? ''}',
        body: '${j['body'] ?? ''}',
        kind: '${j['kind'] ?? 'text'}',
        media: _map(j['media']),
        createdAt: asTime(j['created_at']),
        replyTo: j['reply_to'] == null ? null : asInt(j['reply_to']),
        edited: j['edited_at'] != null,
        deleted: j['deleted'] == true,
        expiresAt: j['expires_at'] == null ? null : asTime(j['expires_at']),
      );
}

/// A row of friendships: who asked whom, and whether it was accepted.
class Rel {
  const Rel(this.requester, this.addressee, this.accepted);
  final String requester, addressee;
  final bool accepted;
  String otherThan(String me) => requester == me ? addressee : requester;
  factory Rel.fromJson(Map<String, dynamic> j) => Rel('${j['requester']}', '${j['addressee']}', j['status'] == 'accepted');
}

enum Friendship { none, friends, sent, received }

/// Someone you may know (friend_suggestions): the person and the number of friends in common.
class Suggestion {
  const Suggestion(this.p, this.mutual);
  final Profile p;
  final int mutual;
}

class Counts {
  const Counts(this.friends, this.posts);
  final int friends, posts;
}

/// One story: a photo or a video for a day.
class Story {
  const Story({required this.id, required this.author, required this.url, required this.createdAt, this.video = false, this.postId, this.close = false, this.seen = false});
  final int id;
  final String author, url;
  final DateTime createdAt;
  final bool video, close, seen;
  final int? postId;

  Story seenNow() => Story(id: id, author: author, url: url, createdAt: createdAt, video: video, postId: postId, close: close, seen: true);

  factory Story.fromJson(Map<String, dynamic> j, {bool seen = false}) => Story(
        id: asInt(j['id']),
        author: '${j['author'] ?? ''}',
        url: '${j['media_url'] ?? ''}',
        createdAt: asTime(j['created_at']),
        video: j['media_type'] == 'video',
        postId: j['post_id'] == null ? null : asInt(j['post_id']),
        close: j['audience'] == 'close',
        seen: seen,
      );
}

/// Someone's stories, oldest first, and whether you have seen them all.
class StoryGroup {
  StoryGroup(this.author, this.list);
  final String author;
  final List<Story> list;
  bool get seen => list.every((s) => s.seen);

  /// where to start: the first one not seen yet
  int get firstUnseen {
    final i = list.indexWhere((s) => !s.seen);
    return i < 0 ? 0 : i;
  }
}

/// Who saw a story of mine, and the reaction they left.
class StoryWatcher {
  const StoryWatcher(this.user, this.reaction);
  final String user;
  final String? reaction;
}

/// The reactions under a story (the site's SV_RX)
const storyReactions = ['❤️', '😂', '😮', '😢', '🔥', '👏', '🍷'];

/// The interests a dating profile picks from (the site's INTERESTS), at most six.
const datingInterests = [
  'სწავლა', 'ლაშქრობა', 'მოგზაურობა', 'ნარდი', 'ჭადრაკი', 'კინო', 'მუსიკა', 'ცეკვა', 'სპორტი', //
  'წიგნები', 'ფოტოგრაფია', 'კულინარია', 'ყავა', 'ზღვა', 'მთა', 'თამაშები', 'ხელოვნება', 'პროგრამირება',
];

/// My side of dating: whether I may use it (18+), whether it is on, and what my card says.
class DatingMe {
  const DatingMe({
    this.adult = false,
    this.on = false,
    this.gender,
    this.seeking = 'all',
    this.bio = '',
    this.interests = const [],
    this.photo = false,
  });
  final bool adult, on, photo;

  /// 'f', 'm', 'x'
  final String? gender;

  /// 'f', 'm', 'all'
  final String seeking;
  final String bio;
  final List<String> interests;

  DatingMe copyWith({bool? on, String? gender, String? seeking, String? bio, List<String>? interests}) => DatingMe(
        adult: adult,
        on: on ?? this.on,
        gender: gender ?? this.gender,
        seeking: seeking ?? this.seeking,
        bio: bio ?? this.bio,
        interests: interests ?? this.interests,
        photo: photo,
      );
}

/// A person in the dating deck (dating_feed).
class DatingCard {
  const DatingCard({
    required this.id,
    required this.name,
    this.age = 0,
    this.city,
    this.hue = 200,
    this.avatarUrl,
    this.bio = '',
    this.interests = const [],
    this.verified = false,
    this.likedMe = false,
  });
  final String id, name, bio;
  final String? city, avatarUrl;
  final int age, hue;
  final List<String> interests;
  final bool verified, likedMe;

  String get first => name.trim().split(' ').first;

  Profile get profile => Profile(id: id, name: name, avatarUrl: avatarUrl, hue: hue, city: city, verified: verified, onboarded: true);

  factory DatingCard.fromJson(Map<String, dynamic> j) => DatingCard(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        age: asInt(j['age']),
        city: j['city'] as String?,
        hue: j['hue'] == null ? 200 : asInt(j['hue']),
        avatarUrl: j['avatar_url'] as String?,
        bio: '${j['dating_bio'] ?? ''}',
        interests: [for (final x in (j['interests'] as List? ?? const [])) '$x'],
        verified: j['verified'] == true,
        likedMe: j['liked_me'] == true,
      );
}

/// A Joker table on the server (jk_tables): the seats (people; the empty ones get bots when it starts),
/// 'wait' → 'play' → 'over' (or 'closed'), and the game's public state the server keeps.
class JkTable {
  const JkTable({
    required this.id,
    required this.host,
    this.len = 'quick',
    this.seats = const [null, null, null, null],
    this.status = 'wait',
    this.pub = false,
    this.state = const {},
    this.updatedAt,
  });
  final int id;
  final String host, len, status;
  final List<String?> seats;
  final bool pub;
  final Map<String, dynamic> state;
  final DateTime? updatedAt;

  int get free => seats.where((s) => s == null).length;
  bool get srv => state['srv'] == true;

  factory JkTable.fromJson(Map<String, dynamic> j) => JkTable(
        id: asInt(j['id']),
        host: '${j['host'] ?? ''}',
        len: '${j['len'] ?? 'quick'}',
        seats: [for (final s in (j['seats'] as List? ?? const [null, null, null, null])) s == null ? null : '$s'],
        status: '${j['status'] ?? 'wait'}',
        pub: j['pub'] == true,
        state: j['state'] is Map ? Map<String, dynamic>.from(j['state'] as Map) : {if (j['srv'] == true) 'srv': true},
        updatedAt: DateTime.tryParse('${j['updated_at'] ?? ''}')?.toLocal(),
      );
}
