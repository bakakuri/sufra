// What the backgammon screen needs from a game, whether it is played on the phone against the computer
// (NardiSession) or on the server with another person (OnlineNardi). The player's own checkers are always shown
// moving down to the bottom right.
import 'package:flutter/material.dart' hide Step;

import '../profile/profile.dart';
import 'engine.dart';

/// what a character does for a moment
enum Mood { idle, think, roll, reach, happy, sad, angry }

/// Who sits across: a person, or a drawn character
class NardiSeat {
  const NardiSeat({required this.name, this.person, this.look = const CharacterLook()});
  final String name;
  final Profile? person;
  final CharacterLook look;
}

/// How a drawn character looks (the site's `look`: profiles.look and its bots, games-modes.js BOTC).
class CharacterLook {
  const CharacterLook({
    this.skin = 0xFFEBC0A0,
    this.hair = 0xFF2E2219,
    this.shirt = 0xFF4F46E5,
    this.style = 'short',
    this.mus = false,
    this.beard = false,
    this.hat = false,
    this.fem = false,
    this.glasses = false,
  });
  final int skin, hair, shirt;

  /// short · long · curly · pony · bald (as the site draws them)
  final String style;
  final bool mus, beard, hat, fem, glasses;

  static int _c(Object? v, int d) {
    final t = '$v'.replaceAll('#', '');
    return t.length == 6 ? int.parse('FF$t', radix: 16) : d;
  }

  factory CharacterLook.fromJson(Map? j, {int shirt = 0xFF4F46E5}) => j == null
      ? CharacterLook(shirt: shirt)
      : CharacterLook(
          skin: _c(j['skin'], 0xFFEBC0A0),
          hair: _c(j['hair'], 0xFF2E2219),
          shirt: _c(j['shirt'], shirt),
          style: const ['short', 'long', 'curly', 'pony', 'bald'].contains(j['style']) ? '${j['style']}' : 'short',
          mus: (j['mus'] == true || j['mus'] == 1) && !(j['fem'] == true || j['fem'] == 1),
          beard: (j['beard'] == true || j['beard'] == 1) && !(j['fem'] == true || j['fem'] == 1),
          hat: j['hat'] == true || j['hat'] == 1,
          fem: j['fem'] == true || j['fem'] == 1,
          glasses: j['glasses'] == true || j['glasses'] == 1,
        );

  /// the look as the site keeps it (what the other player's screen draws)
  Map<String, dynamic> toJson() {
    String hex(int c) => '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    return {
      'fem': fem ? 1 : 0,
      'style': style,
      'mus': mus ? 1 : 0,
      'beard': beard ? 1 : 0,
      'glasses': glasses ? 1 : 0,
      'hat': hat ? 1 : 0,
      'skin': hex(skin),
      'hair': hex(hair),
      'shirt': hex(shirt),
    };
  }

  /// a person's look: the one they chose on the site, else the one the site gives them
  factory CharacterLook.of(Profile p) => p.look != null ? CharacterLook.fromJson(p.look) : CharacterLook.ofPerson(p.id, fem: p.gender == 'f');

  /// the look the site gives a person who chose none, from their id (so both screens draw them the same)
  factory CharacterLook.ofPerson(String id, {bool fem = false}) {
    var k = 0;
    for (final ch in id.codeUnits) {
      k = (k * 31 + ch) & 0xFFFFFFFF;
    }
    const skins = [0xFFF2CDB0, 0xFFEBC0A0, 0xFFE2AF8C, 0xFFD69C77, 0xFFC08261, 0xFF8D5A3B];
    const hairs = [0xFF1A120D, 0xFF2E2219, 0xFF4E3220, 0xFF7A4A2A, 0xFFB8875A, 0xFF8A8580, 0xFFD9D4CB];
    const shirts = [0xFF2F5D8A, 0xFF8E3047, 0xFF3E6B47, 0xFF2C2C34, 0xFFC9A227, 0xFF6A4C93, 0xFFD9D4C7];
    // the site shifts a signed 32-bit number; a negative index there falls back to its default colours
    final s32 = k.toSigned(32), hi = (s32 >> 3).remainder(3), si = (s32 >> 5).remainder(shirts.length);
    return CharacterLook(skin: skins[k % 4], hair: hairs[hi < 0 ? 1 : hi], shirt: shirts[si < 0 ? 0 : si], fem: fem, style: fem ? 'long' : 'short');
  }

  /// a look from a person's colour, when they have none of their own
  factory CharacterLook.ofHue(int hue, {bool fem = false}) =>
      CharacterLook(shirt: HSLColor.fromAHSL(1, (hue % 360).toDouble(), .55, .45).toColor().toARGB32(), fem: fem, style: fem ? 'long' : 'short');
}

/// The computer players, by strength (the site's, games-modes.js)
class Bot {
  const Bot(this.name, this.level, this.about, this.look);
  final String name;
  final int level;
  final String about;
  final CharacterLook look;
}

const bots = [
  Bot('ნიკა', 1, 'სტუდენტი, ახლა სწავლობს. ხშირად ცდება და ბევრს იცინის', CharacterLook(style: 'curly', skin: 0xFFC08261, hair: 0xFF1A120D, shirt: 0xFF8E3047, hat: true, beard: true)),
  Bot('მარიამი', 2, 'ფრთხილად თამაშობს, ყოველ სვლაზე ფიქრობს', CharacterLook(fem: true, style: 'long', skin: 0xFFF1C9AC, hair: 0xFF3A2216, shirt: 0xFFD9D4C7)),
  Bot('ბატონი რეზო', 3, 'ეზოს ვეტერანი, იშვიათად ცდება', CharacterLook(style: 'short', mus: true, hat: true, skin: 0xFFD69C77, hair: 0xFF2E2219, shirt: 0xFF7A5A3E)),
  Bot('ოსტატი გურამი', 4, 'ყველაზე ძლიერი. ფიქრს დრო სჭირდება', CharacterLook(style: 'short', skin: 0xFFEBC0A0, hair: 0xFF2E2219, shirt: 0xFF2C2C34)),
];

abstract class NardiTable extends ChangeNotifier {
  /// the game as seen from my side (null while there is none)
  NardiGame? get g;

  /// my player number in [g] (0 or 1)
  int get me;

  /// the other side
  int get other => 1 - me;

  NardiSeat seatOf(int pl);

  bool get myTurn => g != null && g!.turn == me && g!.phase != Phase.over;

  /// I may roll now
  bool get canRoll => g != null && g!.phase == Phase.roll && g!.turn == me;

  /// I may move now
  bool get canMove => g != null && g!.phase == Phase.move && g!.turn == me;

  /// the table is on screen
  set live(bool v);

  /// the coins a won game brought (the computer games), shown at the end
  int? get reward;

  /// the time [pl] has left, when the game has a clock
  Duration? clockOf(int pl) => null;

  /// words over the board while the game waits (for the other phone, say)
  String? get pause => null;

  /// a step may be taken back before the turn is over
  bool get canUndo => true;

  /// the other player's seat is being played for while they are away
  bool get otherAway => false;

  Future<void> roll();
  Future<void> play(Step s);
  Future<void> undo();
  Future<void> endTurn();
  Future<void> resign();

  bool get canAgain;
  Future<void> again();
  String get againNote => '';
  String get againLabel => 'ახალი თამაში';

  /// what each character does now
  Mood moodOf(int pl) => Mood.idle;

  /// grows by one with every step played, for the board to animate it
  int get stepTick;

  /// the step that was just played, with who played it
  (int, Step)? get lastStep;
}
