import { z } from 'zod';
import { serverTimestamp } from '../shared/firestore';
import {
  code,
  codeDocId,
  defineCallable,
  failed,
  id,
  name,
  optionalText,
  saveMaster,
  usable,
} from '../shared/masters';
import { DEFAULT_CATEGORIES, DEFAULT_UNITS } from './defaults';

export type Tracking = 'quantity' | 'batch' | 'asset';

const tracking = z.enum(['quantity', 'batch', 'asset']);
const amount = z.number().min(0).nullish();

export const masters = {
  categoryUpsert: defineCallable({
    name: 'inventory.category.upsert',
    permission: 'inventory.settings',
    input: z.object({
      id: id.optional(),
      code: code.optional(),
      name,
      description: optionalText,
      parentId: id.nullish(),
      suggestedTracking: tracking,
    }),
    handler: (context, i) =>
      saveMaster(context, {
        coll: 'inventoryCategories',
        entityType: 'inventoryCategory',
        idFromCode: true,
        id: i.id,
        code: i.code,
        build: async (before) => {
          if (i.parentId) {
            if (i.parentId === i.id) throw failed('A category cannot be its own parent');
            const parent = usable(
              await context.transaction.get(context.doc(`inventoryCategories/${i.parentId}`)),
              'Parent category',
              before?.parentId === i.parentId,
            );
            if (parent.parentId) throw failed('Only one level of subcategories is supported');
          }
          return {
            name: i.name,
            description: i.description ?? null,
            parentId: i.parentId ?? null,
            suggestedTracking: i.suggestedTracking,
          };
        },
      }),
  }),

  itemUpsert: defineCallable({
    name: 'inventory.item.upsert',
    permission: 'inventory.items.manage',
    input: z.object({
      id: id.optional(),
      code: code.optional(),
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
        id: i.id,
        code: i.code,
        build: async (before) => {
          const category = usable(
            await context.transaction.get(context.doc(`inventoryCategories/${i.categoryId}`)),
            'Category',
            before?.categoryId === i.categoryId,
          );
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
          if (!(await context.transaction.get(context.doc(`inventoryUnits/${i.stockUnit}`))).exists)
            throw failed(`Unit "${i.stockUnit}" not found`);
          if (before && (before.stockUnit !== i.stockUnit || before.tracking !== i.tracking)) {
            const used = await context.transaction.get(
              context.coll('inventoryMovements').where('itemId', '==', i.id).limit(1),
            );
            if (!used.empty)
              throw failed('Stock unit and tracking cannot change once stock has moved');
          }
          return {
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

  /** Adds the FRS default categories and units that do not exist yet. Safe to repeat. */
  seedDefaults: defineCallable({
    name: 'inventory.seedDefaults',
    permission: 'inventory.settings',
    input: z.object({}),
    handler: async (context) => {
      const now = serverTimestamp();
      const categoryRefs = DEFAULT_CATEGORIES.map((category) =>
        context.doc(`inventoryCategories/${codeDocId(category.code)}`),
      );
      const unitRefs = DEFAULT_UNITS.map((unit) => context.doc(`inventoryUnits/${unit.code}`));
      const [categorySnaps, unitSnaps] = await Promise.all([
        context.transaction.getAll(...categoryRefs),
        context.transaction.getAll(...unitRefs),
      ]);
      let categories = 0;
      let units = 0;
      DEFAULT_CATEGORIES.forEach((category, index) => {
        if (categorySnaps[index].exists) return;
        context.set(categoryRefs[index], {
          code: category.code,
          name: category.name,
          description: null,
          parentId: null,
          suggestedTracking: category.tracking,
          status: 'active',
          createdAt: now,
          createdBy: context.uid,
          updatedAt: now,
        });
        categories++;
      });
      DEFAULT_UNITS.forEach((unit, index) => {
        if (unitSnaps[index].exists) return;
        context.set(unitRefs[index], {
          ...unit,
          status: 'active',
          createdAt: now,
          createdBy: context.uid,
          updatedAt: now,
        });
        units++;
      });
      context.audit({
        action: 'inventory.seedDefaults',
        documentPath: `${context.branchPath}`,
        after: { categories, units },
      });
      return { categories, units };
    },
  }),
};
