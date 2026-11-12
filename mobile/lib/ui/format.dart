import 'package:supabase_flutter/supabase_flutter.dart';

const months = ['იანვარი', 'თებერვალი', 'მარტი', 'აპრილი', 'მაისი', 'ივნისი', 'ივლისი', 'აგვისტო', 'სექტემბერი', 'ოქტომბერი', 'ნოემბერი', 'დეკემბერი'];

/// How long ago, in the site's short words (js/core.js ago)
String ago(DateTime t, [DateTime? now]) {
  final d = (now ?? DateTime.now()).difference(t).inSeconds;
  if (d < 60) return 'ახლა';
  if (d < 3600) return '${d ~/ 60} წთ';
  if (d < 86400) return '${d ~/ 3600} სთ';
  if (d < 604800) return '${d ~/ 86400} დღე';
  return '${t.day} ${months[t.month - 1].substring(0, 3)}';
}

String hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "დღეს", "გუშინ" or the date, over a day of messages
String dayLabel(DateTime t, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final a = DateTime(t.year, t.month, t.day), b = DateTime(n.year, n.month, n.day);
  final d = b.difference(a).inDays;
  if (d == 0) return 'დღეს';
  if (d == 1) return 'გუშინ';
  return '${t.day} ${months[t.month - 1]}${t.year == n.year ? '' : ' ${t.year}'}';
}

String lastSeenText(DateTime? t) {
  if (t == null) return '';
  if (DateTime.now().difference(t) < const Duration(minutes: 3)) return 'ონლაინ';
  return 'ბოლოს იყო ${ago(t)}';
}

/// A number with a space every three digits: 12 450
String grouped(int n) {
  final s = n.abs().toString(), b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '${n < 0 ? '−' : ''}$b';
}

/// What went wrong, in a sentence for a person (js/core.js errMsg)
String errText(Object e) {
  final m = e is PostgrestException
      ? e.message
      : e is StorageException
          ? e.message
          : e is AuthException
              ? e.message
              : '$e';
  bool has(String re) => RegExp(re, caseSensitive: false).hasMatch(m);
  if (has('SocketException|Failed host lookup|ClientException|Connection|timed out|Network')) return 'ინტერნეტთან კავშირი არ არის';
  if (has('JWT|not authenticated|401')) return 'სესია ამოიწურა — შედი თავიდან';
  if (has('row-level security|permission denied|42501')) return 'ამის უფლება არ გაქვს';
  if (has('rate|too many')) return 'ძალიან ხშირად — სცადე ცოტა ხანში';
  if (has('payload too large|exceeded|413')) return 'ფაილი ძალიან დიდია';
  if (has('photo|FormatException')) return 'ფოტო ვერ წავიკითხე';
  return 'ვერ მოხერხდა — სცადე ხელახლა';
}
