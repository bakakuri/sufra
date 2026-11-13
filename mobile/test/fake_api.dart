import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

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
      _p(107, giorgi, ago(60 * 50), 'სვანეთი, უშგული 🏔️', [img('hills', 480, 600)]),
      _p(108, giorgi, ago(60 * 80), 'ერთი დღე თბილისში: ძველი უბნები, აბანოები და ხინკალი.', const []),
      _p(109, giorgi, ago(60 * 120), 'ზღვა სექტემბერში', [img('sea', 640, 480), img('sunset', 640, 480), img('food', 520, 520)]),
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
      106: PostStats(reactions: {'❤️': 3}, gradeAvg: 5.4, gradeN: 7),
      107: PostStats(reactions: {'❤️': 22}, gradeAvg: 5.8, gradeN: 12, myGrade: '5+'),
      109: PostStats(reactions: {'❤️': 9}),
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

  // ---- the profile ----

  @override
  Future<int> mutualFriends(String uid) async => uid == giorgi.id ? 12 : 3;
  @override
  Future<void> visit(String uid) async => calls.add('visit $uid');
  @override
  Future<JokerLine?> jokerLine(String uid) async => switch (uid) {
        'u2' => const JokerLine(rating: 1640, games: 38, wins: 17),
        'u1' => const JokerLine(games: 12, wins: 5),
        _ => null,
      };

  @override
  Future<List<(String, DateTime)>> badges(String uid) async {
    final d = DateTime.now().subtract(const Duration(days: 20));
    return switch (uid) {
      'u1' => [('post1', d), ('friends10', d.add(const Duration(days: 3))), ('star', d.add(const Duration(days: 9)))],
      'u2' => [('post1', d), ('verified', d), ('master', d.add(const Duration(days: 5)))],
      _ => const [],
    };
  }

  @override
  Future<List<String>> checkBadges() async {
    calls.add('check badges');
    return const [];
  }

  final hlList = <String, List<Highlight>>{
    'u2': const [Highlight(id: 1, title: 'მთები', cover: 'https://t/hills.jpg'), Highlight(id: 2, title: 'ზღვა', cover: 'https://t/sea.jpg')],
    'u1': const [Highlight(id: 3, title: 'ქუთაისი')],
  };
  @override
  Future<List<Highlight>> highlights(String uid) async => [...?hlList[uid]];
  @override
  Future<List<Story>> highlightItems(int id) async => [
        Story(id: 410 + id, itemId: 70 + id, author: '', url: 'https://t/hills.jpg', createdAt: DateTime.now().subtract(const Duration(days: 30)), seen: true),
        Story(id: 420 + id, itemId: 80 + id, author: '', url: 'https://t/sea.jpg', createdAt: DateTime.now().subtract(const Duration(days: 29)), seen: true),
      ];
  @override
  Future<int> newHighlight(String title, int pos) async {
    calls.add('new highlight $title');
    return 9;
  }

  @override
  Future<bool> addToHighlight(int highlight, int story) async {
    calls.add('keep $story in $highlight');
    return true;
  }

  @override
  Future<void> removeHighlightItem(int itemId) async => calls.add('unkeep $itemId');
  @override
  Future<void> renameHighlight(int id, String title) async => calls.add('rename highlight $id $title');
  @override
  Future<void> deleteHighlight(int id) async => calls.add('delete highlight $id');

  @override
  Future<List<Story>> myStories() async => [
        ...storyList.where((x) => x.author == nino.id),
        Story(id: 450, author: nino.id, url: 'https://t/food.jpg', createdAt: DateTime.now().subtract(const Duration(days: 12)), seen: true),
        Story(id: 451, author: nino.id, url: 'https://t/sea.jpg', createdAt: DateTime.now().subtract(const Duration(days: 40)), seen: true),
      ];

  @override
  Future<List<Album>> albums(String uid) async => [for (final r in albumRows.values) if (r['owner'] == uid) _album(r)];

  @override
  Future<Map<String, dynamic>?> cv(String uid) async => uid == giorgi.id
      ? {
          'headline': 'ფოტოგრაფი',
          'summary': 'ვიღებ ქორწილებს, ბუნებას და რეკლამას.',
          'experience': [
            {'a': 'ფოტოგრაფი', 'b': 'სტუდია „კადრი“', 'c': '2021–'},
          ],
          'education': [
            {'a': 'თსუ', 'b': 'ჟურნალისტიკა', 'c': '2016–2020'},
          ],
          'skills': ['Lightroom', 'სტუდიური შუქი'],
          'languages': ['ქართული', 'ინგლისური'],
          'phone': '+995 555 12 34 56',
          'visible': true,
        }
      : (uid == myId ? savedCv : null);

  @override
  Future<List<String>> friendsOf(String uid) async => uid == giorgi.id ? [nino.id, mariam.id, luka.id] : [for (final r in _rels) if (r.accepted) r.otherThan(uid)];

  @override
  Future<List<Post>> saved({int? folder}) async {
    calls.add('saved ${folder ?? 'all'}');
    return folder == null ? _posts.where((p) => p.id == 101 || p.id == 103).toList() : const [];
  }

  final folderList = <(int, String)>[(1, 'კონსპექტები')];
  @override
  Future<List<(int, String)>> saveFolders() async => [...folderList];

  @override
  Future<List<Visit>> guests() async => [
        Visit(giorgi.id, DateTime.now().subtract(const Duration(minutes: 10))),
        Visit(mariam.id, DateTime.now().subtract(const Duration(hours: 3))),
      ];
  @override
  Future<int> guestsSince(DateTime since) async => 2;

  @override
  Future<List<GiftGot>> giftsGot() async => [
        GiftGot('🌹', giorgi.id, DateTime.now().subtract(const Duration(days: 1))),
        GiftGot('☕', luka.id, DateTime.now().subtract(const Duration(days: 4))),
      ];

  @override
  Future<int> sendGift(String uid, String emoji) async {
    calls.add('gift $uid $emoji');
    return 12400;
  }

  @override
  Future<void> report(String type, String id, String reason) async => calls.add('report $type $id $reason');

  @override
  Future<void> block(String uid) async {
    calls.add('block $uid');
    blockedIds.add(uid);
    _rels = _rels.where((r) => r.requester != uid && r.addressee != uid).toList();
  }

  final closeIds = <String>{'u2'};
  @override
  Future<List<String>> closeFriends() async => [...closeIds];
  @override
  Future<void> setClose(String uid, bool on) async {
    calls.add('close $uid $on');
    on ? closeIds.add(uid) : closeIds.remove(uid);
  }

  @override
  Future<List<Post>> drafts() async => [
        _p(150, nino, DateTime.now().subtract(const Duration(hours: 5)), 'ხვალ ქუთაისში ვიქნები, ვინ ხართ? (დრაფტი)', const []),
      ];
  @override
  Future<void> publishNow(int postId) async => calls.add('publish $postId');

  @override
  Future<void> schedulePost(int postId, DateTime at) async => calls.add('plan $postId');

  @override
  Future<void> renameFolder(int id, String name) async {
    calls.add('rename folder $id $name');
    final i = folderList.indexWhere((f) => f.$1 == id);
    if (i >= 0) folderList[i] = (id, name);
  }

  @override
  Future<void> deleteFolder(int id) async {
    calls.add('delete folder $id');
    folderList.removeWhere((f) => f.$1 == id);
  }

  @override
  Future<int> gradePhoto(int postId, String grade) async {
    calls.add('grade $postId $grade');
    return grade == '5+' ? 50 : 0;
  }

  @override
  Future<void> banUser(String uid) async => calls.add('ban $uid');

  @override
  Future<List<(String, int, int, int)>> gameRatings(String uid) async => uid == giorgi.id ? const [('nardi', 1620, 40, 25), ('chess', 1480, 10, 4)] : const [];

  @override
  Future<int> sendCard(String uid, Map<String, dynamic> card) async {
    calls.add('card $uid ${card['d']} ${card['to']}');
    final conv = _chats.where((c) => c.other == uid).firstOrNull?.convId ?? 1;
    await send(conv, body: '🎉 მისალოცი ბარათი', media: {'card': card});
    return conv;
  }

  // ---- coins ----

  String? lastBonus;
  int bonusStreak = 2;

  @override
  Future<Map<String, dynamic>> myCoins() async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 4));
    final today = now.toIso8601String().substring(0, 10), yest = now.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    return {
      'coins': me['coins'],
      'rate': 10000,
      'today': 35,
      'daily_max': 150,
      'by': {'post': 20, 'comment': 15},
      'done': ['avatar'],
      'promo': false,
      'day': today,
      'last_bonus': lastBonus ?? yest,
      'streak': bonusStreak,
      'plus_cost': 50,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> coinRules() async => const [
        {'action': 'post', 'page': 'home', 'label': 'პოსტის დაწერა', 'amount': 10, 'day_cap': 30, 'active': true},
        {'action': 'comment', 'page': 'home', 'label': 'კომენტარი', 'amount': 5, 'day_cap': 25, 'active': true},
        {'action': 'avatar', 'page': 'me', 'label': 'პროფილის ფოტო', 'hint': 'ერთხელ', 'amount': 50, 'once': true, 'active': true},
        {'action': 'story', 'page': 'stories', 'label': 'ისტორიის დადება', 'amount': 5, 'day_cap': 15, 'active': true},
      ];

  @override
  Future<List<Map<String, dynamic>>> coinLog() async => [
        {'label': 'პოსტის დაწერა', 'amount': 10, 'n': 2, 'created_at': DateTime.now().subtract(const Duration(hours: 2)).toUtc().toIso8601String()},
        {'label': 'საჩუქარი', 'amount': -300, 'created_at': DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String()},
      ];

  @override
  Future<Map<String, dynamic>> dailyBonus() async {
    calls.add('bonus');
    lastBonus = DateTime.now().toUtc().add(const Duration(hours: 4)).toIso8601String().substring(0, 10);
    bonusStreak++;
    me['coins'] = (me['coins'] as int) + 5;
    return {'coins': me['coins'], 'got': 5, 'streak': bonusStreak};
  }

  // ---- albums ----

  final albumRows = <int, Map<String, dynamic>>{
    1: {'id': 1, 'owner': 'u2', 'title': 'სვანეთი 2026', 'about': 'ლაშქრობა უშგულამდე', 'audience': 'friends', 'photos': 2},
    2: {'id': 2, 'owner': 'u1', 'title': 'ნინოს დაბადების დღე', 'about': null, 'audience': 'members', 'photos': 1},
  };
  final albumPics = <int, List<Map<String, dynamic>>>{
    1: [
      {'id': 11, 'added_by': 'u2', 'url': 'https://t/hills.jpg', 'md': 'https://t/hills.jpg', 'sm': 'https://t/hills.jpg', 'created_at': DateTime.now().subtract(const Duration(days: 3)).toUtc().toIso8601String()},
      {'id': 12, 'added_by': 'u1', 'url': 'https://t/sea.jpg', 'md': 'https://t/sea.jpg', 'sm': 'https://t/sea.jpg', 'created_at': DateTime.now().subtract(const Duration(days: 2)).toUtc().toIso8601String()},
    ],
    2: [
      {'id': 21, 'added_by': 'u1', 'url': 'https://t/food.jpg', 'md': 'https://t/food.jpg', 'sm': 'https://t/food.jpg', 'created_at': DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String()},
    ],
  };
  final albumPeople = <int, List<String>>{
    1: ['u1', 'u3'],
    2: ['u4'],
  };
  var _albumId = 10, _albumPic = 100;

  Album _album(Map<String, dynamic> r) => Album(
        id: r['id'] as int,
        owner: '${r['owner']}',
        title: '${r['title']}',
        cover: albumPics[r['id']]?.firstOrNull?['sm'] as String?,
        photos: albumPics[r['id']]?.length ?? 0,
        updatedAt: DateTime.now().subtract(Duration(days: r['id'] as int)),
      );

  @override
  Future<(List<Album>, List<Album>, List<Album>)> albumsPage() async {
    final all = albumRows.values.map(_album).toList();
    return (
      all.where((a) => a.owner == myId).toList(),
      all.where((a) => a.owner != myId && (albumPeople[a.id] ?? const []).contains(myId)).toList(),
      all.where((a) => a.owner != myId && !(albumPeople[a.id] ?? const []).contains(myId)).toList(),
    );
  }

  @override
  Future<Map<String, dynamic>?> album(int id) async => albumRows[id] == null ? null : {...albumRows[id]!, 'photos': albumPics[id]?.length ?? 0};
  @override
  Future<List<Map<String, dynamic>>> albumPhotos(int id) async => [...?albumPics[id]];
  @override
  Future<List<String>> albumMembers(int id) async => [...?albumPeople[id]];
  @override
  Future<bool> albumCanAdd(int id) async => albumRows[id]?['owner'] == myId || (albumPeople[id] ?? const []).contains(myId);

  @override
  Future<int> createAlbum(String title, String? about, String audience) async {
    final id = ++_albumId;
    calls.add('album new $title $audience');
    albumRows[id] = {'id': id, 'owner': myId, 'title': title, 'about': about, 'audience': audience, 'photos': 0};
    return id;
  }

  @override
  Future<void> updateAlbum(int id, String title, String? about, String audience) async {
    calls.add('album edit $id $title');
    albumRows[id] = {...albumRows[id]!, 'title': title, 'about': about, 'audience': audience};
  }

  @override
  Future<void> deleteAlbum(int id) async {
    calls.add('album delete $id');
    albumRows.remove(id);
  }

  @override
  Future<Map<String, dynamic>> addAlbumPhoto(int id, Media m) async {
    calls.add('album photo $id');
    final row = {'id': ++_albumPic, 'added_by': myId, 'url': m.url, 'md': m.md ?? m.url, 'sm': m.sm ?? m.url, 'created_at': DateTime.now().toUtc().toIso8601String()};
    (albumPics[id] ??= []).insert(0, row);
    return row;
  }

  @override
  Future<void> deleteAlbumPhoto(int photoId) async {
    calls.add('album photo delete $photoId');
    for (final l in albumPics.values) {
      l.removeWhere((r) => r['id'] == photoId);
    }
  }

  @override
  Future<void> inviteToAlbum(int id, List<String> uids) async {
    calls.add('album invite $id ${uids.join(',')}');
    (albumPeople[id] ??= []).addAll(uids);
  }

  @override
  Future<void> removeFromAlbum(int id, String uid) async {
    calls.add('album remove $id $uid');
    albumPeople[id]?.remove(uid);
  }

  // ---- CV, education ----

  Map<String, dynamic>? savedCv;
  @override
  Future<void> saveCv(Map<String, dynamic> cv) async {
    calls.add('cv ${cv['headline']}');
    savedCv = cv;
  }

  @override
  Future<List<int>> joinEduGroups() async {
    calls.add('edu groups');
    return const [5, 6];
  }

  @override
  Future<List<Profile>> classmates(String k, String key) async {
    calls.add('mates $k $key');
    if (k != 'school') return const [];
    Profile with_(Profile p, int y1, String cls) => Profile(
          id: p.id,
          name: p.name,
          surname: p.surname,
          username: p.username,
          city: p.city,
          hue: p.hue,
          edu: [
            {'k': 'school', 'n': '41-ე საჯარო სკოლა', 'c': 'ქუთაისი', 'y1': y1, 'cls': cls, 'key': key},
          ],
        );
    return [with_(tamar, 2017, 'ა'), with_(luka, 2015, 'ბ')];
  }

  // ---- family tree, surnames ----

  final kinRows = <Map<String, dynamic>>[
    {'id': 1, 'owner': 'u1', 'anchor': null, 'relative': null, 'name': 'მანანა ბერიძე', 'relation': 'parent', 'sex': 'f', 'born': 1968, 'died': null, 'status': 'ok'},
    {'id': 2, 'owner': 'u1', 'anchor': 1, 'relative': null, 'name': 'ვახტანგ ბერიძე', 'relation': 'parent', 'sex': 'm', 'born': 1940, 'died': 2015, 'status': 'ok'},
    {'id': 3, 'owner': 'u1', 'anchor': null, 'relative': 'u4', 'name': null, 'relation': 'sibling', 'sex': 'm', 'born': null, 'died': null, 'status': 'pending'},
  ];
  final kinPend = <Map<String, dynamic>>[
    {'id': 50, 'owner': 'u3', 'relation': 'sibling'},
  ];
  var _kinId = 20;

  @override
  Future<List<Map<String, dynamic>>> kinOf(String uid) async => [for (final r in kinRows) if (r['owner'] == uid) {...r}];
  @override
  Future<List<Map<String, dynamic>>> kinRequests() async => [...kinPend];
  @override
  Future<void> addKin(Map<String, dynamic> row) async {
    calls.add('kin ${row['relation']} ${row['relative'] ?? row['name']}');
    kinRows.add({'id': ++_kinId, 'owner': myId, 'status': row['relative'] != null ? 'pending' : 'ok', 'name': null, 'relative': null, 'sex': null, 'born': null, 'died': null, ...row});
  }

  @override
  Future<void> updateKin(int id, Map<String, dynamic> fields) async {
    calls.add('kin edit $id ${fields['name']}');
    final r = kinRows.firstWhere((x) => x['id'] == id);
    r.addAll(fields);
  }

  @override
  Future<void> deleteKin(int id) async {
    calls.add('kin delete $id');
    final gone = {id};
    var grew = true;
    while (grew) {
      grew = false;
      for (final r in kinRows) {
        if (gone.contains(r['anchor']) && gone.add(r['id'] as int)) grew = true;
      }
    }
    kinRows.removeWhere((r) => gone.contains(r['id']));
  }

  @override
  Future<void> respondKin(int id, bool accept) async {
    calls.add('kin answer $id $accept');
    kinPend.removeWhere((r) => r['id'] == id);
  }

  @override
  Future<List<Profile>> surnamePeople(String s) async => everyone.where((p) => p.surname == s || (p.id == myId && me['surname'] == s)).toList();
  int? surnameGroupId;
  @override
  Future<int?> surnameGroup(String s) async => surnameGroupId;
  @override
  Future<int> joinSurnameGroup() async {
    calls.add('surname group');
    return surnameGroupId ??= 77;
  }

  // ---- verification ----

  String? verifyState;
  @override
  Future<String?> verification() async => verifyState;
  @override
  Future<void> requestVerification(Uint8List selfie) async {
    calls.add('verify ${selfie.length}');
    verifyState = 'pending';
  }
}
