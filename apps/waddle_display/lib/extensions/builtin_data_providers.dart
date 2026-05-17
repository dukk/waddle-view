import 'package:waddle_shared/collect/stub_data_provider.dart';
import 'package:waddle_shared/extensions/data_provider_registry.dart';
import 'package:waddle_data_providers/waddle_data_providers.dart';

import '../plugins/plugin_http_data_provider.dart';

/// All built-in collectors plus plugin HTTP provider factory registration.
DataProviderRegistry buildBuiltinDataProviderRegistry() {
  final registry = DataProviderRegistry(
    providers: [
      const StubDataProvider(),
      RssNewsDataProvider(),
      JokeDataProvider(),
      TriviaDataProvider(),
      OpenTdbTriviaDataProvider(),
      WeatherDataProvider(),
      NwsWeatherGovAlertsDataProvider(),
      PexelsDataProvider(),
      GoogleCalendarDataProvider(),
      OutlookCalendarDataProvider(),
      OneDriveMediaDataProvider(),
      FlickrMediaDataProvider(),
      BingImageOfDayDataProvider(),
      StockQuoteDataProvider(),
      HomeAssistantDataProvider(),
      PluginHttpDataProvider(),
    ],
  );
  return registry;
}
