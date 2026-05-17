export type IntegrationSecretSlot = {
  id: string;
  label: string;
  configured: boolean;
};

/** True when every slot is configured or has a non-empty draft value in this save. */
export function integrationSecretsSatisfiedForEnable(
  slots: IntegrationSecretSlot[],
  draftValues: Record<string, string>,
): boolean {
  if (slots.length === 0) {
    return true;
  }
  for (const slot of slots) {
    const draft = (draftValues[slot.id] ?? '').trim();
    if (draft.length > 0) {
      continue;
    }
    if (!slot.configured) {
      return false;
    }
  }
  return true;
}
