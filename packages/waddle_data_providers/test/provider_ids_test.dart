import 'package:test/test.dart';
import 'package:waddle_data_providers/calendar_google/google_calendar_data_provider.dart';
import 'package:waddle_data_providers/calendar_outlook/outlook_calendar_data_provider.dart';
import 'package:waddle_data_providers/joke_openai/joke_data_provider.dart';
import 'package:waddle_data_providers/photo_bing_image_of_the_day/bing_image_of_day_data_provider.dart';
import 'package:waddle_data_providers/photo_flickr/flickr_media_data_provider.dart';
import 'package:waddle_data_providers/photo_onedrive/onedrive_media_data_provider.dart';
import 'package:waddle_data_providers/photo_pexels/pexels_data_provider.dart';
import 'package:waddle_data_providers/news_rss/rss_news_data_provider.dart';
import 'package:waddle_data_providers/home_assistant/home_assistant_data_provider.dart';
import 'package:waddle_data_providers/stock_finnhub/stock_quote_data_provider.dart';
import 'package:waddle_data_providers/trivia_openai/trivia_data_provider.dart';
import 'package:waddle_data_providers/trivia_opentdb/opentdb_trivia_data_provider.dart';
import 'package:waddle_data_providers/video_onedrive/onedrive_media_data_provider.dart';
import 'package:waddle_data_providers/video_pexels/pexels_data_provider.dart';
import 'package:waddle_data_providers/weather_alerts_nws/nws_weather_gov_alerts_data_provider.dart';
import 'package:waddle_data_providers/weather_openweathermap/weather_data_provider.dart';

void main() {
  test('collector IDataProvider ids match integration types', () {
    expect(RssNewsDataProvider().id, 'news_rss');
    expect(JokeDataProvider().id, 'joke_openai');
    expect(TriviaDataProvider().id, 'trivia_openai');
    expect(OpenTdbTriviaDataProvider().id, 'trivia_opentdb');
    expect(WeatherDataProvider().id, 'weather_openweathermap');
    expect(NwsWeatherGovAlertsDataProvider().id, 'weather_alerts_nws');
    expect(StockQuoteDataProvider().id, 'stock_finnhub');
    expect(HomeAssistantDataProvider().id, 'home_assistant');
    expect(PexelsPhotosDataProvider().id, 'photo_pexels');
    expect(PexelsVideosDataProvider().id, 'video_pexels');
    expect(FlickrPhotosDataProvider().id, 'photo_flickr');
    expect(OneDrivePhotosDataProvider().id, 'photo_onedrive');
    expect(OneDriveVideosDataProvider().id, 'video_onedrive');
    expect(BingImageOfDayDataProvider().id, 'photo_bing_image_of_the_day');
    expect(GoogleCalendarDataProvider().id, 'calendar_google');
    expect(OutlookCalendarDataProvider().id, 'calendar_outlook');
  });
}
