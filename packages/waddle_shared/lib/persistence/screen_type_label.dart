import 'config_json_documentation.dart';

/// Human-facing labels for [Screens.screenType] / [ScreenTypes] rows.
const Map<String, String> kScreenTypeTitles = {
  'static_text': 'Static text',
  'joke': 'Joke',
  'quote': 'Quote',
  'trivia': 'Trivia',
  'wifi': 'Wi‑Fi',
  'digital_clock': 'Digital clock',
  'analog_clock': 'Analog clock',
  'calendar_month': 'Calendar month',
  'photo_random': 'Random photo',
  'news': 'News',
  'news_columns': 'News columns',
  'news_stack': 'News stack',
  'local_api': 'Local API',
  'admin_setup': 'Admin setup',
  'controller_invite': 'Controller invite',
  'weather': 'Weather',
  'photo': 'Photo',
  'photo_collage': 'Photo collage',
  'video': 'Video',
  'stock_quotes': 'Stock quotes',
  'home_assistant': 'Home Assistant',
  'data_health': 'Data health',
  'web_page': 'Web page',
  'plugin_template': 'Plugin template',
  'general_full_screen': 'General full screen',
  'general_2_column': 'General 2 column',
  'general_3_column': 'General 3 column',
  'general_2x2': 'General 2×2',
  'general_3x2': 'General 3×2',
};

const Map<String, String> _kWordDisplay = {
  'api': 'API',
  'rss': 'RSS',
  'wifi': 'Wi‑Fi',
};

String _capitalizeToken(String word) {
  if (word.isEmpty) return word;
  final lower = word.toLowerCase();
  return _kWordDisplay[lower] ??
      '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
}

String _titleFromSegments(String screenType) {
  final parts = screenType.split('_').where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return screenType;
  return parts.map(_capitalizeToken).join(' ');
}

/// Normalized label for cards, dialogs, and [ScreenTypes.label] seeding.
String screenTypeLabel(String screenType) {
  final key = screenType.trim();
  if (key.isEmpty) return 'Screen';
  return kScreenTypeTitles[key] ?? _titleFromSegments(key);
}

/// All built-in screen types for registry seeding.
Iterable<String> get kAllBuiltinScreenTypes => kScreenLayoutWidgetTypes;
