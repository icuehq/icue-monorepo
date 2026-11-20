import { z } from 'zod';
import { serverTimestamp } from '../shared/firestore';
import {
  defineCallable,
  failed,
  id,
  name,
  optionalText,
  saveMaster,
  usable,
} from '../shared/masters';
import { DEFAULT_CATEGORIES } from './defaults';

export type Tracking = 'quantity' | 'batch' | 'asset';

const tracking = z.enum(['quantity', 'batch', 'asset']);
const amount = z.number().min(0).nullish();

export const masters = {
  categoryUpsert: defineCallable({
    name: 'inventory.category.upsert',
    input: z.object({
      id: id.optional(),
      storeId: id,
      name,
      description: optionalText,
      parentId: id.nullish(),
    }),
    handler: (context, i) =>
      saveMaster(context, {
        coll: 'inventoryCategories',
        entityType: 'inventoryCategory',
        codeless: true,
        id: i.id,
        build: async (before) => {
          usable(
            await context.transaction.get(context.doc(`inventoryStores/${i.storeId}`)),
            'Store',
            before?.storeId === i.storeId,
          );
          if (before && before.storeId !== i.storeId)
            throw failed('A category cannot move to another store');
          if (i.parentId) {
            if (i.parentId === i.id) throw failed('A category cannot be its own parent');
            const parent = usable(
              await context.transaction.get(context.doc(`inventoryCategories/${i.parentId}`)),
              'Parent category',
              before?.parentId === i.parentId,
            );
            if (parent.parentId) throw failed('Only one level of subcategories is supported');
            if (parent.storeId !== i.storeId)
              throw failed('The parent category belongs to another store');
          }
          return {
            storeId: i.storeId,
            name: i.name,
            description: i.description ?? null,
            parentId: i.parentId ?? null,
          };
        },
      }),
  }),

  itemUpsert: defineCallable({
    name: 'inventory.item.upsert',
    input: z.object({
      id: id.optional(),
      storeId: id,
      name,
      categoryId: id,
      subcategoryId: id.nullish(),
      description: optionalText,
      stockUnit: z.string().min(1).max(10),
      tracking,
      variantAttrs: z.array(z.string().trim().min(1).max(30)).max(5).default([]),
      reorderLevel: amount,
      defaultPrice: amount,
      preferredVendorId: id.nullish(),
    }),
    handler: (context, i) =>
      saveMaster(context, {
        coll: 'inventoryItems',
        entityType: 'inventoryItem',
        codeless: true,
        id: i.id,
        build: async (before) => {
          const category = usable(
            await context.transaction.get(context.doc(`inventoryCategories/${i.categoryId}`)),
            'Category',
            before?.categoryId === i.categoryId,
          );
          if (category.storeId !== i.storeId) throw failed('The category belongs to another store');
          if (before && before.storeId !== i.storeId)
            throw failed('An item cannot move to another store');
          if (category.parentId)
            throw failed('Pick a top-level category; use subcategory for the child');
          if (i.subcategoryId) {
            const sub = usable(
              await context.transaction.get(context.doc(`inventoryCategories/${i.subcategoryId}`)),
              'Subcategory',
              before?.subcategoryId === i.subcategoryId,
            );
            if (sub.parentId !== i.categoryId)
              throw failed('Subcategory does not belong to the category');
          }
          if (i.preferredVendorId) {
            usable(
              await context.transaction.get(context.doc(`inventoryVendors/${i.preferredVendorId}`)),
              'Vendor',
              before?.preferredVendorId === i.preferredVendorId,
            );
          }
          const unit = await context.transaction.get(
            context
              .coll('inventoryUnits')
              .where('storeId', '==', i.storeId)
              .where('name', '==', i.stockUnit)
              .limit(1),
          );
          if (unit.empty) throw failed(`Unit "${i.stockUnit}" not found in this store`);
          if (before && (before.stockUnit !== i.stockUnit || before.tracking !== i.tracking)) {
            const used = await context.transaction.get(
              context.coll('inventoryMovements').where('itemId', '==', i.id).limit(1),
            );
            if (!used.empty)
              throw failed('Stock unit and tracking cannot change once stock has moved');
          }
          return {
            storeId: i.storeId,
            name: i.name,
            categoryId: i.categoryId,
            subcategoryId: i.subcategoryId ?? null,
            description: i.description ?? null,
            stockUnit: i.stockUnit,
            tracking: i.tracking,
            variantAttrs: i.variantAttrs,
            reorderLevel: i.reorderLevel ?? null,
            defaultPrice: i.defaultPrice ?? null,
            preferredVendorId: i.preferredVendorId ?? null,
            ...(before ? {} : { imagePath: null }),
          };
        },
      }),
  }),

  /** Adds the FRS default categories that a store does not have yet, for every store. Safe to repeat. */
  seedDefaults: defineCallable({
    name: 'inventory.seedDefaults',
    input: z.object({}),
    handler: async (context) => {
      const now = serverTimestamp();
      const stores = (await context.transaction.get(context.coll('inventoryStores'))).docs;
      if (stores.length === 0) throw failed('Add a store before adding default categories');
      const existing = await context.transaction.get(context.coll('inventoryCategories'));
      const existingKeys = new Set(
        existing.docs.map(
          (snapshot) =>
            `${snapshot.data().storeId}/${String(snapshot.data().name).trim().toLowerCase()}`,
        ),
      );
      let categories = 0;
      stores.forEach((store) => {
        DEFAULT_CATEGORIES.forEach((category) => {
          if (existingKeys.has(`${store.id}/${category.name.toLowerCase()}`)) return;
          context.set(context.newDoc('inventoryCategories'), {
            storeId: store.id,
            name: category.name,
            description: null,
            parentId: null,
            status: 'active',
            createdAt: now,
            createdBy: context.uid,
            updatedAt: now,
          });
          categories++;
        });
      });
      context.audit({
        action: 'inventory.seedDefaults',
        documentPath: `${context.branchPath}`,
        after: { categories },
      });
      return { categories };
    },
  }),
};
