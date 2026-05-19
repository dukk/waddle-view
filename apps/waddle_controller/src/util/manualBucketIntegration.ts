/** Manual bucket integration types (operator-uploaded catalog content). */
export const kPhotoBucketIntegrationType = 'photo_bucket';
export const kVideoBucketIntegrationType = 'video_bucket';
export const kCalendarBucketIntegrationType = 'calendar_bucket';
export const kJokeBucketIntegrationType = 'joke_bucket';
export const kTriviaBucketIntegrationType = 'trivia_bucket';

const MANUAL_BUCKET_TYPES = new Set([
  kPhotoBucketIntegrationType,
  kVideoBucketIntegrationType,
  kCalendarBucketIntegrationType,
  kJokeBucketIntegrationType,
  kTriviaBucketIntegrationType,
]);

export function isManualBucketIntegration(integrationType: string): boolean {
  return MANUAL_BUCKET_TYPES.has(integrationType.trim());
}

export function manualBucketUploadPath(
  integrationId: string,
  integrationType: string,
): string {
  const enc = encodeURIComponent(integrationId);
  switch (integrationType) {
    case kPhotoBucketIntegrationType:
      return `/v1/integrations/${enc}/bucket/photos`;
    case kVideoBucketIntegrationType:
      return `/v1/integrations/${enc}/bucket/videos`;
    case kJokeBucketIntegrationType:
      return `/v1/integrations/${enc}/bucket/jokes`;
    case kTriviaBucketIntegrationType:
      return `/v1/integrations/${enc}/bucket/trivia`;
    case kCalendarBucketIntegrationType:
      return `/v1/integrations/${enc}/bucket/calendar-events`;
    default:
      return `/v1/integrations/${enc}/bucket`;
  }
}
