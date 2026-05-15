export function parseJsonObject(value: unknown): Record<string, unknown> {
  if (value == null) {
    return {};
  }
  if (typeof value === 'string') {
    const t = value.trim();
    if (!t) return {};
    try {
      const parsed: unknown = JSON.parse(t);
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        return parsed as Record<string, unknown>;
      }
    } catch {
      return {};
    }
    return {};
  }
  if (typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}
