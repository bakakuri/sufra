import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../profile/profile.dart';
import 'models.dart';
import 'photos.dart';
import '../media/video_tools.dart';

/// shown beside the app's errors in the admin panel
const appVersion = '0.5.0';

/// Everything the app reads and writes, from the same tables and functions the site uses.
/// The screens only see this; the tests answer it from memory.
abstract class PeeraApi {
  String get myId;

  Future<List<Post>> feed({List<String>? authors, String? before, int limit = 15});
  Future<List<Post>> postsBy(String uid, {String? before, int limit = 30});
  Future<Post?> post(int id);
  Future<Map<int, PostStats>> stats(List<int> ids);
  Future<void> react(int postId, String? emoji);
  Future<void> vote(int postId, int opt);
  Future<void> save(int postId, bool on);
  Future<void> deletePost(int postId);
  Future<List<Comment>> comments(int postId);
  Future<Comment> addComment(int postId, String body, {int? parentId});
  Future<Media> uploadPhoto(PreparedPhoto p);
  Future<Post> createPost(String body, List<Media> media);

  Future<Profile?> person(String uid);
  Future<Counts> counts(String uid);
  Future<List<Profile>> people(List<String> ids);
  Future<List<Profile>> search(String q);
  Future<List<Rel>> rels();
  Future<List<Suggestion>> suggestions();
  Future<void> addFriend(String uid);
  Future<void> acceptFriend(String uid);
  Future<void> removeFriend(String uid);

  Future<List<Chat>> chats();
  Future<List<Message>> messages(int convId, {DateTime? before, int limit = 50});
  Future<Message> send(int convId, {String body = '', String kind = 'text', Map<String, dynamic>? media});
  Future<void> markRead(int convId);
  Future<int> startDm(String uid);

  /// new and changed messages of one conversation, while listened to
  Stream<Message> liveMessages(int convId);

  /// my notifications as they arrive (kind: message, friend_req, friend_ok, …)
  Stream<Map<String, dynamic>> liveNotes();

  Future<void> touchSeen();

  /// this phone, for push notifications (a row of push_subs, beside the browsers the site registers)
  Future<void> savePushToken(String token);
  Future<void> removePushToken(String token);

  /// a problem on the phone, into the admin panel's error log (the site writes its own there too)
  Future<void> logError(String msg, {String stack = ''});

  /// short videos (posts marked as clips), newest first
  Future<List<Post>> clips({String? before, int limit = 12});

  /// a video and its poster, uploaded
  Future<Media> uploadVideo(VideoReady v);

  /// a voice message recorded on the phone (m4a), its link
  Future<String> uploadVoice(String path);

  /// a clip: the video and a few words
  Future<Post> createClip(String body, Media video);

  /// the stories of the last day that I may see, each marked when I have seen it
  Future<List<Story>> stories();
  Future<void> storySeen(int id);
  Future<String> uploadStoryPhoto(PreparedPhoto p);
  Future<void> addStory(String url, {bool video = false});
  Future<void> deleteStory(int id);

  /// a reaction or an answer goes to the author's chat too, as on the site
  Future<void> reactStory(Story s, String emoji);
  Future<void> replyStory(Story s, String text);
  Future<List<StoryWatcher>> storyViewers(int id);

  /// a game against the computer is over (as on the site): a win may bring the day's coins; the server decides how many
  Future<({int coins, int reward})> gameResult(String game, bool win);

  // dating (js/dating.js): adults only, opt-in

  Future<DatingMe> datingMe();

  /// turns dating on with this card, or saves changes to it
  Future<void> saveDating(DatingMe d);
  Future<void> datingOff();
  Future<List<DatingCard>> datingFeed({int limit = 25});

  /// 'like', 'nope' or 'super' (5 coins); true when it made a pair
  Future<bool> swipe(String target, String kind);

  /// how many like me whom I have not answered yet (who they are shows once we are a pair)
  Future<int> likesMeCount();

  /// the people I am a pair with, the newest first
  Future<List<String>> matches();

