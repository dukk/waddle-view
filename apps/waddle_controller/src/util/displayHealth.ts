import { displayProxyFetch } from '@/api/displayProxy';
import type { SavedDisplay } from '@/storage/displays';
import { readProxyErrorMessage } from '@/util/proxyErrorBody';

/** Payload from display `GET /v1/health` (fields optional for older displays). */
export type DisplayHealthPayload = {
  status: string;
  app?: string;
  version?: string;
  build?: string;
  schema_version?: number;
  platform_os?: string;
  platform_os_version?: string;
  hostname?: string;
  cpu_count?: number;
  dart_version?: string;
  uptime_seconds?: number;
};

export type DisplayReachability =
  | { state: 'checking' }
  | { state: 'online'; health: DisplayHealthPayload; checkedAtMs: number }
  | { state: 'offline'; message: string; checkedAtMs: number };

function isHealthPayload(value: unknown): value is DisplayHealthPayload {
  if (value == null || typeof value !== 'object') return false;
  const status = (value as DisplayHealthPayload).status;
  return typeof status === 'string';
}

/** Fetches public health from a display via the controller BFF proxy. */
export async function fetchDisplayHealth(display: SavedDisplay): Promise<DisplayReachability> {
  const checkedAtMs = Date.now();
  try {
    const res = await displayProxyFetch('/v1/health', { method: 'GET' }, { display });
    if (!res.ok) {
      const message = await readProxyErrorMessage(res, `Health check failed (${res.status})`);
      return { state: 'offline', message, checkedAtMs };
    }
    const body: unknown = await res.json();
    if (!isHealthPayload(body) || body.status !== 'ok') {
      return {
        state: 'offline',
        message: 'Display returned an unexpected health response',
        checkedAtMs,
      };
    }
    return { state: 'online', health: body, checkedAtMs };
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return { state: 'offline', message, checkedAtMs };
  }
}

/** One-line host summary for tables and tooltips. */
export function formatDisplayHostSummary(health: DisplayHealthPayload): string {
  const parts: string[] = [];
  const appLabel = health.app?.trim() || 'waddle_display';
  const version = health.version?.trim();
  const build = health.build?.trim();
  if (version) {
    parts.push(build ? `${appLabel} ${version}+${build}` : `${appLabel} ${version}`);
  } else {
    parts.push(appLabel);
  }
  if (health.schema_version != null) {
    parts.push(`schema ${health.schema_version}`);
  }
  const os = health.platform_os?.trim();
  if (os) {
    const osVer = health.platform_os_version?.trim();
    parts.push(osVer ? `${os} (${osVer})` : os);
  }
  const host = health.hostname?.trim();
  if (host) {
    parts.push(host);
  }
  if (health.cpu_count != null && health.cpu_count > 0) {
    parts.push(`${health.cpu_count} CPUs`);
  }
  if (health.uptime_seconds != null && health.uptime_seconds >= 0) {
    parts.push(`up ${formatUptimeSeconds(health.uptime_seconds)}`);
  }
  return parts.join(' · ');
}

function formatUptimeSeconds(totalSeconds: number): string {
  const s = Math.floor(totalSeconds);
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  if (h < 48) return `${h}h ${m % 60}m`;
  const d = Math.floor(h / 24);
  return `${d}d ${h % 24}h`;
}
