import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../people/search_screen.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'chat_screen.dart';
import 'chat_tools.dart';

/// The conversations, newest first: a search over them, who is online now in a row (a tap writes to them), each
/// conversation a card with what was said last, when, and how many are unread (the unread ones stand out).
class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key, this.archived = false});
  final bool archived;
  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  String q = '';
  final findCtl = TextEditingController();

  bool get archived => widget.archived;

  @override
  void dispose() {
    findCtl.dispose();
    super.dispose();
  }

  Future<void> _new(BuildContext context) async {
    final uid = await openPage<String>(context, const _PickFriend());
    if (uid == null || !context.mounted) return;
    final app = context.app;
    try {
      final conv = await app.api.startDm(uid);
      if (context.mounted) await openChat(context, conv);
    } catch (e) {
      if (context.mounted) toast(context, errText(e));
    }
  }

  Future<void> _group(BuildContext context) async {
    final id = await openPage<int>(context, const NewGroupChatScreen(), full: true);
    if (id != null && context.mounted) await openChat(context, id);
  }

  String _title(Chat ch) {
    final app = context.app;
    if (ch.isGroup) return (ch.title ?? '').isEmpty ? 'ჯგუფი' : ch.title!;
    return ch.other == null ? '' : (app.people[ch.other!]?.fullName ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app, c = context.pc;
    return Scaffold(
      appBar: peeraBar(context, title: archived ? 'არქივი' : 'მიმოწერა', actions: [
        if (!archived) IconBtn('users', key: const ValueKey('new-group'), label: 'ახალი ჯგუფი', onTap: () => _group(context)),
        if (!archived) IconBtn('edit', label: 'ახალი მიმოწერა', onTap: () => _new(context)),
      ]),
      body: ListenableBuilder(
        listenable: Listenable.merge([app.chats, app.people, app.friends]),
        builder: (context, _) {
          final store = app.chats;
          final all = store.chats.where((x) => x.archived == archived).toList();
          final words = q.trim().toLowerCase();
          final list = words.isEmpty ? all : [for (final x in all) if (_title(x).toLowerCase().contains(words) || x.lastText.toLowerCase().contains(words)) x];
          final arch = store.chats.where((x) => x.archived).toList();
          final online = archived ? const <Profile>[] : [for (final id in app.friends.friends) if (app.people[id]?.online == true) app.people[id]!];
          Widget body;
          if (!store.loaded) {
            body = const Center(child: SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 2.4)));
          } else if (store.error != null && store.chats.isEmpty) {
            body = ListView(children: [Empty(icon: 'msg', title: 'მიმოწერა ვერ ჩაიტვირთა', text: errText(store.error!), action: 'ხელახლა ცდა', onAction: store.load)]);
          } else if (all.isEmpty && (archived || arch.isEmpty)) {
            body = ListView(children: [
              Empty(
                icon: 'msg',
                title: archived ? 'არქივი ცარიელია' : 'ჯერ არავისთან გიწერია',
                text: archived ? null : 'მიწერე მეგობარს — შეტყობინებები აქ გამოჩნდება.',
                action: archived ? null : 'ახალი მიმოწერა',
                onAction: () => _new(context),
              ),
            ]);
          } else {
            body = ListView(padding: const EdgeInsets.only(top: 4, bottom: 16), children: [
              if (all.length > 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                  child: TextField(
                    key: const ValueKey('ch-find'),
                    controller: findCtl,
                    onChanged: (v) => setState(() => q = v),
                    decoration: InputDecoration(
                      hintText: 'მოძებნე მიმოწერაში',
                      isDense: true,
                      filled: true,
                      fillColor: c.surface,
                      prefixIcon: Padding(padding: const EdgeInsets.all(11), child: PIcon('search', size: 18, color: c.muted)),
                      prefixIconConstraints: const BoxConstraints(minWidth: 40),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.line)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.accent, width: 1.5)),
                    ),
                  ),
                ),
              if (online.isNotEmpty && words.isEmpty)
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    key: const ValueKey('ch-online'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                    itemCount: online.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final p = online[i];
                      return Rise(
                        order: i,
                        dy: 8,
                        child: Pressable(
                          key: ValueKey('ch-on-${p.id}'),
                          onTap: () => chatWith(context, p.id),
                          child: SizedBox(
                            width: 66,
                            child: Column(children: [
                              Avatar(p: p, size: 56, online: true),
                              const SizedBox(height: 5),
                              Text(p.name.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (list.isEmpty && words.isNotEmpty)
                Padding(padding: const EdgeInsets.all(28), child: Center(child: Text('ასეთი მიმოწერა ვერ ვიპოვე', style: TextStyle(color: c.muted)))),
              for (final (i, ch) in list.indexed) Rise(key: ValueKey('chr-${ch.convId}'), order: i, child: ChatRow(key: ValueKey('chat-${ch.convId}'), chat: ch)),
              if (!archived && arch.isNotEmpty && words.isEmpty)
                Pressable(
                  onTap: () => openPage(context, const ChatsTab(archived: true)),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    padding: const EdgeInsets.all(10),
                    decoration: cardLook(context, radius: 18, color: c.sunk),
                    child: Row(children: [
                      Container(
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                        child: PIcon('archive', size: 23, color: c.muted),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('არქივი', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          Text('${arch.length} მიმოწერა', style: TextStyle(color: c.muted, fontSize: 13)),
                        ]),
                      ),
                      PIcon('chev', size: 20, color: c.muted),
                    ]),
                  ),
                ),
              if (list.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                  child: Text('საუბარს დიდხანს დააჭირე: დადუმება ან არქივი.', style: TextStyle(color: c.muted, fontSize: 12.5)),
                ),
            ]);
          }
          return RefreshIndicator(onRefresh: () => store.load(fresh: true), child: body);
        },
      ),
    );
  }
}

