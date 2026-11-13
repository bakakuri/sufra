import 'dart:async';

import 'package:flutter/material.dart';

import '../profile/profile.dart';
import '../push/push.dart';
import 'api.dart';
import 'models.dart';

/// A store that may still be answering the server after sign-out; then it stays quiet.
class Store extends ChangeNotifier {
  bool _gone = false;

  @override
  void dispose() {
    _gone = true;
    super.dispose();
  }

  void changed() {
    if (!_gone) notifyListeners();
  }
}

/// People already loaded, so names and pictures show at once everywhere.
class People extends Store {
  People(this.api);
  final PeeraApi api;
  final _m = <String, Profile>{};

  Profile? operator [](String id) => _m[id];
  void put(Profile p) => _m[p.id] = p;

  /// loads the ones not here yet; with [fresh] all of them again (to see who is online now)
  Future<void> ensure(Iterable<String> ids, {bool fresh = false}) async {
    final miss = ids.where((i) => i.isNotEmpty && (fresh || !_m.containsKey(i))).toSet().toList();
    if (miss.isEmpty) return;
    try {
      for (final p in await api.people(miss)) {
        _m[p.id] = p;
      }
      changed();
    } catch (_) {}
  }
}

/// Reactions, votes, saves and comment counts of every post on screen; a change shows on every card of that post.
class PostStore extends Store {
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
      changed();
    } catch (_) {}
  }

  Future<void> react(int id, String? e) async {
    final s = of(id), old = s.mine;
    s.setReaction(e);
    changed();
    try {
      await api.react(id, e);
    } catch (_) {
      s.setReaction(old);
      changed();
      rethrow;
    }
  }

  Future<void> vote(int id, int opt) async {
    final s = of(id);
    s.setVote(opt);
    changed();
    await api.vote(id, opt);
  }

  Future<void> save(int id) async {
    final s = of(id);
    s.saved = !s.saved;
    changed();
    try {
      await api.save(id, s.saved);
    } catch (_) {
      s.saved = !s.saved;
      changed();
      rethrow;
    }
  }

  void commented(int id, [int n = 1]) {
    of(id).comments += n;
    changed();
  }
}

/// My friendships: friends, requests to me, requests from me.
class FriendStore extends Store {
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
    changed();
    await people.ensure(rels.map((r) => r.otherThan(_me)));
  }

  Future<void> add(String uid) async {
    if (stateWith(uid) == Friendship.received) return accept(uid);
    rels = [...rels, Rel(_me, uid, false)];
    changed();
    try {
      await api.addFriend(uid);
    } catch (_) {
      await load();
      rethrow;
    }
  }

  Future<void> accept(String uid) async {
    rels = [for (final r in rels) r.requester == uid && r.addressee == _me ? Rel(uid, _me, true) : r];
    changed();
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
    changed();
    try {
      await api.removeFriend(uid);
    } catch (_) {
      await load();
      rethrow;
    }
  }
}

/// The conversations and the unread count for the tab's badge; kept fresh by my notifications.
class ChatStore extends Store {
  ChatStore(this.api, this.people);
  final PeeraApi api;
  final People people;
  List<Chat> chats = [];
  bool loaded = false;
  Object? error;

  /// the conversation on screen: its messages are read as they come
  int? open;

  int get unread => chats.where((c) => !c.muted && c.convId != open).fold(0, (a, c) => a + c.unread);

  Future<void> load({bool fresh = false}) async {
    try {
      final list = await api.chats();
      chats = list;
      for (final c in chats) {
        if (c.convId == open) c.unread = 0;
      }
      loaded = true;
      error = null;
      changed();
      await people.ensure(list.expand((c) => c.members), fresh: fresh);
    } catch (e) {
      error = e;
      loaded = true;
      changed();
    }
  }

  void opened(int conv) {
    open = conv;
    for (final c in chats) {
      if (c.convId == conv) c.unread = 0;
    }
    changed();
    api.markRead(conv).catchError((_) {});
  }

  void closed(int conv) {
    if (open == conv) open = null;
    api.markRead(conv).catchError((_) {});
    load();
  }
}

/// The stories bar: everyone's stories of the last day, by person; mine first, then the ones not seen yet, friends before others.
class StoryStore extends Store {
  StoryStore(this.api, this.people, this.friends);
  final PeeraApi api;
  final People people;
  final FriendStore friends;
  List<StoryGroup> groups = [];
  bool loaded = false;

