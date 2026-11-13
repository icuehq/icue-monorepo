import type { Tracking } from './masters';

/** FRS 10.2 default categories. */
export const DEFAULT_CATEGORIES: { name: string; tracking: Tracking }[] = [
  { name: 'Stationery', tracking: 'quantity' },
  { name: 'Classroom supplies', tracking: 'quantity' },
  { name: 'Furniture', tracking: 'asset' },
  { name: 'IT equipment', tracking: 'asset' },
  { name: 'Laboratory equipment', tracking: 'asset' },
  { name: 'Sports equipment', tracking: 'quantity' },
  { name: 'Kitchen supplies', tracking: 'batch' },
  { name: 'Medical supplies', tracking: 'batch' },
  { name: 'Uniforms', tracking: 'quantity' },
  { name: 'Books for distribution', tracking: 'quantity' },
  { name: 'Cleaning materials', tracking: 'quantity' },
  { name: 'Transport spare parts', tracking: 'quantity' },
  { name: 'Electrical supplies', tracking: 'quantity' },
  { name: 'Maintenance materials', tracking: 'quantity' },
];

/** FRS 10.4 default units; the doc ID is the code. */
export const DEFAULT_UNITS: { code: string; name: string }[] = [
  { code: 'pcs', name: 'Pieces' },
  { code: 'box', name: 'Boxes' },
  { code: 'pkt', name: 'Packets' },
  { code: 'kg', name: 'Kilograms' },
  { code: 'g', name: 'Grams' },
  { code: 'l', name: 'Litres' },
  { code: 'ml', name: 'Millilitres' },
  { code: 'm', name: 'Metres' },
  { code: 'set', name: 'Sets' },
  { code: 'pair', name: 'Pairs' },
  { code: 'doz', name: 'Dozens' },
  { code: 'roll', name: 'Rolls' },
];
