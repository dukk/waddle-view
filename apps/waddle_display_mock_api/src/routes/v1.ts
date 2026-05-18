import { Hono } from 'hono';
import type { Scenario } from '../lib/scenario.js';
import { wantsEmpty, wantsError } from '../lib/scenario.js';

const mockConfigKv = new Map<string, string>([['display.timezone', 'America/New_York']]);

function maybeErr(c: { json: (a: unknown, s: number) => Response }, scenario: Scenario) {
  if (wantsError(scenario)) {
    return c.json({ error: 'mock_error' }, 500);
  }
  return null;
}

export function v1Router() {
  const r = new Hono<{ Variables: { scenario: Scenario } }>();

  r.get('/health', (c) =>
    c.json({
      status: 'ok',
      app: 'waddle_display_mock_api',
      version: '0.0.0',
      build: 'mock',
      schema_version: 48,
      platform_os: 'linux',
      platform_os_version: 'mock',
      hostname: 'mock-display',
      cpu_count: 1,
      uptime_seconds: Math.floor(process.uptime()),
    }),
  );

  r.get('/telemetry/integrations', (c) => {
    const scenario = c.get('scenario');
    const bad = maybeErr(c, scenario);
    if (bad) return bad;
    if (wantsEmpty(scenario)) return c.json({ items: [] });
    return c.json({
      items: [
        { at_ms: Date.now(), channel: 'integration', message: 'mock: collector idle' },
        { at_ms: Date.now() - 1000, channel: 'engine', message: 'mock: tick' },
      ],
    });
  });

  r.get('/telemetry/programs', (c) => {
    const scenario = c.get('scenario');
    const bad = maybeErr(c, scenario);
    if (bad) return bad;
    if (wantsEmpty(scenario)) return c.json({ items: [] });
    return c.json({
      items: [
        {
          at_ms: Date.now(),
          reason: 'mock_program',
          slides: [
            {
              screen_id: 'mock_screen',
              screen_type: 'static_text',
              dwell_ms: 8000,
              layout_json: '{"widgets":[]}',
              random_choices: {},
            },
          ],
        },
      ],
    });
  });

  r.get('/telemetry/ticker-programs', (c) => {
    const scenario = c.get('scenario');
    const bad = maybeErr(c, scenario);
    if (bad) return bad;
    if (wantsEmpty(scenario)) return c.json({ items: [] });
    return c.json({
      items: [
        {
          at_ms: Date.now(),
          items: [{ kind: 'time', body: '12:00', source_id: null }],
        },
      ],
    });
  });

  r.post('/display/navigation', (c) => {
    const scenario = c.get('scenario');
    const bad = maybeErr(c, scenario);
    if (bad) return bad;
    return c.json({});
  });

  r.get('/meta/screen-types', (c) => {
    const scenario = c.get('scenario');
    if (wantsEmpty(scenario)) return c.json({ items: [] });
    return c.json({
      items: [
        {
          screen_type: 'static_text',
          config_json_schema: {
            type: 'object',
            properties: { text: { type: 'string' } },
            required: ['text'],
          },
          example_config_json: { text: 'Hello from mock API' },
        },
      ],
    });
  });

  r.get('/meta/ticker-types', (c) => {
    const scenario = c.get('scenario');
    if (wantsEmpty(scenario)) return c.json({ items: [] });
    return c.json({
      items: [
        {
          ticker_type: 'time',
          config_json_schema: { type: 'object' },
          example_config_json: {},
        },
      ],
    });
  });

  r.get('/ticker/tapes', (c) => {
    const scenario = c.get('scenario');
    if (wantsEmpty(scenario)) return c.json({ items: [] });
    return c.json({
      items: [
        {
          id: 'mock_time',
          name: 'Clock',
          description: '',
          enabled: true,
          ticker_type: 'time',
          frequency_weight: 100,
          sort_order: 0,
          config_key: null,
          config_json_schema: null,
          example_config_json: null,
        },
      ],
    });
  });

  r.post('/ticker/tapes', (c) => c.json({}));

  r.patch('/ticker/tapes/:id', (c) => c.json({}));

  r.delete('/ticker/tapes/:id', (c) => c.json({}));

  r.get('/ticker/items', (c) => {
    const scenario = c.get('scenario');
    if (wantsEmpty(scenario)) return c.json({ items: [] });
    return c.json({
      items: [{ ordinal: 0, kind: 'time', body: 'mock ticker' }],
    });
  });

  r.get('/display/settings', (c) => {
    const scenario = c.get('scenario');
    const bad = maybeErr(c, scenario);
    if (bad) return bad;
    const display_timezone = mockConfigKv.get('display.timezone') ?? 'America/New_York';
    const controller_time_format = mockConfigKv.get('controller.time_format') ?? '12h';
    const controller_date_order = mockConfigKv.get('controller.date_order') ?? 'mdy';
    return c.json({
      display_theme_id: mockConfigKv.get('display.theme.id') ?? 'navy_coral',
      display_text_scale_screen: mockConfigKv.get('display.text_scale.screen') ?? 'normal',
      display_text_scale_ticker: mockConfigKv.get('display.text_scale.ticker') ?? 'normal',
      display_timezone,
      controller_time_format,
      controller_date_order,
      adoption_allowed_roles: ['viewer', 'power_viewer', 'operator', 'admin'],
      adoption_allow_new_requests: true,
    });
  });

  r.put('/display/settings', async (c) => {
    const scenario = c.get('scenario');
    const bad = maybeErr(c, scenario);
    if (bad) return bad;
    try {
      const body = (await c.req.json()) as Record<string, unknown>;
      if (typeof body.display_timezone === 'string') {
        const t = body.display_timezone.trim();
        if (t) mockConfigKv.set('display.timezone', t);
        else mockConfigKv.delete('display.timezone');
      }
      if (typeof body.display_theme_id === 'string') {
        mockConfigKv.set('display.theme.id', body.display_theme_id);
      }
      if (typeof body.display_text_scale_screen === 'string') {
        mockConfigKv.set('display.text_scale.screen', body.display_text_scale_screen);
      }
      if (typeof body.display_text_scale_ticker === 'string') {
        mockConfigKv.set('display.text_scale.ticker', body.display_text_scale_ticker);
      }
      if (typeof body.controller_time_format === 'string') {
        mockConfigKv.set('controller.time_format', body.controller_time_format);
      }
      if (typeof body.controller_date_order === 'string') {
        mockConfigKv.set('controller.date_order', body.controller_date_order);
      }
    } catch {
      /* ignore malformed body */
    }
    return c.json({});
  });

  r.get('/config/key-values', (c) => {
    const scenario = c.get('scenario');
    const bad = maybeErr(c, scenario);
    if (bad) return bad;
    if (wantsEmpty(scenario)) return c.json({ items: [] });
    const items = [...mockConfigKv.entries()]
      .map(([key, value]) => ({ key, value }))
      .sort((a, b) => a.key.localeCompare(b.key));
    return c.json({ items });
  });

  r.put('/config/key-values', async (c) => {
    const scenario = c.get('scenario');
    const bad = maybeErr(c, scenario);
    if (bad) return bad;
    let body: Record<string, unknown>;
    try {
      body = (await c.req.json()) as Record<string, unknown>;
    } catch {
      return c.json({ error: 'invalid_json' }, 400);
    }
    const key = typeof body.key === 'string' ? body.key.trim() : '';
    if (!key) return c.json({ error: 'key_required' }, 400);
    const value = body.value == null ? '' : String(body.value);
    mockConfigKv.set(key, value);
    return c.json({});
  });

  r.delete('/config/key-values', (c) => {
    const scenario = c.get('scenario');
    const bad = maybeErr(c, scenario);
    if (bad) return bad;
    const key = c.req.query('key')?.trim() ?? '';
    if (!key) return c.json({ error: 'key_required' }, 400);
    if (!mockConfigKv.has(key)) return c.json({ error: 'not_found' }, 404);
    mockConfigKv.delete(key);
    return c.json({});
  });

  r.get('/integrations', (c) => {
    const scenario = c.get('scenario');
    if (wantsEmpty(scenario)) return c.json({ items: [] });
    return c.json({
      items: [
        {
          id: 'mock_integration',
          integration_type: 'mock',
          enabled: true,
          poll_seconds: 60,
          config_json: {
            note: 'mock',
            baseUrl: 'https://example.invalid',
          },
          config_json_schema: { type: 'object' },
        },
      ],
    });
  });

  r.patch('/integrations/:id', (c) => c.json({}));

  r.get('/screens', (c) => {
    const scenario = c.get('scenario');
    if (wantsEmpty(scenario)) return c.json({ items: [] });
    return c.json({
      items: [
        {
          id: 'mock_screen',
          name: 'Mock slide',
          description: '',
          enabled: true,
          screen_type: 'static_text',
          config_json: JSON.stringify({ text: 'Mock' }),
          config_json_schema: JSON.stringify({ type: 'object' }),
          example_config_json: JSON.stringify({ text: 'Example' }),
          dwell_seconds: 10,
          frequency_weight: 100,
          min_gap_between_shows_seconds: 0,
          min_placements_per_program: 0,
          max_placements_per_program: null,
          data_key: '',
          data_key_min_placements_per_program: null,
          data_key_max_placements_per_program: null,
        },
      ],
    });
  });

  r.post('/screens', (c) => {
    const scenario = c.get('scenario');
    if (wantsError(scenario)) return c.json({ error: 'mock_post_failed' }, 400);
    return c.json({});
  });

  r.patch('/screens/:id', (c) => c.json({}));

  r.delete('/screens/:id', (c) => {
    const scenario = c.get('scenario');
    if (c.req.param('id') === 'missing') {
      return c.json({ error: 'not_found' }, 404);
    }
    if (wantsError(scenario)) return c.json({ error: 'not_found' }, 404);
    return c.json({});
  });

  r.get('/display/overlays', (c) => {
    const scenario = c.get('scenario');
    if (wantsEmpty(scenario)) return c.json({ items: [] });
    return c.json({
      items: [
        {
          id: 'mock_overlay',
          overlay_type: 'hearts_rain',
          name: 'Mock hearts',
          config_json: { messages: ['Hi'] },
          config_json_schema: {},
          example_config_json: { messages: ['Hi'] },
        },
      ],
    });
  });

  r.get('/meta/overlay-types', (c) =>
    c.json({
      items: [
        {
          overlay_type: 'hearts_rain',
          config_json_schema: {
            type: 'object',
            properties: {
              messages: { type: 'array', items: { type: 'string' } },
            },
          },
          example_config_json: { messages: ['Hello'] },
        },
        {
          overlay_type: 'birthday_confetti',
          config_json_schema: { type: 'object', additionalProperties: true },
          example_config_json: {
            shapes: ['rect', 'circle', 'mix'],
            density: 0.36,
            fall_speed: 0.14,
            opacity: 0.46,
          },
        },
        {
          overlay_type: 'bouncing_message',
          config_json_schema: { type: 'object', additionalProperties: true },
          example_config_json: { messages: ['Happy Birthday Waddle!!'] },
        },
        {
          overlay_type: 'falling_images',
          config_json_schema: {
            type: 'object',
            properties: {
              image_blob_keys: {
                type: 'array',
                items: { type: 'string', format: 'waddle-overlay-blob-key' },
              },
            },
          },
          example_config_json: { image_blob_keys: [], drop_interval_sec: 45, fall_speed: 0.12 },
        },
      ],
    }),
  );

  r.get('/alerts', (c) => c.json({ items: [] }));

  return r;
}