/// A conversation in the list: a card with the picture (the green dot when they are online), the name and when, what
/// was said last, how many are unread; the unread ones lifted a little and tinted.
class ChatRow extends StatelessWidget {
  const ChatRow({super.key, required this.chat});
  final Chat chat;
  @override
  Widget build(BuildContext context) {
    final c = context.pc, app = context.app, me = context.me;
    final other = chat.other == null ? null : (app.people[chat.other!] ?? Profile(id: chat.other!, name: '…'));
    final title = chat.isGroup ? ((chat.title ?? '').isEmpty ? 'ჯგუფი' : chat.title!) : (other?.fullName ?? '');
    final unread = chat.unread > 0;
    final from = chat.lastSender == me.id
        ? 'შენ: '
        : chat.isGroup && chat.lastSender != null && app.people[chat.lastSender!] != null
            ? '${app.people[chat.lastSender!]!.name}: '
            : '';
    final last = '$from${chat.lastText}';
    final fire = app.chats.streaks[chat.convId];
    return Pressable(
      onTap: () => openChat(context, chat.convId),
      onLongPress: () => chatMenu(context, chat),
      scale: .98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        decoration: cardLook(context, radius: 18, raised: unread, color: unread ? Color.alphaBlend(c.accent.withValues(alpha: .07), c.surface) : null),
        child: Row(children: [
          if (other != null) Avatar(p: other, size: 54, online: other.online) else GroupAvatar(id: chat.convId, size: 54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(title.isEmpty ? 'უსახელო' : title,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.5, fontWeight: unread ? FontWeight.w800 : FontWeight.w700)),
                ),
                if (other?.verified == true) const Verified(size: 14),
                if (fire != null) Padding(padding: const EdgeInsets.only(left: 5), child: Text('🔥$fire', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                if (chat.muted) Padding(padding: const EdgeInsets.only(left: 5), child: PIcon('mute', size: 15, color: c.muted)),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Flexible(
                  child: Text(last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: unread ? c.ink : c.muted, fontSize: 14, fontWeight: unread ? FontWeight.w600 : FontWeight.w400)),
                ),
                if (chat.lastAt != null) Text(' · ${ago(chat.lastAt!)}', style: TextStyle(color: unread ? c.accent : c.muted, fontSize: 13, fontWeight: unread ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ]),
          ),
          if (unread)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: .4, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.elasticOut,
              builder: (_, v, ch) => Transform.scale(scale: v, child: ch),
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                constraints: const BoxConstraints(minWidth: 24),
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: chat.muted ? null : LinearGradient(colors: [c.accent, Color.lerp(c.accent, const Color(0xFFEC4899), .45)!]),
                  color: chat.muted ? c.muted : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: chat.muted ? null : [BoxShadow(color: c.accent.withValues(alpha: .35), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Text(chat.unread > 99 ? '99+' : '${chat.unread}', style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ),
        ]),
      ),
    );
  }
}

/// A group's round picture: the people icon on a colour of its own.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({super.key, required this.id, this.size = 48});
  final int id;
  final double size;
  @override
  Widget build(BuildContext context) {
    final h = ((id * 47) % 360).toDouble();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [HSLColor.fromAHSL(1, h, .6, .58).toColor(), HSLColor.fromAHSL(1, (h + 38) % 360, .6, .4).toColor()]),
      ),
      child: PIcon('users', size: size * .46, color: Colors.white),
    );
  }
}

/// Choosing a friend to write to.
class _PickFriend extends StatelessWidget {
  const _PickFriend();
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return Scaffold(
      appBar: peeraBar(context, title: 'ვის მისწერ?'),
      body: ListenableBuilder(
        listenable: Listenable.merge([app.friends, app.people]),
        builder: (context, _) {
          final list = app.friends.friends.map((id) => app.people[id] ?? Profile(id: id, name: '…')).toList()..sort((a, b) => a.name.compareTo(b.name));
          if (list.isEmpty) {
            return const Empty(icon: 'users', title: 'ჯერ მეგობრები არ გყავს', text: 'სხვისი გვერდიდანაც შეგიძლია მიწერო — „მიწერა“.');
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: list.length,
            itemBuilder: (_, i) => PersonRow(p: list[i], onTap: () => Navigator.of(context).pop(list[i].id)),
          );
        },
      ),
    );
  }
}
