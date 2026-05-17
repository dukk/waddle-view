import type { BffStatus } from '@/api/bffAuth';

export function resolveClientIdentifier(
  status: BffStatus | null | undefined,
  fallback: string,
): { value: string; locked: boolean } {
  const envValue = status?.clientIdentifier?.trim();
  if (envValue) {
    return { value: envValue, locked: true };
  }
  return { value: fallback, locked: false };
}
