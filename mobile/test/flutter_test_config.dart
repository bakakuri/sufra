import 'dart:async';

import 'package:peera/nardi/character.dart';
import 'package:peera/nardi/nardi_screen.dart';
import 'package:peera/system/updates.dart';
import 'package:peera/ui/sparkles.dart';

/// Runs before every test file: the stars that scatter from my picture on the tab bar come in bursts on a timer, and
/// the tests wait for a still screen, so they are off here (one test turns them on and watches a burst); so is the
/// endless movement of the backgammon characters.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  sparklesOn = false;
  charactersMove = false;
  clocksTick = false;
  // no looking for a new version on the internet
  fetchRelease = () async => null;
  await testMain();
}
