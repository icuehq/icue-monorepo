import '../region';
import { z } from 'zod';
import { uniqueKeyRef } from '../shared/keys';
import { code, defineCallable, failed, id, missing, name, optionalText, saveMaster, defineSetStatus, status, usable } from '../shared/masters';
import { DEFAULT_CATEGORIES, DEFAULT_UNITS } from './defaults';
import { serverTimestamp } from '../shared/firestore';

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
        id: i.id,
        code: i.code,
        build: async (before) => {
          if (i.parentId) {
            if (i.parentId === i.id) throw failed('A category cannot be its own parent');
            const parent = usable(await context.transaction.get(context.doc(`inventoryCategories/${i.parentId}`)), 'Parent category', before?.parentId === i.parentId);
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
  categorySetStatus: defineSetStatus('inventory.category.setStatus', 'inventory.settings', 'inventoryCategories', 'inventoryCategory'),

  unitUpsert: defineCallable({
    name: 'inventory.unit.upsert',
    permission: 'inventory.settings',
    input: z.object({ code: z.string().trim().toLowerCase().regex(/^[a-z0-9_-]{1,10}$/), name }),
    handler: async (context, i) => {
      const ref = context.doc(`inventoryUnits/${i.code}`);
      const snapshot = await context.transaction.get(ref);
      const now = serverTimestamp();
      if (snapshot.exists) context.update(ref, { name: i.name, updatedAt: now });
      else context.set(ref, { code: i.code, name: i.name, status: 'active', createdAt: now, createdBy: context.uid, updatedAt: now });
      context.audit({ action: snapshot.exists ? 'inventoryUnit.update' : 'inventoryUnit.create', documentPath: ref.path, before: snapshot.data(), after: i });
      return { id: ref.id };
    },
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
      purchaseUnits: z.array(z.object({ unit: z.string().min(1).max(10), factor: z.number().positive() })).max(10).default([]),
      tracking,
      variantAttrs: z.array(z.string().trim().min(1).max(30)).max(5).default([]),
      minLevel: amount,
      reorderLevel: amount,
      defaultPrice: amount,
      preferredVendorId: id.nullish(),
      defaultLocation: optionalText,
    }),
    handler: (context, i) =>
      saveMaster(context, {
        coll: 'inventoryItems',
        entityType: 'inventoryItem',
        id: i.id,
        code: i.code,
        build: async (before) => {
          const category = usable(await context.transaction.get(context.doc(`inventoryCategories/${i.categoryId}`)), 'Category', before?.categoryId === i.categoryId);
          if (category.parentId) throw failed('Pick a top-level category; use subcategory for the child');
          if (i.subcategoryId) {
            const sub = usable(await context.transaction.get(context.doc(`inventoryCategories/${i.subcategoryId}`)), 'Subcategory', before?.subcategoryId === i.subcategoryId);
            if (sub.parentId !== i.categoryId) throw failed('Subcategory does not belong to the category');
          }
          if (i.preferredVendorId) {
            usable(await context.transaction.get(context.doc(`inventoryVendors/${i.preferredVendorId}`)), 'Vendor', before?.preferredVendorId === i.preferredVendorId);
          }
          const units = new Set([i.stockUnit, ...i.purchaseUnits.map((purchaseUnit) => purchaseUnit.unit)]);
          if (i.purchaseUnits.some((purchaseUnit) => purchaseUnit.unit === i.stockUnit)) throw failed('Purchase unit equals the stock unit');
          for (const unit of units) {
            if (!(await context.transaction.get(context.doc(`inventoryUnits/${unit}`))).exists) throw failed(`Unit "${unit}" not found`);
          }
          if (before && (before.stockUnit !== i.stockUnit || before.tracking !== i.tracking)) {
            const used = await context.transaction.get(context.coll('inventoryMovements').where('itemId', '==', i.id).limit(1));
            if (!used.empty) throw failed('Stock unit and tracking cannot change once stock has moved');
          }
          return {
            name: i.name,
            categoryId: i.categoryId,
            subcategoryId: i.subcategoryId ?? null,
            description: i.description ?? null,
            stockUnit: i.stockUnit,
            purchaseUnits: i.purchaseUnits,
            tracking: i.tracking,
            variantAttrs: i.variantAttrs,
            minLevel: i.minLevel ?? null,
            reorderLevel: i.reorderLevel ?? null,
            defaultPrice: i.defaultPrice ?? null,
            preferredVendorId: i.preferredVendorId ?? null,
            defaultLocation: i.defaultLocation ?? null,
            ...(before ? {} : { imagePath: null }),
          };
        },
      }),
  }),
  itemSetStatus: defineSetStatus('inventory.item.setStatus', 'inventory.items.manage', 'inventoryItems', 'inventoryItem'),

  variantUpsert: defineCallable({
    name: 'inventory.variant.upsert',
    permission: 'inventory.items.manage',
    input: z.object({
      itemId: id,
      id: id.optional(),
      code: code.optional(),
      attrs: z.record(z.string().min(1).max(30), z.string().trim().min(1).max(50)),
      status: status.optional(),
    }),
    handler: (context, i) =>
      saveMaster(context, {
        coll: `inventoryItems/${i.itemId}/variants`,
        entityType: 'inventorySku',
        id: i.id,
        code: i.code,
        build: async (_before, sku) => {
          const item = (await context.transaction.get(context.doc(`inventoryItems/${i.itemId}`))).data();
          if (!item) throw missing('inventoryItem');
          const allowed = new Set<string>(item.variantAttrs);
          const keys = Object.keys(i.attrs);
          if (!keys.length || keys.some((key) => !allowed.has(key))) {
            throw failed(`Attributes must be among: ${[...allowed].join(', ') || '(none defined)'}`);
          }
          return { itemId: i.itemId, sku, attrs: i.attrs, ...(i.status ? { status: i.status } : {}) };
        },
      }),
  }),

  storeUpsert: defineCallable({
    name: 'inventory.store.upsert',
    permission: 'inventory.settings',
    input: z.object({
      id: id.optional(),
      code: code.optional(),
      name,
      campusId: z.number().int(),
      description: optionalText,
      location: optionalText,
      storekeeperIds: z.array(z.number().int()).max(20).default([]),
    }),
    handler: (context, i) =>
      saveMaster(context, {
        coll: 'inventoryStores',
        entityType: 'inventoryStore',
        id: i.id,
        code: i.code,
        build: async (before) => {
          if (before && before.campusId !== i.campusId) throw failed('A store cannot move to another campus');
          return {
            name: i.name,
            campusId: i.campusId,
            description: i.description ?? null,
            location: i.location ?? null,
            storekeeperIds: [...new Set(i.storekeeperIds)],
          };
        },
      }),
  }),
  storeSetStatus: defineSetStatus('inventory.store.setStatus', 'inventory.settings', 'inventoryStores', 'inventoryStore'),

  /** Adds the FRS default categories and units that do not exist yet. Safe to repeat. */
  seedDefaults: defineCallable({
    name: 'inventory.seedDefaults',
    permission: 'inventory.settings',
    input: z.object({}),
    handler: async (context) => {
      const now = serverTimestamp();
      const keys = DEFAULT_CATEGORIES.map((category) => uniqueKeyRef(context, 'inventoryCategory', category.code));
      const unitRefs = DEFAULT_UNITS.map((unit) => context.doc(`inventoryUnits/${unit.code}`));
      const [keySnaps, unitSnaps] = await Promise.all([context.transaction.getAll(...keys), context.transaction.getAll(...unitRefs)]);
      let categories = 0;
      let units = 0;
      DEFAULT_CATEGORIES.forEach((category, index) => {
        if (keySnaps[index].exists) return;
        const ref = context.newDoc('inventoryCategories');
        context.set(keys[index], { keyType: 'inventoryCategory', value: category.code.toLowerCase(), documentPath: ref.path });
        context.set(ref, {
          code: category.code, name: category.name, description: null, parentId: null, suggestedTracking: category.tracking,
          status: 'active', createdAt: now, createdBy: context.uid, updatedAt: now,
        });
        categories++;
      });
      DEFAULT_UNITS.forEach((unit, index) => {
        if (unitSnaps[index].exists) return;
        context.set(unitRefs[index], { ...unit, status: 'active', createdAt: now, createdBy: context.uid, updatedAt: now });
        units++;
      });
      context.audit({ action: 'inventory.seedDefaults', documentPath: `schools/${context.schoolId}`, after: { categories, units } });
      return { categories, units };
    },
  }),
};