  // Joker with people, at a table the server runs (public.jks_*, as on the site)

  Future<JkTable?> jkTable(int id);
  Stream<JkTable> liveJkTable(int id);

  /// my cards at the table (the first three while a nine-card hand's trump is chosen)
  Future<({int seat, int deal, List<Map<String, dynamic>> cards})?> jkHand(int id);

  /// moves the game on where it waits for a bot, someone away, a taken trick or the next hand
  Future<Map<String, dynamic>?> jkTick(int id);

  /// my move: {k: 'bid', v} · {k: 'trump', s} · {k: 'card', c, jm, js}
  Future<({Map<String, dynamic> state, List<Map<String, dynamic>>? hand})> jkAct(int id, Map<String, dynamic> move);
  Future<void> jkBack(int id);
  Future<Map<String, dynamic>?> jkStart(int id);

  /// a seat at an open table of this length that waits for people, or a new one
  Future<int> jkQuick(String len);

  /// a table of my own for friends
  Future<int> jkNew();
  Future<int> jkJoin(int id);
  Future<void> jkLeave(int id);
  Future<void> jkSet(int id, {String? len, bool? pub});
  Future<void> jkClose(int id);
  Future<int> jkInvite(int id, List<String> users);

  /// open tables that wait for people (or play now)
  Future<List<JkTable>> jkLobby();

  /// the tables I sit at that are not over
  Future<List<JkTable>> jkMine();

  // the live map (js/livemap.js): who shares their place with me now; who sees what is decided on the server

  Future<List<LiveSpot>> liveMap();

  /// my share as the server has it (null when there is none, or it ran out)
  Future<MyShare?> myShare();

  /// a secret for this phone only: its service can move or stop my place with it, nothing else
  Future<String> locToken();
  Future<void> locStop();

  /// under 18: the place is shared with friends only
  Future<bool> amMinor();

  // notifications, my profile and settings

  /// the latest notifications (not the messages: those are in the conversations)
  Future<List<Notif>> notes();
  Future<void> notesRead(List<int> ids);
  Future<void> allNotesRead();
  Future<int> unreadNotes();

  /// my whole profile row as the site has it (what the settings and the editor need)
  Future<Map<String, dynamic>> mySettings();

  /// changes to my profile row (name, picture, privacy, notifications…)
  Future<void> updateMe(Map<String, dynamic> fields);

  /// people I blocked
  Future<List<String>> blocked();
  Future<void> unblock(String uid);
}

class SupaApi implements PeeraApi {
  SupaApi([SupabaseClient? client]) : sb = client ?? Supabase.instance.client;
  final SupabaseClient sb;
  final _rnd = Random();

  @override
  String get myId => sb.auth.currentUser?.id ?? '';

  static const _who = 'id,name,surname,username,avatar_url,hue,verified';
  static const postSel = 'id,author,body,media,poll,tags,group_id,page_id,is_clip,hidden,created_at,link,edited_at,repost_of,pending,'
      'ap:profiles!posts_author_fkey($_who),page:pages!posts_page_id_fkey(id,name,hue,avatar_url,verified,kind),'
      'grp:groups!posts_group_id_fkey(id,name),pl:places!posts_place_id_fkey(id,name,kind,city)';
  static const commentSel = 'id,post_id,body,media,created_at,author,parent_id,likes,profiles!comments_author_fkey($_who)';
  static const personSel = 'id,username,name,surname,bio,city,hue,avatar_url,cover_url,verified,last_seen';
  static const msgSel = 'id,conv_id,sender,body,media,kind,created_at,reply_to,edited_at,deleted,expires_at';

  String _id(int n) => List.generate(n, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[_rnd.nextInt(36)]).join();

  /// published posts only, and none from the future (scheduled ones wait)
  PostgrestFilterBuilder<PostgrestList> _posts() => sb
      .from('posts')
      .select(postSel)
      .eq('draft', false)
      .lte('created_at', DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String());

