// A profile page, as on the site (js/people.js loadUser): the cover (or the drawn mountains), the picture, the name,
// a line of who they are, about, chips (school, Joker, surname, angel's day, home), what can be done, the numbers,
// my coins and "my space" on my own page, the highlights, and the tabs: posts as a grid, albums, CV, saved or friends.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../chat/chat_screen.dart';
import '../data/models.dart';
import '../data/photos.dart';
import '../data/stores.dart';
import '../feed/compose_screen.dart';
import '../feed/photo_viewer.dart';
import '../profile/profile.dart';
import '../settings/edit_profile.dart';
import '../settings/frame_photo.dart';
import '../settings/settings_screens.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/net_image.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'albums.dart';
import 'badges.dart';
import 'coins.dart';
import 'cv_edit.dart';
import 'edu.dart';
import 'family.dart';
import 'my_space.dart';
import 'namedays.dart';
import 'post_grid.dart';
import 'profile_parts.dart';
import 'verify.dart';

/// Someone's page, or mine ([ownTab]: the profile tab). [extra] goes under my coins (a note when notifications are
/// off); [actions] in the bar.
class PersonScreen extends StatefulWidget {
  const PersonScreen({super.key, required this.uid, this.initial, this.ownTab = false, this.extra, this.actions = const [], this.onRefresh});
  final String uid;

  /// also run on pull-to-refresh (your own page: the coins)
  final Future<void> Function()? onRefresh;
  final Profile? initial;
  final bool ownTab;
  final Widget? extra;
  final List<Widget> actions;

  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

const _tabsMine = [('posts', 'grid', 'პოსტები'), ('albums', 'image', 'ალბომები'), ('cv', 'school', 'CV'), ('saved', 'bookmark', 'შენახული')];
const _tabsOther = [('posts', 'grid', 'პოსტები'), ('albums', 'image', 'ალბომები'), ('friends', 'users', 'მეგობრები'), ('cv', 'school', 'CV')];

class _PersonScreenState extends State<PersonScreen> {
  Profile? p;
  Counts? counts;
  List<Post>? posts;
  Object? error;
  int? mutual;
  JokerLine? joker;
  List<(String, DateTime)> badges = const [];
  List<Highlight> highlights = const [];
  bool blocked = false, _started = false, opening = false, _visited = false;
  String tab = 'posts';
  final _tabsKey = GlobalKey();

  // what each tab shows, loaded when first opened
  List<Album>? albums;
  Map<String, dynamic>? cv;
  bool cvLoaded = false;
  List<String>? friendIds;
  List<Post>? saved;
  List<(int, String)> folders = const [];
  int? folder;

  bool get mine => widget.uid == context.me.id;

  @override
  void initState() {
    super.initState();
    p = widget.initial;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.uid == context.me.id) p = widget.ownTab ? context.me : (p ?? context.me);
    final f = context.app.friends;
    if (!f.loaded) f.load().catchError((_) {});
    _load();
  }

  @override
  void didUpdateWidget(PersonScreen old) {
    super.didUpdateWidget(old);
    if (widget.ownTab && p != null) p = _mergeMine(p!);
  }

