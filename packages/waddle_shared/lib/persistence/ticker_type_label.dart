import 'config_json_documentation.dart';
import 'tables.dart';

/// Human-facing labels for [TickerTapes.tickerType] / [TickerTapeTypes] rows.
const Map<String, String> kTickerTypeTitles = {
  'time': 'Date and time',
  'weather': 'Weather',
  'news': 'News',
  'quote': 'Quote',
  'stocks': 'Stock quotes',
  'static_text': 'Static text',
  kTickerTypePlugin: 'Plugin',
};

String _capitalizeToken(String word) {
  if (word.isEmpty) return word;
  return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
}

String _titleFromSegments(String tickerType) {
  final parts = tickerType.split('_').where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return tickerType;
  return parts.map(_capitalizeToken).join(' ');
}

/// Normalized label for cards, dialogs, and [TickerTapeTypes.label] seeding.
String tickerTypeLabel(String tickerType) {
  final key = tickerType.trim();
  if (key.isEmpty) return 'Ticker';
  return kTickerTypeTitles[key] ?? _titleFromSegments(key);
}

/// All built-in ticker types for registry seeding.
Iterable<String> get kAllBuiltinTickerTypes => kTickerSlotDefinitionTypes;
