import { onCall } from 'firebase-functions/v2/https';
import { importRows, toNumber, toText, type ImportType } from '../shared/importRows';
import { masters } from './masters';
import { procurement } from './procurement';

const tracking = (value: string | undefined) => toText(value)?.toLowerCase() ?? 'quantity';

const types: Record<string, ImportType> = {
  categories: {
    callable: masters.categoryUpsert,
    mapRow: async (row, lookup) => ({
      code: row.code,
      name: row.name,
      suggestedTracking: tracking(row.tracking),
      parentId: toText(row.parentCode)
        ? await lookup('inventoryCategory', row.parentCode, 'Category')
        : undefined,
    }),
  },
  items: {
    callable: masters.itemUpsert,
    mapRow: async (row, lookup) => ({
      code: row.code,
      name: row.name,
      categoryId: await lookup('inventoryCategory', row.categoryCode, 'Category'),
      stockUnit: toText(row.stockUnit) ?? 'pcs',
      tracking: tracking(row.tracking),
      reorderLevel: toNumber(row.reorderLevel),
      defaultPrice: toNumber(row.defaultPrice),
    }),
  },
  vendors: {
    callable: procurement.vendorUpsert,
    mapRow: async (row) => ({
      code: row.code,
      name: row.name,
      contactPerson: toText(row.contactPerson),
      phone: toText(row.phone),
      email: toText(row.email),
      taxNumber: toText(row.taxNumber),
    }),
  },
};

export const runImport = (auth: Parameters<typeof importRows>[0], data: unknown) =>
  importRows(auth, data, types);

export const importRun = onCall((request) => runImport(request.auth, request.data));
