import 'dart:async';
import 'dart:math';

import 'package:peera/data/api.dart';
import 'package:peera/data/models.dart';
import 'package:peera/data/photos.dart';
import 'package:peera/joker/engine.dart';
import 'package:peera/joker/online.dart';
import 'package:peera/media/video_tools.dart';
import 'package:peera/profile/profile.dart';

import 'helpers.dart';

/// The server, answered from memory: a few friends, posts with photos, a poll, a shared post, conversations.
/// Every write is noted in [calls] so the tests can check what would have been sent.
class FakeApi implements PeeraApi {
  FakeApi() {
    final now = DateTime.now();
    DateTime ago(int minutes) => now.subtract(Duration(minutes: minutes));
    _posts.addAll([
      _p(101, giorgi, ago(12), 'მცხეთიდან დაბრუნებისას ასეთი მზის ჩასვლა დაგვხვდა 🌄 #საქართველო', [img('sunset', 640, 480), img('hills', 480, 600)]),
      _p(102, mariam, ago(130),
          'დღეს პირველად ვცადე ქართული ტრადიციული პურის გამოცხობა თონეში. ბებიამ მასწავლა ყველაფერი: როგორ მოვზილო ცომი, რამდენ ხანს დავტოვო ამოსასვლელად და როგორ მივაკრა თონის კედელზე ისე, რომ არ ჩამოვარდეს.\n\nპირველი ორი ჩამომივარდა 😅 მაგრამ მესამე უკვე იდეალური გამოვიდა.\n\nვინც გინდათ, რეცეპტს გამოგიგზავნით!', const []),
      _p(103, luka, ago(300), 'ამინდი კარგი იქნება, სადმე წავიდეთ ☀️', const [], poll: const Poll('შაბათს სად წავიდეთ?', ['ზღვაზე', 'მთაში', 'ქალაქში დავრჩეთ'])),
      _p(104, ana, ago(420), '', const [], repostOf: 105),
      _p(106, nino, ago(60 * 26), 'ახალი აპი ვცადე! 📱 სულ სხვა სისწრაფეა', [img('sea', 640, 480)]),
    ]);
    _orig[105] = _p(105, dato, ago(60 * 30), 'დედაჩემის ხაჭაპური 😋', [img('food', 520, 520)]);
    for (final p in _posts) {
      if (p.repostOf != null) p.original = _orig[p.repostOf];
    }
    _stats.addAll({
      101: PostStats(reactions: {'❤️': 14, '👍': 6, '😮': 2}, mine: '❤️', comments: 4),
      102: PostStats(reactions: {'👍': 3, '🍷': 5}, comments: 2),
      103: PostStats(votes: {0: 7, 1: 11, 2: 3}),
      105: PostStats(reactions: {'😂': 2, '❤️': 9}, comments: 1),
      106: PostStats(reactions: {'❤️': 3}),
    });
    _comments[101] = [
      Comment(id: 1, postId: 101, author: mariam.id, ap: mariam, body: 'რა ლამაზია! სად არის ზუსტად?', createdAt: ago(10)),
      Comment(id: 2, postId: 101, author: giorgi.id, ap: giorgi, body: 'ჯვრის მონასტერთან ახლოს 🙂', createdAt: ago(8), parentId: 1),
      Comment(id: 3, postId: 101, author: luka.id, ap: luka, body: 'შემდეგ ჯერზე მეც წამიყვანეთ!', createdAt: ago(5), likes: 2),
      Comment(id: 4, postId: 101, author: ana.id, ap: ana, body: '👏👏👏', createdAt: ago(2)),
    ];
    _chats.addAll([
      Chat(convId: 1, members: [giorgi.id], lastBody: 'ხვალ 7-ზე შევხვდეთ?', lastKind: 'text', lastSender: giorgi.id, lastAt: ago(3), unread: 2),
      Chat(convId: 3, isGroup: true, title: 'კლასელები', members: [luka.id, ana.id, dato.id], lastKind: 'image', lastSender: ana.id, lastAt: ago(50), unread: 5),
      Chat(convId: 2, members: [mariam.id], lastBody: 'კარგი, მერე მომწერე', lastKind: 'text', lastSender: nino.id, lastAt: ago(90)),
      Chat(convId: 4, members: [luka.id], lastKind: 'voice', lastSender: luka.id, lastAt: ago(60 * 50)),
      Chat(convId: 5, members: [dato.id], lastBody: 'მადლობა!', lastKind: 'text', lastSender: dato.id, lastAt: ago(60 * 24 * 9), archived: true),
    ]);
    clipPosts.addAll([
      Post(id: 301, author: giorgi.id, ap: giorgi, createdAt: ago(40), cursor: '', body: 'გუდაურში პირველი თოვლი ❄️ #ზამთარი', media: const [Media(url: 'https://t/clip1.mp4', type: 'video', w: 720, h: 1280, poster: 'https://t/hills.jpg', dur: 14)]),
      Post(id: 302, author: mariam.id, ap: mariam, createdAt: ago(300), cursor: '', body: 'ბათუმის ბულვარი საღამოს', media: const [Media(url: 'https://t/clip2.mp4', type: 'video', w: 720, h: 1280, poster: 'https://t/sea.jpg', dur: 22)]),
    ]);
    _stats[301] = PostStats(reactions: {'❤️': 128, '😮': 4}, comments: 9);
    _stats[302] = PostStats(reactions: {'❤️': 41}, mine: '❤️', comments: 2);
    storyList.addAll([
      Story(id: 401, author: giorgi.id, url: 'https://t/sunset.jpg', createdAt: ago(90), seen: true),
      Story(id: 402, author: giorgi.id, url: 'https://t/hills.jpg', createdAt: ago(30)),
      Story(id: 403, author: mariam.id, url: 'https://t/sea.jpg', createdAt: ago(200)),
      Story(id: 404, author: luka.id, url: 'https://t/food.jpg', createdAt: ago(500), seen: true),
    ]);
    final y = DateTime(now.year, now.month, now.day).subtract(const Duration(hours: 4));
    var id = 500;
    Message m(String who, String body, DateTime at, {String kind = 'text', Map<String, dynamic>? media}) =>
        Message(id: id++, convId: 1, sender: who, body: body, kind: kind, media: media, createdAt: at);
    _msgs[1] = [
      m(giorgi.id, 'გამარჯობა! როგორ ხარ?', y),
      m(nino.id, 'კარგად, შენ? 😊', y.add(const Duration(minutes: 2))),
      m(giorgi.id, 'მეც კარგად. ნახე სად ვიყავით დღეს', y.add(const Duration(minutes: 3))),
      m(giorgi.id, '', y.add(const Duration(minutes: 3)), kind: 'image', media: {'url': 'https://t/sea.jpg', 'w': 640, 'h': 480}),
      m(nino.id, 'ვაუ, რა ლამაზია! სად არის?', y.add(const Duration(minutes: 6))),
      m(giorgi.id, 'ურეკში. ზაფხულში აუცილებლად უნდა წავიდეთ ყველა ერთად', y.add(const Duration(minutes: 7))),
      m(giorgi.id, '', y.add(const Duration(minutes: 8)), kind: 'voice', media: {'url': 'https://t/voice.m4a', 'dur': 14}),
      m(nino.id, 'აუცილებლად!', now.subtract(const Duration(minutes: 20))),
      m(giorgi.id, 'ხვალ თავისუფალი ხარ?', now.subtract(const Duration(minutes: 4))),
      m(giorgi.id, 'ხვალ 7-ზე შევხვდეთ?', now.subtract(const Duration(minutes: 3))),
    ].reversed.toList();
  }

