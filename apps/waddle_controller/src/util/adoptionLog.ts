const PREFIX = '[waddle-adoption]';

export type AdoptionLogData = Record<string, unknown>;

/** Redact API keys; leave challenge codes and identifiers visible for debugging. */
export function sanitizeAdoptionLogData(data: AdoptionLogData): AdoptionLogData {
  const out: AdoptionLogData = { ...data };
  for (const key of ['api_key', 'apiKey', 'adminApiKey'] as const) {
    const v = out[key];
    if (typeof v === 'string') {
      out[key] = `<redacted len=${v.length}>`;
    }
  }
  return out;
}

export function adoptionLog(step: string, detail: string, data?: AdoptionLogData): void {
  if (data !== undefined) {
    console.info(PREFIX, step, detail, sanitizeAdoptionLogData(data));
  } else {
    console.info(PREFIX, step, detail);
  }
}

export function adoptionWarn(step: string, detail: string, data?: AdoptionLogData): void {
  if (data !== undefined) {
    console.warn(PREFIX, step, detail, sanitizeAdoptionLogData(data));
  } else {
    console.warn(PREFIX, step, detail);
  }
}

export function adoptionError(step: string, detail: string, data?: AdoptionLogData): void {
  if (data !== undefined) {
    console.error(PREFIX, step, detail, sanitizeAdoptionLogData(data));
  } else {
    console.error(PREFIX, step, detail);
  }
}
