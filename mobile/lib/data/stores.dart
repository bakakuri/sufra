import 'dart:async';

import 'package:flutter/material.dart';

import '../profile/profile.dart';
import 'api.dart';
import 'models.dart';

/// People already loaded, so names and pictures show at once everywhere.
class People extends ChangeNotifier {
  People(this.api);
  final PeeraApi api;
  final _m = <String, Profile>{};

  Profile? operator [](String id) => _m[id];
  void put(Profile p) => _m[p.id] = p;

  Future<void> ensure(Iterable<String> ids) async {
    final miss = ids.where((i) => i.isNotEmpty && !_m.containsKey(i)).toSet().toList();
    if (miss.isEmpty) return;
    try {
      for (final p in await api.people(miss)) {
        _m[p.id] = p;
      }
      notifyListeners();
    } catch (_) {}
  }
}

/// Reactions, votes, saves and comment counts of every post on screen; a change shows on every card of that post.
class PostStore extends ChangeNotifier {
  PostStore(this.api);
  final PeeraApi api;
  final _s = <int, PostStats>{};

  PostStats of(int id) => _s[id] ??= PostStats();

  Future<void> load(Iterable<Post> posts) async {
    final ids = <int>{};
    for (final p in posts) {
      ids.add(p.id);
      if (p.original != null) ids.add(p.original!.id);
    }
    if (ids.isEmpty) return;
    try {
      _s.addAll(await api.stats(ids.toList()));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> react(int id, String? e) async {
    final s = of(id), old = s.mine;
    s.setReaction(e);
    notifyListeners();
    try {
      await api.react(id, e);
    } catch (_) {
      s.setReaction(old);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> vote(int id, int opt) async {
    final s = of(id);
    s.setVote(opt);
    notifyListeners();
    await api.vote(id, opt);
  }

  Future<void> save(int id) async {
    final s = of(id);
    s.saved = !s.saved;
    notifyListeners();
    try {
      await api.save(id, s.saved);
    } catch (_) {
      s.saved = !s.saved;
      notifyListeners();
      rethrow;
    }
  }

  void commented(int id, [int n = 1]) {
    of(id).comments += n;
    notifyListeners();
  }
}

/// My friendships: friends, requests to me, requests from me.
class FriendStore extends ChangeNotifier {
  FriendStore(this.api, this.people);
  final PeeraApi api;
  final People people;
  List<Rel> rels = [];
  bool loaded = false;

  String get _me => api.myId;
  List<String> get friends => [for (final r in rels) if (r.accepted) r.otherThan(_me)];
  List<String> get incoming => [for (final r in rels) if (!r.accepted && r.addressee == _me) r.requester];
  List<String> get outgoing => [for (final r in rels) if (!r.accepted && r.requester == _me) r.addressee];

  Friendship stateWith(String uid) {
    for (final r in rels) {
      if (r.requester == uid || r.addressee == uid) {
        if (r.accepted) return Friendship.friends;
        return r.requester == _me ? Friendship.sent : Friendship.received;
      }
    }
    return Friendship.none;
  }

  Future<void> load() async {
    rels = await api.rels();
    loaded = true;
    notifyListeners();
    await people.ensure(rels.map((r) => r.otherThan(_me)));
  }

  Future<void> add(String uid) async {
    if (stateWith(uid) == Friendship.received) return accept(uid);
    rels = [...rels, Rel(_me, uid, false)];
    notifyListeners();
    try {
      await api.addFriend(uid);
    } catch (_) {
      await load();
      rethrow;
    }
  }

  Future<void> accept(String uid) async {
    rels = [for (final r in rels) r.requester == uid && r.addressee == _me ? Rel(uid, _me, true) : r];
    notifyListeners();
    try {
      await api.acceptFriend(uid);
    } catch (_) {
      await load();
      rethrow;
    }
  }

  /// unfriend, take back a request, or turn one down
  Future<void> remove(String uid) async {
    rels = [for (final r in rels) if (r.otherThan(_me) != uid) r];
    notifyListeners();
    try {
      await api.removeFriend(uid);
    } catch (_) {
      await load();
      rethrow;
    }
  }
}

/// The conversations and the unread count for the tab's badge; kept fresh by my notifications.
class ChatStore extends ChangeNotifier {
  ChatStore(this.api, this.people);
  final PeeraApi api;
  final People people;
  List<Chat> chats = [];
  bool loaded = false;
  Object? error;

  /// the conversation on screen: its messages are read as they come
  int? open;

  int get unread => chats.where((c) => !c.muted && c.convId != open).fold(0, (a, c) => a + c.unread);

  Future<void> load() async {
    try {
      final list = await api.chats();
      chats = list;
      for (final c in chats) {
        if (c.convId == open) c.unread = 0;
      }
      loaded = true;
      error = null;
      notifyListeners();
      await people.ensure(list.expand((c) => c.members));
    } catch (e) {
      error = e;
      loaded = true;
      notifyListeners();
    }
  }

  void opened(int conv) {
    open = conv;
    for (final c in chats) {
      if (c.convId == conv) c.unread = 0;
    }
    notifyListeners();
    api.markRead(conv).catchError((_) {});
  }

  void closed(int conv) {
    if (open == conv) open = null;
    api.markRead(conv).catchError((_) {});
    load();
  }
}

/// Everything the signed-in screens share. Made once per sign-in, by the shell.
class AppState {
  AppState(this.api)
      : people = People(api),
        posts = PostStore(api) {
    friends = FriendStore(api, people);
    chats = ChatStore(api, people);
  }

  final PeeraApi api;
  final People people;
  final PostStore posts;
  late final FriendStore friends;
  late final ChatStore chats;
  StreamSubscription<Map<String, dynamic>>? _notes;
  Timer? _seen;

  void start() {
    chats.load();
    friends.load().catchError((_) {});
    _notes = api.liveNotes().listen((n) {
      final k = n['kind'];
      if (k == 'message') chats.load();
      if (k == 'friend_req' || k == 'friend_ok') friends.load().catchError((_) {});
    }, onError: (_) {});
    api.touchSeen().catchError((_) {});
    _seen = Timer.periodic(const Duration(minutes: 2), (_) => api.touchSeen().catchError((_) {}));
  }

  void dispose() {
    _notes?.cancel();
    _seen?.cancel();
    people.dispose();
    posts.dispose();
    friends.dispose();
    chats.dispose();
  }
}

/// Makes [AppState] and the signed-in person reachable from any screen below.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.app, required this.me, required super.child});
  final AppState app;
  final Profile me;

  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) => app != old.app || me != old.me;
}

extension AppScopeX on BuildContext {
  AppState get app => AppScope.of(this).app;
  Profile get me => AppScope.of(this).me;
}

/// Opens a screen one step deeper. Inside the tab (its bar stays) or, with [full], over the whole app — a
/// conversation, a post with its comments, writing a post. The back button closes exactly that one screen.
Future<T?> openPage<T>(BuildContext context, Widget page, {bool full = false}) {
  final s = AppScope.of(context);
  return Navigator.of(context, rootNavigator: full).push<T>(
    MaterialPageRoute(builder: (_) => AppScope(app: s.app, me: s.me, child: page)),
  );
}