  static Media img(String name, int w, int h) => Media(url: 'https://t/$name.jpg', w: w, h: h);

  Post _p(int id, Profile who, DateTime at, String body, List<Media> media, {Poll? poll, int? repostOf}) =>
      Post(id: id, author: who.id, ap: who, createdAt: at, cursor: at.toIso8601String(), body: body, media: media, poll: poll, repostOf: repostOf);

  final calls = <String>[];
  final _posts = <Post>[];
  final _orig = <int, Post>{};
  final _stats = <int, PostStats>{};
  final _comments = <int, List<Comment>>{};
  final _chats = <Chat>[];
  final _msgs = <int, List<Message>>{};
  final live = <int, StreamController<Message>>{};
  final liveNote = StreamController<Map<String, dynamic>>.broadcast();
  var _rels = <Rel>[Rel(nino.id, giorgi.id, true), Rel(mariam.id, nino.id, true), Rel(nino.id, luka.id, true), Rel(ana.id, nino.id, false), Rel(nino.id, dato.id, false)];
  int _id = 900;

  /// a message from someone else, as if it arrived live
  void push(int conv, String from, String body) {
    final m = Message(id: _id++, convId: conv, sender: from, body: body, createdAt: DateTime.now());
    _msgs[conv] = [m, ...?_msgs[conv]];
    live[conv]?.add(m);
  }

