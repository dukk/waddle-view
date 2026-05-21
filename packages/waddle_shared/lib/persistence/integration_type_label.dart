/// Human-facing labels for [Integrations.integrationType] / [IntegrationTypes] rows.
const Map<String, String> kIntegrationTypeTitles = {
  'stub': 'Stub',
  'news_rss': 'RSS News',
  'photo_pexels': 'Pexels Photos',
  'video_pexels': 'Pexels Videos',
  'weather_openweathermap': 'OpenWeatherMap Weather',
  'weather_alerts_nws': 'NWS Weather Alerts',
  'joke_openai': 'OpenAI Jokes',
  'general_openai': 'OpenAI General',
  'trivia_openai': 'OpenAI Trivia',
  'trivia_opentdb': 'OpenTDB Trivia',
  'stock_finnhub': 'Finnhub Stock',
  'home_assistant': 'Home Assistant',
  'calendar_outlook': 'Outlook Calendar',
  'calendar_google': 'Google Calendar',
  'calendar_ical': 'iCal / ICS Calendar',
  'calendar_mealviewer': 'MealViewer School Menus',
  'google_calendar': 'Google Calendar',
  'photo_google': 'Google Photos',
  'video_google': 'Google Photos Videos',
  'photo_onedrive': 'OneDrive Photos',
  'video_onedrive': 'OneDrive Videos',
  'photo_flickr': 'Flickr Photos',
  'photo_bing_image_of_the_day': 'Bing Image of the Day',
  'photo_bucket': 'Photo Bucket',
  'video_bucket': 'Video Bucket',
  'calendar_bucket': 'Calendar Bucket',
  'joke_bucket': 'Joke Bucket',
  'trivia_bucket': 'Trivia Bucket',
  'news_facebook': 'Facebook News',
  'news_twitter': 'X (Twitter) News',
  'news_linkedin': 'LinkedIn News',
};

const Map<String, String> _kWordDisplay = {
  'rss': 'RSS',
  'nws': 'NWS',
  'api': 'API',
  'iotd': 'IOTD',
  'onedrive': 'OneDrive',
  'openai': 'OpenAI',
  'openweathermap': 'OpenWeatherMap',
  'opentdb': 'OpenTDB',
  'finnhub': 'Finnhub',
  'google': 'Google',
  'outlook': 'Outlook',
  'pexels': 'Pexels',
  'flickr': 'Flickr',
  'bing': 'Bing',
};

String _capitalizeToken(String word) {
  if (word.isEmpty) return word;
  final lower = word.toLowerCase();
  return _kWordDisplay[lower] ??
      '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
}

String _titleFromReversedSegments(String integrationType) {
  final parts =
      integrationType.split('_').where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return integrationType;
  if (parts.length == 1) return _capitalizeToken(parts.single);
  return parts.reversed.map(_capitalizeToken).join(' ');
}

/// Normalized label for cards, dialogs, and [IntegrationTypes.label] seeding.
String integrationTypeLabel(String integrationType) {
  final key = integrationType.trim();
  if (key.isEmpty) return 'Integration';
  return kIntegrationTypeTitles[key] ?? _titleFromReversedSegments(key);
}
