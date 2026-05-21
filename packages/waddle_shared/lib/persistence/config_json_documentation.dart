import 'dart:convert';


import 'display_overlay_falling_images_settings.dart';
import 'display_overlay_floating_balloons_settings.dart';
import 'display_overlay_cloud_drift_settings.dart';
import 'display_overlay_edge_glow_settings.dart';
import 'display_overlay_matrix_rain_settings.dart';
import 'display_overlay_calendar_month_settings.dart';
import 'display_overlay_calendar_upcoming_settings.dart';
import 'display_overlay_clock_placement.dart';
import 'display_overlay_photo_slideshow_settings.dart';
import 'display_overlay_static_image_settings.dart';
import 'display_overlay_qr_code_settings.dart';
import 'qr_overlay_payload.dart';
import 'kv_schema_documentation.dart';
import 'tables.dart';

/// JSON Schema (draft 2020-12) and example payload for one [integration_type].
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

Map<String, Object?> _integrationConfigProperties(
  Map<String, Object?> properties,
) =>
    {
      ...properties,
      'baseUrl': {
        'type': 'string',
        'description': 'HTTP API or service root URL for this collector.',
      },
    };

/// Permissive schema for unknown provider types.
final ProviderConfigJsonDoc kGenericProviderConfigJsonDoc =
    ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'GenericProviderConfig',
          description: 'Arbitrary JSON; no parser-specific shape.',
          properties: _integrationConfigProperties({}),
        ),
      ),
      example: '{}',
    );