  @override
  String get myId => nino.id;

  @override
  Future<List<Post>> feed({List<String>? authors, String? before, int limit = 15}) async =>
      _posts.where((p) => authors == null || authors.contains(p.author)).toList();

  @override
  Future<List<Post>> postsBy(String uid, {String? before, int limit = 30}) async => _posts.where((p) => p.author == uid && p.repostOf == null).toList();

  @override
  Future<Post?> post(int id) async => _posts.where((p) => p.id == id).firstOrNull ?? _orig[id];

  @override
  Future<Map<int, PostStats>> stats(List<int> ids) async => {
        for (final i in ids)
          if (_stats[i] != null) i: _stats[i]!,
      };

  @override
  Future<void> react(int postId, String? emoji) async => calls.add('react $postId $emoji');
  @override
  Future<void> vote(int postId, int opt) async => calls.add('vote $postId $opt');
  @override
  Future<void> save(int postId, bool on) async => calls.add('save $postId $on');
  @override
  Future<void> deletePost(int postId) async {
    calls.add('delete $postId');
    _posts.removeWhere((p) => p.id == postId);
  }

  @override
  Future<List<Comment>> comments(int postId) async => [...?_comments[postId]];

  @override
  Future<Comment> addComment(int postId, String body, {int? parentId}) async {
    calls.add('comment $postId $body${parentId == null ? '' : ' ↩$parentId'}');
    final c = Comment(id: _id++, postId: postId, author: nino.id, ap: nino, body: body, createdAt: DateTime.now(), parentId: parentId);
    (_comments[postId] ??= []).add(c);
    return c;
  }

  @override
  Future<Media> uploadPhoto(PreparedPhoto p) async {
    calls.add('upload ${p.w}x${p.h}');
    return img('hills', p.w, p.h);
  }

  @override
  Future<Post> createPost(String body, List<Media> media) async {
    calls.add('post $body ${media.length}');
    final p = _p(_id++, nino, DateTime.now(), body, media);
    _posts.insert(0, p);
    return p;
  }

  @override
  Future<Profile?> person(String uid) async => everyone.where((p) => p.id == uid).firstOrNull;
  @override
  Future<Counts> counts(String uid) async => Counts(uid == giorgi.id ? 248 : 87, _posts.where((p) => p.author == uid).length);
  @override
  Future<List<Profile>> people(List<String> ids) async => everyone.where((p) => ids.contains(p.id)).toList();
  @override
  Future<List<Profile>> search(String q) async => everyone.where((p) => p.id != nino.id && (p.name.contains(q) || (p.username ?? '').contains(q))).toList();
  @override
  Future<List<Rel>> rels() async => [..._rels];
  @override
  Future<List<Suggestion>> suggestions() async => [Suggestion(tamar, 4), Suggestion(nika, 2)];
  @override
  Future<void> addFriend(String uid) async => calls.add('add $uid');
  @override
  Future<void> acceptFriend(String uid) async {
    calls.add('accept $uid');
    _rels = [for (final r in _rels) r.requester == uid && r.addressee == nino.id ? Rel(uid, nino.id, true) : r];
  }

  @override
  Future<void> removeFriend(String uid) async => calls.add('remove $uid');

  @override
  Future<List<Chat>> chats() async => [
        for (final c in _chats)
          Chat(
            convId: c.convId,
            isGroup: c.isGroup,
            title: c.title,
            members: c.members,
            lastBody: c.lastBody,
            lastKind: c.lastKind,
            lastSender: c.lastSender,
            lastAt: c.lastAt,
            unread: c.unread,
            archived: c.archived,
          ),
      ];

