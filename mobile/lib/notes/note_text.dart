// What a notification says (js/people.js NOTE_TXT): after the name of whoever did it, in the site's words.
import '../data/models.dart';

String _s(Map r, String k) => '${r[k] ?? ''}';
String _gel(Map r) => (double.tryParse('${r['gel'] ?? 0}') ?? 0).toStringAsFixed(2);
String _note(Map r, [String sep = ' · ']) => _s(r, 'note').isEmpty ? '' : '$sep${_s(r, 'note')}';
String _plus(Map r) => asInt(r['n']) > 1 ? ' · და კიდევ ${asInt(r['n']) - 1} მეგობარი' : '';

const _studyKinds = {'exam': '🎓 გამოცდა', 'midterm': '📝 შუალედური', 'quiz': '❓ ქვიზი', 'task': '✏️ დავალება', 'project': '📁 პროექტი'};
String _dk(Map r) => _studyKinds[_s(r, 'kind')] ?? '✏️ დავალება';

String noteText(String kind, Map r) {
  switch (kind) {
    case 'lesson_soon':
      return 'მალე იწყება: ${_s(r, 'title')}${_s(r, 'starts').isEmpty ? '' : ' · ${_s(r, 'starts')}'}${_s(r, 'place').isEmpty ? '' : ' · ${_s(r, 'place')}'}';
    case 'deadline_soon':
      return '${_s(r, 'when') == 'today' ? 'დღეს' : 'ხვალ'}: ${_dk(r)} · ${_s(r, 'title')}';
    case 'study_deadline':
      return 'დაამატა ${_dk(r)} ჯგუფში „${_s(r, 'gname')}“: ${_s(r, 'title')}';
    case 'promo':
      return _s(r, 'text');
    case 'admin_msg':
      return 'Peera-ს გუნდი: ${_s(r, 'text')}';
    case 'admin_coins':
      return '${asInt(r['coins']) > 0 ? '+' : ''}${asInt(r['coins'])} მონეტა · ${_s(r, 'note')}';
    case 'story_mention':
      return 'მოგნიშნა თავის ისტორიაზე';
    case 'recipe_cook':
      return 'შენი კონსპექტით ისწავლა 📚';
    case 'jk_invite':
      return 'გეპატიჟება ჯოკერზე 🃏';
    case 'grade_plus':
      return 'შენს ფოტოს „5+“ დაუწერა${asInt(r['coins']) > 0 ? ' · +${asInt(r['coins'])} მონეტა' : ''}';
    case 'mention':
      return 'მოგიხსენია${r['comment'] != null && r['comment'] != false ? ' კომენტარში' : ' პოსტში'}: ${_s(r, 'text')}';
    case 'msg_react':
      return '${_s(r, 'emoji').isEmpty ? '❤️' : _s(r, 'emoji')} შენს მესიჯზე: ${_s(r, 'text')}';
    case 'story_react':
      return '${_s(r, 'emoji').isEmpty ? '❤️' : _s(r, 'emoji')} შენს ისტორიაზე';
    case 'event_invite':
      return 'გეპატიჟება: ${_s(r, 'title')}';
    case 'event_soon':
      return 'მალე იწყება: ${_s(r, 'title')}';
    case 'album_invite':
      return 'დაგამატა ალბომში „${_s(r, 'title')}“';
    case 'album_photo':
      return 'ფოტოები დაამატა ალბომში „${_s(r, 'title')}“';
    case 'group_request':
      return 'ითხოვს გაწევრიანებას: ${_s(r, 'name')}';
    case 'group_ok':
      return 'მიგიღეს ჯგუფში: ${_s(r, 'name')}';
    case 'group_pending':
      return 'პოსტი ელოდება დამტკიცებას: ${_s(r, 'name')}';
    case 'group_post_ok':
      return 'შენი პოსტი დამტკიცდა: ${_s(r, 'name')}';
    case 'group_post_no':
      return 'შენი პოსტი არ დამტკიცდა: ${_s(r, 'name')}';
    case 'group_admin':
      return 'ადმინი გაგხადა: ${_s(r, 'name')}';
    case 'react':
      return '${_s(r, 'emoji').isEmpty ? '👍' : _s(r, 'emoji')} შენს პოსტზე';
    case 'repost':
      return r['quote'] == true ? 'გააზიარა შენი პოსტი თავისი სიტყვით' : 'გააზიარა შენი პოსტი';
    case 'comment_reply':
      return 'გიპასუხა კომენტარზე: ${_s(r, 'text')}';
    case 'comment_like':
      return 'მოიწონა შენი კომენტარი: ${_s(r, 'text')}';
    case 'comment':
      return 'დაწერა კომენტარი: ${_s(r, 'text')}';
    case 'friend_req':
      return 'გიგზავნის მეგობრობის მოთხოვნას';
    case 'friend_ok':
      return 'დაადასტურა მეგობრობა';
    case 'shop_order':
      return 'იყიდა „${_s(r, 'title')}“ · ${asInt(r['coins'])} მონეტა. გაგზავნე ნივთი';
    case 'shop_shipped':
      return 'გამოგიგზავნა „${_s(r, 'title')}“${_note(r)}';
    case 'shop_done':
      return '„${_s(r, 'title')}“: გაყიდვა დასრულდა, +${asInt(r['coins'])} მონეტა';
    case 'shop_cancelled':
      return 'შეკვეთა გაუქმდა: „${_s(r, 'title')}“';
    case 'shop_dispute':
      return 'მყიდველმა პრობლემა მიუთითა: „${_s(r, 'title')}“';
    case 'shop_refunded':
      return '„${_s(r, 'title')}“: მონეტები მყიდველს დაუბრუნდა${_note(r)}';
    case 'shop_resolved':
      return '„${_s(r, 'title')}“: დავა დასრულდა${_note(r)}';
    case 'shop_seller_approved':
      return 'Peera-ს მაღაზიაში ახლა გამყიდველი ხარ';
    case 'shop_seller_rejected':
      return 'გამყიდველობის განაცხადი არ დადასტურდა${_note(r, ': ')}';
    case 'shop_seller_blocked':
      return 'მაღაზიაში გაყიდვა შეგიჩერდა${_note(r, ': ')}';
    case 'shop_item_ok':
      return '„${_s(r, 'title')}“ მაღაზიაში გამოჩნდა';
    case 'shop_item_rejected':
      return '„${_s(r, 'title')}“ არ დადასტურდა${_note(r, ': ')}';
    case 'payout_paid':
      return 'ლარად გატანა გადაირიცხა: ${_gel(r)} ₾${_note(r)}';
    case 'payout_rejected':
      return 'გატანაზე უარი: ${_gel(r)} ₾${_note(r)}. მონეტები დაგიბრუნდა';
    case 'gift':
      return '${r['post'] != null ? 'შენს ფოტოს აჩუქა' : 'გიგზავნის საჩუქარს'} ${_s(r, 'emoji').isEmpty ? '🎁' : _s(r, 'emoji')}${asInt(r['coins']) > 0 ? ' · +${asInt(r['coins'])} მონეტა' : ''}';
    case 'match':
      return 'წყვილი ხართ! მიწერე პირველმა';
    case 'super':
      return 'სუპერ მოწონება გამოგიგზავნა ⭐';
    case 'verified':
      return 'შენი პროფილი ვერიფიცირდა ✓';
    case 'verify_rejected':
      return 'ვერიფიკაცია ვერ დადასტურდა. სცადე ახალი სელფით';
    case 'ad_ok':
      return 'შენი რეკლამა დამტკიცდა';
    case 'ad_rejected':
      return 'რეკლამა არ დამტკიცდა, მონეტები დაგიბრუნდა';
    case 'room_invite':
      return 'გეპატიჟება ${_s(r, 'kind') == 'birja' ? 'დისკუსიაზე' : (_s(r, 'kind') == 'live' ? 'ლაივზე' : 'სასწავლო ოთახში')}: ${_s(r, 'title')}';
    case 'bet_won':
      return 'მოიგე ${_s(r, 'coins')} მონეტა · ${_s(r, 'match')} ${_s(r, 'score')}';
    case 'bet_lost':
      return '${_s(r, 'match')} ${_s(r, 'score')} · პროგნოზი არ გამართლდა';
    case 'bet_refund':
      return '${_s(r, 'match')} · მონეტები დაგიბრუნდა';
    case 'ride_req':
      return 'ითხოვს ${asInt(r['seats'], 1)} ადგილს · ${_s(r, 'route')}';
    case 'ride_ok':
      return 'დაგიდასტურა ადგილი · ${_s(r, 'route')}';
    case 'ride_no':
      return 'ადგილი ვერ დაგიდასტურა · ${_s(r, 'route')}';
    case 'ride_cancel':
      return 'გააუქმა ჯავშანი · ${_s(r, 'route')}';
    case 'job_apply':
      return 'გამოეხმაურა ვაკანსიას: ${_s(r, 'title')}';
    case 'job_invited':
      return 'გასაუბრებაზე მიგიწვია: ${_s(r, 'title')}';
    case 'job_rejected':
      return '${_s(r, 'title')} · სხვა კანდიდატი შეირჩა';
    case 'nameday':
      return '· ${_s(r, 'label').isEmpty ? 'ანგელოზის დღე' : _s(r, 'label')}${_plus(r)}. მიულოცე!';
    case 'birthday':
      return '· დაბადების დღე${_plus(r)}. მიულოცე! 🎉';
    case 'nameday_me':
      return 'გილოცავ ანგელოზის დღეს! ${_s(r, 'label')}';
    case 'birthday_me':
      return 'Peera გილოცავს დაბადების დღეს! 🎉';
    case 'kin_req':
      return 'გთავაზობს ოჯახის ხეში დაკავშირებას';
    case 'kin_ok':
      return 'დაადასტურა ნათესაობა';
    case 'help_new':
      final k = _s(r, 'kind');
      final head = k == 'blood'
          ? '🩸 საჭიროა დონორი${_s(r, 'blood').isEmpty ? '' : ' ${_s(r, 'blood')}'}'
          : k == 'volunteer'
              ? '🤝 საჭიროა მოხალისე'
              : '🐾 ${k == 'found_pet' ? 'ნაპოვნია ცხოველი' : 'დაიკარგა ცხოველი'}';
      return '$head: ${_s(r, 'title')} · ${_s(r, 'region')}';
    case 'help_offer':
      return 'გთავაზობს დახმარებას: ${_s(r, 'title')}';
    case 'help_done':
      return '${_s(r, 'title')} · მოგვარდა. მადლობა, რომ გამოეხმაურე';
    case 'live_start':
      return 'ცოცხალ ეთერშია: ${_s(r, 'title')}';
    default:
      return 'ახალი შეტყობინება';
  }
}