/// Documentation keyed by [Integrations.integrationType] (seeded + built-in).
final Map<String, ProviderConfigJsonDoc> kProviderConfigJsonMeta = {
  'stub': kGenericProviderConfigJsonDoc,
  'news_rss': kGenericProviderConfigJsonDoc,
  'photo_pexels': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'PexelsPhotoProviderConfig',
        description: 'Photo rate limits, retention, and curated search sources.',
        properties: _integrationConfigProperties({
          'maxPhotos': {'type': 'integer', 'minimum': 1},
          'photosPerHour': {'type': 'integer', 'minimum': 1},
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
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://api.pexels.com',
      'maxPhotos': 100,
      'photosPerHour': 2,
      'sources': [
        {'query': 'nature', 'category': 'pexels'},
      ],
    }),
  ),
  'video_pexels': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'PexelsVideoProviderConfig',
        description: 'Video rate limits, retention, and curated search sources.',
        properties: _integrationConfigProperties({
          'maxVideos': {'type': 'integer', 'minimum': 1},
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
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://api.pexels.com',
      'maxVideos': 100,
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
        properties: _integrationConfigProperties({
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
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://api.openweathermap.org',
      'units': 'imperial',
      'lang': 'en',
      'hourlyCount': 6,
      'defaultLocation': {'name': 'Default', 'lat': 40.7128, 'lon': -74.006},
    }),
  ),
  'weather_openmeteo': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'OpenMeteoWeatherConfig',
        description:
            'Open-Meteo forecast (no API key). Writes weather_current for '
            'interests_locations with include_weather. units: imperial→fahrenheit, '
            'metric→celsius. lang is ignored (WMO descriptions).',
        properties: _integrationConfigProperties({
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
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://api.open-meteo.com',
      'units': 'imperial',
      'lang': 'en',
      'hourlyCount': 6,
      'defaultLocation': {'name': 'Default', 'lat': 40.7128, 'lon': -74.006},
    }),
  ),
  'air_quality_openmeteo': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'OpenMeteoAirQualityConfig',
        description:
            'Open-Meteo air quality (no API key). Stores per-location JSON in '
            'integration KV: air_quality.location.{locationId}.current, '
            '.hourly, .collected_at_ms. Uses interests_locations with '
            'include_weather (or defaultLocation).',
        properties: _integrationConfigProperties({
          'units': {'type': 'string'},
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
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://air-quality-api.open-meteo.com',
      'hourlyCount': 6,
      'defaultLocation': {'name': 'Default', 'lat': 40.7128, 'lon': -74.006},
    }),
  ),
  'weather_alerts_nws': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'NwsWeatherGovAlertsConfig',
        description:
            'api.weather.gov active alerts. Set userAgent with contact info per NWS API rules. '
            'Optional defaultLocation when no rows exist in interests_locations.',
        properties: _integrationConfigProperties({
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
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://api.weather.gov',
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
  'general_openai': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'GeneralOpenAiProviderConfig',
        description:
            'Scheduled OpenAI Responses API prompts with optional remote HTTP MCP '
            'tools. Results are stored in integration key-value rows.',
        properties: {
          'defaultModel': {'type': 'string'},
          'defaultRetentionDays': {'type': 'integer', 'minimum': 1},
          'defaultMaxHistoryEntries': {'type': 'integer', 'minimum': 1},
          'prompts': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'id': {'type': 'string', 'minLength': 1},
                'label': {'type': 'string'},
                'enabled': {'type': 'boolean'},
                'pollSeconds': {'type': 'integer', 'minimum': 0},
                'model': {'type': 'string'},
                'systemPrompt': {'type': 'string'},
                'userPrompt': {'type': 'string', 'minLength': 1},
                'temperature': {'type': 'number'},
                'maxOutputTokens': {'type': 'integer', 'minimum': 1},
                'retentionDays': {'type': 'integer', 'minimum': 1},
                'maxHistoryEntries': {'type': 'integer', 'minimum': 1},
                'responseFormat': {
                  'type': 'string',
                  'enum': ['text', 'json_object'],
                },
                'expectedValueType': {
                  'type': 'string',
                  'description':
                      'Documents intended KV value shape for widgets (see kv_value_data_types meta).',
                },
                'mcpServers': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'serverLabel': {'type': 'string', 'minLength': 1},
                      'serverUrl': {'type': 'string', 'minLength': 1},
                      'serverDescription': {'type': 'string'},
                      'requireApproval': {
                        'type': 'string',
                        'enum': ['never', 'always'],
                      },
                      'authorizationSecretKey': {'type': 'string'},
                    },
                    'required': ['serverLabel', 'serverUrl'],
                  },
                },
              },
              'required': ['id', 'userPrompt'],
            },
          },
        },
      ),
    ),
    example: jsonEncode({
      'defaultModel': 'gpt-4o-mini',
      'defaultRetentionDays': 30,
      'defaultMaxHistoryEntries': 500,
      'prompts': [
        {
          'id': 'daily_summary',
          'label': 'Daily summary',
          'enabled': true,
          'pollSeconds': 3600,
          'userPrompt': 'Return JSON: {"items":["example"]}',
          'systemPrompt': 'Valid JSON only.',
          'responseFormat': 'json_object',
          'expectedValueType': 'list_string_array',
        },
      ],
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
        properties: _integrationConfigProperties({
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
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://opentdb.com/api.php',
      'amount': 10,
      'difficulty': 'easy',
      'questionType': 'multiple',
      'categoryMap': {'science': 17, 'history': 23},
      'questionRetentionDays': 15,
      'maxQuestionChars': 90,
      'maxOptionChars': 45,
    }),
  ),
  'home_assistant': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'HomeAssistantProviderConfig',
        description:
            'Home Assistant REST collector: default entities (when '
            'interests_home_assistant_entities has no enabled rows), '
            'per-tick fetch ceiling, and HTTP timeout.',
        properties: _integrationConfigProperties({
          'maxEntitiesPerCollect': {'type': 'integer', 'minimum': 1},
          'requestTimeoutMs': {'type': 'integer', 'minimum': 1000},
          'defaultEntities': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'entityId': {'type': 'string', 'minLength': 1},
                'displayName': {'type': 'string'},
              },
              'required': ['entityId'],
              'additionalProperties': true,
            },
          },
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'http://homeassistant.local:8123',
      'maxEntitiesPerCollect': 50,
      'requestTimeoutMs': 15000,
      'defaultEntities': [
        {'entityId': 'sensor.example', 'displayName': 'Example'},
      ],
    }),
  ),
  'stock_finnhub': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'StockQuoteProviderConfig',
        description:
            'Finnhub stock quote provider: default symbols (used when '
            'interests_stock_symbols has no enabled rows) and per-tick fetch ceiling.',
        properties: _integrationConfigProperties({
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
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://finnhub.io',
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
        properties: _integrationConfigProperties({
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
                      'defaultCategoryIds': {
                        'type': 'array',
                        'items': {'type': 'string'},
                      },
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
                                'categoryIds': {
                                  'type': 'array',
                                  'items': {'type': 'string'},
                                },
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
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://graph.microsoft.com/v1.0',
      'accounts': [
        {
          'graphAccountKey': 'primary',
          'sources': [
            {'mailbox': 'me', 'calendars': []},
          ],
        },
      ],
      'pastDays': 30,
      'futureDays': 30,
    }),
  ),
  'calendar_google': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'GoogleCalendarProviderConfig',
        description:
            'Google Calendar sync: accounts, calendar filters, window.',
        properties: _integrationConfigProperties({
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
                      'defaultCategoryIds': {
                        'type': 'array',
                        'items': {'type': 'string'},
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
                                'categoryIds': {
                                  'type': 'array',
                                  'items': {'type': 'string'},
                                },
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
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://www.googleapis.com/calendar/v3',
      'accounts': [
        {
          'googleAccountKey': 'primary',
          'sources': [
            {'calendars': []},
          ],
        },
      ],
      'pastDays': 30,
      'futureDays': 30,
    }),
  ),
  'calendar_ical': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'IcalCalendarProviderConfig',
        description:
            'Subscribe to iCalendar (.ics) feeds by URL; sync window and per-feed category. '
            'Feed ids are assigned by the controller and are not operator-editable.',
        properties: _integrationConfigProperties({
          'pastDays': {
            'type': 'integer',
            'minimum': 1,
            'description': 'Days before today (UTC) in the sync window; default 30.',
          },
          'futureDays': {
            'type': 'integer',
            'minimum': 1,
            'description': 'Days after today (UTC) in the sync window; default 30.',
          },
          'feeds': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'id': {
                  'type': 'string',
                  'minLength': 1,
                  'description':
                      'Stable feed key (auto-generated by controller; opaque to operators).',
                },
                'url': {
                  'type': 'string',
                  'minLength': 1,
                  'description': 'ICS subscription URL (http, https, or webcal).',
                },
                'label': {
                  'type': 'string',
                  'description': 'Optional operator-facing name.',
                },
                'categoryId': _kJsonSchemaOptionalContentCategoryId,
                'category': {'type': 'string'},
                'categoryIds': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
                'enabled': {'type': 'boolean'},
              },
              'required': ['id', 'url'],
              'additionalProperties': true,
            },
          },
        }),
      ),
    ),
    example: jsonEncode({
      'feeds': [
        {
          'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          'url': 'https://calendar.example.com/public/work.ics',
          'label': 'Work',
          'categoryId': 'work',
          'enabled': true,
        },
      ],
      'pastDays': 30,
      'futureDays': 30,
    }),
  ),
  'calendar_mealviewer': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'MealviewerCalendarProviderConfig',
        description:
            'Sync school lunch menus from MealViewer into calendar events; '
            'configure schools and per-school categories.',
        properties: _integrationConfigProperties({
          'pastDays': {'type': 'integer', 'minimum': 1},
          'futureDays': {'type': 'integer', 'minimum': 1},
          'schools': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'schoolSlug': {'type': 'string', 'minLength': 1},
                'label': {'type': 'string'},
                'districtSlug': {'type': 'string'},
                'categoryId': {'type': 'string'},
                'category': {'type': 'string'},
                'categoryIds': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
              },
              'required': ['schoolSlug'],
              'additionalProperties': true,
            },
          },
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://api.mealviewer.com',
      'schools': [
        {
          'schoolSlug': 'ElmwoodElementary',
          'label': 'Elmwood Elementary',
          'districtSlug': 'Hopkinton',
          'categoryIds': ['school'],
        },
      ],
      'pastDays': 30,
      'futureDays': 30,
    }),
  ),
  'photo_onedrive': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'OneDrivePhotoProviderConfig',
        description:
            'Microsoft Graph OneDrive (read-only): delta sync of photo paths '
            'into [Photos]; JPEG/PNG/WebP/GIF/HEIC/HEIF; downloads use '
            'pre-auth URL or /items/{id}/content when delta omits downloadUrl; '
            'retention and per-poll download caps. Paths are Graph '
            'root-relative (/Pictures/...), not Windows C:\\ paths.',
        properties: _integrationConfigProperties({
          'globalPerPollLimit': {'type': 'integer', 'minimum': 1},
          'accounts': _kOneDriveMediaAccountsSchema(
            sourceKindEnum: ['photo', 'video', 'both'],
          ),
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://graph.microsoft.com/v1.0',
      'globalPerPollLimit': 50,
      'accounts': [
        {
          'graphAccountKey': 'personal',
          'sources': [
            {
              'path': '/Pictures/Family',
              'kind': 'photo',
              'categoryIds': ['family_media'],
              'maxFiles': 30,
            },
          ],
        },
      ],
    }),
  ),
  'video_onedrive': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'OneDriveVideoProviderConfig',
        description:
            'Microsoft Graph OneDrive (read-only): delta sync of video paths '
            'into [Videos]; MP4/QuickTime; content-endpoint download fallback; '
            'retention and per-poll download caps. Paths are Graph '
            'root-relative (/Videos/...), not Windows C:\\ paths.',
        properties: _integrationConfigProperties({
          'globalPerPollLimit': {'type': 'integer', 'minimum': 1},
          'accounts': _kOneDriveMediaAccountsSchema(
            sourceKindEnum: ['photo', 'video'],
          ),
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://graph.microsoft.com/v1.0',
      'globalPerPollLimit': 50,
      'accounts': [
        {
          'graphAccountKey': 'personal',
          'sources': [
            {
              'path': '/Videos/Clips',
              'kind': 'video',
              'categoryIds': ['home_videos'],
              'maxFiles': 20,
            },
          ],
        },
      ],
    }),
  ),
  'photo_google': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'GooglePhotosPhotoProviderConfig',
        description:
            'Google Photos Picker: operator-selected photos (including shared '
            'albums via search in Google Photos) sync into [Photos].',
        properties: _integrationConfigProperties({
          'globalPerPollLimit': {'type': 'integer', 'minimum': 1},
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
                      'sourceId': {'type': 'string', 'minLength': 1},
                      'albumLabel': {'type': 'string'},
                      'albumSearchHint': {'type': 'string'},
                      'category': _kJsonSchemaOptionalContentCategoryId,
                      'maxFiles': {'type': 'integer', 'minimum': 1},
                      'perPollLimit': {'type': 'integer', 'minimum': 1},
                      'mediaItemIds': {
                        'type': 'array',
                        'items': {'type': 'string', 'minLength': 1},
                      },
                      'pickerSessionId': {'type': 'string'},
                      'lastPickedAtMs': {'type': 'integer'},
                    },
                    'required': ['sourceId', 'category'],
                    'additionalProperties': true,
                  },
                },
              },
              'required': ['googleAccountKey'],
              'additionalProperties': true,
            },
          },
        }),
      ),
    ),
    example: jsonEncode({
      'globalPerPollLimit': 50,
      'accounts': [
        {
          'googleAccountKey': 'family',
          'sources': [
            {
              'sourceId': 'vacation-2025',
              'albumLabel': 'Vacation 2025 (shared)',
              'albumSearchHint': 'Vacation 2025',
              'category': 'family_media',
              'maxFiles': 200,
              'perPollLimit': 10,
              'mediaItemIds': [],
            },
          ],
        },
      ],
    }),
  ),
  'video_google': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'GooglePhotosVideoProviderConfig',
        description:
            'Google Photos Picker: operator-selected videos (including shared '
            'albums via search in Google Photos) sync into [Videos].',
        properties: _integrationConfigProperties({
          'globalPerPollLimit': {'type': 'integer', 'minimum': 1},
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
                      'sourceId': {'type': 'string', 'minLength': 1},
                      'albumLabel': {'type': 'string'},
                      'albumSearchHint': {'type': 'string'},
                      'category': _kJsonSchemaOptionalContentCategoryId,
                      'maxFiles': {'type': 'integer', 'minimum': 1},
                      'perPollLimit': {'type': 'integer', 'minimum': 1},
                      'mediaItemIds': {
                        'type': 'array',
                        'items': {'type': 'string', 'minLength': 1},
                      },
                      'pickerSessionId': {'type': 'string'},
                      'lastPickedAtMs': {'type': 'integer'},
                    },
                    'required': ['sourceId', 'category'],
                    'additionalProperties': true,
                  },
                },
              },
              'required': ['googleAccountKey'],
              'additionalProperties': true,
            },
          },
        }),
      ),
    ),
    example: jsonEncode({
      'globalPerPollLimit': 50,
      'accounts': [
        {
          'googleAccountKey': 'family',
          'sources': [
            {
              'sourceId': 'clips',
              'albumLabel': 'Family clips',
              'albumSearchHint': 'Family videos',
              'category': 'family_media',
              'maxFiles': 50,
              'mediaItemIds': [],
            },
          ],
        },
      ],
    }),
  ),
  'photo_flickr': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'FlickrMediaProviderConfig',
        description:
            'Public Flickr group photo sync. API key comes from environment variable WADDLE_DISPLAY_FLICKR_API_KEY.',
        properties: _integrationConfigProperties({
          'groupIds': {
            'type': 'array',
            'items': {'type': 'string', 'minLength': 1},
          },
          'category': {'type': 'string', 'minLength': 1},
          'perPollLimit': {'type': 'integer', 'minimum': 1},
          'sort': {'type': 'string'},
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://api.flickr.com/services/rest',
      'groupIds': ['34427469792@N01'],
      'category': 'flickr',
      'perPollLimit': 20,
      'sort': 'date-posted-desc',
    }),
  ),
  'photo_bing_image_of_the_day': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'BingImageOfDayProviderConfig',
        description:
            'Bing homepage image of the day. Fetches HPImageArchive JSON then '
            'downloads {baseUrl}{urlbase}_{resolution}.jpg. No API key.',
        properties: _integrationConfigProperties({
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
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://www.bing.com',
      'retentionDays': 1,
      'market': 'en-US',
      'resolution': 'UHD',
      'category': 'bing',
    }),
  ),
  'quote_quoterism': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'QuoterismQuoteProviderConfig',
        description:
            'Quoterism REST API (X-API-Key). Paginates /api/quotes, stores '
            'text and author portraits, and syncs quote categories into '
            'content_categories.',
        properties: _integrationConfigProperties({
          'pageLimit': {'type': 'integer', 'minimum': 1, 'maximum': 100},
          'pagesPerCollect': {'type': 'integer', 'minimum': 1, 'maximum': 5},
          'maxStoredQuotes': {'type': 'integer', 'minimum': 10},
          'retentionDays': {'type': 'integer', 'minimum': 0},
          'fetchAuthorImages': {'type': 'boolean'},
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://www.quoterism.com',
      'pageLimit': 20,
      'pagesPerCollect': 1,
      'maxStoredQuotes': 500,
      'retentionDays': 90,
      'fetchAuthorImages': true,
    }),
  ),
  'photo_nasa_apod': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'NasaApodProviderConfig',
        description:
            'NASA Astronomy Picture of the Day. Requires api.nasa.gov API key.',
        properties: _integrationConfigProperties({
          'retentionDays': {'type': 'integer'},
          'category': {'type': 'string', 'minLength': 1},
          'hd': {'type': 'boolean'},
          'backfillDays': {
            'type': 'integer',
            'minimum': 0,
            'maximum': 7,
          },
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://api.nasa.gov',
      'retentionDays': 30,
      'category': 'nasa_apod',
      'hd': true,
      'backfillDays': 0,
    }),
  ),
  'photo_nasa_mars_rover': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'NasaMarsRoverProviderConfig',
        description:
            'NASA Mars rover photos by earth_date. Categories stored as '
            '{category}_{rover} (default category nasa_mars).',
        properties: _integrationConfigProperties({
          'rovers': {
            'type': 'array',
            'items': {
              'type': 'string',
              'enum': [
                'curiosity',
                'opportunity',
                'spirit',
                'perseverance',
              ],
            },
          },
          'photosPerCollect': {'type': 'integer', 'minimum': 1, 'maximum': 20},
          'maxDaysBack': {'type': 'integer', 'minimum': 1, 'maximum': 30},
          'maxPhotos': {'type': 'integer', 'minimum': 10},
          'retentionDays': {'type': 'integer'},
          'category': {'type': 'string', 'minLength': 1},
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://api.nasa.gov',
      'rovers': ['perseverance', 'curiosity'],
      'photosPerCollect': 5,
      'maxDaysBack': 7,
      'maxPhotos': 200,
      'retentionDays': 90,
      'category': 'nasa_mars',
    }),
  ),
  'photo_nasa_earth_imagery': ProviderConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'NasaEarthImageryProviderConfig',
        description:
            'NASA Landsat Earth imagery for interests_locations with '
            'include_weather (or synthetic default). Two-step assets + imagery API.',
        properties: _integrationConfigProperties({
          'retentionDays': {'type': 'integer'},
          'category': {'type': 'string', 'minLength': 1},
          'lookbackDays': {'type': 'integer', 'minimum': 1, 'maximum': 60},
          'dim': {'type': 'number', 'minimum': 0.05, 'maximum': 0.25},
          'defaultLocation': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
              'lat': {'type': 'number'},
              'lon': {'type': 'number'},
            },
          },
        }),
      ),
    ),
    example: jsonEncode({
      'baseUrl': 'https://api.nasa.gov',
      'retentionDays': 30,
      'category': 'nasa_earth',
      'lookbackDays': 16,
      'dim': 0.15,
      'defaultLocation': {'name': 'Default', 'lat': 40.7128, 'lon': -74.006},
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

/// JSON Schema properties shared by digital/analog clock overlays.
Map<String, Object?> get _kOverlayClockPlacementProperties => {
      'x': {
        'type': 'number',
        'minimum': 0,
        'maximum': 1,
        'x-waddle-widget': 'slider',
        'description': 'Horizontal anchor (0 = left, 1 = right).',
      },
      'y': {
        'type': 'number',
        'minimum': 0,
        'maximum': 1,
        'x-waddle-widget': 'slider',
        'description': 'Vertical anchor (0 = top, 1 = bottom).',
      },
      'scale': {
        'type': 'number',
        'minimum': kStaticImageOverlayScaleMin,
        'maximum': kStaticImageOverlayScaleMax,
        'x-waddle-widget': 'slider',
        'description':
            'Clock width (digital) or dial diameter (analog) as a fraction of '
            'the viewport shortest side.',
      },
      'opacity': {
        'type': 'number',
        'minimum': 0,
        'maximum': 1,
        'x-waddle-widget': 'slider',
        'description': 'Opacity (default 1).',
      },
    };

/// JSON Schema placement properties for calendar overlays.
Map<String, Object?> get _kOverlayCalendarPlacementProperties => {
      'x': {
        'type': 'number',
        'minimum': 0,
        'maximum': 1,
        'x-waddle-widget': 'slider',
        'description': 'Horizontal anchor (0 = left, 1 = right).',
      },
      'y': {
        'type': 'number',
        'minimum': 0,
        'maximum': 1,
        'x-waddle-widget': 'slider',
        'description': 'Vertical anchor (0 = top, 1 = bottom).',
      },
      'scale': {
        'type': 'number',
        'minimum': kStaticImageOverlayScaleMin,
        'maximum': kStaticImageOverlayScaleMax,
        'x-waddle-widget': 'slider',
        'description':
            'Overlay block width as a fraction of the viewport shortest side.',
      },
      'opacity': {
        'type': 'number',
        'minimum': 0,
        'maximum': 1,
        'x-waddle-widget': 'slider',
        'description': 'Opacity (default 1).',
      },
    };

/// Optional [ContentCategories.id] on screen widget config (controller: content-category picker).
Map<String, Object?> _kOneDriveMediaAccountsSchema({
  required List<String> sourceKindEnum,
}) =>
    {
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
                'path': {'type': 'string'},
                'folder': {'type': 'string'},
                'kind': {
                  'type': 'string',
                  'enum': sourceKindEnum,
                },
                'category': {'type': 'string', 'minLength': 1},
                'categoryIds': {
                  'type': 'array',
                  'items': {'type': 'string', 'minLength': 1},
                  'minItems': 1,
                },
                'maxFiles': {'type': 'integer', 'minimum': 1},
                'perPollLimit': {'type': 'integer', 'minimum': 1},
              },
              'required': ['kind'],
              'additionalProperties': true,
            },
          },
        },
        'required': ['graphAccountKey'],
        'additionalProperties': true,
      },
    };