  @override
  Future<List<Message>> messages(int convId, {DateTime? before, int limit = 50}) async =>
      before == null ? [...?_msgs[convId]] : const [];

  @override
  Future<Message> send(int convId, {String body = '', String kind = 'text', Map<String, dynamic>? media}) async {
    calls.add('send $convId $kind $body');
    final m = Message(id: _id++, convId: convId, sender: nino.id, body: body, kind: kind, media: media, createdAt: DateTime.now());
    _msgs[convId] = [m, ...?_msgs[convId]];
    return m;
  }

  @override
  Future<void> markRead(int convId) async {
    calls.add('read $convId');
    for (final c in _chats) {
      if (c.convId == convId) c.unread = 0;
    }
  }

  @override
  Future<int> startDm(String uid) async {
    calls.add('dm $uid');
    return _chats.where((c) => c.other == uid).firstOrNull?.convId ?? 1;
  }

  @override
  Stream<Message> liveMessages(int convId) => (live[convId] ??= StreamController<Message>.broadcast()).stream;
  @override
  Stream<Map<String, dynamic>> liveNotes() => liveNote.stream;
  @override
  Future<void> touchSeen() async {}
  @override
  Future<void> savePushToken(String token) async => calls.add('push+ $token');
  @override
  Future<void> removePushToken(String token) async => calls.add('push- $token');
  @override
  Future<void> logError(String msg, {String stack = ''}) async => calls.add('error $msg');
  // dating: on is false until the card is saved; ანა likes me back
  DatingMe dating = const DatingMe(adult: true);
  late final datingCards = <DatingCard>[
    const DatingCard(id: 'u5', name: 'ანა მელაძე', age: 24, city: 'რუსთავი', hue: 28, likedMe: true, bio: 'ვხატავ, დავდივარ კონცერტებზე და ყოველ შაბათს მთაში ვარ.', interests: ['ხელოვნება', 'მთა', 'მუსიკა']),
    const DatingCard(id: 'u6', name: 'დათო ხარაბაძე', age: 27, city: 'გორი', hue: 260, verified: true, bio: 'ნარდი და კარგი ყავა.', interests: ['ნარდი', 'ყავა']),
    const DatingCard(id: 'u7', name: 'თამარ ლომიძე', age: 22, city: 'ქუთაისი', hue: 190, avatarUrl: 'https://t/sea.jpg', likedMe: true, interests: ['ზღვა', 'წიგნები', 'კინო', 'ცეკვა']),
  ];
  final pairIds = <String>['u3', 'u4'];

  @override
  Future<DatingMe> datingMe() async => dating;
  @override
  Future<void> saveDating(DatingMe d) async {
    calls.add('dating on ${d.gender} ${d.seeking} ${d.interests.join(',')}');
    dating = d.copyWith(on: true);
  }

  @override
  Future<void> datingOff() async {
    calls.add('dating off');
    dating = dating.copyWith(on: false);
  }

  @override
  Future<List<DatingCard>> datingFeed({int limit = 25}) async => [...datingCards];
  @override
  Future<bool> swipe(String target, String kind) async {
    calls.add('swipe $target $kind');
    datingCards.removeWhere((c) => c.id == target);
    final pair = kind != 'nope' && target == 'u5';
    if (pair) pairIds.insert(0, target);
    return pair;
  }

  @override
  Future<int> likesMeCount() async => datingCards.where((c) => c.likedMe).length;
  @override
  Future<List<String>> matches() async => [...pairIds];

  // Joker tables "on the server": the engine plays it, bots (and the other people) move when the table is ticked
  final jk = <int, JkTable>{};
  final _jkLive = StreamController<JkTable>.broadcast();
  final _jkGame = <int, JokerGame>{};
  final _jkBots = <int, List<String?>>{};
  final _jkDeal = <int, int>{};
  int _jkSeq = 0;

