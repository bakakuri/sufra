import 'dart:async';
import 'dart:convert';
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
  Future<Comment> addComment(int postId, String body, {int? parentId, Map<String, dynamic>? media});
  Future<Media> uploadPhoto(PreparedPhoto p);
  /// a post: now, as a draft, or waiting for [publishAt]; with a place, or quoting another post ([repostOf])
  Future<Post> createPost(String body, List<Media> media, {Poll? poll, int? placeId, bool draft = false, DateTime? publishAt, int? repostOf});

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
  Future<Message> send(int convId, {String body = '', String kind = 'text', Map<String, dynamic>? media, int? replyTo});
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
  Future<void> addStory(String url, {bool video = false, int? postId});
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

  // ---- the profile, as on the site ----

  /// friends in common with someone
  Future<int> mutualFriends(String uid);

  /// I came by someone's profile (they see it among their guests, unless I visit invisibly)
  Future<void> visit(String uid);

  /// someone's Joker numbers (online rating, games, wins), null when they never played
  Future<JokerLine?> jokerLine(String uid);

  /// the badges someone earned: code and when; [check] first asks the server for new ones of mine (they bring coins)
  Future<List<(String, DateTime)>> badges(String uid);
  Future<List<String>> checkBadges();

  /// highlights: someone's, the stories in one, and mine to change
  Future<List<Highlight>> highlights(String uid);
  Future<List<Story>> highlightItems(int id);
  Future<int> newHighlight(String title, int pos);
  Future<bool> addToHighlight(int highlight, int story);
  Future<void> removeHighlightItem(int itemId);
  Future<void> renameHighlight(int id, String title);
  Future<void> deleteHighlight(int id);

  /// every story I ever posted, newest first (the archive only I see)
  Future<List<Story>> myStories();

  Future<List<Album>> albums(String uid);

  /// someone's CV row (null when there is none, or it is not shown)
  Future<Map<String, dynamic>?> cv(String uid);

  /// a person's friends (ids)
  Future<List<String>> friendsOf(String uid);

  /// what I saved, newest first, from one folder or all; and the folders
  Future<List<Post>> saved({int? folder});
  Future<List<(int, String)>> saveFolders();

  /// who came by my profile, newest first; how many since [since]
  Future<List<Visit>> guests();
  Future<int> guestsSince(DateTime since);

  /// the gifts I got; sending one (the server takes the coins and gives half to them), my balance after
  Future<List<GiftGot>> giftsGot();
  Future<int> sendGift(String uid, String emoji);

  Future<void> report(String type, String id, String reason);

  /// blocking also ends a friendship
  Future<void> block(String uid);

  /// close friends: who sees my "close friends" stories
  Future<List<String>> closeFriends();
  Future<void> setClose(String uid, bool on);

  /// my drafts and the posts waiting for their time; publishing one now, or at a time
  Future<List<Post>> drafts();
  Future<void> publishNow(int postId);
  Future<void> schedulePost(int postId, DateTime at);

  /// a folder of saved posts: renamed, or deleted (the posts stay saved)
  Future<void> renameFolder(int id, String name);
  Future<void> deleteFolder(int id);

  /// a grade for someone's photo ('1'…'5', '5+'): the coins the author got (a 5+ costs coins)
  Future<int> gradePhoto(int postId, String grade);

  /// staff only: a person may no longer post, comment or write
  Future<void> banUser(String uid);

  /// someone's ratings in the site's games: game, rating, games, wins
  Future<List<(String, int, int, int)>> gameRatings(String uid);

  /// a greeting card into a conversation with them (made if needed); the conversation
  Future<int> sendCard(String uid, Map<String, dynamic> card);

  // ---- coins ----

  /// my_coins: balance, today's earnings, the bonus streak, the promotion, the 5+ price…
  Future<Map<String, dynamic>> myCoins();
  Future<List<Map<String, dynamic>>> coinRules();
  Future<List<Map<String, dynamic>>> coinLog();

  /// today's bonus: {coins, got, streak}
  Future<Map<String, dynamic>> dailyBonus();

  // ---- albums ----

  /// mine, the ones I was invited to, and friends'
  Future<(List<Album>, List<Album>, List<Album>)> albumsPage();
  Future<Map<String, dynamic>?> album(int id);
  Future<List<Map<String, dynamic>>> albumPhotos(int id);
  Future<List<String>> albumMembers(int id);
  Future<bool> albumCanAdd(int id);
  Future<int> createAlbum(String title, String? about, String audience);
  Future<void> updateAlbum(int id, String title, String? about, String audience);
  Future<void> deleteAlbum(int id);
  Future<Map<String, dynamic>> addAlbumPhoto(int id, Media m);
  Future<void> deleteAlbumPhoto(int photoId);
  Future<void> inviteToAlbum(int id, List<String> uids);
  Future<void> removeFromAlbum(int id, String uid);

  // ---- CV, education ----

  Future<void> saveCv(Map<String, dynamic> cv);

  /// joins the class and course groups of my schools (their ids)
  Future<List<int>> joinEduGroups();

  /// people who put the same school or university ({k, key}) on their profile, with their edu
  Future<List<Profile>> classmates(String k, String key);

  // ---- family tree, surnames ----

  /// the rows of someone's tree, and the requests to be in others' trees (mine)
  Future<List<Map<String, dynamic>>> kinOf(String uid);
  Future<List<Map<String, dynamic>>> kinRequests();
  Future<void> addKin(Map<String, dynamic> row);
  Future<void> updateKin(int id, Map<String, dynamic> fields);
  Future<void> deleteKin(int id);
  Future<void> respondKin(int id, bool accept);

  /// people with a surname, and its group (null when there is none)
  Future<List<Profile>> surnamePeople(String s);
  Future<int?> surnameGroup(String s);
  Future<int> joinSurnameGroup();

  // ---- verification ----

  /// my last request ('pending', 'rejected', …), null when there was none
  Future<String?> verification();

  /// the selfie (kept where only moderators see it) and the request
  Future<void> requestVerification(Uint8List selfie);

  // ---- the home page ----

  /// what the admin set for everyone (app_settings: banner, features…), by key
  Future<Map<String, dynamic>> appSettings();

  /// how much is going on in each service (service_counts), by page
  Future<Map<String, int>> serviceCounts();

  /// the hashtags I follow, and following or leaving some
  Future<Set<String>> tagFollows();
  Future<void> followTags(List<String> tags, bool on);

  /// the newest posts on any of these hashtags
  Future<List<Post>> feedTagged(List<String> tags, {int limit = 5});

  /// posts by their ids (memories, sponsored ones), newest first
  Future<List<Post>> postsByIds(List<int> ids);

  /// the admin's sponsored posts and stories (promos), the live ones; seen or opened
  Future<List<Map<String, dynamic>>> promos();
  Future<void> promoHit(int id, {bool click = false});

  /// paid posts (ads) running now: the ad's id and its post; one more shown
  Future<List<(int, Post)>> adPosts();
  Future<void> adImpression(int adId);

  /// friends' birthdays (friend_birthdays): id, name, hue, avatar_url, month, day
  Future<List<Map<String, dynamic>>> friendBirthdays();

  /// my posts from this day in earlier years (my_memories)
  Future<List<int>> myMemories();

  /// first steps: people I asked or who are my friends, and whether I have posted
  Future<(int, bool)> firstStepsCounts();

  /// the welcome gift's coins when it came (coin_log), null when there was none
  Future<int?> welcomeGift();

  /// the coins for inviting (coin_rules welcome and invite) and who came by my link (count, paid)
  Future<Map<String, int>> inviteRules();
  Future<(int, int)> referrals();

  // ---------- posts: sharing, editing, moderation, comments (feed.js), tags and search (home.js) ----------

  /// how many shared each post and my own repost's id (repost_stats)
  Future<Map<int, (int, int?)>> repostStats(List<int> ids);

  /// a plain repost (its id); taking it back
  Future<int> repost(int postId);
  Future<void> unrepost(int repostId);

  /// my post changed: the words, the photos left and the place ([setPlace] with a null [placeId] takes it away)
  Future<Post> updatePost(int id, String body, {List<Media>? media, int? placeId, bool setPlace = false});

  /// staff: hidden for everyone, or shown again (admin_hide)
  Future<void> modHide(String type, int id, bool hidden);

  /// a saved post put into a folder (null: none); a new folder
  Future<void> saveToFolder(int postId, int? folder);
  Future<(int, String)> newFolder(String name);

  /// the words in [target] (the translate function): the translation and the language it found
  Future<(String, String?)> translate(String text, String source, String target);

  /// which of these comments I like; liking one; deleting one (its replies go with it)
  Future<Set<int>> commentLikes(List<int> ids);
  Future<void> likeComment(int id, bool on);
  Future<void> deleteComment(int id);

  /// people whose @username starts so (for @mentions); one by @username
  Future<List<Profile>> mentionPeople(String prefix);
  Future<Profile?> personByUsername(String username);

  /// posts with a #tag, the newest first
  Future<List<Post>> postsTagged(String tag, {int limit = 40});

  /// the tags used most lately (trending_tags): the tag and its uses
  Future<List<(String, int)>> trendingTags();

  /// search: posts with the words, pages and channels, groups
  Future<List<Post>> searchPosts(String q);
  Future<List<Map<String, dynamic>>> searchPages(String q);
  Future<List<Map<String, dynamic>>> searchGroups(String q);

  /// places for a post: by name, or the ones near (places_near) when [q] is empty
  Future<List<Map<String, dynamic>>> findPlaces(String q, {double? lat, double? lng});

  // ---------- chat in full (chat.js): reactions, edits, pins, disappearing, search, groups, mute, archive ----------

  /// who reacted how to these messages: message → (person → emoji)
  Future<Map<int, Map<String, String>>> messageReactions(List<int> ids);

  /// my reaction on a message (null takes it away); [had] when I had one before
  Future<void> reactMessage(int id, String? emoji, {bool had = false});

  /// reactions as they change in a conversation: (message, person, emoji or null)
  Stream<(int, String, String?)> liveReactions(int convId);

  /// someone typing in a conversation (a person's id), and telling the others I am
  Stream<String> typing(int convId);
  void sendTyping(int convId);

  Future<void> editMessage(int id, String body);
  Future<void> unsendMessage(int id);
  Future<Message?> message(int id);

  /// the pinned message and the disappearing time (seconds) of a conversation
  Future<(int?, int?)> chatMeta(int convId);
  Future<void> pinMessage(int convId, int? id);
  Future<void> setChatTtl(int convId, int? seconds);

  /// when the others last saw the conversation (read receipts)
  Future<Map<String, DateTime?>> chatSeen(int convId);

  /// muted until (null: sound on), in the archive or not
  Future<void> muteChat(int convId, DateTime? until);
  Future<void> archiveChat(int convId, bool on);

  /// messages with the words, newest first
  Future<List<Message>> searchMessages(int convId, String q);

  /// photos, links and places shared in a conversation
  Future<({List<Message> photos, List<Message> links, List<Message> places})> chatMedia(int convId);

  /// a group conversation: made with friends (its id), more added, renamed, left
  Future<int> createGroupChat(String title, List<String> members);
  Future<void> addToGroupChat(int convId, List<String> members);
  Future<void> renameGroupChat(int convId, String title);
  Future<void> leaveGroupChat(int convId);

  /// days in a row of writing to each other (dm_streaks): conversation → days
  Future<Map<int, int>> streaks();
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
  static const personSel = 'id,username,name,surname,bio,city,hue,avatar_url,cover_url,verified,last_seen,role,banned,rating,nameday,nameday_label,home_place,edu,gender';
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
  Future<Comment> addComment(int postId, String body, {int? parentId, Map<String, dynamic>? media}) async => Comment.fromJson(await sb
      .from('comments')
      .insert({'post_id': postId, 'author': myId, 'body': body, 'parent_id': parentId, if (media != null) 'media': media})
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
  Future<Post> createPost(String body, List<Media> media, {Poll? poll, int? placeId, bool draft = false, DateTime? publishAt, int? repostOf}) async {
    final r = await sb
        .from('posts')
        .insert({
          'author': myId,
          'body': body,
          'media': media.map((m) => m.toJson()).toList(),
          if (poll != null) 'poll': {'q': poll.q, 'opts': poll.opts},
          if (placeId != null) 'place_id': placeId,
          if (repostOf != null) 'repost_of': repostOf,
          if (draft) 'draft': true,
          if (publishAt != null) 'publish_at': publishAt.toUtc().toIso8601String(),
          if (media.length == 1 && media.first.isVideo && RegExp(r'#კლიპი|#clip', caseSensitive: false).hasMatch(body)) 'is_clip': true,
        })
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
  Future<Message> send(int convId, {String body = '', String kind = 'text', Map<String, dynamic>? media, int? replyTo}) async =>
      Message.fromJson(await sb
          .from('messages')
          .insert({'conv_id': convId, 'sender': myId, 'body': body, 'kind': kind, 'media': media, if (replyTo != null) 'reply_to': replyTo})
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
  Future<int> mutualFriends(String uid) async => asInt(await sb.rpc('mutual_friends', params: {'other': uid}));

  @override
  Future<void> visit(String uid) =>
      sb.from('profile_visits').upsert({'visitor': myId, 'visited': uid, 'visited_at': DateTime.now().toUtc().toIso8601String()}, onConflict: 'visitor,visited');

  @override
  Future<JokerLine?> jokerLine(String uid) async {
    final r = await sb.from('jk_ratings').select('rating,games,wins').eq('user_id', uid).maybeSingle();
    final st = await sb.from('jk_stats').select('g,w,best').eq('user_id', uid).maybeSingle();
    if (r == null && st == null) return null;
    final g = asInt(st?['g']) > 0 ? asInt(st?['g']) : asInt(r?['games']);
    if (g == 0) return null;
    return JokerLine(rating: r == null ? null : asInt(r['rating']), games: g, wins: asInt(st?['w']) > 0 ? asInt(st?['w']) : asInt(r?['wins']));
  }

  @override
  Future<List<(String, DateTime)>> badges(String uid) async => [
        for (final r in await sb.from('achievements').select('code,created_at').eq('user_id', uid).order('created_at')) ('${r['code']}', asTime(r['created_at'])),
      ];

  @override
  Future<List<String>> checkBadges() async {
    final r = await sb.rpc('check_achievements');
    return r is List ? [for (final x in r) '$x'] : const [];
  }

  @override
  Future<List<Highlight>> highlights(String uid) async =>
      [for (final r in await sb.from('highlights').select('id,title,cover_url').eq('owner', uid).order('pos').order('id').limit(30)) Highlight.fromJson(r)];

  @override
  Future<List<Story>> highlightItems(int id) async => [
        for (final r in await sb.from('highlight_items').select('id,story_id,url,media_type,created_at').eq('highlight_id', id).order('created_at'))
          Story(
            id: r['story_id'] == null ? -asInt(r['id']) : asInt(r['story_id']),
            itemId: asInt(r['id']),
            author: '',
            url: '${r['url'] ?? ''}',
            createdAt: asTime(r['created_at']),
            video: r['media_type'] == 'video',
            seen: true,
          ),
      ];

  @override
  Future<int> newHighlight(String title, int pos) async =>
      asInt((await sb.from('highlights').insert({'owner': myId, 'title': title, 'pos': pos}).select('id').single())['id']);

  @override
  Future<bool> addToHighlight(int highlight, int story) async => asInt(await sb.rpc('add_to_highlight', params: {'p_highlight': highlight, 'p_story': story})) > 0;

  @override
  Future<void> removeHighlightItem(int itemId) => sb.from('highlight_items').delete().eq('id', itemId);

  @override
  Future<void> renameHighlight(int id, String title) => sb.from('highlights').update({'title': title}).eq('id', id);

  @override
  Future<void> deleteHighlight(int id) => sb.from('highlights').delete().eq('id', id);

  @override
  Future<List<Story>> myStories() async => [
        for (final r in await sb
            .from('stories')
            .select('id,author,media_url,media_type,created_at,expires_at,audience,post_id')
            .eq('author', myId)
            .order('created_at', ascending: false)
            .limit(300))
          Story.fromJson(r, seen: true),
      ];

  @override
  Future<List<Album>> albums(String uid) async => [
        for (final r in await sb
            .from('albums')
            .select('id,owner,title,cover_url,photos,updated_at,created_at')
            .eq('owner', uid)
            .order('updated_at', ascending: false)
            .limit(40))
          Album.fromJson(r),
      ];

  @override
  Future<Map<String, dynamic>?> cv(String uid) => sb.from('cvs').select('*').eq('user_id', uid).maybeSingle();

  @override
  Future<List<String>> friendsOf(String uid) async => [
        for (final r in await sb.from('friendships').select('requester,addressee').eq('status', 'accepted').or('requester.eq.$uid,addressee.eq.$uid').limit(200))
          r['requester'] == uid ? '${r['addressee']}' : '${r['requester']}',
      ];

  @override
  Future<List<Post>> saved({int? folder}) async {
    var q = sb.from('saves').select('post_id').eq('user_id', myId);
    if (folder != null) q = q.eq('folder_id', folder);
    final ids = [for (final r in await q.order('created_at', ascending: false).limit(90)) asInt(r['post_id'])];
    if (ids.isEmpty) return [];
    final list = await _hydrate(await _posts().inFilter('id', ids));
    list.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
    return list;
  }

  @override
  Future<List<(int, String)>> saveFolders() async =>
      [for (final r in await sb.from('save_folders').select('id,name').eq('user_id', myId).order('created_at')) (asInt(r['id']), '${r['name'] ?? ''}')];

  @override
  Future<List<Visit>> guests() async => [
        for (final r in await sb.from('profile_visits').select('visitor,visited_at').eq('visited', myId).order('visited_at', ascending: false).limit(50))
          Visit('${r['visitor']}', asTime(r['visited_at'])),
      ];

  @override
  Future<int> guestsSince(DateTime since) =>
      sb.from('profile_visits').count(CountOption.exact).eq('visited', myId).gt('visited_at', since.toUtc().toIso8601String());

  @override
  Future<List<GiftGot>> giftsGot() async => [
        for (final r in await sb.from('gifts').select('emoji,sender,created_at').eq('recipient', myId).order('created_at', ascending: false).limit(60))
          GiftGot('${r['emoji']}', '${r['sender']}', asTime(r['created_at'])),
      ];

  @override
  Future<int> sendGift(String uid, String emoji) async => asInt(await sb.rpc('send_gift', params: {'p_to': uid, 'p_emoji': emoji}));

  @override
  Future<void> report(String type, String id, String reason) =>
      sb.from('reports').insert({'reporter': myId, 'target_type': type, 'target_id': id, 'reason': reason});

  @override
  Future<void> block(String uid) async {
    await sb.from('blocks').insert({'blocker': myId, 'blocked': uid});
    await sb.from('friendships').delete().or('and(requester.eq.$myId,addressee.eq.$uid),and(requester.eq.$uid,addressee.eq.$myId)');
  }

  @override
  Future<List<String>> closeFriends() async => [for (final r in await sb.from('close_friends').select('friend').eq('owner', myId)) '${r['friend']}'];

  @override
  Future<void> setClose(String uid, bool on) =>
      on ? sb.from('close_friends').insert({'owner': myId, 'friend': uid}) : sb.from('close_friends').delete().eq('owner', myId).eq('friend', uid);

  @override
  Future<List<Post>> drafts() async => _hydrate(await sb
      .from('posts')
      .select(postSel)
      .eq('author', myId)
      .or('draft.eq.true,created_at.gt.${DateTime.now().toUtc().toIso8601String()}')
      .order('created_at')
      .limit(60));

  @override
  Future<void> publishNow(int postId) => sb.from('posts').update({'draft': false, 'publish_at': null}).eq('id', postId);

  @override
  Future<void> schedulePost(int postId, DateTime at) => sb.from('posts').update({'draft': false, 'publish_at': at.toUtc().toIso8601String()}).eq('id', postId);

  @override
  Future<void> renameFolder(int id, String name) => sb.from('save_folders').update({'name': name}).eq('id', id);

  @override
  Future<void> deleteFolder(int id) => sb.from('save_folders').delete().eq('id', id);

  @override
  Future<int> gradePhoto(int postId, String grade) async => asInt(await sb.rpc('grade_photo', params: {'p_post': postId, 'p_grade': grade}));

  @override
  Future<void> banUser(String uid) => sb.rpc('admin_ban', params: {'p_user': uid, 'p_banned': true});

  @override
  Future<List<(String, int, int, int)>> gameRatings(String uid) async => [
        for (final r in await sb.from('game_ratings').select('game,rating,games,wins').eq('user_id', uid))
          ('${r['game']}', asInt(r['rating'], 1500), asInt(r['games']), asInt(r['wins'])),
      ];

  @override
  Future<int> sendCard(String uid, Map<String, dynamic> card) async {
    final conv = await startDm(uid);
    await send(conv, body: '🎉 მისალოცი ბარათი', media: {'card': card});
    return conv;
  }

  @override
  Future<Map<String, dynamic>> myCoins() async {
    final r = await sb.rpc('my_coins');
    return r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
  }

  @override
  Future<List<Map<String, dynamic>>> coinRules() async =>
      await sb.from('coin_rules').select('action,page,label,hint,amount,every_n,day_cap,once,active,pos').order('pos');

  @override
  Future<List<Map<String, dynamic>>> coinLog() async =>
      await sb.from('coin_log').select('amount,label,created_at,cash,n').eq('user_id', myId).order('created_at', ascending: false).limit(40);

  @override
  Future<Map<String, dynamic>> dailyBonus() async {
    final r = await sb.rpc('daily_bonus');
    return r is Map ? Map<String, dynamic>.from(r) : {'coins': asInt(r), 'got': 5};
  }

  static const _albSel = 'id,owner,title,cover_url,photos,updated_at,created_at,event_id';

  @override
  Future<(List<Album>, List<Album>, List<Album>)> albumsPage() async {
    final mine = await sb.from('albums').select(_albSel).eq('owner', myId).order('updated_at', ascending: false).limit(60);
    final mem = {for (final r in await sb.from('album_members').select('album_id').eq('user_id', myId).limit(100)) asInt(r['album_id'])};
    final other = await sb.from('albums').select(_albSel).neq('owner', myId).order('updated_at', ascending: false).limit(40);
    final o = other.map(Album.fromJson).toList();
    return (mine.map(Album.fromJson).toList(), o.where((a) => mem.contains(a.id)).toList(), o.where((a) => !mem.contains(a.id)).toList());
  }

  @override
  Future<Map<String, dynamic>?> album(int id) => sb.from('albums').select('*').eq('id', id).maybeSingle();

  @override
  Future<List<Map<String, dynamic>>> albumPhotos(int id) async =>
      await sb.from('album_photos').select('id,added_by,url,md,sm,w,h,caption,created_at').eq('album_id', id).order('created_at', ascending: false).limit(500);

  @override
  Future<List<String>> albumMembers(int id) async => [for (final r in await sb.from('album_members').select('user_id').eq('album_id', id)) '${r['user_id']}'];

  @override
  Future<bool> albumCanAdd(int id) async {
    try {
      return await sb.rpc('album_can_add', params: {'a': id, 'u': myId}) == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<int> createAlbum(String title, String? about, String audience) async =>
      asInt((await sb.from('albums').insert({'title': title, 'about': about, 'audience': audience, 'owner': myId}).select('id').single())['id']);

  @override
  Future<void> updateAlbum(int id, String title, String? about, String audience) =>
      sb.from('albums').update({'title': title, 'about': about, 'audience': audience}).eq('id', id);

  @override
  Future<void> deleteAlbum(int id) => sb.from('albums').delete().eq('id', id);

  @override
  Future<Map<String, dynamic>> addAlbumPhoto(int id, Media m) => sb
      .from('album_photos')
      .insert({'album_id': id, 'added_by': myId, 'url': m.url, 'md': m.md, 'sm': m.sm, 'w': m.w > 0 ? m.w : null, 'h': m.h > 0 ? m.h : null})
      .select('id,added_by,url,md,sm,w,h,caption,created_at')
      .single();

  @override
  Future<void> deleteAlbumPhoto(int photoId) => sb.from('album_photos').delete().eq('id', photoId);

  @override
  Future<void> inviteToAlbum(int id, List<String> uids) =>
      sb.from('album_members').insert([for (final u in uids) {'album_id': id, 'user_id': u, 'added_by': myId}]);

  @override
  Future<void> removeFromAlbum(int id, String uid) => sb.from('album_members').delete().eq('album_id', id).eq('user_id', uid);

  @override
  Future<void> saveCv(Map<String, dynamic> cv) =>
      sb.from('cvs').upsert({...cv, 'user_id': myId, 'updated_at': DateTime.now().toUtc().toIso8601String()}, onConflict: 'user_id');

  @override
  Future<List<int>> joinEduGroups() async {
    final r = await sb.rpc('join_edu_groups');
    return r is List ? [for (final x in r) asInt(x)] : const [];
  }

  @override
  Future<List<Profile>> classmates(String k, String key) async => [
        for (final r in await sb
            .from('profiles')
            .select(personSel)
            .filter('edu', 'cs', jsonEncode([
              {'k': k, 'key': key},
            ]))
            .neq('id', myId)
            .eq('onboarded', true)
            .limit(200))
          Profile.fromJson(r),
      ];

  static const _kinSel = 'id,owner,anchor,relative,name,relation,sex,born,died,status,created_at';

  @override
  Future<List<Map<String, dynamic>>> kinOf(String uid) async => await sb.from('kin').select(_kinSel).eq('owner', uid).order('id').limit(200);

  @override
  Future<List<Map<String, dynamic>>> kinRequests() async =>
      await sb.from('kin').select('id,owner,relation,created_at').eq('relative', myId).eq('status', 'pending');

  @override
  Future<void> addKin(Map<String, dynamic> row) => sb.from('kin').insert({...row, 'owner': myId});

  @override
  Future<void> updateKin(int id, Map<String, dynamic> fields) => sb.from('kin').update(fields).eq('id', id);

  @override
  Future<void> deleteKin(int id) => sb.from('kin').delete().eq('id', id);

  @override
  Future<void> respondKin(int id, bool accept) => sb.rpc('respond_kin', params: {'p_id': id, 'p_accept': accept});

  @override
  Future<List<Profile>> surnamePeople(String s) async =>
      [for (final r in await sb.from('profiles').select(personSel).eq('surname', s).eq('onboarded', true).order('created_at').limit(80)) Profile.fromJson(r)];

  @override
  Future<int?> surnameGroup(String s) async {
    final r = await sb.from('groups').select('id').eq('place_key', 'surname:${s.toLowerCase()}').maybeSingle();
    return r == null ? null : asInt(r['id']);
  }

  @override
  Future<int> joinSurnameGroup() async => asInt(await sb.rpc('join_surname_group'));

  @override
  Future<String?> verification() async {
    final r = await sb.from('verification_requests').select('status,created_at').eq('user_id', myId).order('created_at', ascending: false).limit(1).maybeSingle();
    return r == null ? null : '${r['status']}';
  }

  @override
  Future<void> requestVerification(Uint8List selfie) async {
    // the private bucket: a path, not a public link
    final path = '$myId/${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-${_id(6)}.jpg';
    await sb.storage.from('verify').uploadBinary(path, selfie, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
    await sb.from('verification_requests').insert({'user_id': myId, 'selfie_url': path});
  }

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
  Future<void> addStory(String url, {bool video = false, int? postId}) =>
      sb.from('stories').insert({'author': myId, 'media_url': url, 'media_type': video ? 'video' : 'image', 'audience': 'all', if (postId != null) 'post_id': postId});

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

  // ---- the home page ----

  @override
  Future<Map<String, dynamic>> appSettings() async {
    final rows = await sb.from('app_settings').select('key,value');
    return {for (final r in rows) '${r['key']}': r['value']};
  }

  @override
  Future<Map<String, int>> serviceCounts() async {
    final r = await sb.rpc('service_counts');
    final m = r is Map ? r : const {};
    return {for (final e in m.entries) '${e.key}': asInt(e.value)};
  }

  @override
  Future<Set<String>> tagFollows() async {
    final r = await sb.from('tag_follows').select('tag').eq('user_id', myId);
    return {for (final x in r) '${x['tag']}'};
  }

  @override
  Future<void> followTags(List<String> tags, bool on) async {
    if (tags.isEmpty) return;
    if (on) {
      final have = await tagFollows();
      final add = tags.where((t) => !have.contains(t)).toList();
      if (add.isNotEmpty) await sb.from('tag_follows').insert([for (final t in add) {'user_id': myId, 'tag': t}]);
    } else {
      await sb.from('tag_follows').delete().eq('user_id', myId).inFilter('tag', tags);
    }
  }

  @override
  Future<List<Post>> feedTagged(List<String> tags, {int limit = 5}) async {
    if (tags.isEmpty) return const [];
    return _hydrate(await _posts().isFilter('group_id', null).eq('hidden', false).overlaps('tags', tags.take(40).toList()).order('created_at', ascending: false).limit(limit));
  }

  @override
  Future<List<Post>> postsByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    return _hydrate(await _posts().inFilter('id', ids).order('created_at', ascending: false));
  }

  static const _promoSel = 'id,kind,brand,brand_url,title,body,media_url,media_type,w,h,link,cta,every,starts_at,ends_at,active';

  @override
  Future<List<Map<String, dynamic>>> promos() async {
    final rows = await sb.from('promos').select(_promoSel).order('created_at', ascending: false).limit(30);
    final now = DateTime.now();
    return [
      for (final r in rows)
        if (r['active'] == true &&
            !(DateTime.tryParse('${r['starts_at']}')?.isAfter(now) ?? false) &&
            (r['ends_at'] == null || (DateTime.tryParse('${r['ends_at']}')?.isAfter(now) ?? true)))
          Map<String, dynamic>.from(r),
    ];
  }

  @override
  Future<void> promoHit(int id, {bool click = false}) async {
    await sb.rpc('promo_hit', params: {'p_promo': id, 'p_click': click});
  }

  @override
  Future<List<(int, Post)>> adPosts() async {
    final ads = await sb.from('ads').select('id,post_id').eq('status', 'active').limit(6);
    if (ads.isEmpty) return const [];
    final posts = await postsByIds([for (final a in ads) asInt(a['post_id'])]);
    return [
      for (final p in posts) (asInt(ads.firstWhere((a) => asInt(a['post_id']) == p.id)['id']), p),
    ];
  }

  @override
  Future<void> adImpression(int adId) async {
    await sb.rpc('ad_impression', params: {'p_ad': adId});
  }

  @override
  Future<List<Map<String, dynamic>>> friendBirthdays() async {
    final r = await sb.rpc('friend_birthdays');
    return [for (final x in (r as List? ?? const [])) if (x is Map) Map<String, dynamic>.from(x)];
  }

  @override
  Future<List<int>> myMemories() async {
    final r = await sb.rpc('my_memories');
    return [for (final x in (r as List? ?? const [])) asInt(x is Map ? x.values.first : x)];
  }

  @override
  Future<(int, bool)> firstStepsCounts() async {
    final f = await sb.from('friendships').count(CountOption.exact).or('requester.eq.$myId,and(addressee.eq.$myId,status.eq.accepted)');
    final p = await sb.from('posts').count(CountOption.exact).eq('author', myId).eq('draft', false);
    return (f, p > 0);
  }

  @override
  Future<int?> welcomeGift() async {
    final r = await sb.from('coin_log').select('amount,created_at').eq('user_id', myId).eq('action', 'welcome').limit(1);
    if (r.isEmpty) return null;
    final at = DateTime.tryParse('${r.first['created_at']}');
    if (at != null && DateTime.now().difference(at).inDays >= 3) return null;
    return asInt(r.first['amount']);
  }

  @override
  Future<Map<String, int>> inviteRules() async {
    final rows = await sb.from('coin_rules').select('action,amount,active').inFilter('action', ['welcome', 'invite']);
    return {for (final x in rows) if (x['active'] == true && asInt(x['amount']) > 0) '${x['action']}': asInt(x['amount'])};
  }

  @override
  Future<(int, int)> referrals() async {
    final rows = await sb.from('referrals').select('paid').eq('inviter', myId);
    return (rows.length, rows.where((x) => x['paid'] == true).length);
  }
  @override
  Future<Map<int, (int, int?)>> repostStats(List<int> ids) async {
    if (ids.isEmpty) return {};
    final r = await sb.rpc('repost_stats', params: {'p_ids': ids});
    return {
      for (final x in (r as List? ?? const []))
        if (x is Map) asInt(x['post_id']): (asInt(x['n']), x['mine'] == null ? null : asInt(x['mine'])),
    };
  }

  @override
  Future<int> repost(int postId) async => asInt((await sb.from('posts').insert({'author': myId, 'body': '', 'repost_of': postId}).select('id').single())['id']);

  @override
  Future<void> unrepost(int repostId) => sb.from('posts').delete().eq('id', repostId).eq('author', myId);

  @override
  Future<Post> updatePost(int id, String body, {List<Media>? media, int? placeId, bool setPlace = false}) async {
    final r = await sb
        .from('posts')
        .update({
          'body': body,
          if (media != null) 'media': media.map((m) => m.toJson()).toList(),
          if (setPlace) 'place_id': placeId,
        })
        .eq('id', id)
        .eq('author', myId)
        .select(postSel)
        .single();
    return (await _hydrate([r])).firstOrNull ?? Post.fromJson(r);
  }

  @override
  Future<void> modHide(String type, int id, bool hidden) => sb.rpc('admin_hide', params: {'p_type': type, 'p_id': id, 'p_hidden': hidden});

  @override
  Future<void> saveToFolder(int postId, int? folder) => sb.from('saves').update({'folder_id': folder}).eq('user_id', myId).eq('post_id', postId);

  @override
  Future<(int, String)> newFolder(String name) async {
    final r = await sb.from('save_folders').insert({'user_id': myId, 'name': name}).select('id,name').single();
    return (asInt(r['id']), '${r['name'] ?? name}');
  }

  @override
  Future<(String, String?)> translate(String text, String source, String target) async {
    final r = await sb.functions.invoke('translate', body: {'text': text, 'source': source, 'target': target});
    final d = r.data;
    if (d is Map && d['text'] is String && '${d['text']}'.trim().isNotEmpty) return ('${d['text']}', d['source'] as String?);
    throw Exception('თარგმნა ახლა ვერ მოხერხდა. სცადე ცოტა ხანში');
  }

  @override
  Future<Set<int>> commentLikes(List<int> ids) async {
    if (ids.isEmpty) return {};
    return {for (final r in await sb.from('comment_likes').select('comment_id').eq('user_id', myId).inFilter('comment_id', ids.take(400).toList())) asInt(r['comment_id'])};
  }

  @override
  Future<void> likeComment(int id, bool on) async {
    if (on) {
      try {
        await sb.from('comment_likes').insert({'comment_id': id, 'user_id': myId});
      } on PostgrestException catch (e) {
        if (!'${e.message}'.contains('duplicate')) rethrow;
      }
    } else {
      await sb.from('comment_likes').delete().eq('comment_id', id).eq('user_id', myId);
    }
  }

  @override
  Future<void> deleteComment(int id) => sb.from('comments').delete().eq('id', id);

  static String _like(String q) => q.replaceAll(RegExp(r'[,()%*\\:"]'), ' ').trim();

  @override
  Future<List<Profile>> mentionPeople(String prefix) async {
    final s = prefix.replaceAll(RegExp(r'[^A-Za-z0-9_.]'), '');
    if (s.isEmpty) return [];
    final r = await sb.from('profiles').select(personSel).ilike('username', '${s.replaceAll('_', r'\_')}%').eq('onboarded', true).neq('id', myId).limit(6);
    return r.map(Profile.fromJson).toList();
  }

  @override
  Future<Profile?> personByUsername(String username) async {
    final r = await sb.from('profiles').select(personSel).eq('username', username).maybeSingle();
    return r == null ? null : Profile.fromJson(r);
  }

  @override
  Future<List<Post>> postsTagged(String tag, {int limit = 40}) async =>
      _hydrate(await _posts().eq('hidden', false).contains('tags', [tag]).order('created_at', ascending: false).limit(limit));

  @override
  Future<List<(String, int)>> trendingTags() async => [
        for (final x in (await sb.rpc('trending_tags', params: {'p_limit': 12}) as List? ?? const []))
          if (x is Map) ('${x['tag']}', asInt(x['uses'])),
      ];

  @override
  Future<List<Post>> searchPosts(String q) async {
    final s = _like(q);
    if (s.isEmpty) return [];
    return _hydrate(await _posts().eq('hidden', false).ilike('body', '%$s%').order('created_at', ascending: false).limit(20));
  }

  @override
  Future<List<Map<String, dynamic>>> searchPages(String q) async {
    final s = _like(q);
    if (s.isEmpty) return [];
    return await sb.from('pages').select('id,name,kind,hue,verified,category,avatar_url').ilike('name', '%$s%').limit(30);
  }

  @override
  Future<List<Map<String, dynamic>>> searchGroups(String q) async {
    final s = _like(q);
    if (s.isEmpty) return [];
    return await sb.from('groups').select('id,name,hue,is_private,description,avatar_url').ilike('name', '%$s%').limit(30);
  }

  @override
  Future<List<Map<String, dynamic>>> findPlaces(String q, {double? lat, double? lng}) async {
    final s = _like(q);
    if (s.isNotEmpty) return await sb.from('places').select('id,name,kind,city,lat,lng').ilike('name', '%$s%').eq('hidden', false).limit(20);
    final r = await sb.rpc('places_near', params: {'p_lat': lat ?? 41.7151, 'p_lng': lng ?? 44.8271, 'p_km': 40, 'p_kind': null, 'p_q': null, 'p_limit': 20});
    return [for (final x in (r as List? ?? const [])) if (x is Map) Map<String, dynamic>.from(x)];
  }
  @override
  Future<Map<int, Map<String, String>>> messageReactions(List<int> ids) async {
    if (ids.isEmpty) return {};
    final out = <int, Map<String, String>>{};
    for (final r in await sb.from('message_reactions').select('message_id,user_id,emoji').inFilter('message_id', ids.take(400).toList())) {
      if (r['emoji'] != null) (out[asInt(r['message_id'])] ??= {})['${r['user_id']}'] = '${r['emoji']}';
    }
    return out;
  }

  @override
  Future<void> reactMessage(int id, String? emoji, {bool had = false}) async {
    Future<void> upd() => sb.from('message_reactions').update({'emoji': emoji}).eq('message_id', id).eq('user_id', myId);
    if (had || emoji == null) return upd();
    try {
      await sb.from('message_reactions').upsert({'message_id': id, 'user_id': myId, 'emoji': emoji}, onConflict: 'message_id,user_id');
    } on PostgrestException catch (e) {
      if (RegExp('duplicate|conflict', caseSensitive: false).hasMatch(e.message)) return upd();
      rethrow;
    }
  }

  @override
  Stream<(int, String, String?)> liveReactions(int convId) {
    RealtimeChannel? ch;
    late final StreamController<(int, String, String?)> out;
    out = StreamController<(int, String, String?)>(
      onListen: () {
        ch = sb
            .channel('app-react-$convId-${_id(5)}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'message_reactions',
              filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conv_id', value: convId),
              callback: (pl) {
                final r = pl.newRecord;
                if (r.isNotEmpty && r['message_id'] != null && !out.isClosed) out.add((asInt(r['message_id']), '${r['user_id']}', r['emoji'] as String?));
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

  final _typingCh = <int, RealtimeChannel>{};

  @override
  Stream<String> typing(int convId) {
    late final StreamController<String> out;
    out = StreamController<String>(
      onListen: () {
        _typingCh[convId] = sb.channel('conv-$convId').onBroadcast(
          event: 'typing',
          callback: (p) {
            final u = p['u'] ?? (p['payload'] is Map ? (p['payload'] as Map)['u'] : null);
            if (u != null && u != myId && !out.isClosed) out.add('$u');
          },
        )..subscribe();
      },
      onCancel: () async {
        final c = _typingCh.remove(convId);
        if (c != null) await sb.removeChannel(c);
      },
    );
    return out.stream;
  }

  @override
  void sendTyping(int convId) {
    try {
      _typingCh[convId]?.sendBroadcastMessage(event: 'typing', payload: {'u': myId});
    } catch (_) {}
  }

  @override
  Future<void> editMessage(int id, String body) => sb.rpc('edit_message', params: {'p_id': id, 'p_body': body});

  @override
  Future<void> unsendMessage(int id) => sb.rpc('unsend_message', params: {'p_id': id});

  @override
  Future<Message?> message(int id) async {
    final r = await sb.from('messages').select(msgSel).eq('id', id).maybeSingle();
    return r == null ? null : Message.fromJson(r);
  }

  @override
  Future<(int?, int?)> chatMeta(int convId) async {
    final r = await sb.from('conversations').select('pinned_msg,ttl').eq('id', convId).maybeSingle();
    if (r == null) return (null, null);
    return (r['pinned_msg'] == null ? null : asInt(r['pinned_msg']), r['ttl'] == null ? null : asInt(r['ttl']));
  }

  @override
  Future<void> pinMessage(int convId, int? id) => sb.rpc('pin_message', params: {'p_conv': convId, 'p_msg': id});

  @override
  Future<void> setChatTtl(int convId, int? seconds) => sb.rpc('set_chat_ttl', params: {'p_conv': convId, 'p_ttl': seconds});

  @override
  Future<Map<String, DateTime?>> chatSeen(int convId) async => {
        for (final r in await sb.from('conversation_members').select('user_id,seen_at').eq('conv_id', convId))
          if ('${r['user_id']}' != myId) '${r['user_id']}': r['seen_at'] == null ? null : asTime(r['seen_at']),
      };

  @override
  Future<void> muteChat(int convId, DateTime? until) =>
      sb.from('conversation_members').update({'muted_until': until?.toUtc().toIso8601String()}).eq('conv_id', convId).eq('user_id', myId);

  @override
  Future<void> archiveChat(int convId, bool on) => sb.from('conversation_members').update({'archived': on}).eq('conv_id', convId).eq('user_id', myId);

  @override
  Future<List<Message>> searchMessages(int convId, String q) async {
    final s = q.replaceAll(RegExp(r'[%_\\]'), ' ').trim();
    if (s.length < 2) return [];
    return (await sb.from('messages').select(msgSel).eq('conv_id', convId).eq('deleted', false).ilike('body', '%$s%').order('created_at', ascending: false).limit(40))
        .map(Message.fromJson)
        .toList();
  }

  @override
  Future<({List<Message> photos, List<Message> links, List<Message> places})> chatMedia(int convId) async {
    final ph = sb.from('messages').select(msgSel).eq('conv_id', convId).eq('kind', 'image').eq('deleted', false).order('created_at', ascending: false).limit(150);
    final lk = sb.from('messages').select(msgSel).eq('conv_id', convId).eq('deleted', false).ilike('body', '%http%').order('created_at', ascending: false).limit(80);
    final lc = sb.from('messages').select(msgSel).eq('conv_id', convId).eq('deleted', false).not('media->loc', 'is', null).order('created_at', ascending: false).limit(40);
    return (photos: (await ph).map(Message.fromJson).toList(), links: (await lk).map(Message.fromJson).toList(), places: (await lc).map(Message.fromJson).toList());
  }

  @override
  Future<int> createGroupChat(String title, List<String> members) async => asInt(await sb.rpc('create_group_chat', params: {'p_title': title, 'p_members': members}));

  @override
  Future<void> addToGroupChat(int convId, List<String> members) => sb.rpc('add_to_group_chat', params: {'c': convId, 'p_members': members});

  @override
  Future<void> renameGroupChat(int convId, String title) => sb.from('conversations').update({'title': title}).eq('id', convId);

  @override
  Future<void> leaveGroupChat(int convId) => sb.from('conversation_members').delete().eq('conv_id', convId).eq('user_id', myId);

  @override
  Future<Map<int, int>> streaks() async => {
        for (final x in (await sb.rpc('dm_streaks') as List? ?? const []))
          if (x is Map && asInt(x['streak']) > 0) asInt(x['conv_id']): asInt(x['streak']),
      };
}