/// Where a notification leads on the site, for the parts the app does not have yet (the push function's own routes).
String? noteSitePath(String kind, Map r) {
  String id(String k) => _s(r, k);
  if (kind == 'lesson_soon') return '#schedule';
  if (kind == 'deadline_soon' || kind == 'study_deadline') return '#exams';
  if (kind == 'admin_coins') return '#coins';
  if (kind.startsWith('payout_')) return '#payout';
  if (kind.startsWith('shop_')) return '#shop';
  if (kind == 'recipe_cook' && id('recipe').isNotEmpty) return '#recipe-${id('recipe')}';
  if (kind.startsWith('event_') && id('event').isNotEmpty) return '#event-${id('event')}';
  if (kind.startsWith('album_') && id('album').isNotEmpty) return '#album-${id('album')}';
  if (kind.startsWith('group_') && id('group').isNotEmpty) return '#group-${id('group')}';
  if ((kind == 'room_invite' || kind == 'live_start') && id('room').isNotEmpty) return '#room-${id('room')}';
  if (kind.startsWith('bet_') && id('fixture').isNotEmpty) return '#fixture-${id('fixture')}';
  if (kind.startsWith('ride_') && id('ride').isNotEmpty) return '#ride-${id('ride')}';
  if (kind.startsWith('job_') && id('job').isNotEmpty) return '#job-${id('job')}';
  if (kind.startsWith('help_') && id('help').isNotEmpty) return '#helpreq-${id('help')}';
  if (kind == 'nameday' || kind == 'birthday') return '#calendar';
  if (kind == 'nameday_me' || kind == 'birthday_me') return '#namedays';
  if (kind == 'kin_req' || kind == 'kin_ok') return '#tree';
  if (kind.startsWith('ad_')) return '#pages';
  if (kind == 'verify_rejected') return '#verify';
  if (kind == 'promo' && RegExp(r'^#[a-z]+(-[^\s"<>()]+)?$').hasMatch(id('link'))) return id('link');
  return null;
}