  Map<String, dynamic> _jkState(int id) {
    final g = _jkGame[id]!;
    Map<String, dynamic> e(Play x) => {'p': x.p, 'card': cardJson(x.card), 'jm': x.jm, 'js': x.js};
    return {
      'srv': true,
      'len': g.len,
      'h': g.h,
      'n': g.n,
      'score': [...g.score],
      'hist': [for (final r in g.hist) r.toJson()],
      'bots': _jkBots[id],
      'away': [false, false, false, false],
      'dealer': g.dealer,
      'deal': _jkDeal[id],
      'seq': ++_jkSeq,
      'phase': g.phase,
      'cur': g.cur,
      'bids': [...g.bids],
      'taken': [...g.taken],
      'trick': [for (final x in g.trick) e(x)],
      'trump': g.trump,
      'trumpCard': g.trumpCard == null ? null : cardJson(g.trumpCard!),
      'counts': [for (final h in g.hands) h.length],
      'win': g.win,
      'last': g.lastT == null ? null : {'t': [for (final x in g.lastT!.t) e(x)], 'w': g.lastT!.w},
      // another person's turn is over at once (the server would play for them after the time limit)
      'dl': g.cur >= 0 && jk[id]!.seats[g.cur] != null && jk[id]!.seats[g.cur] != myId ? 1 : 0,
      'at': 0,
    };
  }

  void _jkPut(int id, {String? status}) {
    final t = jk[id]!, g = _jkGame[id];
    jk[id] = JkTable(id: id, host: t.host, len: t.len, seats: t.seats, status: status ?? (g?.phase == 'over' ? 'over' : t.status), pub: t.pub, state: g == null ? t.state : _jkState(id));
    _jkLive.add(jk[id]!);
  }

  void _jkSeats(int id, List<String?> seats, {String? len, bool? pub}) {
    final t = jk[id]!;
    jk[id] = JkTable(id: id, host: t.host, len: len ?? t.len, seats: seats, status: t.status, pub: pub ?? t.pub, state: t.state);
    _jkLive.add(jk[id]!);
  }

  @override
  Future<JkTable?> jkTable(int id) async => jk[id];
  @override
  Stream<JkTable> liveJkTable(int id) => _jkLive.stream.where((t) => t.id == id);

  @override
  Future<({int seat, int deal, List<Map<String, dynamic>> cards})?> jkHand(int id) async {
    final g = _jkGame[id], seat = jk[id]?.seats.indexOf(myId) ?? -1;
    if (g == null || seat < 0) return null;
    return (seat: seat, deal: _jkDeal[id]!, cards: [for (final c in g.phase == 'trump' ? g.first3[seat] : g.hands[seat]) cardJson(c)]);
  }

  @override
  Future<Map<String, dynamic>?> jkTick(int id) async {
    final g = _jkGame[id], t = jk[id];
    if (g == null || t == null) return null;
    final me = t.seats.indexOf(myId);
    if (g.phase == 'play' && g.win != null) {
      g.collect();
    } else if (g.phase == 'handover') {
      g.nextHand();
      _jkDeal[id] = _jkDeal[id]! + 1;
    } else if (g.cur >= 0 && g.cur != me) {
      final p = g.cur;
      switch (g.phase) {
        case 'trump':
          g.setTrump(g.botTrump(p));
        case 'bid':
          g.bid(p, g.botBid(p, 3));
        case 'play':
          final m = g.botPlay(p, 3);
          g.play(p, m.c, jm: m.jm, js: m.js);
      }
    } else {
      return jk[id]!.state;
    }
    _jkPut(id);
    return jk[id]!.state;
  }

  @override
  Future<({Map<String, dynamic> state, List<Map<String, dynamic>>? hand})> jkAct(int id, Map<String, dynamic> move) async {
    final g = _jkGame[id]!, seat = jk[id]!.seats.indexOf(myId);
    if (g.cur != seat) throw Exception('not_your_turn');
    calls.add('jk act ${move['k']}');
    switch (move['k']) {
      case 'trump':
        g.setTrump(move['s'] as String?);
      case 'bid':
        g.bid(seat, move['v'] as int);
      case 'card':
        final c = cardOf(move['c'] as Map);
        if (!g.legal(seat).contains(c)) throw Exception('bad_move');
        g.play(seat, c, jm: move['jm'] as String?, js: move['js'] as String?);
    }
    _jkPut(id);
    return (state: jk[id]!.state, hand: [for (final c in g.hands[seat]) cardJson(c)]);
  }

  @override
  Future<void> jkBack(int id) async {}

