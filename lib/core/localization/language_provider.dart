import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'language_provider.g.dart';

@Riverpod(keepAlive: true)
class Language extends _$Language {
  final _preferences = SharedPreferencesAsync();
  static const _key = 'jewellery_language';

  @override
  Future<Locale> build() async =>
      Locale((await _preferences.getString(_key)) == 'si' ? 'si' : 'en');

  Future<void> select(Locale locale) async {
    state = AsyncData(locale);
    await _preferences.setString(_key, locale.languageCode);
  }
}
