import 'dart:convert';

import 'config_json_documentation.dart';

/// Widget `type` values used inside [general_*] screen slots (not standalone screens).
const List<String> kKvWidgetTypes = [
  'kv_list',
  'kv_table',
  'kv_chart',
  'kv_graph',
  'kv_gauge',
  'kv_image',
  'kv_shape',
];

/// JSON Schema and example for a KV-bound slide widget `config` object.
class KvWidgetConfigJsonDoc {
  const KvWidgetConfigJsonDoc({
    required this.schema,
    required this.example,
    required this.expectedValueType,
  });

  final String schema;
  final String example;
  final String expectedValueType;
}

/// Canonical JSON shape for data at [IntegrationsKeyValue] (after optional jsonPath).
class KvValueDataTypeDoc {
  const KvValueDataTypeDoc({
    required this.id,
    required this.description,
    required this.schema,
    required this.example,
  });

  final String id;
  final String description;
  final String schema;
  final String example;
}

const String _kKvSchemaDraft = 'https://json-schema.org/draft/2020-12/schema';

Map<String, Object?> _kvBaseWidgetProperties({
  required String expectedValueType,
  Map<String, Object?> extra = const {},
}) =>
    {
      'integrationId': {
        'type': 'string',
        'minLength': 1,
        'description': 'Integrations.id (e.g. default_general_openai).',
      },
      'valueKey': {
        'type': 'string',
        'minLength': 1,
        'description':
            'IntegrationsKeyValue.key (e.g. prompt.daily_summary.latest).',
      },
      'jsonPath': {
        'type': 'string',
        'description': 'Optional JSONPath into the KV value (e.g. \$.items).',
      },
      'title': {'type': 'string'},
      'emptyText': {'type': 'string'},
      'x-waddle-value-type': expectedValueType,
      ...extra,
    };

Map<String, Object?> _kvWidgetSchema({
  required String title,
  required String description,
  required String expectedValueType,
  Map<String, Object?> extra = const {},
  List<String> required = const ['integrationId', 'valueKey'],
}) =>
    {
      r'$schema': _kKvSchemaDraft,
      'title': title,
      'description': description,
      'type': 'object',
      'properties': _kvBaseWidgetProperties(
        expectedValueType: expectedValueType,
        extra: extra,
      ),
      'required': required,
      'additionalProperties': true,
    };

