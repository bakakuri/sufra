import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stores.dart';
import '../people/search_screen.dart';
import '../profile/profile.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'chat_screen.dart';

/// The conversations, newest first, with what was said last and how many are unread.
class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key, this.archived = false});
  final bool archived;

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

  @override
  Widget build(BuildContext context) {
    final app = context.app, c = context.pc;
    return Scaffold(
      appBar: peeraBar(context, title: archived ? 'არქივი' : 'მიმოწერა', actions: [
        if (!archived) IconBtn('edit', label: 'ახალი მიმოწერა', onTap: () => _new(context)),
      ]),
      body: ListenableBuilder(
        listenable: Listenable.merge([app.chats, app.people]),
        builder: (context, _) {
          final store = app.chats;
          final list = store.chats.where((x) => x.archived == archived).toList();
          final arch = store.chats.where((x) => x.archived).toList();
          Widget body;
          if (!store.loaded) {
            body = const Center(child: SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 2.4)));
          } else if (store.error != null && store.chats.isEmpty) {
            body = ListView(children: [Empty(icon: 'msg', title: 'მიმოწერა ვერ ჩაიტვირთა', text: errText(store.error!), action: 'ხელახლა ცდა', onAction: store.load)]);
          } else if (list.isEmpty && (archived || arch.isEmpty)) {
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
            body = ListView(padding: const EdgeInsets.symmetric(vertical: 4), children: [
              for (final ch in list) ChatRow(chat: ch),
              if (!archived && arch.isNotEmpty)
                ListTile(
                  leading: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.sunk, shape: BoxShape.circle),
                    child: PIcon('archive', size: 24, color: c.muted),
                  ),
                  title: const Text('არქივი', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${arch.length} მიმოწერა', style: TextStyle(color: c.muted)),
                  trailing: PIcon('chev', size: 20, color: c.muted),
                  onTap: () => openPage(context, const ChatsTab(archived: true)),
                ),
            ]);
          }
          return RefreshIndicator(onRefresh: store.load, child: body);
        },
      ),
    );
  }
}

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
    return InkWell(
      onTap: () => openChat(context, chat.convId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                if (chat.lastAt != null) Text(' · ${ago(chat.lastAt!)}', style: TextStyle(color: c.muted, fontSize: 13)),
              ]),
            ]),
          ),
          if (unread)
            Container(
              margin: const EdgeInsets.only(left: 8),
              constraints: const BoxConstraints(minWidth: 22),
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: chat.muted ? c.muted : c.accent, borderRadius: BorderRadius.circular(11)),
              child: Text(chat.unread > 99 ? '99+' : '${chat.unread}', style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w800, fontSize: 12)),
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
