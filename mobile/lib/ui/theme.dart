import 'package:flutter/material.dart';

/// The site's colours (css/base.css), light and dark: a cool clean base, one indigo accent, amber for highlights.
@immutable
class PeeraColors extends ThemeExtension<PeeraColors> {
  const PeeraColors({
    required this.bg,
    required this.surface,
    required this.sunk,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.vine,
    required this.gold,
    required this.nope,
  });

  final Color bg, surface, sunk, ink, muted, line, accent, accentSoft, onAccent, vine, gold, nope;

  static const light = PeeraColors(
    bg: Color(0xFFF5F6FA),
    surface: Color(0xFFFFFFFF),
    sunk: Color(0xFFEDEFF5),
    ink: Color(0xFF141726),
    muted: Color(0xFF636A7F),
    line: Color(0xFFE2E5EE),
    accent: Color(0xFF4F46E5),
    accentSoft: Color(0xFFE8E7FD),
    onAccent: Color(0xFFFFFFFF),
    vine: Color(0xFF0F9F76),
    gold: Color(0xFFE08A00),
    nope: Color(0xFFE5484D),
  );

  static const dark = PeeraColors(
    bg: Color(0xFF0C0E14),
    surface: Color(0xFF151821),
    sunk: Color(0xFF1E2230),
    ink: Color(0xFFEEF0F7),
    muted: Color(0xFF9AA1B5),
    line: Color(0xFF272C3B),
    accent: Color(0xFF8D86FF),
    accentSoft: Color(0xFF25244A),
    onAccent: Color(0xFF0D0B26),
    vine: Color(0xFF3CCB9A),
    gold: Color(0xFFF5B544),
    nope: Color(0xFFE5484D),
  );

  @override
  PeeraColors copyWith({
    Color? bg,
    Color? surface,
    Color? sunk,
    Color? ink,
    Color? muted,
    Color? line,
    Color? accent,
    Color? accentSoft,
    Color? onAccent,
    Color? vine,
    Color? gold,
    Color? nope,
  }) =>
      PeeraColors(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        sunk: sunk ?? this.sunk,
        ink: ink ?? this.ink,
        muted: muted ?? this.muted,
        line: line ?? this.line,
        accent: accent ?? this.accent,
        accentSoft: accentSoft ?? this.accentSoft,
        onAccent: onAccent ?? this.onAccent,
        vine: vine ?? this.vine,
        gold: gold ?? this.gold,
        nope: nope ?? this.nope,
      );

  @override
  PeeraColors lerp(ThemeExtension<PeeraColors>? other, double t) {
    if (other is! PeeraColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return PeeraColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      sunk: l(sunk, other.sunk),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      line: l(line, other.line),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      onAccent: l(onAccent, other.onAccent),
      vine: l(vine, other.vine),
      gold: l(gold, other.gold),
      nope: l(nope, other.nope),
    );
  }
}

extension PeeraTheme on BuildContext {
  PeeraColors get pc => Theme.of(this).extension<PeeraColors>()!;
}

const fontBody = 'NotoSansGeorgian';
const fontLogo = 'NotoSansGeorgianCondensed';

/// Latin letters (e-mails, @names) fall back to these: the system's own font on a phone, Noto Sans in the screenshots.
const fontFallback = ['NotoSans', 'Roboto', 'NotoColorEmoji'];

ThemeData peeraTheme(Brightness b) {
  final c = b == Brightness.dark ? PeeraColors.dark : PeeraColors.light;
  final scheme = ColorScheme(
    brightness: b,
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.gold,
    onSecondary: const Color(0xFF1A1205),
    error: c.nope,
    onError: Colors.white,
    surface: c.surface,
    onSurface: c.ink,
    surfaceContainerHighest: c.sunk,
    outline: c.line,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    fontFamily: fontBody,
    fontFamilyFallback: fontFallback,
    scaffoldBackgroundColor: c.bg,
    extensions: [c],
  );
  final r = BorderRadius.circular(14);
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink, fontFamily: fontBody, fontFamilyFallback: fontFallback),
    dividerColor: c.line,
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: c.line)),
      titleTextStyle: TextStyle(fontFamily: fontBody, fontFamilyFallback: fontFallback, fontSize: 18, fontWeight: FontWeight.w700, color: c.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.sunk,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: r, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: c.line)),
      focusedBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: c.accent, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: c.nope)),
      labelStyle: TextStyle(color: c.muted),
      hintStyle: TextStyle(color: c.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: r),
        textStyle: const TextStyle(fontFamily: fontBody, fontFamilyFallback: fontFallback, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: c.line),
        shape: RoundedRectangleBorder(borderRadius: r),
        textStyle: const TextStyle(fontFamily: fontBody, fontFamilyFallback: fontFallback, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.accent, textStyle: const TextStyle(fontFamily: fontBody, fontFamilyFallback: fontFallback, fontWeight: FontWeight.w600)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: TextStyle(fontFamily: fontBody, fontFamilyFallback: fontFallback, color: c.bg, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: r),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: c.line)),
    ),
  );
}
