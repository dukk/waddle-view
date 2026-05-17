import 'dart:convert';

import 'tables.dart';

/// JSON Schema (draft 2020-12) and example payload for one [provider_type].
class ProviderConfigJsonDoc {
  const ProviderConfigJsonDoc({required this.schema, required this.example});

  final String schema;
  final String example;
}

const String _kJsonSchemaDraft = 'https://json-schema.org/draft/2020-12/schema';

Map<String, Object?> _baseSchema({
  required String title,
  required String description,
  required Map<String, Object?> properties,
  List<String> requiredKeys = const [],
}) {
  return {
    r'$schema': _kJsonSchemaDraft,
    'title': title,
    'description': description,
    'type': 'object',
    'properties': properties,
    'additionalProperties': true,
    if (requiredKeys.isNotEmpty) 'required': requiredKeys,
  };
}

/// Permissive schema for unknown provider types.
final ProviderConfigJsonDoc kGenericProviderConfigJsonDoc =
    ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'GenericProviderConfig',
          description: 'Arbitrary JSON; no parser-specific shape.',
          properties: {},
        ),
      ),
      example: '{}',
    );

/// Documentation keyed by [Integrations.providerType] (seeded + built-in).
final Map<String, ProviderConfigJsonDoc> kProviderConfigJsonMeta = {
  'stub': kGenericProviderConfigJsonDoc,
  'news_rss': kGenericProviderConfigJsonDoc,
  'media_pexels': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'PexelsProviderConfig',
        description:
            'Rate limits, retention, and optional curated search sources.',
        properties: {
          'maxPhotos': {'type': 'integer', 'minimum': 1},
          'maxVideos': {'type': 'integer', 'minimum': 1},
          'photosPerHour': {'type': 'integer', 'minimum': 1},
          'videosPerHour': {'type': 'integer', 'minimum': 1},
          'minVideoSeconds': {'type': 'integer', 'minimum': 1},
          'maxVideoSeconds': {'type': 'integer', 'minimum': 1},
          'maxVideoDownloadWidth': {
            'type': 'integer',
            'minimum': 1,
            'description':
                'Prefer the largest Pexels MP4 with width ≤ this value (default 1920). Use 1280 on Raspberry Pi.',
          },
          'sources': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'query': {'type': 'string', 'minLength': 1},
                'category': {'type': 'string', 'minLength': 1},
              },
              'required': ['query', 'category'],
              'additionalProperties': true,
            },
          },
        },
      ),
    ),
    example: jsonEncode({
      'maxPhotos': 100,
      'maxVideos': 100,
      'photosPerHour': 2,
      'videosPerHour': 2,
      'minVideoSeconds': 11,
      'maxVideoSeconds': 29,
      'maxVideoDownloadWidth': 1920,
      'sources': [
        {'query': 'nature', 'category': 'pexels'},
      ],
    }),
  ),
  'weather_openweathermap': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'WeatherProviderConfig',
        description:
            'OpenWeather units, language, hourly columns, default map.',
        properties: {
          'units': {'type': 'string'},
          'lang': {'type': 'string'},
          'hourlyCount': {'type': 'integer', 'minimum': 0},
          'defaultLocation': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
              'lat': {'type': 'number'},
              'lon': {'type': 'number'},
            },
            'required': ['lat', 'lon'],
            'additionalProperties': true,
          },
        },
      ),
    ),
    example: jsonEncode({
      'units': 'imperial',
      'lang': 'en',
      'hourlyCount': 6,
      'defaultLocation': {'name': 'Default', 'lat': 40.7128, 'lon': -74.006},
    }),
  ),
  'weather_nws_alerts': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'NwsWeatherGovAlertsConfig',
        description:
            'api.weather.gov active alerts. Set userAgent with contact info per NWS API rules. '
            'Optional defaultLocation when no rows exist in interests_locations.',
        properties: {
          'userAgent': {'type': 'string'},
          'defaultLocation': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
              'lat': {'type': 'number'},
              'lon': {'type': 'number'},
            },
            'required': ['lat', 'lon'],
            'additionalProperties': true,
          },
        },
      ),
    ),
    example: jsonEncode({
      'userAgent': '(example.org, ops@example.org)',
      'defaultLocation': {'name': 'Default', 'lat': 40.7128, 'lon': -74.006},
    }),
  ),
  'joke_openai': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'JokeProviderConfig',
        description: 'OpenAI joke generation limits and prompts.',
        properties: {
          'jokesPerDay': {'type': 'integer', 'minimum': 0},
          'model': {'type': 'string'},
          'globalPrompt': {'type': 'string'},
          'systemPrompt': {'type': 'string'},
          'temperature': {'type': 'number'},
          'maxOutputTokens': {'type': 'integer', 'minimum': 1},
          'maxJokesPerTwoHours': {'type': 'integer', 'minimum': 1},
          'twoHourWindowMs': {'type': 'integer', 'minimum': 1},
          'jokeRetentionDays': {'type': 'integer'},
        },
      ),
    ),
    example: jsonEncode({
      'jokesPerDay': 10,
      'maxJokesPerTwoHours': 20,
      'twoHourWindowMs': 7200000,
      'jokeRetentionDays': 14,
      'model': 'gpt-4o-mini',
      'globalPrompt': 'You write original, family-friendly jokes.',
    }),
  ),
  'trivia_openai': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'TriviaProviderConfig',
        description:
            'OpenAI trivia generation limits and prompts. Rolling window: '
            'at most maxQuestionPerHour requests per twoHourWindowMs (default '
            '1 hour). Legacy JSON keys questionsPerDay and '
            'maxQuestionsPerTwoHours are still parsed if the new keys are '
            'absent.',
        properties: {
          'maxQuestionPerDay': {'type': 'integer', 'minimum': 1},
          'questionsPerDay': {
            'type': 'integer',
            'minimum': 0,
            'description': 'Deprecated; use maxQuestionPerDay.',
          },
          'maxQuestionPerHour': {'type': 'integer', 'minimum': 1},
          'maxQuestionsPerTwoHours': {
            'type': 'integer',
            'minimum': 1,
            'description': 'Deprecated; use maxQuestionPerHour.',
          },
          'model': {'type': 'string'},
          'globalPrompt': {'type': 'string'},
          'systemPrompt': {'type': 'string'},
          'temperature': {'type': 'number'},
          'maxOutputTokens': {'type': 'integer', 'minimum': 1},
          'twoHourWindowMs': {'type': 'integer', 'minimum': 1},
          'questionRetentionDays': {'type': 'integer'},
        },
      ),
    ),
    example: jsonEncode({
      'maxQuestionPerDay': 200,
      'maxQuestionPerHour': 20,
      'twoHourWindowMs': 3600000,
      'questionRetentionDays': 15,
      'model': 'gpt-4o-mini',
    }),
  ),
  'trivia_opentdb': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'OpenTdbTriviaProviderConfig',
        description:
            'Open Trivia DB fetch settings. categoryMap maps local trivia category ids '
            'to OpenTDB numeric category ids.',
        properties: {
          'amount': {'type': 'integer', 'minimum': 1, 'maximum': 50},
          'difficulty': {
            'type': 'string',
            'enum': ['easy', 'medium', 'hard'],
          },
          'questionType': {
            'type': 'string',
            'enum': ['multiple', 'boolean'],
          },
          'categoryMap': {
            'type': 'object',
            'additionalProperties': {'type': 'integer', 'minimum': 1},
          },
          'questionRetentionDays': {'type': 'integer'},
          'maxQuestionChars': {'type': 'integer', 'minimum': 20},
          'maxOptionChars': {'type': 'integer', 'minimum': 10},
        },
      ),
    ),
    example: jsonEncode({
      'amount': 10,
      'difficulty': 'easy',
      'questionType': 'multiple',
      'categoryMap': {'science': 17, 'history': 23},
      'questionRetentionDays': 15,
      'maxQuestionChars': 90,
      'maxOptionChars': 45,
    }),
  ),
  'stock_finnhub': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'StockQuoteProviderConfig',
        description:
            'Finnhub stock quote provider: default symbols (used when '
            'interests_stock_symbols has no enabled rows) and per-tick fetch ceiling.',
        properties: {
          'maxSymbolsPerCollect': {'type': 'integer', 'minimum': 1},
          'defaultSymbols': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'symbol': {'type': 'string', 'minLength': 1},
                'displayName': {'type': 'string'},
              },
              'required': ['symbol'],
              'additionalProperties': true,
            },
          },
        },
      ),
    ),
    example: jsonEncode({
      'maxSymbolsPerCollect': 25,
      'defaultSymbols': [
        {'symbol': 'AAPL', 'displayName': 'Apple'},
        {'symbol': 'MSFT', 'displayName': 'Microsoft'},
      ],
    }),
  ),
  'calendar_outlook': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'OutlookCalendarProviderConfig',
        description:
            'Microsoft Graph calendar sync: accounts, mailboxes, sync window.',
        properties: {
          'pastDays': {'type': 'integer', 'minimum': 1},
          'futureDays': {'type': 'integer', 'minimum': 1},
          'accounts': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'graphAccountKey': {'type': 'string', 'minLength': 1},
                'sources': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'mailbox': {'type': 'string', 'minLength': 1},
                      'email': {'type': 'string'},
                      'defaultCategoryId': {'type': 'string'},
                      'defaultCategory': {'type': 'string'},
                      'categoryMap': {
                        'type': 'object',
                        'additionalProperties': {'type': 'string'},
                      },
                      'calendars': {
                        'type': 'array',
                        'items': {
                          'oneOf': [
                            {'type': 'string'},
                            {
                              'type': 'object',
                              'properties': {
                                'calendar': {'type': 'string'},
                                'name': {'type': 'string'},
                                'id': {'type': 'string'},
                                'categoryId': {'type': 'string'},
                                'category': {'type': 'string'},
                              },
                              'additionalProperties': true,
                            },
                          ],
                        },
                      },
                    },
                    'required': ['mailbox'],
                    'additionalProperties': true,
                  },
                },
              },
              'required': ['graphAccountKey'],
              'additionalProperties': true,
            },
          },
        },
      ),
    ),
    example: jsonEncode({
      'accounts': [
        {
          'graphAccountKey': 'primary',
          'sources': [
            {'mailbox': 'me', 'calendars': []},
          ],
        },
      ],
      'pastDays': 14,
      'futureDays': 14,
    }),
  ),
  'calendar_google': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'GoogleCalendarProviderConfig',
        description:
            'Google Calendar sync: accounts, calendar filters, window.',
        properties: {
          'pastDays': {'type': 'integer', 'minimum': 1},
          'futureDays': {'type': 'integer', 'minimum': 1},
          'accounts': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'googleAccountKey': {'type': 'string', 'minLength': 1},
                'sources': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'defaultCategoryId': {'type': 'string'},
                      'defaultCategory': {'type': 'string'},
                      'calendars': {
                        'type': 'array',
                        'items': {
                          'oneOf': [
                            {'type': 'string'},
                            {
                              'type': 'object',
                              'properties': {
                                'calendar': {'type': 'string'},
                                'name': {'type': 'string'},
                                'id': {'type': 'string'},
                                'categoryId': {'type': 'string'},
                                'category': {'type': 'string'},
                              },
                              'additionalProperties': true,
                            },
                          ],
                        },
                      },
                    },
                    'additionalProperties': true,
                  },
                },
              },
              'required': ['googleAccountKey'],
              'additionalProperties': true,
            },
          },
        },
      ),
    ),
    example: jsonEncode({
      'accounts': [
        {
          'googleAccountKey': 'primary',
          'sources': [
            {'calendars': []},
          ],
        },
      ],
      'pastDays': 14,
      'futureDays': 14,
    }),
  ),
  'media_onedrive': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'OneDriveMediaProviderConfig',
        description:
            'Microsoft Graph OneDrive (read-only): delta sync of each path '
            'subtree into photo/video categories; retention and per-poll '
            'download caps. Remote deletes remove local rows.',
        properties: {
          'globalPerPollLimit': {'type': 'integer', 'minimum': 1},
          'accounts': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'graphAccountKey': {'type': 'string', 'minLength': 1},
                'sources': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'path': {'type': 'string', 'minLength': 1},
                      'folder': {'type': 'string'},
                      'kind': {
                        'type': 'string',
                        'enum': ['photo', 'video'],
                      },
                      'category': {'type': 'string', 'minLength': 1},
                      'maxFiles': {'type': 'integer', 'minimum': 1},
                      'perPollLimit': {'type': 'integer', 'minimum': 1},
                    },
                    'required': ['kind', 'category'],
                    'additionalProperties': true,
                  },
                },
              },
              'required': ['graphAccountKey'],
              'additionalProperties': true,
            },
          },
        },
      ),
    ),
    example: jsonEncode({
      'globalPerPollLimit': 50,
      'accounts': [
        {
          'graphAccountKey': 'personal',
          'sources': [
            {
              'path': '/Pictures/Family',
              'kind': 'both',
              'category': 'family_media',
              'maxFiles': 30,
              'perPollLimit': 5,
            },
            {
              'path': '/Videos/Clips',
              'kind': 'video',
              'category': 'home_videos',
              'maxFiles': 20,
              'perPollLimit': 2,
            },
          ],
        },
      ],
    }),
  ),
  'media_flickr': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'FlickrMediaProviderConfig',
        description:
            'Public Flickr group photo sync. API key comes from environment variable WADDLE_DISPLAY_FLICKR_API_KEY.',
        properties: {
          'groupIds': {
            'type': 'array',
            'items': {'type': 'string', 'minLength': 1},
          },
          'category': {'type': 'string', 'minLength': 1},
          'perPollLimit': {'type': 'integer', 'minimum': 1},
          'sort': {'type': 'string'},
        },
      ),
    ),
    example: jsonEncode({
      'groupIds': ['34427469792@N01'],
      'category': 'flickr',
      'perPollLimit': 20,
      'sort': 'date-posted-desc',
    }),
  ),
  'media_bing_iotd': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'BingImageOfDayProviderConfig',
        description:
            'Bing homepage image of the day. Fetches HPImageArchive JSON then '
            'downloads {baseUrl}{urlbase}_{resolution}.jpg. No API key.',
        properties: {
          'retentionDays': {
            'type': 'integer',
            'description': 'Age-based prune; <=0 disables pruning.',
          },
          'market': {'type': 'string', 'minLength': 1},
          'resolution': {
            'type': 'string',
            'enum': [
              'UHD',
              '1920x1200',
              '1920x1080',
              '1366x768',
              '1080x1920',
              '768x1280',
            ],
          },
          'category': {
            'type': 'string',
            'minLength': 1,
            'description': 'ContentCategories id for Photos.category',
          },
        },
      ),
    ),
    example: jsonEncode({
      'retentionDays': 1,
      'market': 'en-US',
      'resolution': 'UHD',
      'category': 'bing',
    }),
  ),
};