const Map<String, Object?> _kJsonSchemaOptionalContentCategoryId = {
  'type': 'string',
  'minLength': 1,
  'description':
      'Optional content_categories id for filtering or curation scope.',
  'x-waddle-widget': 'content-category',
};

/// Widget `type` values handled by [ScreenRotator].
const List<String> kScreenLayoutWidgetTypes = [
  'static_text',
  'joke',
  'quote',
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
  'home_assistant',
  'data_health',
  'web_page',
  kScreenTypePluginTemplate,
  'general_full_screen',
  'general_2_column',
  'general_3_column',
  'general_2x2',
  'general_3x2',
];

/// [TickerTapes.tickerType] values for curation and seeds.
const List<String> kTickerSlotDefinitionTypes = [
  'time',
  'weather',
  'news',
  'quote',
  'stocks',
  'static_text',
  kTickerTypePlugin,
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
      'config': {'locationId': 'new_york_ny'},
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
          'categoryId': _kJsonSchemaOptionalContentCategoryId,
        },
      ),
    ),
    example: jsonEncode({'categoryId': 'general'}),
  ),
  'quote': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'QuoteScreenConfig',
        description:
            'Optional content_categories id to scope Quoterism quotes for '
            'curation; omit for the full catalog.',
        properties: {
          'categoryId': _kJsonSchemaOptionalContentCategoryId,
        },
      ),
    ),
    example: jsonEncode({'categoryId': 'quoterism_wisdom'}),
  ),
  'trivia': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'TriviaScreenConfig',
        description:
            'Category pool, elimination timing, and wrong-answer strike animation.',
        properties: {
          'categoryId': _kJsonSchemaOptionalContentCategoryId,
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
            'Two-column flex weights, optional category filter, and '
            'upcoming-event time label formatting.',
        properties: {
          'categoryId': {
            ..._kJsonSchemaOptionalContentCategoryId,
            'description':
                'Optional content_categories id; when set, only events with '
                'this category are shown and the category header is displayed.',
          },
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
            ..._kJsonSchemaOptionalContentCategoryId,
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
            ..._kJsonSchemaOptionalContentCategoryId,
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
            ..._kJsonSchemaOptionalContentCategoryId,
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
    example: jsonEncode({'locationId': 'new_york_ny'}),
  ),
  'photo': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'PexelsPhotoScreenConfig',
        description:
            'Optional photos category id; when omitted, any non-suppressed photo may be chosen.',
        properties: {
          'categoryId': _kJsonSchemaOptionalContentCategoryId,
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
            ..._kJsonSchemaOptionalContentCategoryId,
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
            ..._kJsonSchemaOptionalContentCategoryId,
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
  'home_assistant': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'HomeAssistantScreenConfig',
        description:
            'No per-screen options; the slide lists all enabled '
            'interests_home_assistant_entities rows and their latest states.',
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
  kScreenTypePluginTemplate: ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'PluginTemplateScreenConfig',
        description:
            'JSON-driven slide for plugin sidecars (`state_json` or inline title/body/metrics).',
        properties: {
          'title': {'type': 'string'},
          'body': {'type': 'string'},
          'state_json': {'type': 'string'},
          'metrics': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'label': {'type': 'string'},
                'value': {'type': 'string'},
              },
            },
          },
        },
      ),
    ),
    example: jsonEncode({
      'title': 'Plugin status',
      'body': 'All systems nominal',
      'metrics': [
        {'label': 'Motion', 'value': 'off'},
      ],
    }),
  ),
};

