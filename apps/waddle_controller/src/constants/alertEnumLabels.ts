/** Human labels for dashboard alert [Alerts.severity] values. */
export const ALERT_SEVERITY_LABELS: Record<string, string> = {
  info: 'Info',
  auth: 'Sign-in required',
  security: 'Security',
  warning: 'Warning',
  error: 'Error',
  critical: 'Critical',
};

/** Human labels for dashboard alert [Alerts.source] slugs. */
export const ALERT_SOURCE_LABELS: Record<string, string> = {
  api: 'API',
  adoption: 'Display adoption',
  google: 'Google sign-in',
  google_calendar: 'Google sign-in',
  microsoft_graph: 'Microsoft sign-in',
  news_facebook: 'Facebook sign-in',
  manual_entry: 'Manual notice',
  system: 'System',
};

export function alertSeverityLabel(severity: string | null | undefined): string {
  const key = (severity ?? '').trim().toLowerCase();
  if (!key) return '—';
  return ALERT_SEVERITY_LABELS[key] ?? titleFromSlug(key);
}

export function alertSourceLabel(source: string | null | undefined): string {
  const key = (source ?? '').trim().toLowerCase();
  if (!key) return '—';
  return ALERT_SOURCE_LABELS[key] ?? titleFromSlug(key);
}

function titleFromSlug(slug: string): string {
  const parts = slug.split('_').filter(Boolean);
  if (parts.length === 0) return slug;
  return parts.map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join(' ');
}