ProviderConfigJsonDoc providerConfigJsonDocForType(String providerType) {
  return kProviderConfigJsonMeta[providerType] ?? kGenericProviderConfigJsonDoc;
}

/// JSON Schema and example for [Screens.configJson] (widget `config` object).
class ScreenConfigJsonDoc {
  const ScreenConfigJsonDoc({required this.schema, required this.example});

  final String schema;
  final String example;
}

/// Permissive schema for unknown or empty widget configs.
final ScreenConfigJsonDoc kGenericScreenConfigJsonDoc = ScreenConfigJsonDoc(
  schema: jsonEncode(
    _baseSchema(
      title: 'ScreenWidgetConfig',
      description: 'Widget-specific options for this screen type.',
      properties: {},
    ),
  ),
  example: '{}',
);

/// JSON Schema fragment: analog clock per-hand accent (`hourHandAccent`, etc.).
final Map<String, Object?> _kJsonSchemaAnalogHandAccent = {
  'description':
      'Theme accent for this hand (hour defaults to accent1, minute to '
      'accent2, second to accent3). Use accent1, accent2, accent3 or integers '
      '1–3.',
  'oneOf': [
    {
      'type': 'string',
      'enum': ['accent1', 'accent2', 'accent3', '1', '2', '3'],
    },
    {'type': 'integer', 'minimum': 1, 'maximum': 3},
  ],
};