  /// reposts bring their original along; a plain repost of a post that is gone is left out
  Future<List<Post>> _hydrate(PostgrestList rows) async {
    final list = rows.map(Post.fromJson).toList();
    final have = {for (final p in list) p.id: p};
    final miss = {for (final p in list) if (p.repostOf != null && !have.containsKey(p.repostOf)) p.repostOf!};
    if (miss.isNotEmpty) {
      try {
        for (final r in await _posts().inFilter('id', miss.toList())) {
          final o = Post.fromJson(r);
          have[o.id] = o;
        }
      } catch (_) {}
    }
    for (final p in list) {
      if (p.repostOf != null) p.original = have[p.repostOf];
    }
    return list.where((p) => !(p.plainRepost && p.original == null)).toList();
  }

  @override
  Future<List<Post>> feed({List<String>? authors, String? before, int limit = 15}) async {
    var q = _posts().isFilter('group_id', null).eq('hidden', false);
    if (before != null) q = q.lt('created_at', before);
    if (authors != null) q = q.inFilter('author', authors);
    return _hydrate(await q.order('created_at', ascending: false).limit(limit));
  }

  @override
  Future<List<Post>> postsBy(String uid, {String? before, int limit = 30}) async {
    var q = _posts().eq('author', uid).isFilter('group_id', null).isFilter('repost_of', null);
    if (before != null) q = q.lt('created_at', before);
    return _hydrate(await q.order('created_at', ascending: false).limit(limit));
  }

  @override
  Future<Post?> post(int id) async {
    final r = await _hydrate(await _posts().eq('id', id).limit(1));
    return r.firstOrNull;
  }

  @override
  Future<Map<int, PostStats>> stats(List<int> ids) async {
    if (ids.isEmpty) return {};
    final r = await sb.rpc('feed_stats', params: {'p_ids': ids});
    return {
      for (final s in (r as List? ?? const []))
        if (s is Map) asInt(s['post_id']): PostStats.fromJson(Map<String, dynamic>.from(s)),
    };
  }

  @override
  Future<void> react(int postId, String? emoji) async {
    if (emoji == null) {
      await sb.from('reactions').delete().eq('post_id', postId).eq('user_id', myId);
    } else {
      await sb.from('reactions').upsert({'post_id': postId, 'user_id': myId, 'emoji': emoji}, onConflict: 'post_id,user_id');
    }
  }

  @override
  Future<void> vote(int postId, int opt) =>
      sb.from('poll_votes').upsert({'post_id': postId, 'user_id': myId, 'opt': opt}, onConflict: 'post_id,user_id');

  @override
  Future<void> save(int postId, bool on) async {
    if (on) {
      await sb.from('saves').insert({'user_id': myId, 'post_id': postId});
    } else {
      await sb.from('saves').delete().eq('user_id', myId).eq('post_id', postId);
    }
  }

  @override
  Future<void> deletePost(int postId) => sb.from('posts').delete().eq('id', postId);

  @override
  Future<List<Comment>> comments(int postId) async =>
      (await sb.from('comments').select(commentSel).eq('post_id', postId).order('created_at').limit(400)).map(Comment.fromJson).toList();

  @override
  Future<Comment> addComment(int postId, String body, {int? parentId}) async => Comment.fromJson(await sb
      .from('comments')
      .insert({'post_id': postId, 'author': myId, 'body': body, 'parent_id': parentId})
      .select(commentSel)
      .single());

  Future<String> _put(Uint8List b) async {
    final path = '$myId/${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-${_id(6)}.jpg';
    await sb.storage
        .from('media')
        .uploadBinary(path, b, fileOptions: const FileOptions(contentType: 'image/jpeg', cacheControl: '31536000', upsert: false));
    return sb.storage.from('media').getPublicUrl(path);
  }

  @override
  Future<Media> uploadPhoto(PreparedPhoto p) async {
    final full = _put(p.full);
    final md = p.md == null ? null : _put(p.md!);
    final sm = p.sm == null ? null : _put(p.sm!);
    return Media(url: await full, w: p.w, h: p.h, md: md == null ? null : await md, sm: sm == null ? null : await sm);
  }

