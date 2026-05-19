import type { RJSFSchema } from '@rjsf/utils';

/** Keep in sync with `kFloatingBalloonsSpawnIntervalSecMin` / `Max` in waddle_shared. */
export const FLOATING_BALLOONS_SPAWN_INTERVAL_SEC_MIN = 1;
export const FLOATING_BALLOONS_SPAWN_INTERVAL_SEC_MAX = 120;

/** Keep in sync with `kFloatingBalloonsRiseSpeedPxPerSecMin` / `Max`. */
export const FLOATING_BALLOONS_RISE_SPEED_PX_PER_SEC_MIN = 30;
export const FLOATING_BALLOONS_RISE_SPEED_PX_PER_SEC_MAX = 500;

/** Keep in sync with `kFloatingBalloonsMaxActiveMin` / `Max`. */
export const FLOATING_BALLOONS_MAX_ACTIVE_MIN = 1;
export const FLOATING_BALLOONS_MAX_ACTIVE_MAX = 12;

/** Keep in sync with `kFloatingBalloonsBalloonScaleMin` / `Max`. */
export const FLOATING_BALLOONS_BALLOON_SCALE_MIN = 0.04;
export const FLOATING_BALLOONS_BALLOON_SCALE_MAX = 0.2;

/** Keep in sync with `kFloatingBalloonsScaleJitterMax`. */
export const FLOATING_BALLOONS_SCALE_JITTER_MAX = 1;

const hexColorPattern = '^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$';

/**
 * Canonical JSON Schema for `floating_balloons` overlay config validation in the
 * controller. Matches display normalize rules.
 */
export const floatingBalloonsValidationSchema: RJSFSchema = {
  type: 'object',
  additionalProperties: false,
  properties: {
    colors: {
      type: 'array',
      title: 'Balloon colors',
      items: { type: 'string', pattern: hexColorPattern },
    },
    spawn_interval_sec: {
      type: 'integer',
      title: 'Spawn interval',
      minimum: FLOATING_BALLOONS_SPAWN_INTERVAL_SEC_MIN,
      maximum: FLOATING_BALLOONS_SPAWN_INTERVAL_SEC_MAX,
    },
    rise_speed: {
      type: 'number',
      title: 'Rise speed',
      minimum: FLOATING_BALLOONS_RISE_SPEED_PX_PER_SEC_MIN,
      maximum: FLOATING_BALLOONS_RISE_SPEED_PX_PER_SEC_MAX,
    },
    max_active: {
      type: 'integer',
      title: 'Max on screen',
      minimum: FLOATING_BALLOONS_MAX_ACTIVE_MIN,
      maximum: FLOATING_BALLOONS_MAX_ACTIVE_MAX,
    },
    cluster_chance: {
      type: 'number',
      title: 'Cluster chance',
      minimum: 0,
      maximum: 1,
    },
    balloon_scale: {
      type: 'number',
      title: 'Balloon scale',
      minimum: FLOATING_BALLOONS_BALLOON_SCALE_MIN,
      maximum: FLOATING_BALLOONS_BALLOON_SCALE_MAX,
    },
    scale_jitter: {
      type: 'number',
      title: 'Random size variation',
      minimum: 0,
      maximum: FLOATING_BALLOONS_SCALE_JITTER_MAX,
    },
    opacity: {
      type: 'number',
      title: 'Opacity',
      minimum: 0.2,
      maximum: 1,
    },
  },
};