/// JSON Schema fragment: analog clock `dialLabels` string values.
final Map<String, Object?> _kJsonSchemaAnalogDialLabels = {
  'type': 'string',
  'description':
      'Hour labels on the dial. none: hidden (default). numbers or numeric: '
      '1–12. roman or roman_numerals: I–XII. cardinal_numbers, cardinal, or '
      'crosshair_numbers: 12, 3, 6, and 9 only.',
  'enum': [
    'none',
    'numbers',
    'numeric',
    'roman',
    'roman_numerals',
    'cardinal_numbers',
    'cardinal',
    'crosshair_numbers',
  ],
};

/// Widget `type` values handled by [ScreenRotator].
const List<String> kScreenLayoutWidgetTypes = [
  'static_text',
  'joke',
  'trivia',
  'wifi',
  'digital_clock',
  'analog_clock',
  'calendar_month',
  'photo_random',
  'news',
  'news_columns',
  'news_stack',
  'local_api',
  'admin_setup',
  'controller_invite',
  'weather',
  'photo',
  'photo_collage',
  'video',
  'stock_quotes',
  'data_health',
  'web_page',
];

/// [TickerTapes.tickerType] values for curation and seeds.
const List<String> kTickerSlotDefinitionTypes = [
  'time',
  'weather',
  'news',
  'quote',
  'stocks',
  'custom',
];

