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
  });
  final int skin, hair, shirt;

  /// short · long · curly · bald
  final String style;
  final bool mus, beard, hat, fem;

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
          style: const ['short', 'long', 'curly', 'bald'].contains(j['style']) ? '${j['style']}' : 'short',
          mus: j['mus'] == true || j['mus'] == 1,
          beard: j['beard'] == true || j['beard'] == 1,
          hat: j['hat'] == true || j['hat'] == 1,
          fem: j['fem'] == true || j['fem'] == 1,
        );

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

  /// seconds left for the move now waited for, when there is a limit
  int? get secondsLeft => null;

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

  /// what each character does now
  Mood moodOf(int pl) => Mood.idle;

  /// grows by one with every step played, for the board to animate it
  int get stepTick;

  /// the step that was just played, with who played it
  (int, Step)? get lastStep;
}
