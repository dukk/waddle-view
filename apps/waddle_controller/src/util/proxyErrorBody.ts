/** User-facing message from a failed `/bff/v1/proxy/*` response body. */
export function messageFromProxyErrorBody(
  bodyText: string,
  fallback: string,
): string {
  const trimmed = bodyText.trim();
  if (!trimmed) {
    return fallback;
  }
  try {
    const json = JSON.parse(trimmed) as { error?: unknown };
    if (typeof json.error === 'string' && json.error.length > 0) {
      return json.error;
    }
  } catch {
    // plain text or HTML from upstream
  }
  return trimmed;
}

export async function readProxyErrorMessage(
  res: Response,
  fallback?: string,
): Promise<string> {
  const text = await res.text().catch(() => '');
  return messageFromProxyErrorBody(text, fallback ?? res.statusText);
}