final Map<String, KvWidgetConfigJsonDoc> kKvWidgetConfigJsonMeta = {
  'kv_list': KvWidgetConfigJsonDoc(
    expectedValueType: 'list_string_array',
    schema: jsonEncode(
      _kvWidgetSchema(
        title: 'KvListWidgetConfig',
        description: 'Bulleted list from a string array or newline text.',
        expectedValueType: 'list_string_array',
        extra: {
          'maxItems': {'type': 'integer', 'minimum': 1},
          'ordered': {'type': 'boolean'},
        },
      ),
    ),
    example: jsonEncode({
      'integrationId': 'default_general_openai',
      'valueKey': 'prompt.daily_summary.latest',
      'jsonPath': r'$.items',
      'maxItems': 20,
    }),
  ),
  'kv_table': KvWidgetConfigJsonDoc(
    expectedValueType: 'table_rows',
    schema: jsonEncode(
      _kvWidgetSchema(
        title: 'KvTableWidgetConfig',
        description: 'Table from an array of row objects.',
        expectedValueType: 'table_rows',
        extra: {
          'columns': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'field': {'type': 'string'},
                'label': {'type': 'string'},
              },
              'required': ['field'],
            },
          },
          'maxRows': {'type': 'integer', 'minimum': 1},
        },
      ),
    ),
    example: jsonEncode({
      'integrationId': 'default_general_openai',
      'valueKey': 'prompt.metrics.latest',
      'jsonPath': r'$.rows',
      'columns': [
        {'field': 'name', 'label': 'Name'},
        {'field': 'value', 'label': 'Value'},
      ],
    }),
  ),
  'kv_chart': KvWidgetConfigJsonDoc(
    expectedValueType: 'chart_series',
    schema: jsonEncode(
      _kvWidgetSchema(
        title: 'KvChartWidgetConfig',
        description: 'Line or bar chart from series points.',
        expectedValueType: 'chart_series',
        extra: {
          'chartKind': {'type': 'string', 'enum': ['line', 'bar']},
          'xField': {'type': 'string'},
          'yField': {'type': 'string'},
        },
      ),
    ),
    example: jsonEncode({
      'integrationId': 'default_general_openai',
      'valueKey': 'prompt.trend.latest',
      'jsonPath': r'$.series',
      'chartKind': 'line',
      'xField': 'x',
      'yField': 'y',
    }),
  ),
  'kv_graph': KvWidgetConfigJsonDoc(
    expectedValueType: 'graph_adjacency',
    schema: jsonEncode(
      _kvWidgetSchema(
        title: 'KvGraphWidgetConfig',
        description: 'Node/edge graph visualization.',
        expectedValueType: 'graph_adjacency',
        extra: {
          'nodesPath': {'type': 'string'},
          'edgesPath': {'type': 'string'},
        },
      ),
    ),
    example: jsonEncode({
      'integrationId': 'default_general_openai',
      'valueKey': 'prompt.network.latest',
      'nodesPath': r'$.nodes',
      'edgesPath': r'$.edges',
    }),
  ),
  'kv_gauge': KvWidgetConfigJsonDoc(
    expectedValueType: 'gauge_scalar',
    schema: jsonEncode(
      _kvWidgetSchema(
        title: 'KvGaugeWidgetConfig',
        description: 'Radial gauge for a numeric value.',
        expectedValueType: 'gauge_scalar',
        extra: {
          'valuePath': {'type': 'string'},
          'min': {'type': 'number'},
          'max': {'type': 'number'},
          'unit': {'type': 'string'},
        },
      ),
    ),
    example: jsonEncode({
      'integrationId': 'default_general_openai',
      'valueKey': 'prompt.score.latest',
      'valuePath': r'$.value',
      'min': 0,
      'max': 100,
      'unit': '%',
    }),
  ),
  'kv_image': KvWidgetConfigJsonDoc(
    expectedValueType: 'image_url',
    schema: jsonEncode(
      _kvWidgetSchema(
        title: 'KvImageWidgetConfig',
        description: 'Image from a URL in the KV JSON.',
        expectedValueType: 'image_url',
        extra: {
          'urlPath': {'type': 'string'},
        },
      ),
    ),
    example: jsonEncode({
      'integrationId': 'default_general_openai',
      'valueKey': 'prompt.hero.latest',
      'urlPath': r'$.url',
    }),
  ),
  'kv_shape': KvWidgetConfigJsonDoc(
    expectedValueType: 'shape_style',
    schema: jsonEncode(
      _kvWidgetSchema(
        title: 'KvShapeWidgetConfig',
        description: 'Decorative shape (rectangle, circle, line).',
        expectedValueType: 'shape_style',
        extra: {
          'shape': {'type': 'string', 'enum': ['rectangle', 'circle', 'line']},
          'color': {'type': 'string'},
          'width': {'type': 'number'},
          'height': {'type': 'number'},
        },
      ),
    ),
    example: jsonEncode({
      'integrationId': 'default_general_openai',
      'valueKey': 'prompt.accent.latest',
      'shape': 'rectangle',
      'color': '#3366cc',
    }),
  ),
};

final Map<String, KvValueDataTypeDoc> kKvValueDataTypeMeta = {
  'text_plain': KvValueDataTypeDoc(
    id: 'text_plain',
    description: 'Plain text or {items: string[]} for lists.',
    schema: jsonEncode({
      r'$schema': _kKvSchemaDraft,
      'oneOf': [
        {'type': 'string'},
        {
          'type': 'object',
          'properties': {
            'items': {'type': 'array', 'items': {'type': 'string'}},
          },
        },
      ],
    }),
    example: jsonEncode({'items': ['Alpha', 'Beta']}),
  ),
  'list_string_array': KvValueDataTypeDoc(
    id: 'list_string_array',
    description: 'JSON array of strings.',
    schema: jsonEncode({
      r'$schema': _kKvSchemaDraft,
      'type': 'array',
      'items': {'type': 'string'},
    }),
    example: jsonEncode(['Task one', 'Task two']),
  ),
  'table_rows': KvValueDataTypeDoc(
    id: 'table_rows',
    description: 'Array of row objects with consistent keys.',
    schema: jsonEncode({
      r'$schema': _kKvSchemaDraft,
      'type': 'array',
      'items': {'type': 'object', 'additionalProperties': true},
    }),
    example: jsonEncode([
      {'name': 'CPU', 'value': 42},
      {'name': 'RAM', 'value': 68},
    ]),
  ),
  'chart_series': KvValueDataTypeDoc(
    id: 'chart_series',
    description: 'Points with x/y fields or {series: [...]}.',
    schema: jsonEncode({
      r'$schema': _kKvSchemaDraft,
      'oneOf': [
        {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'x': {},
              'y': {'type': 'number'},
            },
            'required': ['x', 'y'],
          },
        },
        {
          'type': 'object',
          'properties': {
            'series': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'x': {},
                  'y': {'type': 'number'},
                },
              },
            },
          },
        },
      ],
    }),
    example: jsonEncode([
      {'x': 'Mon', 'y': 12},
      {'x': 'Tue', 'y': 18},
    ]),
  ),
  'gauge_scalar': KvValueDataTypeDoc(
    id: 'gauge_scalar',
    description: 'Numeric gauge value or {value, max}.',
    schema: jsonEncode({
      r'$schema': _kKvSchemaDraft,
      'oneOf': [
        {'type': 'number'},
        {
          'type': 'object',
          'properties': {
            'value': {'type': 'number'},
            'max': {'type': 'number'},
          },
          'required': ['value'],
        },
      ],
    }),
    example: jsonEncode({'value': 72, 'max': 100}),
  ),
  'graph_adjacency': KvValueDataTypeDoc(
    id: 'graph_adjacency',
    description: 'Nodes and edges arrays.',
    schema: jsonEncode({
      r'$schema': _kKvSchemaDraft,
      'type': 'object',
      'properties': {
        'nodes': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'id': {'type': 'string'},
              'label': {'type': 'string'},
            },
          },
        },
        'edges': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'from': {'type': 'string'},
              'to': {'type': 'string'},
            },
          },
        },
      },
      'required': ['nodes', 'edges'],
    }),
    example: jsonEncode({
      'nodes': [
        {'id': 'a', 'label': 'A'},
        {'id': 'b', 'label': 'B'},
      ],
      'edges': [
        {'from': 'a', 'to': 'b'},
      ],
    }),
  ),
  'image_url': KvValueDataTypeDoc(
    id: 'image_url',
    description: 'HTTPS image URL string or {url}.',
    schema: jsonEncode({
      r'$schema': _kKvSchemaDraft,
      'oneOf': [
        {'type': 'string', 'format': 'uri'},
        {
          'type': 'object',
          'properties': {'url': {'type': 'string', 'format': 'uri'}},
          'required': ['url'],
        },
      ],
    }),
    example: jsonEncode({'url': 'https://example.com/image.png'}),
  ),
  'shape_style': KvValueDataTypeDoc(
    id: 'shape_style',
    description: 'Shape name and color for kv_shape.',
    schema: jsonEncode({
      r'$schema': _kKvSchemaDraft,
      'type': 'object',
      'properties': {
        'shape': {'type': 'string'},
        'color': {'type': 'string'},
      },
    }),
    example: jsonEncode({'shape': 'circle', 'color': '#ff6600'}),
  ),
};

