enum AppLanguage { ku, ar, en }

extension AppLanguageX on AppLanguage {
  String get code => switch (this) {
    AppLanguage.ku => 'ku',
    AppLanguage.ar => 'ar',
    AppLanguage.en => 'en',
  };

  String get label => switch (this) {
    AppLanguage.ku => 'کوردی',
    AppLanguage.ar => 'العربية',
    AppLanguage.en => 'English',
  };
}

class AppLocalizations {
  const AppLocalizations(this.language);

  final AppLanguage language;

  String t(String ku, String ar, String en) => switch (language) {
    AppLanguage.ku => ku,
    AppLanguage.ar => ar,
    AppLanguage.en => en,
  };
}
