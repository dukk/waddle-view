import { fetchCatalogItem } from './fetchCatalogItem';
import { pushCatalogItem } from './pushCatalogItem';
import type { TransferCatalogItemInput, TransferResult } from './types';

export async function transferCatalogItem(
  input: TransferCatalogItemInput,
): Promise<{ results: TransferResult[]; sourceMissing: boolean }> {
  const { kind, source, targets, itemId, policy, newId, newLabel } = input;
  const payload = await fetchCatalogItem(kind, source, itemId);
  if (!payload) {
    return { results: [], sourceMissing: true };
  }

  const results: TransferResult[] = [];
  for (const target of targets) {
    const result = await pushCatalogItem({
      source,
      target,
      payload,
      policy,
      newId,
      newLabel,
    });
    results.push(result);
  }
  return { results, sourceMissing: false };
}
