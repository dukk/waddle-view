/** Partial mask with literal `***`; full term in tooltip. */
export function maskRejectTermForDisplay(term: string): string {
  const t = term.trim();
  if (t.length === 0) return '';
  if (t.length === 1) return '*';
  if (t.length === 2) return `${t[0]}*`;
  return `${t[0]}***${t[t.length - 1]}`;
}