KvWidgetConfigJsonDoc kvWidgetConfigJsonDocForType(String widgetType) =>
    kKvWidgetConfigJsonMeta[widgetType] ??
    KvWidgetConfigJsonDoc(
      expectedValueType: 'text_plain',
      schema: jsonEncode(_kvWidgetSchema(
        title: 'KvWidgetConfig',
        description: 'Unknown KV widget type.',
        expectedValueType: 'text_plain',
      )),
      example: '{}',
    );

KvValueDataTypeDoc? kvValueDataTypeDocForId(String id) =>
    kKvValueDataTypeMeta[id.trim()];

/// Slot ids allowed per [general_*] screen type.
List<String> generalLayoutSlotIdsForScreenType(String screenType) {
  switch (screenType) {
    case 'general_full_screen':
      return const ['main'];
    case 'general_2_column':
      return const ['left', 'right'];
    case 'general_3_column':
      return const ['left', 'center', 'right'];
    case 'general_2x2':
      return const ['a1', 'a2', 'b1', 'b2'];
    case 'general_3x2':
      return const ['a1', 'a2', 'a3', 'b1', 'b2', 'b3'];
    default:
      return const [];
  }
}

Map<String, Object?> _generalScreenSlotSchema(String screenType) {
  final slots = generalLayoutSlotIdsForScreenType(screenType);
  return {
    'type': 'array',
    'items': {
      'type': 'object',
      'properties': {
        'slot': {'type': 'string', 'enum': slots},
        'widget': {
          'type': 'object',
          'properties': {
            'type': {'type': 'string', 'enum': kKvWidgetTypes},
            'config': {'type': 'object', 'additionalProperties': true},
          },
          'required': ['type', 'config'],
        },
      },
      'required': ['slot', 'widget'],
    },
  };
}

/// Adds [general_*] screen docs to [kScreenConfigJsonMeta] entries.
ScreenConfigJsonDoc generalScreenConfigJsonDocForType(String screenType) {
  final slots = generalLayoutSlotIdsForScreenType(screenType);
  return ScreenConfigJsonDoc(
    schema: jsonEncode({
      r'$schema': _kKvSchemaDraft,
      'title': '${screenType}ScreenConfig',
      'description':
          'Multi-slot layout. Each slot hosts a kv_* widget bound to integration KV.',
      'type': 'object',
      'properties': {
        'slots': _generalScreenSlotSchema(screenType),
      },
      'required': ['slots'],
    }),
    example: jsonEncode({
      'slots': [
        if (slots.isNotEmpty)
          {
            'slot': slots.first,
            'widget': {
              'type': 'kv_list',
              'config': jsonDecode(
                kKvWidgetConfigJsonMeta['kv_list']!.example,
              ),
            },
          },
      ],
    }),
  );
}

bool isGeneralLayoutScreenType(String screenType) =>
    screenType.startsWith('general_');
