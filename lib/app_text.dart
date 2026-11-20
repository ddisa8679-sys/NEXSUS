class AppText {
  static String language = 'ru';

  static String tx(String russian, String english) =>
      language == 'en' ? english : russian;
}