ScreenConfigJsonDoc screenConfigJsonDocForType(String screenType) {
  if (isGeneralLayoutScreenType(screenType)) {
    return generalScreenConfigJsonDocForType(screenType);
  }
  return kScreenConfigJsonMeta[screenType] ?? kGenericScreenConfigJsonDoc;
}

/// JSON Schema and example for [TickerTapes] documentation columns
/// (per-tape config_json and optional curator tuning keys).
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
            'interests_locations.include_weather_alerts is enabled. No marquee '
            'line when live data is empty.',
        properties: {},
      ),
    ),
    example: jsonEncode({}),
  ),
  'quote': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'TickerQuoteSlotDoc',
        description:
            'Quoterism quote lines from quoterism_quotes. Optional categoryId '
            'filters via quoterism_quote_categories; omit for random catalog.',
        properties: {
          'categoryId': _kJsonSchemaOptionalContentCategoryId,
        },
      ),
    ),
    example: jsonEncode({'categoryId': 'quoterism_wisdom'}),
  ),
  'news': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'TickerNewsSlotDoc',
        description:
            'RSS headlines from stored articles when available; no line when '
            'the RSS slice is empty. Curator KV keys in config_key_values '
            '(curator.ticker.*) tune scroll width and cadence (string values, '
            'parsed as numbers/bools). Operator UI may also set '
            'display_text_scale_ticker for ticker font scale. Controller '
            'date/time display uses controller.time_format (12h|24h) and '
            'controller.date_order (mdy|dmy|ymd) via GET/PUT /v1/display/settings.',
        properties: {},
      ),
    ),
    example: jsonEncode({}),
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
  'static_text': ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'TickerStaticTextSlotDoc',
        description: 'Fixed headline / body text for the ticker marquee.',
        properties: {
          'text': {'type': 'string'},
        },
        requiredKeys: ['text'],
      ),
    ),
    example: jsonEncode({'text': 'Thanks for visiting'}),
  ),
  kTickerTypePlugin: ScreenConfigJsonDoc(
    schema: jsonEncode(
      _baseSchema(
        title: 'TickerPluginSlotDoc',
        description:
            'Plugin ticker slot: [pluginId] names an installed_plugins row; '
            'optional [fallbackText] when the plugin returns no lines.',
        properties: {
          'pluginId': {
            'type': 'string',
            'description': 'Installed plugin id (installed_plugins.id).',
          },
          'fallbackText': {
            'type': 'string',
            'description':
                'Fallback marquee text when the plugin yields no ticker lines.',
          },
        },
      ),
    ),
    example: jsonEncode({
      'pluginId': 'example_ticker_plugin',
      'fallbackText': 'Plugin ticker unavailable',
    }),
  ),
};

