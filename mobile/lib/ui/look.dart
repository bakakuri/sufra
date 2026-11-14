// How the app looks on this phone: light, dark or as the phone is; the text a little bigger. Kept on the phone.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeChoice = ValueNotifier<ThemeMode>(ThemeMode.system);
final textZoom = ValueNotifier<double>(1);

/// the economy mode (core.js ECO): no video plays by itself, photos in the feed show on a touch, uploads are smaller
final ecoMode = ValueNotifier<bool>(false);

const zooms = [1.0, 1.1, 1.2];

Future<void> loadLook() async {
  try {
    final p = await SharedPreferences.getInstance();
    themeChoice.value = switch (p.getString('look.theme')) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system };
    final z = p.getDouble('look.zoom') ?? 1;
    textZoom.value = zooms.contains(z) ? z : 1;
    ecoMode.value = p.getBool('look.eco') ?? false;
  } catch (_) {}
}

Future<void> setTheme(ThemeMode m) async {
  themeChoice.value = m;
  try {
    (await SharedPreferences.getInstance()).setString('look.theme', m == ThemeMode.light ? 'light' : (m == ThemeMode.dark ? 'dark' : 'system'));
  } catch (_) {}
}

Future<void> setZoom(double z) async {
  textZoom.value = z;
  try {
    (await SharedPreferences.getInstance()).setDouble('look.zoom', z);
  } catch (_) {}
}

Future<void> setEco(bool on) async {
  ecoMode.value = on;
  try {
    (await SharedPreferences.getInstance()).setBool('look.eco', on);
  } catch (_) {}
}
