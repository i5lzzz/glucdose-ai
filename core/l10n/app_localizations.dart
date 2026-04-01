// lib/core/l10n/app_localizations.dart

import 'package:flutter/material.dart';
import 'package:insulin_assistant/core/l10n/app_localizations_ar.dart';
import 'package:insulin_assistant/core/l10n/app_localizations_en.dart';

/// Custom localisation class.
///
/// Usage: `context.l10n.translate('dose_title')`
/// Or via extension: `context.tr('dose_title')`
final class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('ar'),
    Locale('en'),
  ];

  String translate(String key, {Map<String, String>? args}) {
    final strings = locale.languageCode == 'ar' ? arStrings : enStrings;
    var value = strings[key] ?? enStrings[key] ?? key;

    if (args != null) {
      for (final entry in args.entries) {
        value = value.replaceAll('{${entry.key}}', entry.value);
      }
    }

    return value;
  }

  /// Shorthand.
  String tr(String key, {Map<String, String>? args}) =>
      translate(key, args: args);

  bool get isRTL => locale.languageCode == 'ar';
  TextDirection get textDirection =>
      isRTL ? TextDirection.rtl : TextDirection.ltr;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension BuildContextL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String tr(String key, {Map<String, String>? args}) =>
      l10n.translate(key, args: args);
}
