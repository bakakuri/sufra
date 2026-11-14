// A file made on the phone handed to the person: saved in the phone's Downloads (Android 10 and newer), or offered to
// another app through the share sheet on older phones (android/.../MainActivity.kt "peera/share" save).
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// 'saved', 'shared' or 'fail' (the tests put in their own)
Future<String> Function(String name, Uint8List bytes, String mime) saveFile = (name, bytes, mime) async {
  try {
    return '${await const MethodChannel('peera/share').invokeMethod<String>('save', {'name': name, 'bytes': bytes, 'mime': mime}) ?? 'fail'}';
  } catch (_) {
    return 'fail';
  }
};
