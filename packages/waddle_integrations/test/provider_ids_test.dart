import 'package:test/test.dart';

import 'package:waddle_integrations/calendar_google/google_calendar_data_provider.dart';

import 'package:waddle_integrations/calendar_ical/ical_calendar_data_provider.dart';
import 'package:waddle_integrations/calendar_mealviewer/mealviewer_calendar_data_provider.dart';

import 'package:waddle_integrations/calendar_outlook/outlook_calendar_data_provider.dart';

import 'package:waddle_integrations/general_openai/general_openai_data_provider.dart';
import 'package:waddle_integrations/joke_openai/joke_data_provider.dart';

import 'package:waddle_integrations/photo_bing_image_of_the_day/bing_image_of_day_data_provider.dart';

import 'package:waddle_integrations/google_photos/google_photos_media_data_provider.dart';
import 'package:waddle_integrations/photo_flickr/flickr_media_data_provider.dart';

import 'package:waddle_integrations/photo_onedrive/onedrive_media_data_provider.dart';

import 'package:waddle_integrations/photo_pexels/pexels_data_provider.dart';

import 'package:waddle_integrations/news_rss/rss_news_data_provider.dart';

import 'package:waddle_integrations/home_assistant/home_assistant_data_provider.dart';

import 'package:waddle_integrations/stock_finnhub/stock_quote_data_provider.dart';

import 'package:waddle_integrations/trivia_openai/trivia_data_provider.dart';

import 'package:waddle_integrations/trivia_opentdb/opentdb_trivia_data_provider.dart';

import 'package:waddle_integrations/video_onedrive/onedrive_media_data_provider.dart';

import 'package:waddle_integrations/video_pexels/pexels_data_provider.dart';

import 'package:waddle_integrations/weather_alerts_nws/nws_weather_gov_alerts_data_provider.dart';

import 'package:waddle_integrations/weather_openweathermap/weather_data_provider.dart';

import 'package:waddle_integrations/manual_bucket/manual_bucket_data_provider.dart';

void main() {

  test('collector IDataProvider ids match integration types', () {

    expect(RssNewsDataProvider().id, 'news_rss');

    expect(JokeDataProvider().id, 'joke_openai');

    expect(GeneralOpenAiDataProvider().id, 'general_openai');

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

    expect(IcalCalendarDataProvider().id, 'calendar_ical');

    expect(MealviewerCalendarDataProvider().id, 'calendar_mealviewer');

    expect(GooglePhotosPhotosDataProvider().id, 'photo_google');

    expect(GooglePhotosVideosDataProvider().id, 'video_google');

  });

}

