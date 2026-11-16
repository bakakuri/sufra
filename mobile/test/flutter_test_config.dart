import 'dart:async';

import 'package:peera/ui/sparkles.dart';

/// Runs before every test file: the stars that scatter from my picture on the tab bar come in bursts on a timer, and
/// the tests wait for a still screen, so they are off here (one test turns them on and watches a burst).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  sparklesOn = false;
  await testMain();
}
