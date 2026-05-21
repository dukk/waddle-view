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

      JokeApiDataProvider(),

      GeneralOpenAiDataProvider(),

      TriviaDataProvider(),

      OpenTdbTriviaDataProvider(),

      WeatherDataProvider(),

      OpenMeteoWeatherDataProvider(),

      OpenMeteoAirQualityDataProvider(),

      NwsWeatherGovAlertsDataProvider(),

      PexelsPhotosDataProvider(),

      PexelsVideosDataProvider(),

      GoogleCalendarDataProvider(),

      OutlookCalendarDataProvider(),

      IcalCalendarDataProvider(),

      MealviewerCalendarDataProvider(),

      OneDrivePhotosDataProvider(),

      OneDriveVideosDataProvider(),

      FlickrPhotosDataProvider(),

      BingImageOfDayDataProvider(),

      NasaApodDataProvider(),

      NasaMarsRoverDataProvider(),

      NasaEarthImageryDataProvider(),

      QuoterismDataProvider(),

      GooglePhotosPhotosDataProvider(),

      GooglePhotosVideosDataProvider(),

      StockQuoteDataProvider(),

      HomeAssistantDataProvider(),

      PluginHttpDataProvider(),

    ],

  );

  return registry;

}

