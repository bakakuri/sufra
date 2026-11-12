import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../profile/profile.dart';

/// Everything the sign-in screens need from the server, behind one door, so the screens can be tried without it.
abstract class AuthApi {
  Future<void> signIn(String email, String password);

  /// true when the account is ready, false when the e-mail still has to be confirmed
  Future<bool> signUp(String email, String password, String name);
  Future<void> resetPassword(String email);
  Future<void> completeOnboarding({required String name, required DateTime birthday, required String username, required String city});
  Future<Profile?> myProfile();
  Future<void> signOut();
}

class SupaAuthApi implements AuthApi {
  SupabaseClient get _c => Supabase.instance.client;

  @override
  Future<void> signIn(String email, String password) => _c.auth.signInWithPassword(email: email, password: password);

  @override
  Future<bool> signUp(String email, String password, String name) async {
    final r = await _c.auth.signUp(email: email, password: password, data: {'name': name}, emailRedirectTo: siteUrl);
    return r.session != null;
  }

  @override
  Future<void> resetPassword(String email) => _c.auth.resetPasswordForEmail(email, redirectTo: siteUrl);

  @override
  Future<void> completeOnboarding({required String name, required DateTime birthday, required String username, required String city}) =>
      _c.rpc('complete_onboarding', params: {
        'p_name': name,
        'p_birthday': '${birthday.year.toString().padLeft(4, '0')}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}',
        'p_username': username,
        'p_city': city,
      });

  @override
  Future<Profile?> myProfile() async {
    // the profile row is made by the database right after sign-up; give it a moment, as the site does
    for (var i = 0; i < 4; i++) {
      final r = await _c.rpc('my_profile');
      if (r is Map) return Profile.fromJson(Map<String, dynamic>.from(r));
      if (r is List && r.isNotEmpty && r.first is Map) return Profile.fromJson(Map<String, dynamic>.from(r.first as Map));
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    return null;
  }

  @override
  Future<void> signOut() => _c.auth.signOut();
}

/// The site's wording for what can go wrong (js/auth.js authErr, js/core.js errMsg)
String authErr(Object e) {
  final m = e is AuthException ? e.message : e is PostgrestException ? e.message : '$e';
  bool has(String re) => RegExp(re, caseSensitive: false).hasMatch(m);
  if (has('Invalid login credentials')) return 'ელფოსტა ან პაროლი არასწორია';
  if (has('Email not confirmed')) return 'ჯერ დაადასტურე ელფოსტა. ბმული ფოსტაში გამოგიგზავნეთ';
  if (has('already registered|already been registered')) return 'ეს ელფოსტა უკვე დარეგისტრირებულია. შედი ან აღადგინე პაროლი';
  if (has('Password should|at least')) return 'პაროლი მინიმუმ 8 სიმბოლო უნდა იყოს';
  if (has('rate limit|too many')) return 'ძალიან ბევრი მცდელობა. სცადე ცოტა ხანში';
  if (has(r'invalid.*email|Unable to validate email')) return 'ელფოსტის მისამართი არასწორია';
  if (has('too_young')) return 'Peera-ზე რეგისტრაცია 13 წლიდანაა შესაძლებელი';
  if (has('bad_birthday')) return 'დაბადების თარიღი არასწორია';
  if (has('duplicate key|username')) return 'ეს მომხმარებლის სახელი დაკავებულია, სცადე სხვა';
  if (has('SocketException|Failed host lookup|ClientException|Connection|timed out')) return 'ინტერნეტთან კავშირი არ არის';
  return 'შეცდომა: ${m.length > 120 ? m.substring(0, 120) : m}';
}