  @override
  Future<Map<String, dynamic>?> jkStart(int id) async {
    final t = jk[id]!;
    calls.add('jk start $id');
    const names = ['რეზო', 'სალომე', 'დათო', 'მარიამი'];
    _jkBots[id] = [for (var i = 0; i < 4; i++) t.seats[i] == null ? names[i] : null];
    _jkGame[id] = JokerGame.start(t.len, rng: Random(3));
    _jkDeal[id] = 1;
    _jkPut(id, status: 'play');
    return jk[id]!.state;
  }

  @override
  Future<int> jkQuick(String len) async {
    calls.add('jk quick $len');
    jk[70] = JkTable(id: 70, host: 'u2', len: len, seats: const ['u2', 'u1', null, null], pub: true, state: const {'srv': true});
    return 70;
  }

  @override
  Future<int> jkNew() async {
    final id = 50 + jk.length;
    calls.add('jk new $id');
    jk[id] = JkTable(id: id, host: myId, seats: [myId, null, null, null], state: const {'srv': true});
    return id;
  }

  @override
  Future<int> jkJoin(int id) async {
    final s = [...jk[id]!.seats];
    final i = s.indexOf(null);
    s[i] = myId;
    _jkSeats(id, s);
    return i;
  }

  @override
  Future<void> jkLeave(int id) async => _jkSeats(id, [for (final x in jk[id]!.seats) x == myId ? null : x]);

  @override
  Future<void> jkSet(int id, {String? len, bool? pub}) async {
    calls.add('jk set $id ${len ?? ''}${pub ?? ''}');
    _jkSeats(id, jk[id]!.seats, len: len, pub: pub);
  }

  @override
  Future<void> jkClose(int id) async {
    calls.add('jk close $id');
    jk.remove(id);
  }

  @override
  Future<int> jkInvite(int id, List<String> users) async {
    calls.add('jk invite $id ${users.join(',')}');
    return users.length;
  }

  @override
  Future<List<JkTable>> jkLobby() async => [for (final t in jk.values) if (t.pub && t.status == 'wait') t];
  @override
  Future<List<JkTable>> jkMine() async => [for (final t in jk.values) if (t.seats.contains(myId) && t.status != 'over') t];

  // the live map: გიორგი shares exactly and is live; მარიამ roughly, twenty minutes ago
  late final spots = <LiveSpot>[
    LiveSpot(userId: 'u2', lat: 41.7105, lng: 44.7932, acc: 8, speed: 4.2, audience: 'friends', updatedAt: DateTime.now().subtract(const Duration(seconds: 40)), friend: true),
    LiveSpot(
      userId: 'u3',
      lat: 41.64,
      lng: 41.63,
      acc: 1000,
      audience: 'public',
      approx: true,
      updatedAt: DateTime.now().subtract(const Duration(minutes: 20)),
      expiresAt: DateTime.now().add(const Duration(hours: 2)),
      friend: true,
    ),
  ];
  MyShare? share;
  int _tok = 0;

  @override
  Future<List<LiveSpot>> liveMap() async => [...spots];
  @override
  Future<MyShare?> myShare() async => share;
  @override
  Future<String> locToken() async {
    calls.add('loc token');
    return 'tok-${++_tok}';
  }

  @override
  Future<void> locStop() async {
    calls.add('loc stop');
    share = null;
  }

  @override
  Future<bool> amMinor() async => false;

  @override
  Future<({int coins, int reward})> gameResult(String game, bool win) async {
    calls.add('game $game ${win ? 'won' : 'lost'}');
    return (coins: 1210, reward: win ? 10 : 0);
  }

  final clipPosts = <Post>[];
  final storyList = <Story>[];

  @override
  Future<List<Post>> clips({String? before, int limit = 12}) async => before == null ? [...clipPosts] : const [];
  @override
  Future<String> uploadVoice(String path) async {
    calls.add('voice $path');
    return 'https://t/voice-new.m4a';
  }

  @override
  Future<Media> uploadVideo(VideoReady v) async {
    calls.add('video ${v.w}x${v.h}');
    return Media(url: 'https://t/clip.mp4', type: 'video', w: v.w, h: v.h, poster: 'https://t/sunset.jpg', dur: v.dur);
  }

