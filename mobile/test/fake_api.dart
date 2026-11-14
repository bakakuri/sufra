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
      _p(101, giorgi, ago(12), 'მცხეთიდან დაბრუნებისას ასეთი მზის ჩასვლა დაგვხვდა 🌄 #საქართველო', [img('sunset', 640, 480), img('hills', 480, 600)], tags: const ['საქართველო']),
      _p(102, mariam, ago(130),
          'დღეს პირველად ვცადე ქართული ტრადიციული პურის გამოცხობა თონეში. ბებიამ მასწავლა ყველაფერი: როგორ მოვზილო ცომი, რამდენ ხანს დავტოვო ამოსასვლელად და როგორ მივაკრა თონის კედელზე ისე, რომ არ ჩამოვარდეს.\n\nპირველი ორი ჩამომივარდა 😅 მაგრამ მესამე უკვე იდეალური გამოვიდა.\n\nვინც გინდათ, რეცეპტს გამოგიგზავნით!', const []),
      _p(103, luka, ago(300), 'ამინდი კარგი იქნება, სადმე წავიდეთ ☀️', const [], poll: const Poll('შაბათს სად წავიდეთ?', ['ზღვაზე', 'მთაში', 'ქალაქში დავრჩეთ'])),
      _p(104, ana, ago(420), '', const [], repostOf: 105),
      _p(106, nino, ago(60 * 26), 'ახალი აპი ვცადე! 📱 სულ სხვა სისწრაფეა', [img('sea', 640, 480)]),
      _p(107, giorgi, ago(60 * 50), 'სვანეთი, უშგული 🏔️ #მთა', [img('hills', 480, 600)], tags: const ['მთა']),
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
    _comments[106] = [
      Comment(id: 20, postId: 106, author: tamar.id, ap: tamar, body: 'Looks amazing! Which app is this?', createdAt: ago(60 * 20), likes: 1),
      Comment(id: 21, postId: 106, author: luka.id, ap: luka, body: '🥟 ხინკალი', createdAt: ago(60 * 19), sticker: 'khinkali'),
      Comment(id: 22, postId: 106, author: mariam.id, ap: mariam, body: 'gamarjoba, rogor xar? dzalian lamazia', createdAt: ago(60 * 18)),
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
      Story(
        id: 405,
        author: mariam.id,
        url: 'https://t/sunset.jpg',
        createdAt: ago(100),
        poll: const {'q': 'ზღვა თუ მთა?', 'opts': ['ზღვა', 'მთა']},
        stickers: [
          {'t': 'place', 'name': 'ბათუმი', 'x': .5, 'y': .2},
          {'t': 'ask', 'q': 'სად წავიდეთ?', 'x': .5, 'y': .35},
        ],
      ),
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

  Post _p(int id, Profile who, DateTime at, String body, List<Media> media, {Poll? poll, int? repostOf, List<String> tags = const []}) =>
      Post(id: id, author: who.id, ap: who, createdAt: at, cursor: at.toIso8601String(), body: body, media: media, poll: poll, repostOf: repostOf, tags: tags);

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
  Future<Comment> addComment(int postId, String body, {int? parentId, Map<String, dynamic>? media}) async {
    calls.add('comment $postId $body${parentId == null ? '' : ' ↩$parentId'}${media == null ? '' : ' ${media['sticker'] ?? 'photo'}'}');
    final c = Comment(
        id: _id++,
        postId: postId,
        author: nino.id,
        ap: nino,
        body: body,
        createdAt: DateTime.now(),
        parentId: parentId,
        media: media == null ? null : Media.fromJson(media),
        sticker: media?['sticker'] as String?);
    (_comments[postId] ??= []).add(c);
    return c;
  }

  @override
  Future<Media> uploadPhoto(PreparedPhoto p) async {
    calls.add('upload ${p.w}x${p.h}');
    return img('hills', p.w, p.h);
  }

  @override
  Future<Post> createPost(String body, List<Media> media,
      {Poll? poll, int? placeId, bool draft = false, DateTime? publishAt, int? repostOf, int? groupId, int? pageId}) async {
    calls.add('post $body ${media.length}${poll != null ? ' poll ${poll.q} ${poll.opts.join('/')}' : ''}'
        '${placeId != null ? ' place $placeId' : ''}${draft ? ' draft' : ''}${publishAt != null ? ' at' : ''}${repostOf != null ? ' quote $repostOf' : ''}'
        '${groupId != null ? ' group $groupId' : ''}${pageId != null ? ' page $pageId' : ''}');
    final p = _p(_id++, nino, DateTime.now(), body, media, poll: poll, repostOf: repostOf);
    if (!draft && publishAt == null) _posts.insert(0, p);
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
  Future<Message> send(int convId, {String body = '', String kind = 'text', Map<String, dynamic>? media, int? replyTo}) async {
    calls.add('send $convId $kind $body${replyTo == null ? '' : ' ↩$replyTo'}${media?['fwd'] != null ? ' fwd ${media!['fwd']}' : ''}${media?['sticker'] != null ? ' sticker ${media!['sticker']}' : ''}${media?['loc'] != null ? ' loc' : ''}');
    final m = Message(id: _id++, convId: convId, sender: nino.id, body: body, kind: kind, media: media, replyTo: replyTo, createdAt: DateTime.now());
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
  Future<void> addStory(String url, {bool video = false, int? postId, bool close = false, Map<String, dynamic>? poll, List<Map<String, dynamic>>? stickers}) async {
    calls.add('story $url${postId == null ? '' : ' post $postId'}${close ? ' close' : ''}${poll != null ? ' poll ${(poll['opts'] as List).join('/')}' : ''}'
        '${stickers != null && stickers.isNotEmpty ? ' stickers ${stickers.map((x) => x['t']).join(',')}' : ''}');
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

  // ---- the home page ----

  Map<String, dynamic> settings = {};
  @override
  Future<Map<String, dynamic>> appSettings() async => settings;

  Map<String, int> svcCounts = {'albums': 2, 'groups': 14, 'events': 3, 'rooms': 2, 'jobs': 9, 'places': 31};
  @override
  Future<Map<String, int>> serviceCounts() async => svcCounts;

  final tagF = <String>{};
  @override
  Future<Set<String>> tagFollows() async => {...tagF};
  @override
  Future<void> followTags(List<String> tags, bool on) async {
    calls.add('tags ${on ? '+' : '-'}${tags.join(',')}');
    if (on) {
      tagF.addAll(tags);
    } else {
      tagF.removeAll(tags);
    }
  }

  @override
  Future<List<Post>> feedTagged(List<String> tags, {int limit = 5}) async =>
      [..._posts, ..._orig.values].where((p) => p.tags.any(tags.contains)).take(limit).toList();

  /// posts not in the feed (memories from earlier years)
  final oldPosts = <int, Post>{};

  /// one of my posts from this day [years] ago, among today's memories
  void memory(int id, int years, String body) {
    final n = DateTime.now();
    oldPosts[id] = _p(id, nino, DateTime(n.year - years, n.month, n.day, 10), body, const []);
    memoryIds.add(id);
  }
  @override
  Future<List<Post>> postsByIds(List<int> ids) async => [
        for (final id in ids)
          if (_posts.where((p) => p.id == id).firstOrNull ?? oldPosts[id] ?? _orig[id] case final p?) p,
      ];

  final promoRows = <Map<String, dynamic>>[];
  @override
  Future<List<Map<String, dynamic>>> promos() async => [...promoRows];
  @override
  Future<void> promoHit(int id, {bool click = false}) async => calls.add('promo $id${click ? ' click' : ''}');

  /// paid posts: the ad's id and the post's
  final adRows = <(int, int)>[];
  @override
  Future<List<(int, Post)>> adPosts() async => [
        for (final (ad, pid) in adRows)
          if (_posts.where((p) => p.id == pid).firstOrNull ?? _orig[pid] case final p?) (ad, p),
      ];
  @override
  Future<void> adImpression(int adId) async => calls.add('ad $adId');

  final bdays = <Map<String, dynamic>>[];
  @override
  Future<List<Map<String, dynamic>>> friendBirthdays() async => [...bdays];

  final memoryIds = <int>[];
  @override
  Future<List<int>> myMemories() async => [...memoryIds];

  int fsPeople = 2;
  bool fsPosted = true;
  @override
  Future<(int, bool)> firstStepsCounts() async => (fsPeople, fsPosted);

  int? welcome;
  @override
  Future<int?> welcomeGift() async => welcome;

  @override
  Future<Map<String, int>> inviteRules() async => const {'welcome': 100, 'invite': 50};
  @override
  Future<(int, int)> referrals() async => (3, 2);

  // ---------- posts: sharing, editing, comments, tags, search ----------
  final liked = <int>{3};
  @override
  Future<Map<int, (int, int?)>> repostStats(List<int> ids) async => {for (final i in ids) i: i == 101 ? (3, null) : (0, null)};
  @override
  Future<int> repost(int postId) async {
    calls.add('repost $postId');
    return _id++;
  }

  @override
  Future<void> unrepost(int repostId) async => calls.add('unrepost $repostId');
  @override
  Future<Post> updatePost(int id, String body, {List<Media>? media, int? placeId, bool setPlace = false}) async {
    calls.add('edit $id $body ${media?.length}${setPlace ? ' place $placeId' : ''}');
    final old = _posts.firstWhere((p) => p.id == id);
    final n = Post(id: id, author: old.author, ap: old.ap, createdAt: old.createdAt, cursor: old.cursor, body: body, media: media ?? old.media, poll: old.poll, edited: true, repostOf: old.repostOf, tags: old.tags);
    n.original = old.original;
    _posts[_posts.indexOf(old)] = n;
    return n;
  }

  @override
  Future<void> modHide(String type, int id, bool hidden) async => calls.add('modhide $type $id $hidden');
  @override
  Future<void> saveToFolder(int postId, int? folder) async => calls.add('folder $postId $folder');
  @override
  Future<(int, String)> newFolder(String name) async {
    calls.add('newfolder $name');
    return (77, name);
  }

  @override
  Future<(String, String?)> translate(String text, String source, String target) async {
    calls.add('translate $source');
    return ('ნათარგმნი: $text', source);
  }

  @override
  Future<Set<int>> commentLikes(List<int> ids) async => {...liked.where(ids.contains)};
  @override
  Future<void> likeComment(int id, bool on) async {
    calls.add('clike $id $on');
    on ? liked.add(id) : liked.remove(id);
  }

  @override
  Future<void> deleteComment(int id) async {
    calls.add('cdel $id');
    for (final l in _comments.values) {
      l.removeWhere((c) => c.id == id || c.parentId == id);
    }
  }

  @override
  Future<List<Profile>> mentionPeople(String prefix) async => everyone.where((p) => p.id != nino.id && (p.username ?? '').startsWith(prefix)).take(6).toList();
  @override
  Future<Profile?> personByUsername(String username) async => everyone.where((p) => p.username == username).firstOrNull;
  @override
  Future<List<Post>> postsTagged(String tag, {int limit = 40}) async => _posts.where((p) => p.tags.contains(tag)).toList();
  @override
  Future<List<(String, int)>> trendingTags() async => const [('საქართველო', 12), ('მთა', 7), ('ზამთარი', 4)];
  @override
  Future<List<Post>> searchPosts(String q) async => _posts.where((p) => p.body.contains(q)).toList();
  @override
  Future<List<Map<String, dynamic>>> searchPages(String q) async => [
        for (final g in const [
          {'id': 1, 'name': 'Peera სიახლეები', 'kind': 'channel', 'hue': 200, 'verified': true, 'category': 'სიახლეები'},
          {'id': 2, 'name': 'მთის ამბები', 'kind': 'business', 'hue': 120, 'category': 'ტურიზმი'},
        ])
          if ('${g['name']}'.contains(q)) g,
      ];
  @override
  Future<List<Map<String, dynamic>>> searchGroups(String q) async => [
        for (final g in const [
          {'id': 5, 'name': 'მთის მოყვარულები', 'hue': 150, 'is_private': false, 'description': 'ლაშქრობები ყოველ შაბათს'},
          {'id': 6, 'name': 'თსუ სტუდენტები', 'hue': 30, 'is_private': true},
        ])
          if ('${g['name']}'.contains(q)) g,
      ];
  @override
  Future<List<Map<String, dynamic>>> findPlaces(String q, {double? lat, double? lng}) async => [
        for (final p in const [
          {'id': 9, 'name': 'ჯვრის მონასტერი', 'kind': 'sight', 'city': 'მცხეთა', 'km': 12.4},
          {'id': 10, 'name': 'ფაბრიკა', 'kind': 'cafe', 'city': 'თბილისი', 'km': 0.8},
        ])
          if (q.isEmpty || '${p['name']}'.contains(q)) p,
      ];

  // ---------- chat in full ----------
  final msgReacts = <int, Map<String, String>>{
    509: {'u2': '❤️'},
  };
  int? pinnedMsg = 507;
  int? chatTtl;
  final reactLive = StreamController<(int, String, String?)>.broadcast();
  final typingLive = StreamController<String>.broadcast();
  @override
  Future<Map<int, Map<String, String>>> messageReactions(List<int> ids) async => {for (final i in ids) if (msgReacts[i] != null) i: {...msgReacts[i]!}};
  @override
  Future<void> reactMessage(int id, String? emoji, {bool had = false}) async {
    calls.add('mreact $id $emoji');
    emoji == null ? msgReacts[id]?.remove(nino.id) : (msgReacts[id] ??= {})[nino.id] = emoji;
  }

  @override
  Stream<(int, String, String?)> liveReactions(int convId) => reactLive.stream;
  @override
  Stream<String> typing(int convId) => typingLive.stream;
  @override
  void sendTyping(int convId) => calls.add('typing $convId');
  @override
  Future<void> editMessage(int id, String body) async => calls.add('medit $id $body');
  @override
  Future<void> unsendMessage(int id) async => calls.add('unsend $id');
  @override
  Future<Message?> message(int id) async => _msgs.values.expand((l) => l).where((m) => m.id == id).firstOrNull;
  @override
  Future<(int?, int?)> chatMeta(int convId) async => convId == 1 ? (pinnedMsg, chatTtl) : (null, null);
  @override
  Future<void> pinMessage(int convId, int? id) async {
    calls.add('pin $convId $id');
    pinnedMsg = id;
  }

  @override
  Future<void> setChatTtl(int convId, int? seconds) async {
    calls.add('ttl $convId $seconds');
    chatTtl = seconds;
  }

  @override
  Future<Map<String, DateTime?>> chatSeen(int convId) async => {giorgi.id: DateTime.now()};
  @override
  Future<void> muteChat(int convId, DateTime? until) async => calls.add('mute $convId ${until == null ? 'off' : 'on'}');
  @override
  Future<void> archiveChat(int convId, bool on) async => calls.add('archive $convId $on');
  @override
  Future<List<Message>> searchMessages(int convId, String q) async => [for (final m in _msgs[convId] ?? const <Message>[]) if (m.body.contains(q)) m];
  @override
  Future<({List<Message> photos, List<Message> links, List<Message> places})> chatMedia(int convId) async =>
      (photos: [for (final m in _msgs[convId] ?? const <Message>[]) if (m.kind == 'image') m], links: <Message>[], places: <Message>[]);
  @override
  Future<int> createGroupChat(String title, List<String> members) async {
    calls.add('group $title ${members.join(',')}');
    _chats.insert(0, Chat(convId: 30, isGroup: true, title: title, members: members, lastAt: DateTime.now()));
    return 30;
  }

  @override
  Future<void> addToGroupChat(int convId, List<String> members) async => calls.add('gadd $convId ${members.join(',')}');
  @override
  Future<void> renameGroupChat(int convId, String title) async => calls.add('grename $convId $title');
  @override
  Future<void> leaveGroupChat(int convId) async => calls.add('gleave $convId');
  @override
  Future<Map<int, int>> streaks() async => {1: 12};

  // ---------- story polls ----------
  final storyVotes = <int, Map<String, int>>{};
  @override
  Future<({int? mine, int total, List<int> counts})?> storyPoll(int id) async {
    final v = storyVotes[id] ?? const <String, int>{};
    final opts = storyList.where((x) => x.id == id).firstOrNull?.pollOpts ?? const <String>[];
    return (mine: v[nino.id], total: v.length, counts: [for (var i = 0; i < opts.length; i++) v.values.where((x) => x == i).length]);
  }

  @override
  Future<void> voteStory(int id, int opt) async {
    calls.add('svote $id $opt');
    (storyVotes[id] ??= {giorgi.id: 0})[nino.id] = opt;
  }

  @override
  Future<Map<String, int>> storyVoters(int id) async => {...?storyVotes[id]};

  // ---------- my data, my account ----------
  @override
  Future<Map<String, dynamic>> exportMyData() async {
    calls.add('export');
    return {'profile': {'id': nino.id, 'name': nino.name}, 'posts': [for (final p in _posts) if (p.author == nino.id) {'id': p.id, 'body': p.body}]};
  }

  @override
  Future<void> deleteAccount() async => calls.add('delete account');

  // ---------- groups and pages ----------
  String _at(int minutes) => DateTime.now().subtract(Duration(minutes: minutes)).toIso8601String();
  final groupRows = <Map<String, dynamic>>[
    {'id': 5, 'name': 'მთის მოყვარულები', 'hue': 150, 'is_private': false, 'description': 'ლაშქრობები ყოველ შაბათს', 'owner': 'u2', 'rules': '1. პატივი ეცით ერთმანეთს.', 'join_mode': 'open', 'kind': null},
    {'id': 6, 'name': 'თსუ სტუდენტები', 'hue': 30, 'is_private': true, 'description': 'თბილისის უნივერსიტეტი', 'owner': 'u3', 'join_mode': 'request', 'kind': 'uni'},
    {'id': 7, 'name': 'მე-11 ბ', 'hue': 260, 'is_private': true, 'description': 'ქუთაისის მე-2 სკოლა', 'owner': 'u1', 'join_mode': 'request', 'post_approval': true, 'kind': 'class'},
  ];
  final groupIn = <int>{7};
  final groupAdmins = <int, Set<String>>{7: {}};
  final pageRows = <Map<String, dynamic>>[
    {'id': 1, 'name': 'Peera სიახლეები', 'kind': 'channel', 'hue': 200, 'verified': true, 'category': 'სიახლეები', 'owner': 'u2', 'description': 'რა არის ახალი Peera-ზე'},
    {'id': 2, 'name': 'მთის ამბები', 'kind': 'business', 'hue': 120, 'category': 'ტურიზმი', 'owner': 'u1', 'description': 'ტურები სვანეთში'},
  ];
  final pageFollows = <int>{1};
  @override
  Future<(Set<int>, List<Map<String, dynamic>>)> groups() async => ({...groupIn}, [for (final g in groupRows) {...g}]);
  @override
  Future<({Map<String, dynamic> g, int count, String? role, String? request})?> group(int id) async {
    final g = groupRows.where((x) => x['id'] == id).firstOrNull;
    if (g == null) return null;
    final role = g['owner'] == nino.id ? 'owner' : (groupAdmins[id]?.contains(nino.id) == true ? 'admin' : (groupIn.contains(id) ? 'member' : null));
    return (g: {...g}, count: 12 + (groupIn.contains(id) ? 1 : 0), role: role, request: calls.contains('greq $id') && !calls.contains('greqx $id') ? 'pending' : null);
  }

  @override
  Future<List<Post>> groupPosts(int id) async => id == 5 ? [_posts.firstWhere((p) => p.id == 107)] : [];
  @override
  Future<int> createGroup({required String name, String description = '', bool private = false, String? avatarUrl}) async {
    calls.add('newgroup $name $private');
    groupRows.add({'id': 40, 'name': name, 'hue': 10, 'is_private': private, 'description': description, 'owner': nino.id, 'join_mode': 'open'});
    groupIn.add(40);
    return 40;
  }

  @override
  Future<void> updateGroup(int id, Map<String, dynamic> changes) async {
    calls.add('gupdate $id ${changes.keys.join(',')}');
    groupRows.firstWhere((x) => x['id'] == id).addAll(changes);
  }

  @override
  Future<void> deleteGroup(int id) async {
    calls.add('gdelete $id');
    groupRows.removeWhere((x) => x['id'] == id);
  }

  @override
  Future<void> joinGroup(int id) async {
    calls.add('gjoin $id');
    groupIn.add(id);
  }

  @override
  Future<void> leaveGroup(int id) async {
    calls.add('gleave $id');
    groupIn.remove(id);
  }

  @override
  Future<void> requestGroup(int id, String? note) async => calls.add('greq $id');
  @override
  Future<void> cancelGroupRequest(int id) async => calls.add('greqx $id');
  @override
  Future<List<Map<String, dynamic>>> groupRequests(int id) async => [
        {'user_id': luka.id, 'note': 'მე-11 ბ-ში ვსწავლობდი', 'created_at': _at(60)},
      ];
  @override
  Future<void> groupRespond(int id, String uid, bool accept) async => calls.add('grespond $id $uid $accept');
  @override
  Future<List<Post>> groupPending(int id) async => [_posts.firstWhere((p) => p.id == 102)];
  @override
  Future<void> reviewGroupPost(int postId, bool ok) async => calls.add('greview $postId $ok');
  @override
  Future<List<Map<String, dynamic>>> groupMembers(int id) async => [
        {'user_id': nino.id, 'role': 'admin', 'created_at': _at(9000)},
        {'user_id': giorgi.id, 'role': 'member', 'created_at': _at(8000)},
        {'user_id': mariam.id, 'role': 'member', 'created_at': _at(7000)},
      ];
  @override
  Future<void> setGroupRole(int id, String uid, String role) async => calls.add('grole $id $uid $role');
  @override
  Future<void> kickFromGroup(int id, String uid) async => calls.add('gkick $id $uid');
  @override
  Future<int> groupWaiting(int id) async => 2;
  @override
  Future<List<String>> groupStarostas(int id, String owner) async => [...?groupAdmins[id]];
  @override
  Future<void> claimStarosta(int id) async {
    calls.add('starosta $id');
    (groupAdmins[id] ??= {}).add(nino.id);
  }

  @override
  Future<void> leaveStarosta(int id) async {
    calls.add('starosta- $id');
    groupAdmins[id]?.remove(nino.id);
  }

  @override
  Future<(Set<int>, List<Map<String, dynamic>>)> pages() async => ({...pageFollows}, [for (final p in pageRows) {...p}]);
  @override
  Future<({Map<String, dynamic> p, int count, bool following})?> page(int id) async {
    final p = pageRows.where((x) => x['id'] == id).firstOrNull;
    return p == null ? null : (p: {...p}, count: 340 + (pageFollows.contains(id) ? 1 : 0), following: pageFollows.contains(id));
  }

  @override
  Future<List<Post>> pagePosts(int id) async => [];
  @override
  Future<int> createPage({required String kind, required String name, String category = '', String description = '', String? avatarUrl}) async {
    calls.add('newpage $kind $name');
    pageRows.add({'id': 50, 'name': name, 'kind': kind, 'hue': 40, 'category': category, 'owner': nino.id, 'description': description});
    return 50;
  }

  @override
  Future<void> updatePage(int id, Map<String, dynamic> changes) async {
    calls.add('pupdate $id ${changes['name']}');
    pageRows.firstWhere((x) => x['id'] == id).addAll(changes);
  }

  @override
  Future<void> deletePage(int id) async {
    calls.add('pdelete $id');
    pageRows.removeWhere((x) => x['id'] == id);
  }

  @override
  Future<void> followPage(int id, bool on) async {
    calls.add('pfollow $id $on');
    on ? pageFollows.add(id) : pageFollows.remove(id);
  }

  @override
  Future<void> verifyPage(int id, bool on) async => calls.add('pverify $id $on');
  @override
  Future<List<Map<String, dynamic>>> pageAds(int id) async => [];

  // ---------- events and the market ----------
  final eventRows = <Map<String, dynamic>>[
    {
      'id': 70,
      'title': 'შაბათის სასწავლო შეხვედრა',
      'starts_at': DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String(),
      'place': 'ქუთაისი, ბიბლიოთეკა',
      'host': 'u2',
      'hue': 30,
      'description': 'მოვემზადოთ გამოცდისთვის ერთად',
      'tamada': null,
    },
  ];
  final rsvps = <Map<String, dynamic>>[
    {'event_id': 70, 'user_id': 'u2', 'status': 'yes'},
    {'event_id': 70, 'user_id': 'u3', 'status': 'yes'},
    {'event_id': 70, 'user_id': 'u4', 'status': 'maybe'},
  ];
  final items = <Map<String, dynamic>>[
    {'id': 1, 'event_id': 70, 'name': 'ყავა', 'added_by': 'u2', 'claimed_by': 'u2'},
    {'id': 2, 'event_id': 70, 'name': 'კონსპექტები', 'added_by': 'u2', 'claimed_by': null},
  ];
  final agenda = <Map<String, dynamic>>[];
  final costs = <Map<String, dynamic>>[
    {'id': 1, 'event_id': 70, 'paid_by': 'u2', 'amount': 30, 'what': 'ყავა', 'added_by': 'u2'},
  ];
  final pays = <Map<String, dynamic>>[];
  @override
  Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)> events() async => ([for (final e in eventRows) {...e}], [for (final r in rsvps) {...r}]);
  @override
  Future<(Map<String, dynamic>, List<Map<String, dynamic>>, List<Map<String, dynamic>>)?> event(int id) async {
    final e = eventRows.where((x) => x['id'] == id).firstOrNull;
    if (e == null) return null;
    return ({...e}, [for (final r in rsvps) if (r['event_id'] == id) {...r}], [for (final i in items) if (i['event_id'] == id) {...i}]);
  }

  @override
  Future<void> rsvp(int id, String status) async {
    calls.add('rsvp $id $status');
    rsvps.removeWhere((r) => r['event_id'] == id && r['user_id'] == nino.id);
    rsvps.add({'event_id': id, 'user_id': nino.id, 'status': status});
  }

  @override
  Future<void> addEventItem(int id, String name) async {
    calls.add('item $id $name');
    items.add({'id': _id++, 'event_id': id, 'name': name, 'added_by': nino.id, 'claimed_by': nino.id});
  }

  @override
  Future<void> claimEventItem(int itemId, bool on) async {
    calls.add('claim $itemId $on');
    items.firstWhere((i) => i['id'] == itemId)['claimed_by'] = on ? nino.id : null;
  }

  @override
  Future<void> deleteEventItem(int itemId) async => items.removeWhere((i) => i['id'] == itemId);
  @override
  Future<void> deleteEvent(int id) async {
    calls.add('evdelete $id');
    eventRows.removeWhere((e) => e['id'] == id);
  }

  @override
  Future<int> createEvent({required String title, required DateTime startsAt, required String place, String description = '', String? tamada, int? groupId, List<String> items = const []}) async {
    calls.add('event $title $place ${items.join(',')}${groupId != null ? ' group $groupId' : ''}');
    eventRows.add({'id': 71, 'title': title, 'starts_at': startsAt.toUtc().toIso8601String(), 'place': place, 'host': nino.id, 'hue': 200, 'description': description, 'tamada': tamada});
    rsvps.add({'event_id': 71, 'user_id': nino.id, 'status': 'yes'});
    for (final n in items) {
      this.items.add({'id': _id++, 'event_id': 71, 'name': n, 'added_by': nino.id, 'claimed_by': null});
    }
    return 71;
  }

  @override
  Future<void> setTamada(int id, String? uid) async {
    calls.add('tamada $id $uid');
    eventRows.firstWhere((e) => e['id'] == id)['tamada'] = uid;
  }

  @override
  Future<List<Map<String, dynamic>>> eventAgenda(int id) async => [for (final a in agenda) if (a['event_id'] == id) {...a}];
  @override
  Future<void> addAgenda(int id, List<(String, int?)> rows, int afterPos) async {
    calls.add('agenda $id ${rows.length}');
    for (var i = 0; i < rows.length; i++) {
      agenda.add({'id': _id++, 'event_id': id, 'pos': afterPos + i + 1, 'title': rows[i].$1, 'done': false, 'toast_id': rows[i].$2});
    }
  }

  @override
  Future<void> agendaDone(int rowId, bool done) async {
    calls.add('agdone $rowId $done');
    agenda.firstWhere((a) => a['id'] == rowId)['done'] = done;
  }

  @override
  Future<void> agendaPos(int rowId, int pos) async => agenda.firstWhere((a) => a['id'] == rowId)['pos'] = pos;
  @override
  Future<void> agendaDelete(int rowId) async => agenda.removeWhere((a) => a['id'] == rowId);
  @override
  Future<List<Map<String, dynamic>>> toastBook() async => [
        {'id': 1, 'title': 'მშვიდობის სადღეგრძელო'},
      ];
  @override
  Future<Map<String, dynamic>?> toastText(int id) async => {'title': 'მშვიდობის სადღეგრძელო', 'body': 'გაუმარჯოს მშვიდობას!'};
  @override
  Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)> eventCosts(int id) async =>
      ([for (final c in costs) if (c['event_id'] == id) {...c}], [for (final p in pays) if (p['event_id'] == id) {...p}]);
  @override
  Future<void> addEventCost(int id, String paidBy, double amount, String what) async {
    calls.add('cost $id $paidBy $amount $what');
    costs.add({'id': _id++, 'event_id': id, 'paid_by': paidBy, 'amount': amount, 'what': what, 'added_by': nino.id});
  }

  @override
  Future<void> deleteEventCost(int costId) async => costs.removeWhere((c) => c['id'] == costId);
  @override
  Future<void> addEventPayment(int id, String from, String to, double amount) async {
    calls.add('pay $id $from $to $amount');
    pays.add({'id': _id++, 'event_id': id, 'from_user': from, 'to_user': to, 'amount': amount, 'added_by': nino.id});
  }

  @override
  Future<void> deleteEventPayment(int payId) async => pays.removeWhere((p) => p['id'] == payId);
  @override
  Future<int> inviteToEvent(int id, List<String> users) async {
    calls.add('evinvite $id ${users.join(',')}');
    return users.length;
  }

  @override
  Future<int?> eventAlbum(int id) async => null;
  @override
  Future<int> makeEventAlbum(int id, String title) async {
    calls.add('evalbum $id');
    return 1;
  }

  final listingRows = <Map<String, dynamic>>[
    {'id': 90, 'title': 'ნარდის დაფა', 'price': 45, 'city': 'თბილისი', 'media': [], 'status': 'active', 'seller': 'u2', 'category': 'home', 'created_at': DateTime.now().toIso8601String(), 'description': 'ხის, ხელნაკეთი'},
    {'id': 91, 'title': 'ველოსიპედი', 'price': 300, 'city': 'ქუთაისი', 'media': [], 'status': 'active', 'seller': 'u1', 'category': 'sport', 'created_at': DateTime.now().toIso8601String()},
  ];
  final listingSaves = <int>{};
  @override
  Future<List<Map<String, dynamic>>> listings({String cat = 'all', String q = ''}) async => [
        for (final l in listingRows)
          if ((cat == 'all' || l['category'] == cat) && (q.isEmpty || '${l['title']}'.contains(q))) {...l},
      ];
  @override
  Future<(Map<String, dynamic>, bool)?> listing(int id) async {
    final l = listingRows.where((x) => x['id'] == id).firstOrNull;
    return l == null ? null : ({...l}, listingSaves.contains(id));
  }

  @override
  Future<void> saveListing(int id, bool on) async {
    calls.add('lsave $id $on');
    on ? listingSaves.add(id) : listingSaves.remove(id);
  }

  @override
  Future<void> setListingStatus(int id, String status) async {
    calls.add('lstatus $id $status');
    listingRows.firstWhere((l) => l['id'] == id)['status'] = status;
  }

  @override
  Future<void> deleteListing(int id) async {
    calls.add('ldelete $id');
    listingRows.removeWhere((l) => l['id'] == id);
  }

  @override
  Future<void> createListing({required String title, required double price, required String category, required String city, String description = '', List<Media> media = const []}) async {
    calls.add('listing $title $price $category $city ${media.length}');
    listingRows.insert(0, {'id': 92, 'title': title, 'price': price, 'city': city, 'media': [], 'status': 'active', 'seller': nino.id, 'category': category, 'created_at': DateTime.now().toIso8601String()});
  }

  // ---------- study ----------
  final lessonRows = <Map<String, dynamic>>[
    {'id': 1, 'owner': 'u1', 'title': 'მაკროეკონომიკა', 'kind': 'lecture', 'day': DateTime.now().weekday, 'starts': '00:00', 'ends': '23:59', 'place': 'II კორპუსი, 312', 'teacher': 'ნ. ბერიძე', 'weeks': 'all', 'hue': 250},
    {'id': 2, 'owner': 'u2', 'title': 'სტატისტიკა', 'kind': 'seminar', 'day': DateTime.now().weekday % 7 + 1, 'starts': '12:00', 'ends': '13:30', 'place': '105', 'weeks': 'all', 'hue': 160, 'group_id': 7},
  ];
  final deadlineRows = <Map<String, dynamic>>[
    {'id': 1, 'owner': 'u1', 'kind': 'exam', 'title': 'შუალედური: თავები 1–4', 'subject': 'მაკროეკონომიკა', 'due_at': DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String(), 'notes': 'გავიმეორო გრაფიკები'},
    {'id': 2, 'owner': 'u2', 'kind': 'task', 'title': 'რეფერატი', 'subject': 'ისტორია', 'due_at': DateTime.now().add(const Duration(days: 10)).toUtc().toIso8601String(), 'group_id': 7},
  ];
  final doneIds = <int>{};
  @override
  Future<List<Map<String, dynamic>>> lessons() async => [for (final l in lessonRows) {...l}];
  @override
  Future<Map<String, dynamic>> putLesson(Map<String, dynamic> row) async {
    calls.add('lesson ${row['id'] ?? 'new'} ${row['title']} ${row['day']}${row['group_id'] != null ? ' group ${row['group_id']}' : ''}');
    if (row['id'] != null) {
      final i = lessonRows.indexWhere((l) => l['id'] == row['id']);
      lessonRows[i] = {...lessonRows[i], ...row};
      return lessonRows[i];
    }
    final n = {...row, 'id': _id++, 'owner': nino.id};
    lessonRows.add(n);
    return n;
  }

  @override
  Future<void> deleteLesson(int id) async {
    calls.add('lessondel $id');
    lessonRows.removeWhere((l) => l['id'] == id);
  }

  @override
  Future<List<Map<String, dynamic>>> deadlines() async => [for (final d in deadlineRows) {...d}];
  @override
  Future<Map<String, dynamic>> putDeadline(Map<String, dynamic> row) async {
    calls.add('deadline ${row['id'] ?? 'new'} ${row['kind']} ${row['title']}');
    if (row['id'] != null) {
      final i = deadlineRows.indexWhere((l) => l['id'] == row['id']);
      deadlineRows[i] = {...deadlineRows[i], ...row};
      return deadlineRows[i];
    }
    final n = {...row, 'id': _id++, 'owner': nino.id};
    deadlineRows.add(n);
    return n;
  }

  @override
  Future<void> deleteDeadline(int id) async {
    calls.add('deadlinedel $id');
    deadlineRows.removeWhere((l) => l['id'] == id);
  }

  @override
  Future<Set<int>> deadlinesDone() async => {...doneIds};
  @override
  Future<void> markDeadline(int id, bool done) async {
    calls.add('done $id $done');
    done ? doneIds.add(id) : doneIds.remove(id);
  }

  @override
  Future<List<({int id, String name, String kind, bool admin, bool share})>> studyGroups() async => [
        (id: 7, name: 'მე-11 ბ', kind: 'class', admin: true, share: true),
      ];
  @override
  Future<List<Post>> postsWithTags(List<String> tags, {String q = ''}) async {
    calls.add('tagged ${tags.join('+')}');
    return tags.length == 1 && tags.first == 'კონსპექტი' ? [_posts.firstWhere((p) => p.id == 108)] : <Post>[];
  }
}
