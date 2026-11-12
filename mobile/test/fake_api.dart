import 'dart:async';

import 'package:peera/data/api.dart';
import 'package:peera/data/models.dart';
import 'package:peera/data/photos.dart';
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
  final notes = StreamController<Map<String, dynamic>>.broadcast();
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
  Stream<Map<String, dynamic>> liveNotes() => notes.stream;
  @override
  Future<void> touchSeen() async {}
  @override
  Future<void> savePushToken(String token) async => calls.add('push+ $token');
  @override
  Future<void> removePushToken(String token) async => calls.add('push- $token');
}
