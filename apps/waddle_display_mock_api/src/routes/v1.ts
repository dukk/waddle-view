import { Hono } from 'hono';
import type { Scenario } from '../lib/scenario.js';
import { wantsEmpty, wantsError } from '../lib/scenario.js';

function maybeErr(c: { json: (a: unknown, s: number) => Response }, scenario: Scenario) {
  if (wantsError(scenario)) {
    return c.json({ error: 'mock_error' }, 500);
  }
  return null;
}

export function v1Router() {
  const r = new Hono<{ Variables: { scenario: Scenario } }>();

  r.get('/health', (c) => c.json({ status: 'ok' }));

  r.get('/telemetry/providers', (c) => {
    const scenario = c.get('scenario');
    const bad = maybeErr(c, scenario);
    if (bad) return bad;
    if (wantsEmpty(scenario)) return c.json({ items: [] });
    return c.json({
      items: [
        { at_ms: Date.now(), channel: 'provider', message: 'mock: collector idle' },
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

  r.get('/ticker/definitions', (c) => {
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

  r.patch('/ticker/definitions/:id', (c) => c.json({}));

  r.get('/ticker/items', (c) => {
    const scenario = c.get('scenario');
    if (wantsEmpty(scenario)) return c.json({ items: [] });
    return c.json({
      items: [{ ordinal: 0, kind: 'time', body: 'mock ticker' }],
    });
  });

  r.get('/curator/settings', (c) =>
    c.json({
      program_duration_seconds: 180,
      history_depth: 5,
      ticker_pixels_per_second: '80',
      require_news_photo_for_screens: true,
      display_theme_id: 'navy_coral',
      display_text_scale_screen: 'normal',
      display_text_scale_ticker: 'normal',
    }),
  );

  r.put('/curator/settings', (c) => c.json({}));

  r.get('/providers', (c) => {
    const scenario = c.get('scenario');
    if (wantsEmpty(scenario)) return c.json({ items: [] });
    return c.json({
      items: [
        {
          id: 'mock_provider',
          type: 'mock',
          enabled: true,
          poll_seconds: 60,
          base_url: 'https://example.invalid',
          config_json: { note: 'mock' },
          config_json_schema: { type: 'object' },
          example_config_json: {},
        },
      ],
    });
  });

  r.patch('/providers/:id', (c) => c.json({}));

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
          enabled: false,
          overlay_kind: 'hearts_rain',
          label: 'Mock',
          messages_json: ['Hi'],
          config_json: {},
          config_json_schema: {},
          example_config_json: {},
        },
      ],
    });
  });

  r.get('/alerts', (c) => c.json({ items: [] }));

  return r;
}