/// Frozen layout-level docs for migration 20 (`layout_json_schema` / `example_layout_json`).
final String kMigration20ScreenLayoutJsonSchema = jsonEncode({
  r'$schema': _kJsonSchemaDraft,
  'title': 'ScreenLayout',
  'description':
      'Dashboard slide layout: version, optional layout hint, widgets.',
  'type': 'object',
  'properties': {
    'v': {'type': 'integer'},
    'layout': {'type': 'string'},
    'widgets': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'type': {'type': 'string', 'enum': kScreenLayoutWidgetTypes},
          'slot': {'type': 'string', 'minLength': 1},
          'config': {'type': 'object', 'additionalProperties': true},
        },
        'required': ['type', 'slot'],
        'additionalProperties': true,
      },
    },
  },
  'required': ['v', 'widgets'],
  'additionalProperties': true,
});

final String kMigration20ExampleScreenLayoutJson = jsonEncode({
  'v': 1,
  'layout': 'single',
  'widgets': [
    {
      'type': 'weather',
      'slot': 'main',
      'config': {'locationId': 'salt_lake_city_ut'},
    },
  ],
});

final Map<String, ScreenConfigJsonDoc> kScreenConfigJsonMeta = {
  'static_text': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'StaticTextScreenConfig',
        description: 'Fixed headline / body text for the slide.',
        properties: {
          'text': {'type': 'string'},
        },
        requiredKeys: ['text'],
      ),
    ),
    example: jsonEncode({'text': 'Welcome to Waddle View'}),
  ),
  'joke': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'JokeScreenConfig',
        description:
            'Optional content_categories id to scope the joke pool for curation.',
        properties: {
          'categoryId': {'type': 'string', 'minLength': 1},
        },
      ),
    ),
    example: jsonEncode({'categoryId': 'general'}),
  ),
  'trivia': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'TriviaScreenConfig',
        description:
            'Category pool, elimination timing, and wrong-answer strike animation.',
        properties: {
          'categoryId': {'type': 'string', 'minLength': 1},
          'eliminationWindowMs': {
            'type': 'integer',
            'minimum': 0,
            'description':
                'Override for elimination window length in milliseconds.',
          },
          'strikeAnimation': {
            'type': 'string',
            'description':
                'Wrong-answer strike style (case-insensitive; spaces and '
                'underscores ignored). Typical values: scribble / scribble_out '
                '(default), hand_drawn_x, strike_out_x / strikeout, fade_out / '
                'fade / opacity (opacity-only, no scribble or X).',
          },
          'strikeAnimationDurationMs': {
            'type': 'integer',
            'minimum': 120,
            'maximum': 3000,
            'description':
                'Duration of the strike animation in ms (clamped to 120–3000).',
          },
        },
      ),
    ),
    example: jsonEncode({
      'categoryId': 'science',
      'strikeAnimation': 'hand_drawn_x',
      'strikeAnimationDurationMs': 450,
    }),
  ),
  'wifi': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'WifiScreenConfig',
        description:
            'Standard Wi‑Fi QR payload (`WIFI:...;`) and optional headline. '
            'Each screen can use a different `connection` for multiple networks.',
        properties: {
          'connection': {
            'type': 'string',
            'minLength': 1,
            'description': 'Wi‑Fi DPP / ZXing-style connection string for the QR code.',
          },
          'headline': {'type': 'string'},
        },
      ),
    ),
    example: jsonEncode({
      'headline': 'Guest WiFi',
      'connection': 'WIFI:S:Guest;T:WPA;P:;;',
    }),
  ),
  'digital_clock': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'DigitalClockScreenConfig',
        description: '12/24-hour clock face and second ticks.',
        properties: {
          'hour24': {
            'type': 'boolean',
            'description':
                'When true, use 24-hour time (default false / 12-hour).',
          },
          'showSeconds': {
            'type': 'boolean',
            'description':
                'When true, update every second; otherwise align to minute ticks.',
          },
        },
      ),
    ),
    example: jsonEncode({'hour24': false, 'showSeconds': true}),
  ),
  'analog_clock': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'AnalogClockScreenConfig',
        description: 'Dial labels, per-hand accent colors, and date line.',
        properties: {
          'dialLabels': _kJsonSchemaAnalogDialLabels,
          'hourHandAccent': _kJsonSchemaAnalogHandAccent,
          'minuteHandAccent': _kJsonSchemaAnalogHandAccent,
          'secondHandAccent': _kJsonSchemaAnalogHandAccent,
        },
      ),
    ),
    example: jsonEncode({
      'dialLabels': 'roman',
      'hourHandAccent': 'accent1',
      'minuteHandAccent': 2,
      'secondHandAccent': 'accent3',
    }),
  ),
  'calendar_month': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'CalendarMonthScreenConfig',
        description:
            'Two-column flex weights and upcoming-event time label formatting.',
        properties: {
          'leftFlex': {
            'type': 'integer',
            'minimum': 1,
            'description': 'Flex for the calendar (left) column.',
          },
          'rightFlex': {
            'type': 'integer',
            'minimum': 1,
            'description': 'Flex for the upcoming-events column.',
          },
          'upcomingTime12Hour': {
            'type': 'boolean',
            'description': 'Use 12-hour times with AM/PM (default true).',
          },
          'upcomingTimeNoonLabel': {
            'type': 'string',
            'minLength': 1,
            'description': 'Label for exactly 12:00 PM (default Noon).',
          },
          'upcomingTimeWidthCompact': {
            'type': 'number',
            'minimum': 1,
            'description':
                'Time column width in logical px when the slide is compact.',
          },
          'upcomingTimeWidth': {
            'type': 'number',
            'minimum': 1,
            'description':
                'Time column width in logical px for non-compact layout.',
          },
        },
      ),
    ),
    example: jsonEncode({
      'leftFlex': 1,
      'rightFlex': 1,
      'upcomingTime12Hour': true,
      'upcomingTimeNoonLabel': 'Noon',
      'upcomingTimeWidthCompact': 132,
      'upcomingTimeWidth': 156,
    }),
  ),
  'photo_random': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'PhotoRandomScreenConfig',
        description:
            'Names the random photo pool key for curation (e.g. shared with '
            'other slots). The curator stores the chosen blob id in '
            'randomChoices under the widget choice key.',
        properties: {
          'pool': {'type': 'string', 'minLength': 1},
        },
      ),
    ),
    example: jsonEncode({'pool': 'pix'}),
  ),
  'news': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'RssArticleScreenConfig',
        description:
            'Scroll timing, image side, summary capacity, optional feed or '
            'category filter for article selection.',
        properties: {
          'feedId': {
            'type': 'string',
            'minLength': 1,
            'description': 'Restrict articles to this rss_feeds id.',
          },
          'categoryId': {
            'type': 'string',
            'minLength': 1,
            'description':
                'Restrict to articles in this content_categories id (pool rss_category:<id>).',
          },
          'scrollDelayMs': {'type': 'integer', 'minimum': 0},
          'trailingHoldMs': {'type': 'integer', 'minimum': 0},
          'scrollPixelsPerSecond': {'type': 'number', 'minimum': 0},
          'minReadMs': {'type': 'integer', 'minimum': 0},
          'imageOnRight': {'type': 'boolean'},
          'imagePanelFraction': {
            'type': 'number',
            'minimum': 0.2,
            'maximum': 0.55,
            'description':
                'Width fraction for the image panel (clamped in UI).',
          },
          'summaryCapacityChars': {'type': 'integer', 'minimum': 1},
        },
      ),
    ),
    example: jsonEncode({
      'feedId': 'bbc_world',
      'scrollDelayMs': 2500,
      'trailingHoldMs': 2000,
      'scrollPixelsPerSecond': 48,
      'minReadMs': 8000,
      'imagePanelFraction': 0.39,
      'summaryCapacityChars': 1200,
    }),
  ),
  'news_columns': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'RssArticleColumnsScreenConfig',
        description:
            'Multi-column RSS layout; optional feed or category filter; QR size.',
        properties: {
          'feedId': {
            'type': 'string',
            'minLength': 1,
            'description': 'Restrict articles to this rss_feeds id.',
          },
          'categoryId': {
            'type': 'string',
            'minLength': 1,
            'description':
                'Restrict to articles in this content_categories id (pool rss_category:<id>).',
          },
          'columnCount': {'type': 'integer', 'minimum': 1, 'maximum': 6},
          'minReadMs': {'type': 'integer', 'minimum': 0},
          'qrLogicalSize': {
            'type': 'number',
            'minimum': 48,
            'maximum': 140,
            'description': 'QR code size in logical pixels (clamped in UI).',
          },
          'summaryCapacityCharsPerColumn': {'type': 'integer', 'minimum': 1},
        },
      ),
    ),
    example: jsonEncode({
      'categoryId': 'news',
      'columnCount': 3,
      'minReadMs': 10000,
      'qrLogicalSize': 80,
      'summaryCapacityCharsPerColumn': 220,
    }),
  ),
  'news_stack': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'RssArticleStackScreenConfig',
        description:
            'Two-row stacked RSS layout; optional feed or category filter.',
        properties: {
          'feedId': {
            'type': 'string',
            'minLength': 1,
            'description': 'Restrict articles to this rss_feeds id.',
          },
          'categoryId': {
            'type': 'string',
            'minLength': 1,
            'description':
                'Restrict to articles in this content_categories id (pool rss_category:<id>).',
          },
          'minReadMs': {'type': 'integer', 'minimum': 0},
          'imagePanelFraction': {
            'type': 'number',
            'minimum': 0.2,
            'maximum': 0.48,
            'description':
                'Per-row image panel width fraction (clamped in UI).',
          },
          'qrLogicalSize': {
            'type': 'number',
            'minimum': 72,
            'maximum': 200,
            'description': 'QR code size in logical pixels (clamped in UI).',
          },
          'summaryCapacityCharsPerSlot': {'type': 'integer', 'minimum': 1},
        },
      ),
    ),
    example: jsonEncode({
      'feedId': 'local_news',
      'minReadMs': 12000,
      'imagePanelFraction': 0.32,
      'qrLogicalSize': 112,
      'summaryCapacityCharsPerSlot': 320,
    }),
  ),
  'local_api': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'LocalApiScreenConfig',
        description: 'Headline for the local REST API slide.',
        properties: {
          'headline': {'type': 'string'},
        },
      ),
    ),
    example: jsonEncode({'headline': 'Local REST API'}),
  ),
  'admin_setup': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'AdminSetupScreenConfig',
        description: 'Setup slide headline and QR for admin login.',
        properties: {
          'headline': {'type': 'string'},
          'showLoginQr': {
            'type': 'boolean',
            'description': 'When false, hides the login QR (default true).',
          },
        },
      ),
    ),
    example: jsonEncode({
      'headline': 'Complete device setup',
      'showLoginQr': true,
    }),
  ),
  'weather': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'WeatherScreenConfig',
        description: 'Selects a row from interests_locations.',
        properties: {
          'locationId': {'type': 'string', 'minLength': 1},
        },
        requiredKeys: ['locationId'],
      ),
    ),
    example: jsonEncode({'locationId': 'salt_lake_city_ut'}),
  ),
  'photo': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'PexelsPhotoScreenConfig',
        description:
            'Optional photos category id; when omitted, any non-suppressed photo may be chosen.',
        properties: {
          'categoryId': {'type': 'string', 'minLength': 1},
        },
      ),
    ),
    example: jsonEncode({'categoryId': 'nature'}),
  ),
  'photo_collage': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'PexelsPhotoCollageScreenConfig',
        description:
            'Collage template id and optional category for the photo pool.',
        properties: {
          'template': {'type': 'string', 'minLength': 1},
          'categoryId': {
            'type': 'string',
            'minLength': 1,
            'description':
                'Optional content_categories id for the Pexels photo pool.',
          },
        },
        requiredKeys: ['template'],
      ),
    ),
    example: jsonEncode({
      'template': 'nine_square_asymmetric',
      'categoryId': 'pexels',
    }),
  ),
  'video': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'PexelsVideoScreenConfig',
        description:
            'Playback options and optional video category for selection.',
        properties: {
          'categoryId': {
            'type': 'string',
            'minLength': 1,
            'description':
                'Restrict to videos in this content_categories id (pool video:<id>).',
          },
          'loop': {'type': 'boolean'},
          'unmuted': {'type': 'boolean'},
        },
      ),
    ),
    example: jsonEncode({
      'categoryId': 'pexels',
      'loop': true,
      'unmuted': false,
    }),
  ),
  'stock_quotes': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'StockQuotesScreenConfig',
        description:
            'No per-screen options; the slide lists all enabled interests_stock_symbols rows.',
        properties: {},
      ),
    ),
    example: jsonEncode({}),
  ),
  'controller_invite': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'ControllerInviteScreenConfig',
        description:
            'Promotes the waddle_controller web UI. Optional controllerUrl overrides '
            'WADDLE_DISPLAY_CONTROLLER_PUBLIC_URL on the display device for the QR link.',
        properties: {
          'headline': {'type': 'string'},
          'body': {'type': 'string'},
          'controllerUrl': {
            'type': 'string',
            'minLength': 1,
            'description':
                'Public origin of the controller SPA (e.g. http://192.168.1.10:5173).',
          },
        },
      ),
    ),
    example: jsonEncode({
      'headline': 'Manage this display from your phone',
      'body':
          'Scan the QR code to open waddle_controller, then create a viewer account '
          '(Programs + account access) or sign in.',
      'controllerUrl': 'http://192.168.1.10:5173',
    }),
  ),
  'data_health': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'DataHealthScreenConfig',
        description:
            'Database statistics and content-health charts. Optional headline and '
            'refresh interval for re-querying aggregates (seconds, clamped 15–300).',
        properties: {
          'headline': {'type': 'string'},
          'refreshIntervalSeconds': {
            'type': 'integer',
            'minimum': 15,
            'maximum': 300,
          },
        },
      ),
    ),
    example: jsonEncode({
      'headline': 'Data health',
      'refreshIntervalSeconds': 45,
    }),
  ),
  'web_page': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'WebPageScreenConfig',
        description:
            'Embedded web page loaded before the slide is shown. Supports custom '
            'user agent, per-request headers, auto-scroll, and iframe-like sandbox '
            'restrictions.',
        properties: {
          'url': {
            'type': 'string',
            'minLength': 1,
            'description': 'HTTP or HTTPS URL to load (required).',
          },
          'userAgent': {
            'type': 'string',
            'description': 'Optional User-Agent override for the web view.',
          },
          'requestHeaders': {
            'type': 'object',
            'additionalProperties': {'type': 'string'},
            'description':
                'Extra HTTP headers sent with the initial navigation only.',
          },
          'javascriptEnabled': {
            'type': 'boolean',
            'description':
                'When true (default), JavaScript runs. Ignored when [security.sandbox] '
                'is set without allow-scripts.',
          },
          'loadTimeoutSeconds': {
            'type': 'integer',
            'minimum': 5,
            'maximum': 120,
            'description':
                'Max seconds to wait for the page to finish loading (default 30).',
          },
          'autoScroll': {
            'type': 'object',
            'description': 'Slow vertical scroll through the loaded document.',
            'properties': {
              'enabled': {'type': 'boolean'},
              'delayMs': {
                'type': 'integer',
                'minimum': 0,
                'description': 'Pause before scrolling starts (default 2500).',
              },
              'pixelsPerSecond': {
                'type': 'number',
                'minimum': 1,
                'description': 'Scroll speed (default 48).',
              },
              'trailingHoldMs': {
                'type': 'integer',
                'minimum': 0,
                'description': 'Hold at bottom before advancing (default 1500).',
              },
            },
          },
          'security': {
            'type': 'object',
            'description':
                'Navigation and capability restrictions (iframe sandbox–like).',
            'properties': {
              'restrictNavigation': {
                'type': 'boolean',
                'description':
                    'When true (default), block navigations away from the initial host '
                    'unless listed in allowedHosts.',
              },
              'allowedHosts': {
                'type': 'array',
                'items': {'type': 'string', 'minLength': 1},
                'description':
                    'Extra hostnames allowed when restrictNavigation is true.',
              },
              'blockPopups': {
                'type': 'boolean',
                'description': 'Block window.open / target=_blank (default true).',
              },
              'allowFileAccess': {
                'type': 'boolean',
                'description': 'Allow file:// URLs (default false).',
              },
              'mixedContentMode': {
                'type': 'string',
                'enum': ['never', 'compatibility', 'always'],
                'description':
                    'HTTPS page loading HTTP subresources (platform-dependent).',
              },
              'sandbox': {
                'type': 'array',
                'items': {
                  'type': 'string',
                  'enum': [
                    'allow-scripts',
                    'allow-same-origin',
                    'allow-forms',
                    'allow-popups',
                    'allow-top-navigation',
                    'allow-modals',
                  ],
                },
                'description':
                    'When set, enables only listed capabilities (like iframe sandbox). '
                    'Omit allow-scripts to disable JavaScript regardless of javascriptEnabled.',
              },
            },
          },
        },
        requiredKeys: ['url'],
      ),
    ),
    example: jsonEncode({
      'url': 'https://example.com/status-board',
      'userAgent': 'WaddleDisplay/1.0',
      'requestHeaders': {'X-Waddle-Display': 'lobby'},
      'javascriptEnabled': true,
      'loadTimeoutSeconds': 45,
      'autoScroll': {
        'enabled': true,
        'delayMs': 3000,
        'pixelsPerSecond': 40,
        'trailingHoldMs': 2000,
      },
      'security': {
        'restrictNavigation': true,
        'allowedHosts': ['cdn.example.com'],
        'blockPopups': true,
        'sandbox': ['allow-scripts', 'allow-same-origin', 'allow-forms'],
      },
    }),
  ),
};

