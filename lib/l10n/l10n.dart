import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';
import 'generated/app_localizations_en.dart';

export 'generated/app_localizations.dart';

const fallbackLocale = Locale('en');
final fallbackLocalizations = AppLocalizationsEn();
AppLocalizations serviceLocalizations = fallbackLocalizations;

void setServiceLocale(Locale locale) {
  serviceLocalizations = lookupAppLocalizations(locale);
}

extension LocalizedBuildContext on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? fallbackLocalizations;
}