ScreenConfigJsonDoc tickerSlotConfigJsonDocForType(String tickerType) {
  return kTickerSlotConfigJsonMeta[tickerType] ?? kGenericScreenConfigJsonDoc;
}

/// JSON Schema + example for [overlays.config_json] by [overlayType].
ProviderConfigJsonDoc displayOverlayConfigJsonDocForType(String overlayType) {
  final k = overlayType.trim();
  if (k == kOverlayTypeShapeRain || k == kOverlayTypeHeartsRain) {
    return ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'Shape rain',
          description:
              'Falling glyphs tinted from the theme accent palette. Pick which '
              'shapes drift across the screen.',
          properties: {
            'shapes': {
              'type': 'array',
              'items': {
                'type': 'string',
                'enum': ['heart', 'raindrop', 'cat', 'dog', 'mix'],
              },
              'description': 'Glyphs to drift across the screen.',
            },
          },
        ),
      ),
      example: jsonEncode({
        'shapes': ['heart', 'raindrop', 'cat', 'dog'],
      }),
    );
  }
  if (k == kOverlayTypeBirthdayConfetti) {
    return ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'Birthday confetti',
          description:
              'Thin rectangular confetti strips. Optional hex colors, density, '
              'fall speed, and opacity.',
          properties: {
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
              'x-waddle-widget': 'slider',
            },
            'fall_speed': {
              'type': 'number',
              'minimum': 0.02,
              'maximum': 1.8,
              'x-waddle-widget': 'slider',
              'description':
                  'Relative vertical drift speed; lower is slower (about 5s per '
                  'full cycle at 1.0; the minimum 0.02 yields about 250s per cycle).',
            },
            'opacity': {
              'type': 'number',
              'minimum': 0.12,
              'maximum': 0.72,
              'x-waddle-widget': 'slider',
              'description': 'Upper bound for confetti piece alpha (visibility).',
            },
          },
        ),
      ),
      example: jsonEncode({
        'colors': ['#E53935', '#FFEB3B', '#00BCD4', '#E91E63'],
        'density': 0.36,
        'fall_speed': 0.14,
        'opacity': 0.46,
      }),
    );
  }
  if (k == kOverlayTypeFallingImages) {
    return ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'Falling images',
          description:
              'Upload images via the controller (JPEG, PNG, WebP, GIF, or SVG; '
              'stored as overlay blob keys). The display occasionally drops a '
              'random image and rocks it while it falls.',
          properties: {
            'image_blob_keys': {
              'type': 'array',
              'title': 'Images',
              'items': {
                'type': 'string',
                'format': 'waddle-overlay-blob-key',
                'pattern': r'^overlay/[a-z0-9][a-z0-9_/.-]*$',
              },
              'description':
                  'Blob keys returned from POST /v1/display/overlays/blobs.',
            },
            'drop_interval_sec': {
              'type': 'integer',
              'title': 'Drop interval',
              'minimum': kFallingImagesDropIntervalSecMin,
              'maximum': kFallingImagesDropIntervalSecMax,
              'x-waddle-widget': 'slider',
              'description':
                  'Average seconds between image drops (5–180 s; higher = less frequent).',
            },
            'fall_speed': {
              'type': 'number',
              'title': 'Fall speed',
              'minimum': kFallingImagesFallSpeedPxPerSecMin,
              'maximum': kFallingImagesFallSpeedPxPerSecMax,
              'x-waddle-widget': 'slider',
              'description':
                  'Vertical speed in logical pixels per second '
                  '(${kFallingImagesFallSpeedPxPerSecMin.round()}–'
                  '${kFallingImagesFallSpeedPxPerSecMax.round()} px/s).',
            },
            'image_scale': {
              'type': 'number',
              'title': 'Image scale',
              'minimum': kFallingImagesImageScaleMin,
              'maximum': kFallingImagesImageScaleMax,
              'x-waddle-widget': 'slider',
              'description':
                  'Base sprite size as a fraction of the viewport shortest side '
                  '(0.04 = 4%, 0.70 = 70%).',
            },
            'scale_jitter': {
              'type': 'number',
              'title': 'Random size variation',
              'minimum': 0,
              'maximum': kFallingImagesScaleJitterMax,
              'x-waddle-widget': 'slider',
              'description':
                  'Per-sprite random size spread (0 = fixed size; 1.0 = 100% variation).',
            },
          },
        ),
      ),
      example: jsonEncode({
        'image_blob_keys': [
          'overlay/pool/duck_mascot',
          'overlay/pool/duck_headshot_1',
          'overlay/pool/duck_headshot_2',
        ],
        'drop_interval_sec': 45,
        'fall_speed': kFallingImagesFallSpeedPxPerSecDefault,
        'image_scale': 0.12,
        'scale_jitter': 0.33,
      }),
    );
  }
  if (k == kOverlayTypeFloatingBalloons) {
    return ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'Floating balloons',
          description:
              'Vector balloons that rise from the bottom with animated strings. '
              'Colors are chosen at random from the configured palette; each '
              'balloon in a cluster gets a distinct color when possible.',
          properties: {
            'colors': {
              'type': 'array',
              'items': {
                'type': 'string',
                'pattern': r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
              },
              'description': 'Balloon fill colors (#RRGGBB or #RRGGBBAA).',
            },
            'spawn_interval_sec': {
              'type': 'integer',
              'minimum': kFloatingBalloonsSpawnIntervalSecMin,
              'maximum': kFloatingBalloonsSpawnIntervalSecMax,
              'x-waddle-widget': 'slider',
              'description':
                  'Average seconds between balloon spawns (single balloons or clusters).',
            },
            'rise_speed': {
              'type': 'number',
              'minimum': kFloatingBalloonsRiseSpeedPxPerSecMin,
              'maximum': kFloatingBalloonsRiseSpeedPxPerSecMax,
              'x-waddle-widget': 'slider',
              'description': 'Vertical rise speed in logical pixels per second.',
            },
            'max_active': {
              'type': 'integer',
              'minimum': kFloatingBalloonsMaxActiveMin,
              'maximum': kFloatingBalloonsMaxActiveMax,
              'x-waddle-widget': 'slider',
              'description':
                  'Maximum concurrent balloon units on screen (each cluster counts as one).',
            },
            'cluster_chance': {
              'type': 'number',
              'minimum': 0,
              'maximum': 1,
              'x-waddle-widget': 'slider',
              'description':
                  'Probability that a spawn is a multi-balloon cluster instead of one balloon.',
            },
            'balloon_scale': {
              'type': 'number',
              'minimum': kFloatingBalloonsBalloonScaleMin,
              'maximum': kFloatingBalloonsBalloonScaleMax,
              'x-waddle-widget': 'slider',
              'description':
                  'Base balloon size as a fraction of the viewport shortest side.',
            },
            'scale_jitter': {
              'type': 'number',
              'minimum': 0,
              'maximum': kFloatingBalloonsScaleJitterMax,
              'x-waddle-widget': 'slider',
              'description': 'Per-unit random size spread (0 = fixed size).',
            },
            'opacity': {
              'type': 'number',
              'minimum': 0.2,
              'maximum': 1.0,
              'x-waddle-widget': 'slider',
              'description': 'Upper bound for balloon layer alpha.',
            },
          },
        ),
      ),
      example: jsonEncode({
        'colors': kFloatingBalloonsDefaultColorHexes,
        'spawn_interval_sec': 22,
        'rise_speed': 85,
        'max_active': 6,
        'cluster_chance': 0.4,
        'balloon_scale': 0.09,
        'scale_jitter': 0.25,
        'opacity': 0.92,
      }),
    );
  }
  if (k == kOverlayTypeMatrixRain) {
    return ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'Matrix rain',
          description:
              'Falling green character columns in a Matrix-movie style. '
              'Opacity controls how strongly the effect covers underlying slides.',
          properties: {
            'opacity': {
              'type': 'number',
              'minimum': kMatrixRainOpacityMin,
              'maximum': kMatrixRainOpacityMax,
              'x-waddle-widget': 'slider',
              'description':
                  'Upper bound for glyph alpha; lower values keep slides more visible.',
            },
            'fall_speed': {
              'type': 'number',
              'minimum': kMatrixRainFallSpeedMin,
              'maximum': kMatrixRainFallSpeedMax,
              'x-waddle-widget': 'slider',
              'description':
                  'Relative vertical drift speed; lower is slower (about 5s per '
                  'full cycle at 1.0).',
            },
          },
        ),
      ),
      example: jsonEncode({
        'opacity': 0.35,
        'fall_speed': 0.45,
      }),
    );
  }
  if (k == kOverlayTypeStaticImage) {
    return ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'Static image',
          description:
              'Fixed logo or watermark at a viewport position. Assign on a '
              'curator configuration Overlay tab; respects the global overlay '
              'kill-switch.',
          properties: {
            'image_blob_key': {
              'type': 'string',
              'pattern': r'^overlay/[a-z0-9][a-z0-9_/.-]*$',
              'description':
                  'Blob key from POST /v1/display/overlays/blobs upload.',
            },
            'x': {
              'type': 'number',
              'minimum': 0,
              'maximum': 1,
              'x-waddle-widget': 'slider',
              'description': 'Horizontal anchor (0 = left, 1 = right).',
            },
            'y': {
              'type': 'number',
              'minimum': 0,
              'maximum': 1,
              'x-waddle-widget': 'slider',
              'description': 'Vertical anchor (0 = top, 1 = bottom).',
            },
            'scale': {
              'type': 'number',
              'minimum': kStaticImageOverlayScaleMin,
              'maximum': kStaticImageOverlayScaleMax,
              'x-waddle-widget': 'slider',
              'description':
                  'Image width as a fraction of the viewport shortest side.',
            },
            'opacity': {
              'type': 'number',
              'minimum': 0,
              'maximum': 1,
              'x-waddle-widget': 'slider',
              'description': 'Opacity (default 1).',
            },
          },
          requiredKeys: ['image_blob_key'],
        ),
      ),
      example: jsonEncode({
        'image_blob_key': kOverlayBlobKeyDuckMascot,
        'x': kStaticImageOverlayPositionDefault,
        'y': kStaticImageOverlayPositionDefault,
        'scale': kStaticImageOverlayScaleDefault,
      }),
    );
  }
  if (k == kOverlayTypePhotoSlideshow) {
    return ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'Photo slideshow',
          description:
              'Cycles random photos from the catalog at a viewport position. '
              'Optional filters by content category, pixel size, and aspect '
              'ratio. Assign on a curator configuration Overlay tab.',
          properties: {
            'x': {
              'type': 'number',
              'minimum': 0,
              'maximum': 1,
              'x-waddle-widget': 'slider',
              'description': 'Horizontal anchor (0 = left, 1 = right).',
            },
            'y': {
              'type': 'number',
              'minimum': 0,
              'maximum': 1,
              'x-waddle-widget': 'slider',
              'description': 'Vertical anchor (0 = top, 1 = bottom).',
            },
            'scale': {
              'type': 'number',
              'minimum': kStaticImageOverlayScaleMin,
              'maximum': kStaticImageOverlayScaleMax,
              'x-waddle-widget': 'slider',
              'description':
                  'Image width as a fraction of the viewport shortest side.',
            },
            'opacity': {
              'type': 'number',
              'minimum': 0,
              'maximum': 1,
              'x-waddle-widget': 'slider',
              'description': 'Opacity (default 1).',
            },
            'interval_sec': {
              'type': 'integer',
              'minimum': kPhotoSlideshowIntervalSecMin,
              'maximum': kPhotoSlideshowIntervalSecMax,
              'description':
                  'Seconds between random photo picks (default 60).',
            },
            'category_ids': {
              'type': 'array',
              'items': {'type': 'string', 'minLength': 1},
              'description':
                  'Optional content_categories ids; empty = all non-suppressed photos.',
            },
            'aspect_ratio': {
              'type': 'string',
              'enum': kPhotoSlideshowAspectRatioValues,
              'description': 'Optional aspect filter (default any).',
            },
            'min_width': {
              'type': 'integer',
              'minimum': 1,
              'description': 'Minimum pixel width from blob metadata.',
            },
            'max_width': {
              'type': 'integer',
              'minimum': 1,
              'description': 'Maximum pixel width from blob metadata.',
            },
            'min_height': {
              'type': 'integer',
              'minimum': 1,
              'description': 'Minimum pixel height from blob metadata.',
            },
            'max_height': {
              'type': 'integer',
              'minimum': 1,
              'description': 'Maximum pixel height from blob metadata.',
            },
          },
          requiredKeys: ['interval_sec'],
        ),
      ),
      example: jsonEncode({
        'x': kStaticImageOverlayPositionDefault,
        'y': kStaticImageOverlayPositionDefault,
        'scale': kStaticImageOverlayScaleDefault,
        'interval_sec': kPhotoSlideshowIntervalSecDefault,
        'category_ids': ['nature'],
        'aspect_ratio': kPhotoSlideshowAspectLandscape,
      }),
    );
  }
  if (k == kOverlayTypeDigitalClock) {
    return ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'Digital clock overlay',
          description:
              'Digital clock and date at a viewport position. Options match '
              'the digital clock screen; assign on a curator Overlay tab.',
          properties: {
            ..._kOverlayClockPlacementProperties,
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
      example: jsonEncode({
        'x': kStaticImageOverlayPositionDefault,
        'y': kStaticImageOverlayPositionDefault,
        'scale': kClockOverlayScaleDefault,
        'hour24': false,
        'showSeconds': true,
      }),
    );
  }
  if (k == kOverlayTypeAnalogClock) {
    return ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'Analog clock overlay',
          description:
              'Analog clock and date at a viewport position. Options match '
              'the analog clock screen; assign on a curator Overlay tab.',
          properties: {
            ..._kOverlayClockPlacementProperties,
            'dialLabels': _kJsonSchemaAnalogDialLabels,
            'hourHandAccent': _kJsonSchemaAnalogHandAccent,
            'minuteHandAccent': _kJsonSchemaAnalogHandAccent,
            'secondHandAccent': _kJsonSchemaAnalogHandAccent,
          },
        ),
      ),
      example: jsonEncode({
        'x': kStaticImageOverlayPositionDefault,
        'y': kStaticImageOverlayPositionDefault,
        'scale': kClockOverlayScaleDefault,
        'dialLabels': 'roman',
        'hourHandAccent': 'accent1',
        'minuteHandAccent': 2,
        'secondHandAccent': 'accent3',
      }),
    );
  }
  if (k == kOverlayTypeCalendarMonth) {
    return ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'Calendar month overlay',
          description:
              'Compact month grid at a viewport position. Styling matches the '
              'calendar_month screen; assign on a curator Overlay tab.',
          properties: {
            ..._kOverlayCalendarPlacementProperties,
            'categoryId': {
              ..._kJsonSchemaOptionalContentCategoryId,
              'description':
                  'Optional content_categories id; when set, only events with '
                  'this category appear in day markers.',
            },
          },
        ),
      ),
      example: jsonEncode({
        'x': kStaticImageOverlayPositionDefault,
        'y': kStaticImageOverlayPositionDefault,
        'scale': kCalendarMonthOverlayScaleDefault,
      }),
    );
  }
  if (k == kOverlayTypeCalendarUpcoming) {
    return ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'Calendar upcoming overlay',
          description:
              'Upcoming calendar events list at a viewport position. Options '
              'match the calendar_month screen upcoming column.',
          properties: {
            ..._kOverlayCalendarPlacementProperties,
            'categoryId': {
              ..._kJsonSchemaOptionalContentCategoryId,
              'description':
                  'Optional content_categories id; when set, only matching '
                  'events are listed.',
            },
            'upcomingDays': {
              'type': 'integer',
              'minimum': kCalendarUpcomingOverlayDaysMin,
              'maximum': kCalendarUpcomingOverlayDaysMax,
              'description':
                  'Number of days ahead from today to include (default 5).',
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
                  'Time column width in logical px when layout is compact.',
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
        'x': kCalendarUpcomingOverlayPositionXDefault,
        'y': kStaticImageOverlayPositionDefault,
        'scale': kCalendarUpcomingOverlayScaleDefault,
        'upcomingDays': kCalendarUpcomingOverlayDaysDefault,
        'upcomingTime12Hour': true,
        'upcomingTimeNoonLabel': 'Noon',
      }),
    );
  }
  if (k == kOverlayTypeStockQuote) {
    return ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'Stock quote overlay',
          description:
              'Single stock quote tile at a viewport position. Matches the '
              'stock quotes screen tile; requires stock_finnhub collect and an '
              'interests_stock_symbols row for symbolId.',
          properties: {
            ..._kOverlayClockPlacementProperties,
            'symbolId': {
              'type': 'string',
              'minLength': 1,
              'description':
                  'interests_stock_symbols.id for the symbol to display.',
            },
          },
          requiredKeys: ['symbolId'],
        ),
      ),
      example: jsonEncode({
        'symbolId': 'aapl',
        'x': kStaticImageOverlayPositionDefault,
        'y': kStaticImageOverlayPositionDefault,
        'scale': kClockOverlayScaleDefault,
      }),
    );
  }
  if (k == kOverlayTypeQrCode) {
    return ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'QR code overlay',
          description:
              'QR code with optional title above and description below at a '
              'viewport position. Use template to build common URI payloads '
              '(http, tel, mailto, wifi, geo, vcard, vcalendar, sms) or '
              'custom raw data.',
          properties: {
            ..._kOverlayClockPlacementProperties,
            'template': {
              'type': 'string',
              'enum': kQrOverlayTemplateValues,
              'description': 'Payload builder template (default custom).',
            },
            'template_fields': {
              'type': 'object',
              'description':
                  'Template inputs. http: url. mailto: email, subject, body. '
                  'tel/sms: phone, body (sms). geo: lat, lng, label. wifi: '
                  'ssid, securityType, password, hidden. vcard: fullName or '
                  'firstName/lastName, org, phone, email, title. vcalendar: '
                  'summary, dtStart, dtEnd, location, description. custom: '
                  'payload.',
              'additionalProperties': true,
            },
            'payload': {
              'type': 'string',
              'minLength': 1,
              'description':
                  'Encoded QR data (computed from template on save; editable '
                  'for custom).',
            },
            'title': {
              'type': 'string',
              'description': 'Optional short label above the QR code.',
            },
            'description': {
              'type': 'string',
              'description': 'Optional caption below the QR code.',
            },
          },
          requiredKeys: ['payload', 'template'],
        ),
      ),
      example: jsonEncode({
        'template': kQrOverlayTemplateWifi,
        'template_fields': {
          'ssid': 'GuestWiFi',
          'securityType': 'WPA',
          'password': 'welcome',
          'hidden': false,
        },
        'payload': 'WIFI:T:WPA;S:GuestWiFi;P:welcome;',
        'title': 'Guest Wi‑Fi',
        'description': 'Scan to connect',
        'x': kQrOverlayPositionXDefault,
        'y': kQrOverlayPositionYDefault,
        'scale': kQrOverlayScaleDefault,
      }),
    );
  }
  if (k == kOverlayTypeCloudDrift) {
    return ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'Cloud drift',
          description:
              'Procedural clouds that drift from right to left across the '
              'viewport. Adjust morphology, scatter, density, transparency, '
              'and tint.',
          properties: {
            'cloud_type': {
              'type': 'string',
              'enum': kCloudDriftCloudTypes,
              'description':
                  'Cloud silhouette style (default cirrostratus: thin high sheets).',
            },
            'scatter': {
              'type': 'number',
              'minimum': kCloudDriftScatterMin,
              'maximum': kCloudDriftScatterMax,
              'x-waddle-widget': 'slider',
              'description':
                  'Vertical and size spread (higher = more varied positions).',
            },
            'density': {
              'type': 'number',
              'minimum': kCloudDriftDensityMin,
              'maximum': kCloudDriftDensityMax,
              'x-waddle-widget': 'slider',
              'description': 'How many clouds are active on screen.',
            },
            'opacity': {
              'type': 'number',
              'minimum': kCloudDriftOpacityMin,
              'maximum': kCloudDriftOpacityMax,
              'x-waddle-widget': 'slider',
              'description':
                  'Layer transparency (higher = more visible over slides).',
            },
            'color': {
              'type': 'string',
              'pattern': r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
              'description': 'Cloud tint as a hex color.',
            },
          },
        ),
      ),
      example: jsonEncode({
        'cloud_type': kCloudDriftDefaultCloudType,
        'scatter': 0.45,
        'density': 0.35,
        'opacity': 0.42,
        'color': kCloudDriftDefaultColorHex,
      }),
    );
  }
  if (k == kOverlayTypeEdgeGlow) {
    return ProviderConfigJsonDoc(
      schema: jsonEncode(
        _baseSchema(
          title: 'Edge glow',
          description:
              'Pulsing colored glow along the screen edges. Useful for alarms '
              'when assigned on an active curator.',
          properties: {
            'color': {
              'type': 'string',
              'pattern': r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
              'description': 'Glow tint as a hex color.',
            },
            'intensity': {
              'type': 'number',
              'minimum': kEdgeGlowIntensityMin,
              'maximum': kEdgeGlowIntensityMax,
              'x-waddle-widget': 'slider',
              'description':
                  'Peak edge glow brightness; higher values are more visible.',
            },
            'pulse_speed': {
              'type': 'number',
              'minimum': kEdgeGlowPulseSpeedMin,
              'maximum': kEdgeGlowPulseSpeedMax,
              'x-waddle-widget': 'slider',
              'description':
                  'Relative fade in/out speed; higher is faster (about 3s per '
                  'full pulse at 1.0).',
            },
          },
        ),
      ),
      example: jsonEncode({
        'color': kEdgeGlowDefaultColorHex,
        'intensity': 0.65,
        'pulse_speed': 1.0,
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
              'x-waddle-widget': 'slider',
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
              'x-waddle-widget': 'slider',
            },
            'shadow': {'type': 'boolean'},
            'speed': {
              'type': 'number',
              'minimum': 0.25,
              'maximum': 2.5,
              'x-waddle-widget': 'slider',
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

