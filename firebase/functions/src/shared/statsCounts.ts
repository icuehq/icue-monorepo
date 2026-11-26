import { FieldValue } from 'firebase-admin/firestore';

/** Signed amounts by figure name; a nested figure is `field.key` (`dueOn.2026-11-20`). */
export type Counts = Record<string, number>;

export const bump = (counts: Counts, key: string, amount: number) => {
  counts[key] = (counts[key] ?? 0) + amount;
};

/** `{'dueOn.2026-11-20': 1}` → `{dueOn: {'2026-11-20': increment(1)}}`, without the keys that netted to zero. */
export function increments(counts: Counts) {
  const out: Record<string, unknown> = {};
  for (const [key, amount] of Object.entries(counts)) {
    if (!amount) continue;
    const [field, nested] = key.split('.');
    if (nested === undefined) out[field] = FieldValue.increment(amount);
    else ((out[field] ??= {}) as Record<string, unknown>)[nested] = FieldValue.increment(amount);
  }
  return out;
}