ScreenConfigJsonDoc screenConfigJsonDocForType(String screenType) {
  return kScreenConfigJsonMeta[screenType] ?? kGenericScreenConfigJsonDoc;
}

/// JSON Schema and example for [TickerTapes] documentation columns
/// (per-tape config_json, optional curator tuning keys, and custom-slot KV).
final Map<String, ScreenConfigJsonDoc> kTickerSlotConfigJsonMeta = {
  'time': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'TickerTimeSlotDoc',
        description:
            'Local wall clock (HH:MM:SS). No config_key_values keys; slot is '
            'controlled only by ticker_tapes enabled / frequency_weight / '
            'sort_order.',
        properties: {},
      ),
    ),
    example: jsonEncode({}),
  ),
  'weather': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'TickerWeatherSlotDoc',
        description:
            'Live weather line plus optional NWS active-alert lines when '
            'interests_locations.include_active_weather_alerts is enabled. When '
            'live data is empty, falls back to [fallbackText] in this tape’s '
            'config_json.',
        properties: {
          'fallbackText': {
            'type': 'string',
            'description':
                'Fallback marquee text when no live weather string is available.',
          },
        },
      ),
    ),
    example: jsonEncode({
      'fallbackText': 'Cool and clear — tap for details',
    }),
  ),
  'news': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'TickerNewsSlotDoc',
        description:
            'RSS headlines from stored articles when available; otherwise '
            '[fallbackText] in this tape’s config_json. Curator KV keys in '
            'config_key_values (curator.ticker.*) tune scroll width and cadence '
            '(string values, parsed as numbers/bools). '
            'Operator UI may also set display_text_scale_ticker for ticker font scale.',
        properties: {
          'fallbackText': {
            'type': 'string',
            'description':
                'Fallback single-line headline when the RSS slice is empty.',
          },
        },
      ),
    ),
    example: jsonEncode({
      'fallbackText': 'Local headlines when RSS is quiet',
    }),
  ),
  'quote': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'TickerQuoteSlotDoc',
        description: 'Single static line from config_json [fallbackText].',
        properties: {
          'fallbackText': {
            'type': 'string',
            'description': 'Quote or tagline text for the quote ticker slot.',
          },
        },
      ),
    ),
    example: jsonEncode({'fallbackText': 'Make it a great day'}),
  ),
  'stocks': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'TickerStocksSlotDoc',
        description:
            'One line per enabled interests_stock_symbols row with latest stock_quotes; '
            'no ticker.marquee.* keys.',
        properties: {},
      ),
    ),
    example: jsonEncode({}),
  ),
  'custom': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'TickerCustomSlotDoc',
        description:
            'Uses ticker_tapes.config_key: when set to a single '
            'ticker.marquee.* key, only that key is read from config_key_values. '
            'When null, every ticker.marquee.* key in config_key_values is '
            'included (sorted).',
        properties: {
          'ticker.marquee.example_key': {
            'type': 'string',
            'description':
                'Replace example_key with your suffix; keys must start with '
                'ticker.marquee. Values are plain text lines.',
          },
        },
      ),
    ),
    example: jsonEncode({'ticker.marquee.welcome': 'Thanks for visiting'}),
  ),
};

