import 'dart:convert';

/// JSON Schema (draft 2020-12) and example payload for one [provider_type].
class ProviderConfigJsonDoc {
  const ProviderConfigJsonDoc({required this.schema, required this.example});

  final String schema;
  final String example;
}

const String _kJsonSchemaDraft =
    'https://json-schema.org/draft/2020-12/schema';

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
final ProviderConfigJsonDoc kGenericProviderConfigJsonDoc = ProviderConfigJsonDoc(
  schema: jsonEncode(
    _baseSchema(
      title: 'GenericProviderConfig',
      description: 'Arbitrary JSON; no parser-specific shape.',
      properties: {},
    ),
  ),
  example: '{}',
);

/// Documentation keyed by [ProviderSettings.providerType] (seeded + built-in).
final Map<String, ProviderConfigJsonDoc> kProviderConfigJsonMeta = {
  'stub': kGenericProviderConfigJsonDoc,
  'rss': kGenericProviderConfigJsonDoc,
  'pexels': ProviderConfigJsonDoc(
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
      'sources': [
        {'query': 'nature', 'category': 'pexels'},
      ],
    }),
  ),
  'weather': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'WeatherProviderConfig',
        description: 'OpenWeather units, language, hourly columns, default map.',
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
      'defaultLocation': {
        'name': 'Default',
        'lat': 40.7128,
        'lon': -74.006,
      },
    }),
  ),
  'nws_weather_alerts': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'NwsWeatherGovAlertsConfig',
        description:
            'api.weather.gov active alerts. Set userAgent with contact info per NWS API rules. '
            'Optional defaultLocation when no rows exist in weather_locations.',
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
      'defaultLocation': {
        'name': 'Default',
        'lat': 40.7128,
        'lon': -74.006,
      },
    }),
  ),
  'jokes': ProviderConfigJsonDoc(
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
  'trivia': ProviderConfigJsonDoc(
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
  'opentdb_trivia': ProviderConfigJsonDoc(
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
      'categoryMap': {
        'science': 17,
        'history': 23,
      },
      'questionRetentionDays': 15,
      'maxQuestionChars': 90,
      'maxOptionChars': 45,
    }),
  ),
  'stocks': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'StockQuoteProviderConfig',
        description:
            'Finnhub stock quote provider: default symbols (used when '
            'stock_symbols has no enabled rows) and per-tick fetch ceiling.',
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
  'outlook_calendar': ProviderConfigJsonDoc(
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
  'google_calendar': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'GoogleCalendarProviderConfig',
        description: 'Google Calendar sync: accounts, calendar filters, window.',
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
  'onedrive_media': ProviderConfigJsonDoc(
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
                      'kind': {'type': 'string', 'enum': ['photo', 'video']},
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
  'flickr_media': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'FlickrMediaProviderConfig',
        description:
            'Public Flickr group photo sync. API key comes from SecretStore.',
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
  'bing_iotd': ProviderConfigJsonDoc(
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
  return kProviderConfigJsonMeta[providerType] ??
      kGenericProviderConfigJsonDoc;
}

/// JSON Schema and example for [ScreenDefinitions.configJson] (widget `config` object).
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

/// Widget `type` values handled by [ScreenRotator].
const List<String> kScreenLayoutWidgetTypes = [
  'static_text',
  'joke',
  'trivia',
  'guest_wifi',
  'digital_clock',
  'analog_clock',
  'calendar_month',
  'photo_random',
  'rss_article',
  'rss_article_columns',
  'rss_article_stack',
  'local_api',
  'admin_setup',
  'weather',
  'pexels_photo',
  'pexels_photo_collage',
  'pexels_video',
  'stock_quotes',
];

/// Frozen layout-level docs for migration 20 (`layout_json_schema` / `example_layout_json`).
final String kMigration20ScreenLayoutJsonSchema = jsonEncode({
  r'$schema': _kJsonSchemaDraft,
  'title': 'ScreenLayout',
  'description': 'Dashboard slide layout: version, optional layout hint, widgets.',
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
  'weather': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'WeatherScreenConfig',
        description: 'Selects a row from weather_locations.',
        properties: {
          'locationId': {'type': 'string', 'minLength': 1},
        },
        requiredKeys: ['locationId'],
      ),
    ),
    example: jsonEncode({'locationId': 'salt_lake_city_ut'}),
  ),
  'rss_article': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'RssArticleScreenConfig',
        description: 'Scroll timing, image side, summary capacity.',
        properties: {
          'scrollDelayMs': {'type': 'integer', 'minimum': 0},
          'trailingHoldMs': {'type': 'integer', 'minimum': 0},
          'scrollPixelsPerSecond': {'type': 'number', 'minimum': 0},
          'minReadMs': {'type': 'integer', 'minimum': 0},
          'imageOnRight': {'type': 'boolean'},
          'summaryCapacityChars': {'type': 'integer', 'minimum': 1},
        },
      ),
    ),
    example: jsonEncode({
      'scrollDelayMs': 2500,
      'trailingHoldMs': 2000,
      'scrollPixelsPerSecond': 48,
      'minReadMs': 8000,
      'summaryCapacityChars': 1200,
    }),
  ),
  'rss_article_columns': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'RssArticleColumnsScreenConfig',
        description: 'Multi-column RSS layout.',
        properties: {
          'columnCount': {'type': 'integer', 'minimum': 1, 'maximum': 6},
          'minReadMs': {'type': 'integer', 'minimum': 0},
          'summaryCapacityCharsPerColumn': {'type': 'integer', 'minimum': 1},
        },
      ),
    ),
    example: jsonEncode({
      'columnCount': 3,
      'minReadMs': 10000,
      'summaryCapacityCharsPerColumn': 220,
    }),
  ),
  'rss_article_stack': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'RssArticleStackScreenConfig',
        description: 'Two-row stacked RSS layout.',
        properties: {
          'minReadMs': {'type': 'integer', 'minimum': 0},
          'imagePanelFraction': {'type': 'number', 'minimum': 0, 'maximum': 1},
          'qrLogicalSize': {'type': 'number', 'minimum': 0},
          'summaryCapacityCharsPerSlot': {'type': 'integer', 'minimum': 1},
        },
      ),
    ),
    example: jsonEncode({
      'minReadMs': 12000,
      'imagePanelFraction': 0.32,
      'qrLogicalSize': 112,
      'summaryCapacityCharsPerSlot': 320,
    }),
  ),
  'pexels_video': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'PexelsVideoScreenConfig',
        description: 'Playback options for Pexels video slides.',
        properties: {
          'loop': {'type': 'boolean'},
          'unmuted': {'type': 'boolean'},
        },
      ),
    ),
    example: jsonEncode({'loop': true, 'unmuted': false}),
  ),
  'pexels_photo_collage': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'PexelsPhotoCollageScreenConfig',
        description: 'Collage template id for tile layout.',
        properties: {
          'template': {'type': 'string', 'minLength': 1},
        },
        requiredKeys: ['template'],
      ),
    ),
    example: jsonEncode({'template': 'nine_square_asymmetric'}),
  ),
};

ScreenConfigJsonDoc screenConfigJsonDocForType(String screenType) {
  return kScreenConfigJsonMeta[screenType] ?? kGenericScreenConfigJsonDoc;
}
