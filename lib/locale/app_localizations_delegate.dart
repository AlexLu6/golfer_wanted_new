import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'language.dart';
import 'language_en.dart';
import 'language_zh.dart';

class AppLocalizationsDelegate extends LocalizationsDelegate<Language> {
  const AppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => [
        'en',
        'zh'
      ].contains(locale.languageCode);

  @override
  Future<Language> load(Locale locale) => _load(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<Language> old) => false;

  static Future<Language> _load(Locale locale) async {
    switch (locale.languageCode) {
      case 'en':
        return LanguageEn();
      case 'zh':
        return LanguageZh();
      default:
        return LanguageEn();
    }
  }
}
