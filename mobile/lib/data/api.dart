import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../profile/profile.dart';
import 'models.dart';
import 'photos.dart';

/// shown beside the app's errors in the admin panel
const appVersion = '0.3.2';

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
}
