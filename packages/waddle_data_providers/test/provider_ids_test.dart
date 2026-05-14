import 'package:test/test.dart';
import 'package:waddle_data_providers/calendar_google/google_calendar_data_provider.dart';
import 'package:waddle_data_providers/calendar_outlook/outlook_calendar_data_provider.dart';
import 'package:waddle_data_providers/joke_openai/joke_data_provider.dart';
import 'package:waddle_data_providers/media_bing_iotd/bing_image_of_day_data_provider.dart';
import 'package:waddle_data_providers/media_flickr/flickr_media_data_provider.dart';
import 'package:waddle_data_providers/media_onedrive/onedrive_media_data_provider.dart';
import 'package:waddle_data_providers/media_pexels/pexels_data_provider.dart';
import 'package:waddle_data_providers/news_rss/rss_news_data_provider.dart';
import 'package:waddle_data_providers/stock_finnhub/stock_quote_data_provider.dart';
import 'package:waddle_data_providers/trivia_openai/trivia_data_provider.dart';
import 'package:waddle_data_providers/trivia_opentdb/opentdb_trivia_data_provider.dart';
import 'package:waddle_data_providers/weather_nws_alerts/nws_weather_gov_alerts_data_provider.dart';
import 'package:waddle_data_providers/weather_openweathermap/weather_data_provider.dart';

void main() {
  test('collector IDataProvider ids match persisted provider_settings ids', () {
    expect(RssNewsDataProvider().id, 'news_rss');
    expect(JokeDataProvider().id, 'joke_openai');
    expect(TriviaDataProvider().id, 'trivia_openai');
    expect(OpenTdbTriviaDataProvider().id, 'trivia_opentdb');
    expect(WeatherDataProvider().id, 'weather_openweathermap');
    expect(NwsWeatherGovAlertsDataProvider().id, 'weather_nws_alerts');
    expect(StockQuoteDataProvider().id, 'stock_finnhub');
    expect(PexelsDataProvider().id, 'media_pexels');
    expect(FlickrMediaDataProvider().id, 'media_flickr');
    expect(OneDriveMediaDataProvider().id, 'media_onedrive');
    expect(BingImageOfDayDataProvider().id, 'media_bing_iotd');
    expect(GoogleCalendarDataProvider().id, 'calendar_google');
    expect(OutlookCalendarDataProvider().id, 'calendar_outlook');
  });
}