  @override
  Future<Post> createClip(String body, Media video) async {
    calls.add('clip $body');
    final p = Post(id: _id++, author: nino.id, ap: nino, createdAt: DateTime.now(), cursor: '', body: body, media: [video]);
    clipPosts.insert(0, p);
    return p;
  }

  @override
  Future<List<Story>> stories() async => [...storyList];
  @override
  Future<void> storySeen(int id) async => calls.add('seen $id');
  @override
  Future<String> uploadStoryPhoto(PreparedPhoto p) async {
    calls.add('story photo');
    return 'https://t/hills.jpg';
  }

  @override
  Future<void> addStory(String url, {bool video = false}) async {
    calls.add('story $url');
    storyList.add(Story(id: _id++, author: nino.id, url: url, createdAt: DateTime.now(), video: video));
  }

  @override
  Future<void> deleteStory(int id) async {
    calls.add('unstory $id');
    storyList.removeWhere((s) => s.id == id);
  }

  @override
  Future<void> reactStory(Story s, String emoji) async => calls.add('story react ${s.id} $emoji');
  @override
  Future<void> replyStory(Story s, String text) async => calls.add('story reply ${s.id} $text');
  @override
  Future<List<StoryWatcher>> storyViewers(int id) async => [StoryWatcher(giorgi.id, '❤️'), StoryWatcher(mariam.id, null)];

  // ---- the bell, the settings, the profile row ----

  late final noteList = () {
    final now = DateTime.now();
    Notif n(int id, String? who, String kind, Map<String, dynamic> ref, int min, {bool read = true}) =>
        Notif(id: id, actor: who, kind: kind, ref: ref, read: read, createdAt: now.subtract(Duration(minutes: min)));
    return [
      n(71, giorgi.id, 'react', {'post': 106, 'emoji': '❤️'}, 4, read: false),
      n(70, mariam.id, 'comment', {'post': 106, 'text': 'რა მაგარია! სად გადაიღე?'}, 18, read: false),
      n(69, tamar.id, 'friend_req', {}, 60, read: false),
      n(68, luka.id, 'mention', {'post': 103, 'text': '@nino.beridze შენ რას იტყვი?'}, 60 * 3),
      n(67, null, 'verified', {}, 60 * 26),
      n(66, ana.id, 'birthday', {}, 60 * 30),
      n(65, dato.id, 'jk_invite', {'table': 7}, 60 * 50),
    ];
  }();

  @override
  Future<List<Notif>> notes() async => [...noteList];
  @override
  Future<void> notesRead(List<int> ids) async => calls.add('read ${ids.join(',')}');
  @override
  Future<void> allNotesRead() async => calls.add('read all');
  @override
  Future<int> unreadNotes() async => noteList.where((n) => !n.read).length;

  /// my row as the server keeps it; the settings write into it
  final me = <String, dynamic>{
    'id': nino.id,
    'name': nino.name,
    'surname': nino.surname,
    'username': nino.username,
    'city': nino.city,
    'hue': nino.hue,
    'bio': 'ქუთაისელი, ვსწავლობ თბილისში 📚',
    'coins': nino.coins,
    'birthday': '1999-04-12',
    'home_region': 'იმერეთი',
    'home_place': 'წყალტუბო',
    'abroad': '',
    'is_business': false,
    'dating': false,
    'privacy': <String, dynamic>{'dm': 'all'},
    'notif': <String, dynamic>{
      'off': {'promo': true},
      'quiet': {'on': true, 'from': 23, 'to': 8, 'tz': 'Asia/Tbilisi'},
    },
  };

  /// a write that fails like a taken @name
  Object? updateFail;

  @override
  Future<Map<String, dynamic>> mySettings() async => {...me};
  @override
  Future<void> updateMe(Map<String, dynamic> fields) async {
    if (updateFail != null) throw updateFail!;
    calls.add('me ${fields.keys.join(',')}');
    me.addAll(fields);
  }

  final blockedIds = [nika.id];
  @override
  Future<List<String>> blocked() async => [...blockedIds];
  @override
  Future<void> unblock(String uid) async {
    calls.add('unblock $uid');
    blockedIds.remove(uid);
  }
}
