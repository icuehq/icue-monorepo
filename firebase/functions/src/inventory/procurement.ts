import { z } from 'zod';
import {
  code,
  defineCallable,
  failed,
  id,
  name,
  optionalText,
  saveMaster,
  text,
} from '../shared/masters';

/** Vendor master, kept only for the bulk importer; vendors are edited by the client (`firestore.rules`). */

export const procurement = {
  vendorUpsert: defineCallable({
    name: 'inventory.vendor.upsert',
    permission: 'inventory.vendors.manage',
    input: z.object({
      id: id.optional(),
      code: code.optional(),
      name,
      contactPerson: text(120),
      phone: text(30),
      email: z.union([z.email(), z.literal('')]).nullish(),
      address: optionalText,
      taxNumber: text(40),
      website: text(200),
      categoryIds: z.array(id).max(30).default([]),
      remarks: optionalText,
    }),
    handler: (context, i) =>
      saveMaster(context, {
        coll: 'inventoryVendors',
        entityType: 'inventoryVendor',
        id: i.id,
        code: i.code,
        build: async (before) => {
          const cats = [...new Set(i.categoryIds)];
          if (cats.length) {
            const snapshots = await context.transaction.getAll(
              ...cats.map((category) => context.doc(`inventoryCategories/${category}`)),
            );
            if (snapshots.some((snapshot) => !snapshot.exists)) throw failed('Category not found');
          }
          return {
            name: i.name,
            contactPerson: i.contactPerson ?? null,
            phone: i.phone ?? null,
            email: i.email || null,
            address: i.address ?? null,
            taxNumber: i.taxNumber ?? null,
            website: i.website ?? null,
            categoryIds: cats,
            remarks: i.remarks ?? null,
            // Known limit: documents stay empty until uploads exist (files-getUploadPath).
            ...(before ? {} : { documents: [] }),
          };
        },
      }),
  }),
};
