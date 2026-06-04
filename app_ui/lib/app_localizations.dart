part of 'main.dart';

String loc(AppLanguage language, String key, [String? unused]) {
  switch (language) {
    case AppLanguage.ru:
      return ruTranslations[key] ?? key;
  }
}

String tr(String key, [String? unused]) {
  return loc(_activeLanguage, key);
}