ScreenConfigJsonDoc tickerSlotConfigJsonDocForType(String tickerType) {
  return kTickerSlotConfigJsonMeta[tickerType] ?? kGenericScreenConfigJsonDoc;
}

/// JSON Schema + example for [overlays.config_json] by [overlayType].
ProviderConfigJsonDoc displayOverlayConfigJsonDocForType(String overlayType) {
  final k = overlayType.trim();
  if (k == kOverlayTypeHeartsRain) {
    return ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'HeartsRainOverlayConfig',
          description:
              'Floating hearts use the theme accent palette. Phrases come from '
              'the messages array.',
          properties: {
            'messages': {
              'type': 'array',
              'items': {'type': 'string', 'minLength': 1},
              'description': 'Short phrases occasionally shown with the hearts.',
            },
          },
        ),
      ),
      example: jsonEncode({
        'messages': ['Happy Day!'],
      }),
    );
  }
  if (k == kOverlayTypeBirthdayConfetti) {
    return ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'BirthdayConfettiOverlayConfig',
          description:
              'Optional shapes, hex colors, density, message interval, fall '
              'speed, opacity, and sparse overlay phrases in messages.',
          properties: {
            'messages': {
              'type': 'array',
              'items': {'type': 'string', 'minLength': 1},
              'description': 'Sparse phrases shown among confetti pieces.',
            },
            'shapes': {
              'type': 'array',
              'items': {
                'type': 'string',
                'enum': ['rect', 'circle', 'star', 'streamer', 'mix'],
              },
            },
            'colors': {
              'type': 'array',
              'items': {
                'type': 'string',
                'pattern': r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
              },
            },
            'density': {
              'type': 'number',
              'minimum': 0.15,
              'maximum': 0.9,
            },
            'message_interval_sec': {
              'type': 'integer',
              'minimum': 8,
              'maximum': 120,
            },
            'fall_speed': {
              'type': 'number',
              'minimum': 0.02,
              'maximum': 1.8,
              'description':
                  'Relative vertical drift speed; lower is slower (about 5s per '
                  'full cycle at 1.0; the minimum 0.02 yields about 250s per cycle).',
            },
            'opacity': {
              'type': 'number',
              'minimum': 0.12,
              'maximum': 0.72,
              'description': 'Upper bound for confetti piece alpha (visibility).',
            },
          },
        ),
      ),
      example: jsonEncode({
        'messages': ['Happy birthday!'],
        'shapes': ['rect', 'circle', 'mix'],
        'colors': ['#E05C6C', '#FFE356'],
        'density': 0.36,
        'message_interval_sec': 36,
        'fall_speed': 0.14,
        'opacity': 0.46,
      }),
    );
  }
  if (k == kOverlayTypeBouncingMessage) {
    return ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'BouncingMessageOverlayConfig',
          description:
              'Optional typography and motion for bouncing_message overlays. '
              'The visible phrase is the first entry in messages; when empty '
              'the app uses a built-in default.',
          properties: {
            'messages': {
              'type': 'array',
              'items': {'type': 'string', 'minLength': 1},
              'description': 'First string is shown as the bouncing line.',
            },
            'color': {
              'type': 'string',
              'pattern': r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
              'description': 'Text color; omit to use the theme primary color.',
            },
            'font_family': {
              'type': 'string',
              'maxLength': 120,
              'description': 'TextStyle.fontFamily; omit for the theme default.',
            },
            'font_size': {
              'type': 'number',
              'minimum': 14,
              'maximum': 96,
            },
            'font_weight': {
              'oneOf': [
                {'type': 'integer', 'minimum': 100, 'maximum': 900},
                {'type': 'string'},
              ],
              'description': 'CSS-style weight (100–900, snapped to hundreds).',
            },
            'letter_spacing': {
              'type': 'number',
              'minimum': -1.5,
              'maximum': 6,
            },
            'shadow': {'type': 'boolean'},
            'speed': {
              'type': 'number',
              'minimum': 0.25,
              'maximum': 2.5,
              'description': 'Velocity multiplier for the bounce motion.',
            },
          },
        ),
      ),
      example: jsonEncode({
        'messages': ['Happy Birthday Waddle!!'],
        'color': '#E05C6C',
        'font_family': 'Roboto',
        'font_size': 40,
        'font_weight': 700,
        'letter_spacing': 0.6,
        'shadow': true,
        'speed': 1.0,
      }),
    );
  }
  return ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'OverlayConfig',
        description:
            'Custom overlay_type values the display may not render yet. '
            'Use JSON-serializable keys; messages holds optional phrases.',
        properties: {
          'messages': {
            'type': 'array',
            'items': {'type': 'string', 'minLength': 1},
          },
        },
      ),
    ),
    example: jsonEncode({'messages': ['Hello']}),
  );
}
