import type { Tracking } from './masters';

/** FRS 10.2 default categories. */
export const DEFAULT_CATEGORIES: Array<{ code: string; name: string; tracking: Tracking }> = [
  { code: 'STA', name: 'Stationery', tracking: 'qty' },
  { code: 'CLS', name: 'Classroom supplies', tracking: 'qty' },
  { code: 'FUR', name: 'Furniture', tracking: 'asset' },
  { code: 'ITE', name: 'IT equipment', tracking: 'asset' },
  { code: 'LAB', name: 'Laboratory equipment', tracking: 'asset' },
  { code: 'SPT', name: 'Sports equipment', tracking: 'qty' },
  { code: 'KIT', name: 'Kitchen supplies', tracking: 'batch' },
  { code: 'MED', name: 'Medical supplies', tracking: 'batch' },
  { code: 'UNI', name: 'Uniforms', tracking: 'qty' },
  { code: 'BKD', name: 'Books for distribution', tracking: 'qty' },
  { code: 'CLN', name: 'Cleaning materials', tracking: 'qty' },
  { code: 'TSP', name: 'Transport spare parts', tracking: 'qty' },
  { code: 'ELE', name: 'Electrical supplies', tracking: 'qty' },
  { code: 'MNT', name: 'Maintenance materials', tracking: 'qty' },
];

/** FRS 10.4 default units; the doc ID is the code. */
export const DEFAULT_UNITS: Array<{ code: string; name: string }> = [
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