  @override
  Future<Post> createPost(String body, List<Media> media) async {
    final r = await sb
        .from('posts')
        .insert({'author': myId, 'body': body, 'media': media.map((m) => m.toJson()).toList()})
        .select(postSel)
        .single();
    return Post.fromJson(r);
  }

  @override
  Future<Profile?> person(String uid) async {
    final r = await sb.from('profiles').select(personSel).eq('id', uid).maybeSingle();
    return r == null ? null : Profile.fromJson(r);
  }

  @override
  Future<Counts> counts(String uid) async {
    final f = sb.from('friendships').count(CountOption.exact).eq('status', 'accepted').or('requester.eq.$uid,addressee.eq.$uid');
    final p = sb.from('posts').count(CountOption.exact).eq('author', uid).eq('draft', false);
    return Counts(await f, await p);
  }

  @override
  Future<List<Profile>> people(List<String> ids) async {
    if (ids.isEmpty) return [];
    return (await sb.from('profiles').select(personSel).inFilter('id', ids)).map(Profile.fromJson).toList();
  }

  @override
  Future<List<Profile>> search(String q) async {
    final s = q.replaceAll(RegExp(r'[,()%*\\:"]'), ' ').trim();
    if (s.isEmpty) return [];
    final r = await sb.from('profiles').select(personSel).or('name.ilike.%$s%,username.ilike.%$s%,surname.ilike.%$s%').eq('onboarded', true).limit(30);
    return r.map(Profile.fromJson).where((p) => p.id != myId).toList();
  }

  @override
  Future<List<Rel>> rels() async =>
      (await sb.from('friendships').select('requester,addressee,status').or('requester.eq.$myId,addressee.eq.$myId')).map(Rel.fromJson).toList();

  @override
  Future<List<Suggestion>> suggestions() async {
    final r = await sb.rpc('friend_suggestions', params: {'p_limit': 20});
    return [
      for (final s in (r as List? ?? const []))
        if (s is Map) Suggestion(Profile.fromJson(Map<String, dynamic>.from(s)), asInt(s['mutual'])),
    ];
  }

  @override
  Future<void> addFriend(String uid) => sb.from('friendships').insert({'requester': myId, 'addressee': uid});

  @override
  Future<void> acceptFriend(String uid) => sb.from('friendships').update({'status': 'accepted'}).eq('requester', uid).eq('addressee', myId);

  @override
  Future<void> removeFriend(String uid) =>
      sb.from('friendships').delete().or('and(requester.eq.$myId,addressee.eq.$uid),and(requester.eq.$uid,addressee.eq.$myId)');

  @override
  Future<List<Chat>> chats() async {
    final r = await sb.rpc('my_chats');
    return [
      for (final c in (r as List? ?? const []))
        if (c is Map) Chat.fromJson(Map<String, dynamic>.from(c)),
    ];
  }

  @override
  Future<List<Message>> messages(int convId, {DateTime? before, int limit = 50}) async {
    var q = sb.from('messages').select(msgSel).eq('conv_id', convId);
    if (before != null) q = q.lt('created_at', before.toUtc().toIso8601String());
    return (await q.order('created_at', ascending: false).limit(limit)).map(Message.fromJson).toList();
  }

  @override
  Future<Message> send(int convId, {String body = '', String kind = 'text', Map<String, dynamic>? media}) async =>
      Message.fromJson(await sb
          .from('messages')
          .insert({'conv_id': convId, 'sender': myId, 'body': body, 'kind': kind, 'media': media})
          .select(msgSel)
          .single());

  @override
  Future<void> markRead(int convId) =>
      sb.from('conversation_members').update({'last_read_at': DateTime.now().toUtc().toIso8601String()}).eq('conv_id', convId).eq('user_id', myId);

  @override
  Future<int> startDm(String uid) async => asInt(await sb.rpc('start_dm', params: {'other': uid}));

