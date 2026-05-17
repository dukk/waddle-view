const CHALLENGE_CHARS = /[0-9A-Za-z]/;

/** Crockford challenge without separators (8 characters). */
export function normalizeAdoptionChallengeCode(input: string): string {
  const out: string[] = [];
  for (const ch of input.toUpperCase()) {
    if (CHALLENGE_CHARS.test(ch)) {
      out.push(ch);
    }
    if (out.length >= 8) {
      break;
    }
  }
  return out.join('');
}

/** Display form `XXXX-XXXX` while typing. */
export function formatAdoptionChallengeCodeInput(input: string): string {
  const normalized = normalizeAdoptionChallengeCode(input);
  if (normalized.length <= 4) {
    return normalized;
  }
  return `${normalized.slice(0, 4)}-${normalized.slice(4)}`;
}

export function isAdoptionChallengeCodeComplete(input: string): boolean {
  return normalizeAdoptionChallengeCode(input).length === 8;
}
