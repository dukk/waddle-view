import type { RJSFSchema } from '@rjsf/utils';

/** Keep in sync with `kFallingImagesDropIntervalSecMin` / `Max` in waddle_shared. */
export const FALLING_IMAGES_DROP_INTERVAL_SEC_MIN = 5;
export const FALLING_IMAGES_DROP_INTERVAL_SEC_MAX = 180;

/** Keep in sync with `kFallingImagesFallSpeedPxPerSecMin` / `Max`. */
export const FALLING_IMAGES_FALL_SPEED_PX_PER_SEC_MIN = 30;
export const FALLING_IMAGES_FALL_SPEED_PX_PER_SEC_MAX = 800;
export const FALLING_IMAGES_FALL_SPEED_PX_PER_SEC_DEFAULT = 130;

/** Keep in sync with `kFallingImagesImageScaleMin` / `Max`. */
export const FALLING_IMAGES_IMAGE_SCALE_MIN = 0.04;
export const FALLING_IMAGES_IMAGE_SCALE_MAX = 0.7;

/** Keep in sync with `kFallingImagesScaleJitterMax`. */
export const FALLING_IMAGES_SCALE_JITTER_MAX = 1;

/**
 * Canonical JSON Schema for `falling_images` overlay config validation in the
 * controller. Matches display `config_json_documentation` / normalize rules so
 * saves succeed even when a connected display still serves an older meta schema.
 */
export const fallingImagesValidationSchema: RJSFSchema = {
  type: 'object',
  additionalProperties: false,
  properties: {
    image_blob_keys: {
      type: 'array',
      title: 'Images',
      items: { type: 'string' },
    },
    drop_interval_sec: {
      type: 'integer',
      title: 'Drop interval',
      minimum: FALLING_IMAGES_DROP_INTERVAL_SEC_MIN,
      maximum: FALLING_IMAGES_DROP_INTERVAL_SEC_MAX,
    },
    fall_speed: {
      type: 'number',
      title: 'Fall speed',
      minimum: FALLING_IMAGES_FALL_SPEED_PX_PER_SEC_MIN,
      maximum: FALLING_IMAGES_FALL_SPEED_PX_PER_SEC_MAX,
    },
    image_scale: {
      type: 'number',
      title: 'Image scale',
      minimum: FALLING_IMAGES_IMAGE_SCALE_MIN,
      maximum: FALLING_IMAGES_IMAGE_SCALE_MAX,
    },
    scale_jitter: {
      type: 'number',
      title: 'Random size variation',
      minimum: 0,
      maximum: FALLING_IMAGES_SCALE_JITTER_MAX,
    },
  },
};
