// What the Joker table screen needs from a game, whether it is played on the phone against the bots (JokerSession)
// or on the server with other people (OnlineJoker). The player always sits in seat 0, at the bottom.
import 'package:flutter/foundation.dart';

import '../profile/profile.dart';
import 'engine.dart';

/// Who sits in a seat: a person, or a drawn face (a bot, or the person's own picture when there is none).
class SeatFace {
  const SeatFace({this.person, this.asset});
  final Profile? person;
  final String? asset;
}

abstract class JokerTable extends ChangeNotifier {
  /// the game as seen from seat 0 (null while there is none)
  JokerGame? get g;

  bool get hint;
  bool get c4;

  /// the coins a won game brought (the computer games), shown at the end
  int? get reward;

  bool get myTurn;

  /// the table is on screen
  set live(bool v);

  /// a sheet is open over the table: the next hand waits for it
  set hold(bool v);

  String nameOf(int p);
  SeatFace faceOf(int p);

  /// "გურამმა წაიღო ხელი", said of a seat other than mine
  String tookText(int p);

  /// a person's seat played by the server while they are away
  bool awayOf(int p) => false;

  /// seconds left for the move now being waited for, when there is a limit
  int? get secondsLeft => null;

  void myTrump(String? s);
  void myBid(int b);
  void myPlay(JCard c, {String? jm, String? js});

  /// the next hand at once, without waiting (the computer games)
  bool get canNext => false;
  void nextNow() {}

  /// a new game at the same table, at the end
  bool get canAgain;
  void again();

  /// a line under the end of the game when [canAgain] is false (who starts the next one)
  String get againNote => '';
}