  Future<void> _load() async {
    final app = context.app, me = context.me, uid = widget.uid, isMe = uid == me.id;
    // a visit shows among their guests, unless I visit invisibly (as on the site)
    if (!isMe && !me.guest && !_visited) {
      _visited = true;
      app.api.visit(uid).catchError((_) {});
    }
    // the parts around the profile come as they come; none of them stops the page
    app.api.highlights(uid).then((h) {
      if (mounted) setState(() => highlights = h);
    }).catchError((_) {});
    app.api.jokerLine(uid).then((j) {
      if (mounted) setState(() => joker = j);
    }).catchError((_) {});
    (isMe ? _myBadges() : app.api.badges(uid)).then((b) {
      if (mounted) setState(() => badges = b);
    }).catchError((_) {});
    if (!isMe) {
      app.api.mutualFriends(uid).then((m) {
        if (mounted) setState(() => mutual = m);
      }).catchError((_) {});
      app.api.blocked().then((b) {
        if (mounted) setState(() => blocked = b.contains(uid));
      }).catchError((_) {});
    }
    try {
      final r = await Future.wait<Object?>([
        app.api.person(uid),
        app.api.counts(uid).then<Object?>((x) => x, onError: (_) => null),
        app.api.postsBy(uid, limit: 60),
      ]);
      final list = r[2] as List<Post>;
      await app.posts.load(list);
      if (!mounted) return;
      setState(() {
        final got = r[0] as Profile?;
        if (got != null) {
          p = widget.ownTab ? _mergeMine(got) : got;
          app.people.put(got);
        }
        counts = r[1] as Counts?;
        posts = list;
        error = got == null && p == null ? 'not found' : null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
    if (tab != 'posts') _loadTab(tab, force: true);
  }

  /// my badges: first the server looks for new ones (each brings coins, as on the site)
  Future<List<(String, DateTime)>> _myBadges() async {
    final app = context.app;
    try {
      final got = await app.api.checkBadges();
      if (got.isNotEmpty && mounted) {
        final sum = got.fold<int>(0, (a, c) => a + (badgeList[c]?.$4 ?? 0));
        final b = badgeList[got.first];
        if (b != null) toast(context, '${b.$1} ახალი ნიშანი: ${b.$2} · +$sum მონეტა');
        app.refreshMe?.call();
      }
    } catch (_) {}
    return app.api.badges(widget.uid);
  }

  /// my own profile from the server, with the coins the sign-in already knows
  Profile _mergeMine(Profile x) {
    final m = context.me;
    return Profile(
      id: x.id,
      name: x.name,
      surname: x.surname,
      username: x.username,
      avatarUrl: x.avatarUrl,
      coverUrl: x.coverUrl,
      city: x.city,
      bio: x.bio,
      hue: x.hue,
      verified: x.verified,
      lastSeen: x.lastSeen,
      coins: m.coins,
      onboarded: true,
      role: x.role,
      banned: x.banned,
      rating: x.rating,
      nameday: x.nameday,
      namedayLabel: x.namedayLabel,
      homePlace: x.homePlace,
      edu: x.edu,
      guest: m.guest,
      gender: x.gender ?? m.gender,
      lastBonus: m.lastBonus,
    );
  }

  Future<void> _loadTab(String k, {bool force = false}) async {
    final app = context.app, uid = widget.uid;
    try {
      switch (k) {
        case 'albums':
          if (albums != null && !force) return;
          final a = await app.api.albums(uid);
          if (mounted) setState(() => albums = a);
        case 'cv':
          if (cvLoaded && !force) return;
          final v = await app.api.cv(uid);
          if (mounted) {
            setState(() {
              cv = v;
              cvLoaded = true;
            });
          }
        case 'friends':
          if (friendIds != null && !force) return;
          final f = await app.api.friendsOf(uid);
          await app.people.ensure(f);
          if (mounted) setState(() => friendIds = f);
        case 'saved':
          if (saved != null && !force) return;
          final fs = await app.api.saveFolders();
          if (folder != null && !fs.any((x) => x.$1 == folder)) folder = null;
          final s = await app.api.saved(folder: folder);
          await app.posts.load(s);
          if (mounted) {
            setState(() {
              folders = fs;
              saved = s;
            });
          }
      }
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  void _tab(String k) {
    setState(() => tab = k);
    _loadTab(k);
  }

  /// a number under the profile: posts and friends go to their tab, the rating to Joker
  void _stat(String k) {
    if (k == 'rating') {
      final who = p;
      if (who != null) gamesCard(context, who, joker, mine: widget.uid == context.me.id);
      return;
    }
    if (k == 'friends' && mine) {
      context.app.goTab?.call('friends');
      return;
    }
    _tab(k == 'mutual' ? 'friends' : k);
    final ctx = _tabsKey.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250));
  }

  Future<void> _editEdu() async {
    await openPage(context, const EduScreen(), full: true);
    if (mounted) _load();
  }

  Future<void> _editCv() async {
    final saved = await openPage<bool>(context, const CvEditScreen(), full: true);
    if (saved == true && mounted) _loadTab('cv', force: true);
  }

  /// a saved folder: its new name, or removing it (the posts stay saved)
  Future<void> _folderMenu(int id, String name) async {
    final app = context.app;
    final ctl = TextEditingController(text: name);
    final done = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.pc.surface,
      builder: (s) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(s).bottom),
        child: SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), children: [
            Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(key: const ValueKey('fold-name'), controller: ctl, maxLength: 40, decoration: const InputDecoration(labelText: 'სახელი', counterText: '')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton(
                  key: const ValueKey('fold-save'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  onPressed: () async {
                    final v = ctl.text.trim();
                    if (v.isEmpty) return;
                    try {
                      await app.api.renameFolder(id, v);
                      if (s.mounted) Navigator.of(s).pop(true);
                    } catch (e) {
                      if (s.mounted) toast(s, errText(e));
                    }
                  },
                  child: const Text('შენახვა'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('fold-del'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), foregroundColor: s.pc.nope),
                  onPressed: () async {
                    try {
                      await app.api.deleteFolder(id);
                      folder = null;
                      if (s.mounted) Navigator.of(s).pop(true);
                    } catch (e) {
                      if (s.mounted) toast(s, errText(e));
                    }
                  },
                  child: const Text('საქაღალდის წაშლა'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text('წაშლისას პოსტები შენახულში დარჩება.', style: TextStyle(color: s.pc.muted, fontSize: 12.5)),
          ]),
        ),
      ),
    );
    if (done == true && mounted) {
      setState(() => saved = null);
      _loadTab('saved', force: true);
    }
  }

  Future<void> _edit() async {
    final saved = await openPage<bool>(context, const EditProfileScreen(), full: true);
    if (saved == true && mounted) _load();
  }

  /// my picture or cover, changed right from the page (framed, uploaded, saved)
  Future<void> _myPic({required bool cover}) async {
    final app = context.app;
    List<Uint8List> got;
    try {
      got = await photoSource(false);
    } catch (_) {
      return;
    }
    if (got.isEmpty || !mounted) return;
    final f = await photoFrame(context, got.first, aspect: cover ? 16 / 9 : 1, max: cover ? 1400 : 640, title: cover ? 'ფონის ფოტო' : 'პროფილის ფოტო');
    if (f == null || !mounted) return;
    toast(context, 'იტვირთება…');
    final ok = await attempt(context, () async {
      final m = await app.api.uploadPhoto(PreparedPhoto(f.bytes, f.w, f.h));
      await app.api.updateMe({cover ? 'cover_url' : 'avatar_url': m.url});
      await app.refreshMe?.call();
    });
    if (!ok || !mounted) return;
    toast(context, cover ? 'ფონი შეიცვალა' : 'ფოტო შეიცვალა');
    _load();
  }

  Future<void> _message() async {
    if (opening) return;
    setState(() => opening = true);
    try {
      final conv = await context.app.api.startDm(widget.uid);
      if (!mounted) return;
      setState(() => opening = false);
      await openChat(context, conv);
    } catch (e) {
      if (!mounted) return;
      setState(() => opening = false);
      toast(context, errText(e));
    }
  }

  void _openPerson(String uid) => openPage(context, PersonScreen(uid: uid));

  /// gift, share, family tree, relative, complaint, block (people.js umore)
  void _more() {
    final who = p;
    if (who == null) return;
    final friend = context.app.friends.stateWith(who.id) == Friendship.friends;
    showChoices(context, [
      SheetItem('gift', 'საჩუქრის გაგზავნა', () => giftSheet(context, who)),
      SheetItem('share', 'პროფილის გაზიარება', () => qrSheet(context, who)),
      SheetItem('tree', 'ოჯახის ხე', () => openPage(context, TreeScreen(uid: who.id))),
      if (friend) SheetItem('users', 'ნათესავად მონიშვნა', () => kinAddSheet(context, uid: who.id)),
      SheetItem('flag', 'საჩივარი', () => reportSheet(context, 'user', who.id)),
      if ((context.me.role == 'admin' || context.me.role == 'moderator') && !who.banned)
        SheetItem('shield', 'მოდერაცია: შეზღუდვა', () async {
          if (!await confirm(context,
                  title: 'მომხმარებლის შეზღუდვა', text: 'შეზღუდული მომხმარებელი ვეღარ დაწერს პოსტებს, კომენტარებს და შეტყობინებებს.', yes: 'შეზღუდვა', danger: true) ||
              !mounted) {
            return;
          }
          if (await attempt(context, () => context.app.api.banUser(who.id)) && mounted) {
            toast(context, 'შეიზღუდა');
            _load();
          }
        }, danger: true),
      if (!blocked)
        SheetItem('lock', 'დაბლოკვა', () async {
          if (await blockPerson(context, who) && mounted) setState(() => blocked = true);
        }, danger: true),
    ]);
  }

  Future<void> _unblock() async {
    if (await attempt(context, () => context.app.api.unblock(widget.uid)) && mounted) {
      setState(() => blocked = false);
      toast(context, 'განიბლოკა');
    }
  }

  Widget _friendButton(BuildContext context) {
    final f = context.app.friends, c = context.pc, uid = widget.uid, who = p;
    final filled = FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 10));
    final ghost = OutlinedButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 10), backgroundColor: c.sunk, side: BorderSide(color: c.line));
    Widget label(String t) => Flexible(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis));
    return switch (f.stateWith(uid)) {
      Friendship.none => FilledButton(
          key: const ValueKey('pro-add'),
          style: filled,
          onPressed: () async {
            if (await attempt(context, () => f.add(uid)) && context.mounted) toast(context, 'მოთხოვნა გაიგზავნა');
          },
          child: Row(mainAxisSize: MainAxisSize.min, children: [PIcon('plus', size: 18, color: c.onAccent), const SizedBox(width: 6), label('მეგობრად დამატება')]),
        ),
      Friendship.sent => OutlinedButton(
          style: ghost,
          onPressed: () => attempt(context, () => f.remove(uid)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [label('მოთხოვნა გაგზავნილია')]),
        ),
      Friendship.received => FilledButton(
          style: filled,
          onPressed: () async {
            if (await attempt(context, () => f.accept(uid)) && context.mounted) toast(context, 'ახლა მეგობრები ხართ');
          },
          child: const Text('დადასტურება'),
        ),
      Friendship.friends => OutlinedButton(
          key: const ValueKey('pro-friends'),
          style: ghost,
          onPressed: () => showChoices(context, [
            SheetItem('msg', 'შეტყობინება', _message),
            if (who != null) SheetItem('gift', 'საჩუქრის გაგზავნა', () => giftSheet(context, who)),
            SheetItem('x', 'მეგობრობის გაუქმება', () async {
              if (await confirm(context, title: 'მეგობრობის გაუქმება', text: '${who?.name ?? ''} აღარ იქნება შენს მეგობრებში.', yes: 'გაუქმება', danger: true) && context.mounted) {
                await attempt(context, () => f.remove(uid));
              }
            }, danger: true),
          ]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [PIcon('check', size: 18, color: c.ink), const SizedBox(width: 6), label('მეგობრები')]),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc, who = p, isMe = mine;
    final tabs = isMe ? _tabsMine : _tabsOther;
    if (!tabs.any((t) => t.$1 == tab)) tab = 'posts';
    return Scaffold(
      appBar: peeraBar(context, title: widget.ownTab ? 'პროფილი' : (who?.name ?? ''), actions: widget.actions),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([_load(), if (widget.onRefresh != null) widget.onRefresh!()]),
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          if (who == null)
            error != null
                ? Empty(icon: 'user', title: 'გვერდი ვერ ჩაიტვირთა', text: error is String ? 'პროფილი ვერ მოიძებნა' : errText(error!), action: 'ხელახლა ცდა', onAction: _load)
                : const SizedBox(height: 280, child: Center(child: SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 2.4))))
          else ...[
            _cover(context, who, isMe),
            Container(
              color: c.surface,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 8),
                Row(children: [
                  Flexible(child: Text(who.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15))),
                  if (who.verified) const Padding(padding: EdgeInsets.only(left: 6), child: Verified(size: 20)),
                ]),
                const SizedBox(height: 6),
                _meta(context, who, isMe),
                if ((who.bio ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(who.bio!.trim(), style: TextStyle(fontSize: 15, height: 1.45, color: c.ink)),
                ],
                _chips(context, who, isMe),
                const SizedBox(height: 14),
                _actions(context, who, isMe),
                const SizedBox(height: 14),
                _stats(context, who, isMe),
                if (isMe) ...[
                  const SizedBox(height: 12),
                  _wallet(context),
                  if (widget.extra != null) widget.extra!,
                  const SizedBox(height: 10),
                  _space(context, who),
                ],
                if (highlights.isNotEmpty) _highlights(context, who),
              ]),
            ),
            _tabBar(context, tabs),
            _tabBody(context, isMe),
          ],
        ]),
      ),
    );
  }

  // ---------- the parts ----------

  Widget _cover(BuildContext context, Profile who, bool isMe) {
    final c = context.pc;
    final pic = (who.coverUrl ?? '').isNotEmpty ? PImage(who.coverUrl!) : CustomPaint(painter: MountainArt(who.hue + 11));
    // the picture sits over the cover's lower edge (54 of its 112 points), as on the site
    return SizedBox(
      height: 172 + 58,
      child: Stack(children: [
        Positioned(left: 0, right: 0, top: 172, bottom: 0, child: ColoredBox(color: c.surface)),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 172,
          child: Semantics(
            button: isMe,
            label: isMe ? 'ფონის შეცვლა' : null,
            child: GestureDetector(
              key: const ValueKey('pro-cover'),
              onTap: isMe ? () => _myPic(cover: true) : null,
              child: Stack(fit: StackFit.expand, children: [
                ColoredBox(color: c.sunk, child: pic),
                if (isMe)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(color: const Color(0x8C0A060E), borderRadius: BorderRadius.circular(999)),
                      child: const PIcon('camera', size: 16, color: Colors.white),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        Positioned(left: 16, top: 172 - 54, child: _top(context, who, isMe)),
      ]),
    );
  }

  /// the picture, over the cover's edge (mine: a camera to change it; theirs: a tap shows it big)
  Widget _top(BuildContext context, Profile who, bool isMe) {
    final c = context.pc;
    return Semantics(
              button: true,
              label: isMe ? 'პროფილის ფოტოს შეცვლა' : 'ფოტოს ნახვა',
              child: GestureDetector(
                key: const ValueKey('pro-avatar'),
                onTap: isMe
                    ? () => _myPic(cover: false)
                    : ((who.avatarUrl ?? '').isEmpty ? null : () => openPhotos(context, [Media(url: who.avatarUrl!)])),
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4))]),
                    child: Avatar(p: who, size: 104),
                  ),
                  if (isMe)
                    Positioned(
                      right: 4,
                      bottom: 6,
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 3)),
                        child: PIcon('camera', size: 15, color: c.onAccent),
                      ),
                    )
                  else if (who.online)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(color: c.vine, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 3)),
                      ),
                    ),
                ]),
              ),
            );
  }

  /// @name (with the best badge), city, online, role
  Widget _meta(BuildContext context, Profile who, bool isMe) {
    final c = context.pc, top = topBadge(badges);
    final medal = top == null
        ? null
        : Semantics(
            button: true,
            label: 'ნიშანი: ${badgeList[top]!.$2}, ${tierNames[badgeList[top]!.$5]}. ყველა ნიშანი',
            child: GestureDetector(key: const ValueKey('pro-badge'), onTap: () => badgesSheet(context, who.id, who.name), child: Medal(top, size: 22)),
          );
    final parts = <Widget>[
      if ((who.username ?? '').isNotEmpty)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('@${who.username}', style: TextStyle(color: c.muted, fontSize: 13.5)),
          if (medal != null) ...[const SizedBox(width: 4), medal],
        ])
      else if (medal != null)
        medal,
      if ((who.city ?? '').isNotEmpty)
        Row(mainAxisSize: MainAxisSize.min, children: [
          PIcon('pin', size: 14, color: c.muted),
          const SizedBox(width: 2),
          Text(who.city!, style: TextStyle(color: c.muted, fontSize: 13.5)),
        ]),
      if (!isMe && who.online)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c.vine, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('ონლაინ', style: TextStyle(color: c.muted, fontSize: 13.5)),
        ]),
      if (who.role == 'admin' || who.role == 'moderator') Text(who.role == 'admin' ? 'ადმინისტრატორი' : 'მოდერატორი', style: TextStyle(color: c.muted, fontSize: 13.5)),
      if (who.banned) Text('შეზღუდულია', style: TextStyle(color: c.nope, fontSize: 13.5)),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 2, children: [
      for (var i = 0; i < parts.length; i++) ...[
        if (i > 0) Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('·', style: TextStyle(color: c.muted.withValues(alpha: .6)))),
        parts[i],
      ],
    ]);
  }

  /// school or university, Joker, surname, angel's day, home village
  Widget _chips(BuildContext context, Profile who, bool isMe) {
    final days = nameDaysOf(who.name, who.nameday, who.namedayLabel).map((d) => (d.$1, daysUntil(d.$1))).toList()..sort((a, b) => a.$2.compareTo(b.$2));
    final chips = <Widget>[
      for (final e in who.edu) _Chip(icon: e['k'] == 'uni' ? 'school' : 'book', text: _eduText(e), onTap: isMe ? _editEdu : null),
      if (isMe && who.edu.isEmpty) _Chip(key: const ValueKey('chip-edu'), icon: 'plus', text: 'სკოლა ან უნივერსიტეტი', onTap: _editEdu),
      if (joker != null)
        _Chip(icon: 'cards', text: 'ჯოკერი: ${joker!.rating != null ? '${joker!.rating} რეიტინგი · ' : ''}${joker!.games} თამაში · ${joker!.wins} მოგება'),
      if ((who.surname ?? '').isNotEmpty) _Chip(key: const ValueKey('chip-surname'), icon: 'users', text: 'გვარი: ${who.surname}', onTap: () => openPage(context, SurnameScreen(surname: who.surname!))),
      if (days.isNotEmpty) _Chip(icon: 'cal', text: 'ანგელოზის დღე: ${mdText(days.first.$1)}'),
      if ((who.homePlace ?? '').isNotEmpty) _Chip(icon: 'pin', text: who.homePlace!),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 10), child: Wrap(spacing: 6, runSpacing: 6, children: chips));
  }

  String _eduText(Map<String, dynamic> e) {
    final uni = e['k'] == 'uni';
    String s(String k) => '${e[k] ?? ''}'.trim();
    final name = uni ? (uniShortNames[s('key')] ?? s('n')) : s('n');
    final years = uni ? (s('y0').isEmpty && s('y1').isEmpty ? '' : '${s('y0')}${s('y1').isEmpty ? '' : '–${s('y1')}'}') : s('y1');
    return [name, if (uni && s('f').isNotEmpty) s('f'), if (years.isNotEmpty) years].join(' · ') + (s('cls').isEmpty ? '' : ' „${s('cls')}“');
  }

  Widget _actions(BuildContext context, Profile who, bool isMe) {
    final c = context.pc;
    final ghost = OutlinedButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 10), backgroundColor: c.sunk, side: BorderSide(color: c.line));
    Widget square(String icon, String label, VoidCallback onTap, {Key? key}) => Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: Material(
            color: c.sunk,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: key,
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: SizedBox(width: 42, height: 42, child: Center(child: PIcon(icon, size: 19, color: c.ink))),
            ),
          ),
        );
    Widget iconText(String icon, String t, Color col) => Row(mainAxisSize: MainAxisSize.min, children: [
          PIcon(icon, size: 18, color: col),
          const SizedBox(width: 6),
          Flexible(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]);
    if (isMe) {
      return Row(children: [
        Expanded(
          flex: 135,
          child: FilledButton(
            key: const ValueKey('edit-profile'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 10)),
            onPressed: _edit,
            child: iconText('edit', 'რედაქტირება', c.onAccent),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 100,
          child: OutlinedButton(
            key: const ValueKey('pro-settings'),
            style: ghost,
            onPressed: () => openSettings(context),
            child: iconText('gear', 'პარამეტრები', c.ink),
          ),
        ),
        const SizedBox(width: 8),
        square('share', 'პროფილის გაზიარება', () => qrSheet(context, who), key: const ValueKey('pro-share')),
      ]);
    }
    if (blocked) {
      return Row(children: [
        Expanded(child: OutlinedButton(key: const ValueKey('pro-unblock'), style: ghost, onPressed: _unblock, child: const Text('განბლოკვა'))),
        const SizedBox(width: 8),
        square('more', 'მეტი', _more, key: const ValueKey('pro-more')),
      ]);
    }
    return ListenableBuilder(
      listenable: context.app.friends,
      builder: (context, _) => Row(children: [
        Expanded(flex: 135, child: _friendButton(context)),
        const SizedBox(width: 8),
        Expanded(
          flex: 100,
          child: OutlinedButton(
            key: const ValueKey('pro-message'),
            style: ghost,
            onPressed: _message,
            child: opening ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : iconText('msg', 'მიწერა', c.ink),
          ),
        ),
        const SizedBox(width: 8),
        square('more', 'მეტი', _more, key: const ValueKey('pro-more')),
      ]),
    );
  }

  Widget _stats(BuildContext context, Profile who, bool isMe) {
    final c = context.pc;
    final items = [
      ('posts', counts?.posts, 'პოსტი'),
      ('friends', counts?.friends, 'მეგობარი'),
      ('rating', who.rating ?? 1500, 'რეიტინგი'),
      if (!isMe) ('mutual', mutual, 'საერთო'),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: c.sunk,
        child: Row(children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Container(
                decoration: BoxDecoration(border: i == 0 ? null : Border(left: BorderSide(color: c.line))),
                child: InkWell(
                  key: ValueKey('stat-${items[i].$1}'),
                  onTap: () => _stat(items[i].$1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Column(children: [
                      Text(items[i].$2 == null ? '·' : grouped(items[i].$2!),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.2, fontFeatures: [FontFeature.tabularFigures()])),
                      Text(items[i].$3, style: TextStyle(fontSize: 11.5, color: c.muted)),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  /// my coins (the site's wallet card): the balance, and whether today's bonus waits
  Widget _wallet(BuildContext context) {
    final c = context.pc, me = context.me;
    return Material(
      color: Color.alphaBlend(c.gold.withValues(alpha: .12), c.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Color.alphaBlend(c.gold.withValues(alpha: .3), c.line))),
      child: InkWell(
        key: const ValueKey('pro-wallet'),
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await openPage(context, const CoinsScreen(), full: true);
          if (mounted) setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.gold, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: c.gold.withValues(alpha: .35), blurRadius: 12, offset: const Offset(0, 4))]),
              child: const PIcon('coin', size: 22, color: Color(0xFF1A1205)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('მონეტები', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                Text(bonusWaits(me.lastBonus) ? 'დღის ბონუსი გელოდება' : 'ისტორია, წესები, ბონუსი',
                    style: TextStyle(color: bonusWaits(me.lastBonus) ? c.accent : c.muted, fontSize: 12.5, fontWeight: bonusWaits(me.lastBonus) ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
            Text(grouped(me.coins), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c.ink, fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ),
      ),
    );
  }

  /// "my space": a row of shortcuts, scrolled sideways (verification first while there is no tick)
  Widget _space(BuildContext context, Profile who) {
    final c = context.pc, app = context.app;
    Widget tile(String key, String icon, String label, Color col, VoidCallback onTap, {int badge = 0, String? note}) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Material(
            color: c.sunk,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              key: ValueKey('space-$key'),
              borderRadius: BorderRadius.circular(999),
              onTap: onTap,
              child: Container(
                height: 42,
                padding: const EdgeInsets.fromLTRB(6, 0, 14, 0),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Color.alphaBlend(col.withValues(alpha: .16), c.surface), shape: BoxShape.circle),
                    child: PIcon(icon, size: 17, color: col),
                  ),
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  if (note != null) ...[const SizedBox(width: 6), Text(note, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.muted))],
                  if (badge > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: c.nope, borderRadius: BorderRadius.circular(999)),
                      child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        );
    final got = badges.where((b) => badgeList.containsKey(b.$1)).length;
    return SizedBox(
      height: 46,
      child: ListenableBuilder(
        listenable: app.friends,
        builder: (context, _) => ListView(key: const ValueKey('space-row'), scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(vertical: 2), children: [
          if (!who.verified) tile('verify', 'shield', 'ვერიფიკაცია', const Color(0xFF3E8EF7), () => openPage(context, const VerifyScreen(), full: true)),
          tile('friends', 'users', 'მეგობრები', c.accent, () => app.goTab?.call('friends'), badge: app.friends.incoming.length),
          tile('guests', 'eye', 'სტუმრები', const Color(0xFF3E8EF7), () => guestsSheet(context, open: _openPerson, invisible: context.me.guest)),
          tile('badges', 'trophy', 'ნიშნები', c.gold, () => badgesSheet(context, who.id, who.name), note: '$got/${badgeList.length}'),
          tile('gifts', 'gift', 'საჩუქრები', c.nope, () => giftsGotSheet(context)),
          tile('stories', 'story', 'ისტორიები', c.accent, () => openPage(context, const StoryArchiveScreen(), full: true).then((_) => _load())),
          tile('tree', 'tree', 'ოჯახის ხე', c.vine, () => openPage(context, TreeScreen(uid: who.id), full: true)),
          tile('albums', 'image', 'ალბომები', c.accent, () => openPage(context, const AlbumsScreen(), full: true).then((_) => _loadTab('albums', force: true))),
          tile('close', 'star', 'ახლო მეგობრები', c.gold, () => openPage(context, const CloseFriendsScreen(), full: true)),
          tile('drafts', 'clock', 'დრაფტები', c.muted, () => openPage(context, const DraftsScreen(), full: true).then((_) => _load())),
          tile('namedays', 'cal', 'ანგელოზის დღე', c.vine, () => openPage(context, const NamedaysScreen(), full: true).then((_) => _load())),
        ]),
      ),
    );
  }

  Widget _highlights(BuildContext context, Profile who) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 92,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final h in highlights)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Semantics(
                button: true,
                label: h.title,
                excludeSemantics: true,
                child: GestureDetector(
                  key: ValueKey('hl-${h.id}'),
                  onTap: () => openHighlight(context, h, who.id).then((_) => _load()),
                  child: SizedBox(
                    width: 66,
                    child: Column(children: [
                      Container(
                        width: 62,
                        height: 62,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: c.line, width: 1.5)),
                        child: ClipOval(
                          child: (h.cover ?? '').isNotEmpty ? PImage(h.cover!) : ColoredBox(color: c.sunk, child: Center(child: PIcon('star', size: 24, color: c.muted))),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _tabBar(BuildContext context, List<(String, String, String)> tabs) {
    final c = context.pc;
    return Container(
      key: _tabsKey,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(color: c.surface, border: Border.symmetric(horizontal: BorderSide(color: c.line))),
      child: Row(children: [
        for (final t in tabs)
          Expanded(
            child: Semantics(
              selected: tab == t.$1,
              button: true,
              child: InkWell(
                key: ValueKey('ptab-${t.$1}'),
                onTap: () => _tab(t.$1),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tab == t.$1 ? c.accent : Colors.transparent, width: 2))),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  // the whole word, made a little smaller when four do not fit
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        PIcon(t.$2, size: 18, color: tab == t.$1 ? c.ink : c.muted),
                        const SizedBox(width: 5),
                        Text(t.$3, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tab == t.$1 ? c.ink : c.muted)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _tabBody(BuildContext context, bool isMe) {
    const wait = Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)));
    switch (tab) {
      case 'albums':
        final a = albums;
        if (a == null) return wait;
        if (a.isEmpty) {
          return Empty(
            icon: 'image',
            title: isMe ? 'ალბომები ჯერ არ გაქვს' : 'ალბომები ჯერ არ არის',
            text: isMe ? 'შექმენი ალბომი და მოიწვიე მეგობრები.' : null,
            action: isMe ? 'ალბომის შექმნა' : null,
            onAction: isMe ? () => albumForm(context, done: () => _loadTab('albums', force: true)) : null,
          );
        }
        return Padding(padding: const EdgeInsets.only(top: 12), child: albumGrid(a, onChanged: () => _loadTab('albums', force: true)));
      case 'cv':
        if (!cvLoaded) return wait;
        final v = cv;
        final shown = v != null && (v['visible'] == true || isMe);
        if (!shown) {
          return Empty(
            icon: 'school',
            title: isMe ? 'CV ჯერ არ გაქვს' : 'CV არ არის გამოქვეყნებული',
            text: isMe ? 'შექმენი და ვაკანსიებზე ერთი შეხებით გამოეხმაურე.' : null,
            action: isMe ? 'CV-ის შექმნა' : null,
            onAction: isMe ? _editCv : null,
          );
        }
        return CvView(cv: v, who: p!, mine: isMe, onEdit: _editCv);
      case 'friends':
        final f = friendIds;
        if (f == null) return wait;
        if (f.isEmpty) return const Empty(icon: 'users', title: 'მეგობრები ჯერ არ არის');
        final people = context.app.people;
        return Column(children: [
          const SizedBox(height: 8),
          for (final id in f)
            ListTile(
              key: ValueKey('pfriend-$id'),
              leading: Avatar(p: people[id] ?? Profile(id: id, name: '…'), size: 44),
              title: NameLine(people[id] ?? Profile(id: id, name: '…'), size: 15),
              subtitle: (people[id]?.city ?? '').isEmpty ? null : Text(people[id]!.city!, style: TextStyle(color: context.pc.muted, fontSize: 13)),
              onTap: () => _openPerson(id),
            ),
        ]);
      case 'saved':
        final s = saved;
        final c = context.pc;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 52,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), children: [
              for (final f in [(null, 'ყველა'), ...folders.map((x) => (x.$1, x.$2))])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: ValueKey('savf-${f.$1}'),
                    label: Text(f.$2),
                    selected: folder == f.$1,
                    showCheckmark: false,
                    selectedColor: c.ink,
                    labelStyle: TextStyle(color: folder == f.$1 ? c.bg : c.ink, fontWeight: FontWeight.w600),
                    onSelected: (_) {
                      setState(() {
                        folder = f.$1;
                        saved = null;
                      });
                      _loadTab('saved', force: true);
                    },
                  ),
                ),
              if (folder != null)
                IconBtn('more', key: const ValueKey('savf-menu'), label: 'საქაღალდის მართვა', size: 22, onTap: () {
                  final f = folders.where((x) => x.$1 == folder).firstOrNull;
                  if (f != null) _folderMenu(f.$1, f.$2);
                }),
            ]),
          ),
          if (s == null)
            wait
          else if (s.isEmpty)
            Empty(
              icon: 'bookmark',
              title: folder != null ? 'ეს საქაღალდე ცარიელია' : 'შენახული ჯერ არაფერია',
              text: folder != null ? 'პოსტის შენახვისას ზემოთ ამოვა ღილაკი „საქაღალდეში“.' : 'პოსტთან სანიშნეს დააჭირე და აქ გამოჩნდება.',
            )
          else
            PostGrid(posts: s, onGone: (x) => setState(() => saved!.removeWhere((y) => y.id == x.id))),
        ]);
      default:
        final l = posts;
        if (l == null) return wait;
        if (l.isEmpty) {
          return Empty(
            icon: 'edit',
            title: isMe ? 'ჯერ არაფერი დაგიწერია' : 'პოსტები ჯერ არ არის',
            text: isMe ? 'გაუზიარე მეგობრებს პირველი ფიქრი ან ფოტო.' : null,
            action: isMe ? 'პოსტის დაწერა' : null,
            onAction: isMe
                ? () async {
                    final x = await openPage<Post>(context, const ComposeScreen(), full: true);
                    if (x != null && mounted) _load();
                  }
                : null,
          );
        }
        return PostGrid(posts: l, onGone: (x) => setState(() => posts!.removeWhere((y) => y.id == x.id)));
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.icon, required this.text, this.onTap});
  final String icon, text;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Material(
      color: c.sunk,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            PIcon(icon, size: 14, color: c.accent),
            const SizedBox(width: 5),
            Flexible(child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.ink))),
          ]),
        ),
      ),
    );
  }
}

