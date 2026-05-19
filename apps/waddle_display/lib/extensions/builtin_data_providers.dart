import 'package:waddle_shared/collect/stub_data_provider.dart';

import 'package:waddle_shared/extensions/data_provider_registry.dart';

import 'package:waddle_integrations/waddle_integrations.dart';



import '../plugins/plugin_http_data_provider.dart';



/// All built-in collectors plus plugin HTTP provider factory registration.

DataProviderRegistry buildBuiltinDataProviderRegistry() {

  final registry = DataProviderRegistry(

    providers: [

      const StubDataProvider(),

      RssNewsDataProvider(),

      JokeDataProvider(),

      GeneralOpenAiDataProvider(),

      TriviaDataProvider(),

      OpenTdbTriviaDataProvider(),

      WeatherDataProvider(),

      NwsWeatherGovAlertsDataProvider(),

      PexelsPhotosDataProvider(),

      PexelsVideosDataProvider(),

      GoogleCalendarDataProvider(),

      OutlookCalendarDataProvider(),

      IcalCalendarDataProvider(),

      OneDrivePhotosDataProvider(),

      OneDriveVideosDataProvider(),

      FlickrPhotosDataProvider(),

      BingImageOfDayDataProvider(),

      GooglePhotosPhotosDataProvider(),

      GooglePhotosVideosDataProvider(),

      StockQuoteDataProvider(),

      HomeAssistantDataProvider(),

      photoBucketDataProvider,

      videoBucketDataProvider,

      calendarBucketDataProvider,

      jokeBucketDataProvider,

      triviaBucketDataProvider,

      PluginHttpDataProvider(),

    ],

  );

  return registry;

}