  StoryGroup? get mine => groups.where((g) => g.author == api.myId).firstOrNull;
  List<StoryGroup> get others => [for (final g in groups) if (g.author != api.myId) g];

  Future<void> load() async {
    try {
      final list = await api.stories();
      final by = <String, List<Story>>{};
      for (final s in list) {
        (by[s.author] ??= []).add(s);
      }
      final f = friends.friends.toSet(), me = api.myId;
      final g = [for (final e in by.entries) StoryGroup(e.key, e.value)];
      int rank(StoryGroup x) => x.author == me ? 0 : (x.seen ? 2 : 1);
      g.sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        return (f.contains(b.author) ? 1 : 0).compareTo(f.contains(a.author) ? 1 : 0);
      });
      groups = g;
      loaded = true;
      changed();
      await people.ensure(by.keys);
    } catch (_) {
      loaded = true;
      changed();
    }
  }

  void seen(Story s) {
    if (s.seen || s.author == api.myId) return;
    for (final g in groups) {
      final i = g.list.indexWhere((x) => x.id == s.id);
      if (i >= 0) g.list[i] = s.seenNow();
    }
    // the viewer marks a story as it builds; the bar under it redraws right after
    Future.microtask(changed);
    api.storySeen(s.id).catchError((_) {});
  }

  void removed(int id) {
    for (final g in groups) {
      g.list.removeWhere((x) => x.id == id);
    }
    groups = [for (final g in groups) if (g.list.isNotEmpty) g];
    changed();
  }
}

/// Everything the signed-in screens share. Made once per sign-in, by the shell.
class AppState {
  AppState(this.api)
      : people = People(api),
        posts = PostStore(api) {
    friends = FriendStore(api, people);
    chats = ChatStore(api, people);
    stories = StoryStore(api, people, friends);
  }

  final PeeraApi api;
  final People people;
  final PostStore posts;
  late final FriendStore friends;
  late final ChatStore chats;
  late final StoryStore stories;

  /// the tab on screen (a playing clip stops when another tab opens)
  final tab = ValueNotifier<int>(0);

  /// notifications to the phone, when the app has them (not in the tests)
  PushService? push;
  /// notifications not yet seen (the bell's number)
  final unreadNotes = ValueNotifier<int>(0);

  /// set by the shell: my profile read again (after changing it), a tab opened, signing out
  Future<void> Function()? refreshMe;
  void Function(String tab)? goTab;
  Future<void> Function()? signOut;

  Future<void> countNotes() async {
    try {
      final n = await api.unreadNotes();
      if (!_closed) unreadNotes.value = n;
    } catch (_) {}
  }

  /// a message that just came for a conversation that is not on screen (shown as a banner at the top)
  final banner = ValueNotifier<({int conv, String actor, String text})?>(null);
  StreamSubscription<Map<String, dynamic>>? _notes;
  Timer? _seen;
  AppLifecycleListener? _life;
  bool _closed = false;

  void start() {
    chats.load();
    friends.load().catchError((_) {});
    _notes = api.liveNotes().listen((n) {
      final k = n['kind'];
      if (k == 'message') {
        chats.load();
        final ref = n['ref'] is Map ? n['ref'] as Map : const {}, actor = '${n['actor'] ?? ''}', conv = asInt(ref['conv']);
        if (conv != 0 && conv != chats.open && actor.isNotEmpty && actor != api.myId) {
          people.ensure([actor]).then((_) {
            if (_closed) return;
            banner.value = null;
            banner.value = (conv: conv, actor: actor, text: '${ref['text'] ?? ''}');
          });
        }
      }
      if (k == 'friend_req' || k == 'friend_ok') friends.load().catchError((_) {});
      if (k != 'message' && !_closed) unreadNotes.value++;
    }, onError: (_) {});
    countNotes();
    api.touchSeen().catchError((_) {});
    // "online" only while the app is on screen
    _seen = Timer.periodic(const Duration(minutes: 2), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) api.touchSeen().catchError((_) {});
    });
    // back from the background: whatever came meanwhile
    _life = AppLifecycleListener(onResume: () {
      push?.refresh();
      api.touchSeen().catchError((_) {});
      chats.load();
      friends.load().catchError((_) {});
      countNotes();
    });
  }

  void dispose() {
    _closed = true;
    _notes?.cancel();
    _seen?.cancel();
    _life?.dispose();
    banner.dispose();
    unreadNotes.dispose();
    tab.dispose();
    stories.dispose();
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
