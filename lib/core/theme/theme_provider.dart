import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_provider.g.dart';

@Riverpod(keepAlive: true)
class Appearance extends _$Appearance {
  final _preferences = SharedPreferencesAsync();
  static const _key = 'jewellery_theme';

  @override
  Future<ThemeMode> build() async {
    final stored = await _preferences.getString(_key);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> select(ThemeMode mode) async {
    state = AsyncData(mode);
    await _preferences.setString(_key, mode.name);
  }
}
