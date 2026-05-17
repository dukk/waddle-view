import { normalizeBaseUrl } from '@/storage/displays';

function isBrowserFetchNetworkFailure(error: unknown): boolean {
  if (!(error instanceof TypeError)) {
    return false;
  }
  const msg = error.message.toLowerCase();
  return (
    msg.includes('failed to fetch') ||
    msg.includes('networkerror') ||
    msg.includes('network request failed') ||
    msg.includes('load failed')
  );
}

function mixedContentHint(displayBaseUrl: string): string | null {
  if (typeof window === 'undefined') {
    return null;
  }
  if (window.location.protocol !== 'https:') {
    return null;
  }
  try {
    if (new URL(displayBaseUrl).protocol === 'http:') {
      return (
        'This controller page uses HTTPS but the display URL uses HTTP; browsers block that ' +
        'combination. Open the controller over HTTP on the LAN, or serve the display over HTTPS.'
      );
    }
  } catch {
    return null;
  }
  return null;
}

/** User-facing message when adoption cannot reach the display REST API. */
export function adoptionConnectErrorMessage(displayBaseUrl: string, cause?: unknown): string {
  if (cause instanceof Error && !isBrowserFetchNetworkFailure(cause)) {
    return cause.message;
  }

  const base = normalizeBaseUrl(displayBaseUrl);
  const lines = [
    `Could not reach the display at ${base}.`,
    'Check that waddle_display is running, the base URL is correct, and this browser can reach the display (firewall, VPN, or wrong host/port).',
  ];

  const mixed = mixedContentHint(base);
  if (mixed) {
    lines.push(mixed);
  }

  if (typeof window !== 'undefined' && window.location?.origin) {
    lines.push(
      `Adoption requests are sent from ${window.location.origin}; the display only accepts origins on localhost, .local, or private LAN addresses.`,
    );
  }

  return lines.join(' ');
}

/** Text for adoption UI alerts (avoids `Error: …` from `String(error)`). */
export function adoptionErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
