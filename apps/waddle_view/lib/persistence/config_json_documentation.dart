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
        description: 'OpenAI trivia generation limits and prompts.',
        properties: {
          'questionsPerDay': {'type': 'integer', 'minimum': 0},
          'model': {'type': 'string'},
          'globalPrompt': {'type': 'string'},
          'systemPrompt': {'type': 'string'},
          'temperature': {'type': 'number'},
          'maxOutputTokens': {'type': 'integer', 'minimum': 1},
          'maxQuestionsPerTwoHours': {'type': 'integer', 'minimum': 1},
          'twoHourWindowMs': {'type': 'integer', 'minimum': 1},
          'questionRetentionDays': {'type': 'integer'},
        },
      ),
    ),
    example: jsonEncode({
      'questionsPerDay': 3,
      'maxQuestionsPerTwoHours': 20,
      'twoHourWindowMs': 7200000,
      'questionRetentionDays': 14,
      'model': 'gpt-4o-mini',
      'globalPrompt':
          'You write clear, family-friendly multiple-choice trivia.',
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
                      'calendars': {
                        'type': 'array',
                        'items': {'type': 'string'},
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
};

ProviderConfigJsonDoc providerConfigJsonDocForType(String providerType) {
  return kProviderConfigJsonMeta[providerType] ??
      kGenericProviderConfigJsonDoc;
}

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
  'pexels_video',
];

/// JSON Schema for [ScreenDefinitions.layoutJson] (see [parseScreenLayoutWidgets]).
final String kScreenLayoutJsonSchema = jsonEncode({
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

/// Example layout aligned with seed weather screen.
final String kExampleScreenLayoutJson = jsonEncode({
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
