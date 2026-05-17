/** Parses 1/true/yes vs 0/false/no; returns [defaultValue] when unset. */
export function envFlag(name: string, env: NodeJS.ProcessEnv, defaultValue: boolean): boolean {
  const v = env[name]?.trim();
  if (!v) return defaultValue;
  if (v === '0' || v.toLowerCase() === 'false' || v.toLowerCase() === 'no') {
    return false;
  }
  return v === '1' || v.toLowerCase() === 'true' || v.toLowerCase() === 'yes';
}