  @override
  Stream<Message> liveMessages(int convId) {
    RealtimeChannel? ch;
    late final StreamController<Message> out;
    out = StreamController<Message>(
      onListen: () {
        ch = sb
            .channel('app-conv-$convId-${_id(5)}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conv_id', value: convId),
              callback: (pl) {
                if (pl.newRecord.isNotEmpty && !out.isClosed) out.add(Message.fromJson(pl.newRecord));
              },
            )
            .subscribe();
      },
      onCancel: () async {
        final c = ch;
        if (c != null) await sb.removeChannel(c);
      },
    );
    return out.stream;
  }

  @override
  Stream<Map<String, dynamic>> liveNotes() {
    RealtimeChannel? ch;
    late final StreamController<Map<String, dynamic>> out;
    out = StreamController<Map<String, dynamic>>(
      onListen: () {
        ch = sb
            .channel('app-notes-${_id(5)}')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'notifications',
              filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: myId),
              callback: (pl) {
                if (!out.isClosed) out.add(pl.newRecord);
              },
            )
            .subscribe();
      },
      onCancel: () async {
        final c = ch;
        if (c != null) await sb.removeChannel(c);
      },
    );
    return out.stream;
  }

  /// "last seen", every two minutes while the app is open — unless the person hides when they are online
  @override
  Future<void> touchSeen() async {
    if (myId.isEmpty) return;
    final r = await sb.from('profiles').select('privacy').eq('id', myId).maybeSingle();
    final pv = r?['privacy'];
    if (pv is Map && pv['online'] == false) return;
    await sb.from('profiles').update({'last_seen': DateTime.now().toUtc().toIso8601String()}).eq('id', myId);
  }

  @override
  Future<void> savePushToken(String token) => sb
      .from('push_subs')
      .upsert({'user_id': myId, 'endpoint': 'fcm:$token', 'p256dh': '', 'auth': ''}, onConflict: 'endpoint', ignoreDuplicates: true);

  @override
  Future<void> removePushToken(String token) => sb.from('push_subs').delete().eq('endpoint', 'fcm:$token');

  @override
  Future<void> logError(String msg, {String stack = ''}) => sb.from('client_errors').insert({
        'user_id': myId,
        'msg': msg.length > 500 ? msg.substring(0, 500) : msg,
        'src': 'app',
        'stack': stack.length > 4000 ? stack.substring(0, 4000) : stack,
        'page': 'android',
        'ua': 'Peera app',
        'ver': appVersion,
      });

  @override
  Future<DatingMe> datingMe() async {
    final rs = await Future.wait([sb.rpc('my_profile'), sb.rpc('is_adult', params: {'u': myId})]);
    final r = rs[0], m = r is Map ? r : (r is List && r.isNotEmpty && r.first is Map ? r.first as Map : const {});
    final url = m['avatar_url'];
    return DatingMe(
      adult: rs[1] == true,
      on: m['dating'] == true,
      gender: m['gender'] as String?,
      seeking: (m['seeking'] as String?) ?? 'all',
      bio: '${m['dating_bio'] ?? ''}',
      interests: [for (final x in (m['interests'] as List? ?? const [])) '$x'],
      photo: url is String && url.isNotEmpty,
    );
  }

  @override
  Future<void> saveDating(DatingMe d) => sb.from('profiles').update({
        'dating': true,
        'gender': d.gender,
        'seeking': d.seeking,
        'dating_bio': d.bio.trim(),
        'interests': d.interests.take(6).toList(),
      }).eq('id', myId);

  @override
  Future<void> datingOff() => sb.from('profiles').update({'dating': false}).eq('id', myId);

  @override
  Future<List<DatingCard>> datingFeed({int limit = 25}) async {
    final r = await sb.rpc('dating_feed', params: {'p_limit': limit});
    return [for (final x in (r as List? ?? const [])) DatingCard.fromJson(Map<String, dynamic>.from(x as Map))];
  }

  @override
  Future<bool> swipe(String target, String kind) async => (await sb.rpc('swipe', params: {'p_target': target, 'p_kind': kind})) == true;

  @override
  Future<int> likesMeCount() async => asInt(await sb.rpc('likes_me_count'));

  @override
  Future<List<String>> matches() async {
    final rows = await sb.from('matches').select('a,b,created_at').or('a.eq.$myId,b.eq.$myId').order('created_at', ascending: false);
    return [for (final r in rows) '${r['a']}' == myId ? '${r['b']}' : '${r['a']}'];
  }

  static const _jkCols = 'id,host,len,seats,status,pub,state,updated_at';

  @override
  Future<JkTable?> jkTable(int id) async {
    final r = await sb.from('jk_tables').select(_jkCols).eq('id', id).maybeSingle();
    return r == null ? null : JkTable.fromJson(r);
  }

  @override
  Stream<JkTable> liveJkTable(int id) {
    RealtimeChannel? ch;
    late final StreamController<JkTable> out;
    out = StreamController<JkTable>(
      onListen: () {
        ch = sb
            .channel('app-jk-$id-${_id(5)}')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'jk_tables',
              filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: id),
              callback: (pl) {
                if (pl.newRecord.isNotEmpty && !out.isClosed) out.add(JkTable.fromJson(pl.newRecord));
              },
            )
            .subscribe();
      },
      onCancel: () async {
        final c = ch;
        if (c != null) await sb.removeChannel(c);
      },
    );
    return out.stream;
  }

  static List<Map<String, dynamic>> _cards(Object? x) => [for (final c in (x as List? ?? const [])) Map<String, dynamic>.from(c as Map)];
  static Map<String, dynamic>? _map(Object? x) => x is Map ? Map<String, dynamic>.from(x) : null;

  @override
  Future<({int seat, int deal, List<Map<String, dynamic>> cards})?> jkHand(int id) async {
    final r = _map(await sb.rpc('jks_hand', params: {'p_table': id}));
    if (r == null) return null;
    return (seat: asInt(r['seat'], -1), deal: asInt(r['deal'], -1), cards: _cards(r['cards']));
  }

  @override
  Future<Map<String, dynamic>?> jkTick(int id) async => _map(await sb.rpc('jks_tick', params: {'p_table': id}));

  @override
  Future<({Map<String, dynamic> state, List<Map<String, dynamic>>? hand})> jkAct(int id, Map<String, dynamic> move) async {
    final r = _map(await sb.rpc('jks_act', params: {'p_table': id, 'p_move': move})) ?? const {};
    return (state: _map(r['state']) ?? <String, dynamic>{}, hand: r['hand'] == null ? null : _cards(r['hand']));
  }

  @override
  Future<void> jkBack(int id) => sb.rpc('jks_back', params: {'p_table': id});

  @override
  Future<Map<String, dynamic>?> jkStart(int id) async => _map(await sb.rpc('jks_start', params: {'p_table': id}));

  @override
  Future<int> jkQuick(String len) async => asInt(await sb.rpc('jks_quick', params: {'p_len': len}));

  @override
  Future<int> jkNew() async {
    final r = await sb.from('jk_tables').insert({
      'host': myId,
      'len': 'quick',
      'seats': [myId, null, null, null],
      'state': {'srv': true},
    }).select('id').single();
    return asInt(r['id']);
  }

  @override
  Future<int> jkJoin(int id) async => asInt(await sb.rpc('jk_join', params: {'p_table': id}));

  @override
  Future<void> jkLeave(int id) => sb.rpc('jk_leave', params: {'p_table': id});

  @override
  Future<void> jkSet(int id, {String? len, bool? pub}) => sb.from('jk_tables').update({
        if (len != null) 'len': len,
        if (pub != null) 'pub': pub,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);

  @override
  Future<void> jkClose(int id) =>
      sb.from('jk_tables').update({'status': 'closed', 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);

  @override
  Future<int> jkInvite(int id, List<String> users) async => asInt(await sb.rpc('jk_invite', params: {'p_table': id, 'p_users': users}));

  @override
  Future<List<JkTable>> jkLobby() async {
    final r = await sb.rpc('jks_lobby');
    return [for (final x in (r as List? ?? const [])) JkTable.fromJson({...Map<String, dynamic>.from(x as Map), 'srv': true})];
  }

  @override
  Future<List<JkTable>> jkMine() async {
    final since = DateTime.now().toUtc().subtract(const Duration(hours: 3)).toIso8601String();
    final r = await sb
        .from('jk_tables')
        .select('id,host,len,seats,status,pub,updated_at,srv:state->srv')
        .contains('seats', [myId])
        .inFilter('status', ['wait', 'play'])
        .gt('updated_at', since)
        .order('updated_at', ascending: false)
        .limit(10);
    return [for (final x in r) if (x['srv'] == true) JkTable.fromJson(x)];
  }

  @override
  Future<List<LiveSpot>> liveMap() async {
    final r = await sb.rpc('live_map');
    return [for (final x in (r as List? ?? const [])) LiveSpot.fromJson(Map<String, dynamic>.from(x as Map))];
  }

  @override
  Future<MyShare?> myShare() async {
    final r = await sb.from('live_locations').select('audience,approx,expires_at,dev_at').eq('user_id', myId).maybeSingle();
    if (r == null) return null;
    final ex = DateTime.tryParse('${r['expires_at'] ?? ''}')?.toLocal();
    if (ex != null && ex.isBefore(DateTime.now())) return null;
    return MyShare(audience: '${r['audience'] ?? 'friends'}', approx: r['approx'] == true, expiresAt: ex, device: r['dev_at'] != null);
  }

  @override
  Future<String> locToken() async => '${await sb.rpc('loc_device_token')}';

  @override
  Future<void> locStop() => sb.rpc('loc_stop');

  @override
  Future<bool> amMinor() async {
    final r = await sb.rpc('my_profile');
    final m = r is Map ? r : (r is List && r.isNotEmpty && r.first is Map ? r.first as Map : const {});
    final b = DateTime.tryParse('${m['birthday'] ?? ''}');
    if (b == null) return false;
    final now = DateTime.now();
    var age = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) age--;
    return age < 18;
  }

  @override
  Future<List<Notif>> notes() async {
    final r = await sb.from('notifications').select('id,actor,kind,ref,read,created_at').neq('kind', 'message').order('created_at', ascending: false).limit(60);
    return [for (final x in r) Notif.fromJson(x)];
  }

  @override
  Future<void> notesRead(List<int> ids) async {
    if (ids.isEmpty) return;
    await sb.from('notifications').update({'read': true}).inFilter('id', ids);
  }

  @override
  Future<void> allNotesRead() => sb.from('notifications').update({'read': true}).eq('user_id', myId).eq('read', false);

  @override
  Future<int> unreadNotes() async => await sb.from('notifications').count(CountOption.exact).eq('read', false).neq('kind', 'message');

  @override
  Future<Map<String, dynamic>> mySettings() async {
    final r = await sb.rpc('my_profile');
    final m = r is Map ? r : (r is List && r.isNotEmpty && r.first is Map ? r.first as Map : const {});
    return Map<String, dynamic>.from(m);
  }

  @override
  Future<void> updateMe(Map<String, dynamic> fields) => sb.from('profiles').update(fields).eq('id', myId);

  @override
  Future<List<String>> blocked() async => [for (final r in await sb.from('blocks').select('blocked').eq('blocker', myId)) '${r['blocked']}'];

  @override
  Future<void> unblock(String uid) => sb.from('blocks').delete().eq('blocker', myId).eq('blocked', uid);

  @override
  Future<({int coins, int reward})> gameResult(String game, bool win) async {
    final r = await sb.rpc('game_result', params: {'p_game': game, 'p_win': win});
    final m = r is Map ? r : const {};
    return (coins: asInt(m['coins']), reward: asInt(m['reward']));
  }

  @override
  Future<List<Post>> clips({String? before, int limit = 12}) async {
    var q = _posts().eq('is_clip', true).eq('hidden', false);
    if (before != null) q = q.lt('created_at', before);
    final list = await _hydrate(await q.order('created_at', ascending: false).limit(limit));
    return list.where((p) => p.media.any((m) => m.isVideo)).toList();
  }

  Future<String> _putFile(File f, String ext, String type) async {
    final path = '$myId/${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-${_id(6)}.$ext';
    await sb.storage.from('media').upload(path, f, fileOptions: FileOptions(contentType: type, cacheControl: '31536000', upsert: false));
    return sb.storage.from('media').getPublicUrl(path);
  }

  @override
  Future<String> uploadVoice(String path) => _putFile(File(path), 'm4a', 'audio/mp4');

  @override
  Future<Media> uploadVideo(VideoReady v) async {
    final mov = v.path.toLowerCase().endsWith('.mov');
    final poster = v.poster == null ? null : _putFile(File(v.poster!), 'jpg', 'image/jpeg').then<String?>((x) => x, onError: (_) => null);
    final url = await _putFile(File(v.path), mov ? 'mov' : 'mp4', mov ? 'video/quicktime' : 'video/mp4');
    return Media(url: url, type: 'video', w: v.w, h: v.h, poster: poster == null ? null : await poster, dur: v.dur > 0 ? double.parse(v.dur.toStringAsFixed(1)) : null);
  }

  @override
  Future<Post> createClip(String body, Media video) async => Post.fromJson(await sb
      .from('posts')
      .insert({'author': myId, 'body': body, 'media': [video.toJson()], 'is_clip': true})
      .select(postSel)
      .single());

  @override
  Future<List<Story>> stories() async {
    final rows = await sb
        .from('stories')
        .select('id,author,media_url,media_type,created_at,audience,post_id')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at')
        .limit(200);
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => asInt(r['id'])).toList();
    final seen = {
      for (final r in await sb.from('story_views').select('story_id').eq('user_id', myId).inFilter('story_id', ids.take(300).toList())) asInt(r['story_id']),
    };
    return [for (final r in rows) Story.fromJson(r, seen: seen.contains(asInt(r['id'])))];
  }

  @override
  Future<void> storySeen(int id) => sb.from('story_views').upsert({'story_id': id, 'user_id': myId}, onConflict: 'story_id,user_id');

  @override
  Future<String> uploadStoryPhoto(PreparedPhoto p) => _put(p.full);

  @override
  Future<void> addStory(String url, {bool video = false}) =>
      sb.from('stories').insert({'author': myId, 'media_url': url, 'media_type': video ? 'video' : 'image', 'audience': 'all'});

  @override
  Future<void> deleteStory(int id) => sb.from('stories').delete().eq('id', id);

  Future<void> _storyToChat(Story s, String body, String act) async {
    final conv = await startDm(s.author);
    await sb.from('messages').insert({'conv_id': conv, 'sender': myId, 'body': body, 'kind': 'text', 'media': {'story': s.id, 'act': act}});
  }

  @override
  Future<void> reactStory(Story s, String emoji) async {
    await sb.from('story_reactions').upsert({'story_id': s.id, 'user_id': myId, 'emoji': emoji}, onConflict: 'story_id,user_id');
    await _storyToChat(s, emoji, 'react');
  }

  @override
  Future<void> replyStory(Story s, String text) => _storyToChat(s, text, 'reply');

  @override
  Future<List<StoryWatcher>> storyViewers(int id) async {
    final views = await sb.from('story_views').select('user_id,seen_at').eq('story_id', id).order('seen_at', ascending: false);
    final rx = {for (final r in await sb.from('story_reactions').select('user_id,emoji').eq('story_id', id)) '${r['user_id']}': '${r['emoji']}'};
    return [for (final v in views) if ('${v['user_id']}' != myId) StoryWatcher('${v['user_id']}', rx['${v['user_id']}'])];
  }
}
