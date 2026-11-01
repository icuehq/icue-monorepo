import '../region';
import { FieldValue } from 'firebase-admin/firestore';
import { z } from 'zod';
import { uniqueKeyRef } from '../shared/keys';
import { code, def, failed, id, missing, name, note, saveMaster, setStatusDef, status, usable } from '../shared/masters';
import { DEFAULT_CATEGORIES, DEFAULT_UNITS } from './defaults';

export type Tracking = 'qty' | 'batch' | 'asset';

const tracking = z.enum(['qty', 'batch', 'asset']);
const amount = z.number().min(0).nullish();

export const masters = {
  categoryUpsert: def({
    name: 'inv.category.upsert',
    perm: 'inv.settings',
    input: z.object({
      id: id.optional(),
      code: code.optional(),
      name,
      description: note,
      parentId: id.nullish(),
      suggestedTracking: tracking,
    }),
    handler: (ctx, i) =>
      saveMaster(ctx, {
        coll: 'invCategories',
        kind: 'invCategory',
        id: i.id,
        code: i.code,
        build: async (before) => {
          if (i.parentId) {
            if (i.parentId === i.id) throw failed('A category cannot be its own parent');
            const parent = usable(await ctx.tx.get(ctx.doc(`invCategories/${i.parentId}`)), 'Parent category', before?.parentId === i.parentId);
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
  categorySetStatus: setStatusDef('inv.category.setStatus', 'inv.settings', 'invCategories', 'invCategory'),

  unitUpsert: def({
    name: 'inv.unit.upsert',
    perm: 'inv.settings',
    input: z.object({ code: z.string().trim().toLowerCase().regex(/^[a-z0-9_-]{1,10}$/), name }),
    handler: async (ctx, i) => {
      const ref = ctx.doc(`invUnits/${i.code}`);
      const snap = await ctx.tx.get(ref);
      const now = FieldValue.serverTimestamp();
      if (snap.exists) ctx.update(ref, { name: i.name, updatedAt: now });
      else ctx.set(ref, { code: i.code, name: i.name, status: 'active', createdAt: now, createdBy: ctx.uid, updatedAt: now });
      ctx.audit({ action: snap.exists ? 'invUnit.update' : 'invUnit.create', ref: ref.path, before: snap.data(), after: i });
      return { id: ref.id };
    },
  }),

  itemUpsert: def({
    name: 'inv.item.upsert',
    perm: 'inv.items.manage',
    input: z.object({
      id: id.optional(),
      code: code.optional(),
      name,
      categoryId: id,
      subcategoryId: id.nullish(),
      description: note,
      stockUnit: z.string().min(1).max(10),
      purchaseUnits: z.array(z.object({ unit: z.string().min(1).max(10), factor: z.number().positive() })).max(10).default([]),
      tracking,
      variantAttrs: z.array(z.string().trim().min(1).max(30)).max(5).default([]),
      minLevel: amount,
      reorderLevel: amount,
      defaultPrice: amount,
      preferredVendorId: id.nullish(),
      defaultLocation: note,
    }),
    handler: (ctx, i) =>
      saveMaster(ctx, {
        coll: 'invItems',
        kind: 'invItem',
        id: i.id,
        code: i.code,
        build: async (before) => {
          const category = usable(await ctx.tx.get(ctx.doc(`invCategories/${i.categoryId}`)), 'Category', before?.categoryId === i.categoryId);
          if (category.parentId) throw failed('Pick a top-level category; use subcategory for the child');
          if (i.subcategoryId) {
            const sub = usable(await ctx.tx.get(ctx.doc(`invCategories/${i.subcategoryId}`)), 'Subcategory', before?.subcategoryId === i.subcategoryId);
            if (sub.parentId !== i.categoryId) throw failed('Subcategory does not belong to the category');
          }
          if (i.preferredVendorId) {
            usable(await ctx.tx.get(ctx.doc(`invVendors/${i.preferredVendorId}`)), 'Vendor', before?.preferredVendorId === i.preferredVendorId);
          }
          const units = new Set([i.stockUnit, ...i.purchaseUnits.map((p) => p.unit)]);
          if (i.purchaseUnits.some((p) => p.unit === i.stockUnit)) throw failed('Purchase unit equals the stock unit');
          for (const u of units) {
            if (!(await ctx.tx.get(ctx.doc(`invUnits/${u}`))).exists) throw failed(`Unit "${u}" not found`);
          }
          if (before && (before.stockUnit !== i.stockUnit || before.tracking !== i.tracking)) {
            const used = await ctx.tx.get(ctx.coll('invMovements').where('itemId', '==', i.id).limit(1));
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
  itemSetStatus: setStatusDef('inv.item.setStatus', 'inv.items.manage', 'invItems', 'invItem'),

  variantUpsert: def({
    name: 'inv.variant.upsert',
    perm: 'inv.items.manage',
    input: z.object({
      itemId: id,
      id: id.optional(),
      code: code.optional(),
      attrs: z.record(z.string().min(1).max(30), z.string().trim().min(1).max(50)),
      status: status.optional(),
    }),
    handler: (ctx, i) =>
      saveMaster(ctx, {
        coll: `invItems/${i.itemId}/variants`,
        kind: 'invSku',
        id: i.id,
        code: i.code,
        build: async (_before, sku) => {
          const item = (await ctx.tx.get(ctx.doc(`invItems/${i.itemId}`))).data();
          if (!item) throw missing('invItem');
          const allowed = new Set<string>(item.variantAttrs);
          const keys = Object.keys(i.attrs);
          if (!keys.length || keys.some((k) => !allowed.has(k))) {
            throw failed(`Attributes must be among: ${[...allowed].join(', ') || '(none defined)'}`);
          }
          return { itemId: i.itemId, sku, attrs: i.attrs, ...(i.status ? { status: i.status } : {}) };
        },
      }),
  }),

  storeUpsert: def({
    name: 'inv.store.upsert',
    perm: 'inv.settings',
    input: z.object({
      id: id.optional(),
      code: code.optional(),
      name,
      campusId: z.number().int(),
      description: note,
      location: note,
      storekeeperIds: z.array(z.number().int()).max(20).default([]),
    }),
    handler: (ctx, i) =>
      saveMaster(ctx, {
        coll: 'invStores',
        kind: 'invStore',
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
  storeSetStatus: setStatusDef('inv.store.setStatus', 'inv.settings', 'invStores', 'invStore'),

  /** Adds the FRS default categories and units that do not exist yet. Safe to repeat. */
  seedDefaults: def({
    name: 'inv.seedDefaults',
    perm: 'inv.settings',
    input: z.object({}),
    handler: async (ctx) => {
      const now = FieldValue.serverTimestamp();
      const keys = DEFAULT_CATEGORIES.map((c) => uniqueKeyRef(ctx, 'invCategory', c.code));
      const unitRefs = DEFAULT_UNITS.map((u) => ctx.doc(`invUnits/${u.code}`));
      const [keySnaps, unitSnaps] = await Promise.all([ctx.tx.getAll(...keys), ctx.tx.getAll(...unitRefs)]);
      let categories = 0;
      let units = 0;
      DEFAULT_CATEGORIES.forEach((c, n) => {
        if (keySnaps[n].exists) return;
        const ref = ctx.newDoc('invCategories');
        ctx.set(keys[n], { kind: 'invCategory', value: c.code.toLowerCase(), ref: ref.path });
        ctx.set(ref, {
          code: c.code, name: c.name, description: null, parentId: null, suggestedTracking: c.tracking,
          status: 'active', createdAt: now, createdBy: ctx.uid, updatedAt: now,
        });
        categories++;
      });
      DEFAULT_UNITS.forEach((u, n) => {
        if (unitSnaps[n].exists) return;
        ctx.set(unitRefs[n], { ...u, status: 'active', createdAt: now, createdBy: ctx.uid, updatedAt: now });
        units++;
      });
      ctx.audit({ action: 'inv.seedDefaults', ref: `schools/${ctx.sid}`, after: { categories, units } });
      return { categories, units };
    },
  }),
};