/// A CV as the site lays it out (jobs.js cvHTML): who, the headline, about, experience, education, skills, languages,
/// the phone; mine with who sees it and a way to edit it.
class CvView extends StatelessWidget {
  const CvView({super.key, required this.cv, required this.who, required this.mine, this.onEdit});
  final Map<String, dynamic> cv;
  final Profile who;
  final bool mine;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    List<Map> rows(Object? a) => [for (final x in (a is List ? a : const [])) if (x is Map && ('${x['a'] ?? ''}'.isNotEmpty || '${x['b'] ?? ''}'.isNotEmpty)) x];
    List<String> words(Object? a) => [for (final x in (a is List ? a : const [])) if ('$x'.trim().isNotEmpty) '$x'];
    final exp = rows(cv['experience']), edu = rows(cv['education']), sk = words(cv['skills']), lg = words(cv['languages']);
    final visible = cv['visible'] == true, phone = '${cv['phone'] ?? ''}'.trim();
    Widget sec(String title, String icon, Widget body) => Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [PIcon(icon, size: 18, color: c.accent), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))]),
            const SizedBox(height: 8),
            body,
          ]),
        );
    Widget item(Map x, String icon) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
              child: PIcon(icon, size: 15, color: c.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${(x['a'] ?? '').toString().isNotEmpty ? x['a'] : x['b']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                if ('${x['a'] ?? ''}'.isNotEmpty && '${x['b'] ?? ''}'.isNotEmpty) Text('${x['b']}', style: TextStyle(color: c.muted, fontSize: 13.5)),
              ]),
            ),
            if ('${x['c'] ?? ''}'.isNotEmpty) Text('${x['c']}', style: TextStyle(color: c.muted, fontSize: 12.5, fontStyle: FontStyle.italic)),
          ]),
        );
    Widget chips(List<String> l) => Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in l)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(999)),
              child: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (mine)
          Row(children: [
            PIcon(visible ? 'eye' : 'lock', size: 16, color: visible ? c.vine : c.muted),
            const SizedBox(width: 6),
            Expanded(child: Text(visible ? 'ყველა ხედავს' : 'მხოლოდ დამსაქმებლები ხედავენ', style: TextStyle(color: c.muted, fontSize: 13))),
            TextButton.icon(key: const ValueKey('cv-edit'), onPressed: onEdit, icon: PIcon('edit', size: 16, color: c.accent), label: const Text('რედაქტირება')),
          ]),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
          child: Row(children: [
            Avatar(p: who, size: 68),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                NameLine(who, size: 18, weight: FontWeight.w800),
                if ('${cv['headline'] ?? ''}'.isNotEmpty) Text('${cv['headline']}', style: TextStyle(color: c.ink, fontSize: 14.5)),
                if ((who.city ?? '').isNotEmpty)
                  Row(children: [PIcon('pin', size: 14, color: c.muted), const SizedBox(width: 3), Text(who.city!, style: TextStyle(color: c.muted, fontSize: 13))]),
              ]),
            ),
          ]),
        ),
        if ('${cv['summary'] ?? ''}'.trim().isNotEmpty) sec('ჩემ შესახებ', 'user', Text('${cv['summary']}'.trim(), style: const TextStyle(fontSize: 15, height: 1.45))),
        if (exp.isNotEmpty) sec('გამოცდილება', 'work', Column(children: [for (final x in exp) item(x, 'work')])),
        if (edu.isNotEmpty) sec('განათლება', 'school', Column(children: [for (final x in edu) item(x, 'school')])),
        if (sk.isNotEmpty) sec('უნარები', 'star', chips(sk)),
        if (lg.isNotEmpty) sec('ენები', 'globe', chips(lg)),
        if (phone.replaceAll(RegExp(r'[^+0-9]'), '').isNotEmpty)
          sec(
            'კონტაქტი',
            'phone',
            Material(
              color: c.sunk,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^+0-9]'), ''))),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
                      child: PIcon('phone', size: 15, color: c.accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(phone, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('დარეკვა', style: TextStyle(color: c.muted, fontSize: 12.5)),
                      ]),
                    ),
                    PIcon('chev', size: 18, color: c.muted),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
