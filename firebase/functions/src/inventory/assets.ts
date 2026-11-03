import { type DocumentData, type DocumentReference } from 'firebase-admin/firestore';
import { z } from 'zod';
import type { CallableContext } from '../shared/callable';
import { dayTimestamp, dayTimestampOrNull, isoDate, todayIST } from '../shared/dates';
import { serverTimestamp } from '../shared/firestore';
import { claimUniqueKey, nextNumber, nextNumbers, uniqueKeyRef } from '../shared/keys';
import {
  defineCallable,
  failed,
  id,
  missing,
  money,
  optionalText,
  text,
  usable,
} from '../shared/masters';
import { lineKey, stockPerson, positiveQuantity, Stock } from './stock';

/** Individual assets: registration, custody, condition, retirement (FRS 10.19) and maintenance (FRS 10.20). */

/** Units registered by one call; each adds a few writes to the transaction. */
const MAX_BULK = 50;
const condition = z.enum(['new', 'good', 'fair', 'poor', 'damaged']);
// Maintenance status drives the asset status (architecture §6): `restoreTo` is what the asset was before.
const LIVE = ['open', 'assigned', 'in_progress', 'waiting_for_parts'];
const WORKING = {
  assigned: 'under_maintenance',
  waiting_for_parts: 'under_maintenance',
  in_progress: 'under_repair',
} as const;

async function loadAsset(context: CallableContext, assetId: string) {
  const ref = context.doc(`inventoryAssets/${assetId}`);
  const asset = (await context.transaction.get(ref)).data();
  if (!asset) throw missing('Asset');
  context.requireCampus(asset.campusId);
  return { ref, asset };
}

/** Appends to the asset's history timeline (`inventoryAssets/{id}/history`). */
function hist(
  context: CallableContext,
  ref: DocumentReference,
  asset: DocumentData,
  type: string,
  detail: Record<string, unknown> = {},
) {
  context.set(ref.collection('history').doc(), {
    type,
    ...detail,
    campusId: asset.campusId,
    performedBy: context.uid,
    performedAt: serverTimestamp(),
  });
}

const assignee = z.object({
  assignee: stockPerson,
  location: text(120),
  expectedReturn: isoDate.nullish(),
  acknowledged: z.boolean().default(false),
  remarks: optionalText,
});

/** Opens a custody record; the asset doc is updated by the caller. */
function openAssignment(
  context: CallableContext,
  asset: DocumentData,
  assetDocId: string,
  i: z.infer<typeof assignee>,
  condition: string,
  from?: string,
) {
  if (i.expectedReturn && i.expectedReturn < todayIST())
    throw failed('Expected return date is in the past');
  const ref = context.newDoc('inventoryAssetAssignments');
  context.set(ref, {
    assetId: assetDocId,
    assetCode: asset.assetId,
    assetName: asset.name,
    campusId: asset.campusId,
    assignee: i.assignee,
    // A department ID is not a person's ERP ID, so it never matches a user's own-record rule.
    personErpId: i.assignee.type === 'department' ? null : i.assignee.personErpId,
    location: i.location ?? null,
    assignedDate: dayTimestamp(todayIST()),
    assignedAt: serverTimestamp(),
    assignedBy: context.uid,
    expectedReturn: dayTimestampOrNull(i.expectedReturn),
    conditionOut: condition,
    acknowledgement: i.acknowledged ? { performedAt: serverTimestamp() } : null,
    remarks: i.remarks ?? null,
    transferredFrom: from ?? null,
    returnedAt: null,
    returnedDate: null,
    conditionIn: null,
    closedAs: null,
  });
  return ref;
}

async function closeAssignment(
  context: CallableContext,
  asset: DocumentData,
  closedAs: 'returned' | 'transferred' | 'lost',
  condition: string | null,
) {
  const ref = context.doc(`inventoryAssetAssignments/${asset.activeAssignmentId}`);
  if (!(await context.transaction.get(ref)).exists) throw missing('Assignment');
  context.update(ref, {
    returnedAt: serverTimestamp(),
    returnedDate: dayTimestamp(todayIST()),
    returnedBy: context.uid,
    conditionIn: condition,
    closedAs,
  });
  return ref;
}

export const assets = {
  /** One asset, or `quantity` identical ones (no serial number) per call; the asset ID (`AST/<financialYear>/<seq>`) doubles as its barcode / QR value. */
  register: defineCallable({
    name: 'inventory.asset.register',
    permission: 'inventory.assets.manage',
    input: z.object({
      itemId: id,
      storeId: id,
      quantity: z.number().int().min(1).max(MAX_BULK).default(1),
      name: z.string().trim().min(1).max(120).optional(),
      serialNumber: text(120),
      make: text(120),
      model: text(120),
      purchaseOrderId: id.nullish(),
      vendorId: id.nullish(),
      purchaseDate: isoDate.nullish(),
      price: money.nullish(),
      warrantyStart: isoDate.nullish(),
      warrantyEnd: isoDate.nullish(),
      condition: condition.default('new'),
      location: text(120),
    }),
    handler: async (context, i) => {
      const item = usable(
        await context.transaction.get(context.doc(`inventoryItems/${i.itemId}`)),
        'Item',
        false,
      );
      if (item.tracking !== 'asset')
        throw failed(`${item.name} is not tracked as an individual asset`);
      const store = usable(
        await context.transaction.get(context.doc(`inventoryStores/${i.storeId}`)),
        'Store',
        false,
      );
      context.requireCampus(store.campusId);
      if (i.quantity > 1 && i.serialNumber)
        throw failed('Serial numbers are per unit; register units with a serial one at a time');
      if (i.warrantyStart && i.warrantyEnd && i.warrantyEnd < i.warrantyStart)
        throw failed('Warranty ends before it starts');
      let { vendorId, price } = { vendorId: i.vendorId ?? null, price: i.price ?? null };
      if (i.purchaseOrderId) {
        const purchaseOrder = (
          await context.transaction.get(context.doc(`inventoryPurchaseOrders/${i.purchaseOrderId}`))
        ).data();
        if (!purchaseOrder) throw missing('Purchase order');
        if (purchaseOrder.deliveryCampusId !== store.campusId)
          throw failed("Store is not on the order's delivery campus");
        const line = (
          purchaseOrder.lineItems as {
            itemId: string;
            quantityAccepted: number;
            unitPrice: number;
          }[]
        ).find((lineItem) => lineItem.itemId === i.itemId);
        if (!line) throw failed('Item is not on the order');
        const done = (
          await context.transaction.get(
            context
              .coll('inventoryAssets')
              .where('purchaseOrderId', '==', i.purchaseOrderId)
              .where('itemId', '==', i.itemId),
          )
        ).size;
        if (done + i.quantity > line.quantityAccepted)
          throw failed(
            done >= line.quantityAccepted
              ? 'Every accepted unit of this item is already registered'
              : `Only ${line.quantityAccepted - done} accepted unit(s) left to register`,
          );
        vendorId = purchaseOrder.vendorId;
        price ??= line.unitPrice;
      }
      const numbers = await nextNumbers(context, 'AST', i.quantity);
      const ids: string[] = [];
      for (const assetId of numbers) {
        const ref = context.newDoc('inventoryAssets');
        await claimUniqueKey(context, 'inventoryAsset', assetId, ref.path);
        const asset = {
          assetId,
          itemId: i.itemId,
          name: i.name ?? item.name,
          categoryId: item.categoryId,
          serialNumber: i.serialNumber ?? null,
          make: i.make ?? null,
          model: i.model ?? null,
          purchaseOrderId: i.purchaseOrderId ?? null,
          vendorId,
          purchaseDate: dayTimestampOrNull(i.purchaseDate),
          price,
          warranty: {
            start: dayTimestampOrNull(i.warrantyStart),
            end: dayTimestampOrNull(i.warrantyEnd),
          },
          condition: i.condition,
          campusId: store.campusId,
          storeId: i.storeId,
          location: i.location ?? null,
          status: 'available',
          activeAssignmentId: null,
          assignedTo: null,
          activeMaintenanceId: null,
          nextServiceDate: null,
          rfidTag: null,
          imagePath: null,
          createdAt: serverTimestamp(),
          createdBy: context.uid,
          updatedAt: serverTimestamp(),
        };
        context.set(ref, asset);
        hist(context, ref, asset, 'registered', { condition: i.condition });
        context.audit({
          action: 'inventoryAsset.register',
          documentPath: ref.path,
          after: { assetId, itemId: i.itemId },
        });
        ids.push(ref.id);
      }
      return { id: ids[0], number: numbers[0], ids, numbers };
    },
  }),

  assign: defineCallable({
    name: 'inventory.asset.assign',
    permission: 'inventory.assets.manage',
    input: assignee.extend({ id, condition: condition.optional() }),
    handler: async (context, i) => {
      const { ref, asset } = await loadAsset(context, i.id);
      if (asset.status !== 'available' || asset.activeAssignmentId)
        throw failed(`Asset is ${asset.status}`);
      const condition = i.condition ?? asset.condition;
      const aRef = openAssignment(context, asset, ref.id, i, condition);
      context.update(ref, {
        status: 'assigned',
        activeAssignmentId: aRef.id,
        assignedTo: i.assignee,
        condition,
        location: i.location ?? asset.location,
        updatedAt: serverTimestamp(),
      });
      hist(context, ref, asset, 'assigned', { assignee: i.assignee, assignmentId: aRef.id });
      context.audit({
        action: 'inventoryAsset.assign',
        documentPath: ref.path,
        before: { status: asset.status },
        after: { assignee: i.assignee },
      });
      return { id: ref.id, assignmentId: aRef.id };
    },
  }),

  /** Custody moves to another person or department; the previous assignment is closed and kept. */
  transfer: defineCallable({
    name: 'inventory.asset.transfer',
    permission: 'inventory.assets.manage',
    input: assignee.extend({ id, condition: condition.optional() }),
    handler: async (context, i) => {
      const { ref, asset } = await loadAsset(context, i.id);
      if (asset.status !== 'assigned') throw failed(`Asset is ${asset.status}`);
      const from = asset.assignedTo as { type: string; personErpId: number };
      if (from.type === i.assignee.type && from.personErpId === i.assignee.personErpId)
        throw failed('Asset is already assigned to this custodian');
      const condition = i.condition ?? asset.condition;
      const oldRef = await closeAssignment(context, asset, 'transferred', condition);
      const aRef = openAssignment(context, asset, ref.id, i, condition, oldRef.id);
      context.update(ref, {
        activeAssignmentId: aRef.id,
        assignedTo: i.assignee,
        condition,
        location: i.location ?? asset.location,
        updatedAt: serverTimestamp(),
      });
      hist(context, ref, asset, 'transferred', { from, to: i.assignee, assignmentId: aRef.id });
      context.audit({
        action: 'inventoryAsset.transfer',
        documentPath: ref.path,
        before: { assignedTo: from },
        after: { assignedTo: i.assignee },
      });
      return { id: ref.id, assignmentId: aRef.id };
    },
  }),

  /** Back to the store; a damaged return makes the asset `damaged` until its condition is reviewed. */
  return: defineCallable({
    name: 'inventory.asset.return',
    permission: 'inventory.assets.manage',
    input: z.object({ id, condition, location: text(120), remarks: optionalText }),
    handler: async (context, i) => {
      const { ref, asset } = await loadAsset(context, i.id);
      if (asset.status !== 'assigned') throw failed(`Asset is ${asset.status}`);
      await closeAssignment(context, asset, 'returned', i.condition);
      const status = i.condition === 'damaged' ? 'damaged' : 'available';
      context.update(ref, {
        status,
        activeAssignmentId: null,
        assignedTo: null,
        condition: i.condition,
        location: i.location ?? asset.location,
        updatedAt: serverTimestamp(),
      });
      hist(context, ref, asset, 'returned', { condition: i.condition, remarks: i.remarks ?? null });
      context.audit({
        action: 'inventoryAsset.return',
        documentPath: ref.path,
        before: { status: asset.status },
        after: { status, condition: i.condition },
      });
      return { id: ref.id, status };
    },
  }),

  /**
   * Updates the condition, and optionally moves the asset between `available`, `damaged` and `lost`.
   * Maintenance owns the status while a job is live; an assigned asset can only be written off as lost.
   */
  setCondition: defineCallable({
    name: 'inventory.asset.setCondition',
    permission: 'inventory.assets.manage',
    input: z.object({
      id,
      condition,
      status: z.enum(['available', 'damaged', 'lost']).optional(),
      remarks: optionalText,
    }),
    handler: async (context, i) => {
      const { ref, asset } = await loadAsset(context, i.id);
      if (['retired', 'disposed'].includes(asset.status)) throw failed(`Asset is ${asset.status}`);
      const patch: Record<string, unknown> = {
        condition: i.condition,
        updatedAt: serverTimestamp(),
      };
      if (i.status && i.status !== asset.status) {
        if (asset.activeMaintenanceId) throw failed('Asset is in maintenance');
        if (asset.status === 'assigned') {
          if (i.status !== 'lost') throw failed('Return the asset first');
          await closeAssignment(context, asset, 'lost', null);
          Object.assign(patch, { activeAssignmentId: null, assignedTo: null });
        }
        patch.status = i.status;
      }
      context.update(ref, patch);
      hist(context, ref, asset, 'condition', {
        condition: i.condition,
        status: i.status ?? asset.status,
        remarks: i.remarks ?? null,
      });
      context.audit({
        action: 'inventoryAsset.setCondition',
        documentPath: ref.path,
        before: { status: asset.status, condition: asset.condition },
        after: { status: patch.status ?? asset.status, condition: i.condition },
      });
      return { id: ref.id };
    },
  }),

  /** Assigns (or clears with `null`) the RFID tag. A tag belongs to one asset; scans resolve it by equality on `rfidTag`. */
  setRfid: defineCallable({
    name: 'inventory.asset.setRfid',
    permission: 'inventory.assets.manage',
    input: z.object({ id, rfidTag: z.string().trim().min(1).max(64).nullable() }),
    handler: async (context, i) => {
      const { ref, asset } = await loadAsset(context, i.id);
      if (['retired', 'disposed'].includes(asset.status)) throw failed(`Asset is ${asset.status}`);
      if (i.rfidTag) await claimUniqueKey(context, 'inventoryRfid', i.rfidTag, ref.path);
      if (asset.rfidTag && asset.rfidTag.toLowerCase() !== i.rfidTag?.toLowerCase())
        context.delete(uniqueKeyRef(context, 'inventoryRfid', asset.rfidTag));
      context.update(ref, { rfidTag: i.rfidTag, updatedAt: serverTimestamp() });
      hist(context, ref, asset, 'rfid', { rfidTag: i.rfidTag });
      context.audit({
        action: 'inventoryAsset.setRfid',
        documentPath: ref.path,
        before: { rfidTag: asset.rfidTag ?? null },
        after: { rfidTag: i.rfidTag },
      });
      return { id: ref.id };
    },
  }),

  /** Retire an unused asset, then optionally mark it disposed. Neither can be assigned again. */
  retire: defineCallable({
    name: 'inventory.asset.retire',
    permission: 'inventory.assets.manage',
    input: z.object({
      id,
      status: z.enum(['retired', 'disposed']),
      reason: z.string().trim().min(1).max(500),
    }),
    handler: async (context, i) => {
      const { ref, asset } = await loadAsset(context, i.id);
      const from = ['available', 'damaged', 'lost'].concat(
        i.status === 'disposed' ? ['retired'] : [],
      );
      if (!from.includes(asset.status))
        throw failed(
          asset.status === 'assigned' ? 'Return the asset first' : `Asset is ${asset.status}`,
        );
      context.update(ref, {
        status: i.status,
        retireReason: i.reason,
        retiredAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      hist(context, ref, asset, i.status, { reason: i.reason });
      context.audit({
        action: `inventoryAsset.${i.status}`,
        documentPath: ref.path,
        before: { status: asset.status },
        after: { status: i.status },
        reason: i.reason,
      });
      return { id: ref.id };
    },
  }),
};

export const maintenance = {
  /** Reports a fault (no `id`) or edits a live job. Raising one puts the asset `under_maintenance`. */
  save: defineCallable({
    name: 'inventory.maintenance.save',
    permission: 'inventory.assets.manage',
    input: z.object({
      id: id.optional(),
      assetId: id,
      issue: z.string().trim().min(1).max(1000),
      priority: z.enum(['low', 'medium', 'high', 'urgent']),
      technician: text(120),
      reportedDate: isoDate.optional(),
      nextServiceDate: isoDate.nullish(),
    }),
    handler: async (context, i) => {
      const fields = {
        issue: i.issue,
        priority: i.priority,
        technician: i.technician ?? null,
        nextServiceDate: dayTimestampOrNull(i.nextServiceDate),
        updatedAt: serverTimestamp(),
      };
      if (i.id) {
        const ref = context.doc(`inventoryMaintenanceJobs/${i.id}`);
        const maintenanceJob = (await context.transaction.get(ref)).data();
        if (!maintenanceJob) throw missing('Maintenance request');
        context.requireCampus(maintenanceJob.campusId);
        if (maintenanceJob.assetId !== i.assetId) throw failed('Asset cannot change');
        if (!LIVE.includes(maintenanceJob.status))
          throw failed(`Request is ${maintenanceJob.status}`);
        context.update(ref, {
          ...fields,
          ...(i.reportedDate ? { reportedDate: dayTimestamp(i.reportedDate) } : {}),
        });
        context.audit({
          action: 'inventoryMaintenanceJobs.update',
          documentPath: ref.path,
          before: { priority: maintenanceJob.priority },
          after: { priority: i.priority },
        });
        return { id: ref.id, number: maintenanceJob.number };
      }
      const { ref: aRef, asset } = await loadAsset(context, i.assetId);
      if (['lost', 'retired', 'disposed'].includes(asset.status))
        throw failed(`Asset is ${asset.status}`);
      if (asset.activeMaintenanceId) throw failed('Asset already has an open maintenance request');
      const reported = i.reportedDate ?? todayIST();
      if (reported > todayIST()) throw failed('Reported date is in the future');
      const number = await nextNumber(context, 'MNT');
      const ref = context.newDoc('inventoryMaintenanceJobs');
      context.set(ref, {
        ...fields,
        number,
        assetId: aRef.id,
        assetCode: asset.assetId,
        assetName: asset.name,
        campusId: asset.campusId,
        reportedDate: dayTimestamp(reported),
        reportedBy: context.uid,
        reportedByErpId: context.access.personErpId ?? null,
        repairDetails: null,
        cost: null,
        partsUsed: [],
        attachments: [],
        status: 'open',
        restoreTo: asset.status,
        completedDate: null,
        createdAt: serverTimestamp(),
        createdBy: context.uid,
      });
      context.update(aRef, {
        status: 'under_maintenance',
        activeMaintenanceId: ref.id,
        updatedAt: serverTimestamp(),
      });
      hist(context, aRef, asset, 'maintenance.open', { number, issue: i.issue });
      context.audit({
        action: 'inventoryMaintenanceJobs.create',
        documentPath: ref.path,
        after: { number, assetId: i.assetId },
      });
      return { id: ref.id, number };
    },
  }),

  /**
   * Moves a live job on. Completing needs the repair cost (0 is fine) and frees the asset; cancelling puts the
   * asset back as it was. Parts are drawn from store stock as `issue` movements, once per call (never reversed).
   */
  setStatus: defineCallable({
    name: 'inventory.maintenance.setStatus',
    permission: 'inventory.assets.manage',
    input: z.object({
      id,
      status: z.enum(['assigned', 'in_progress', 'waiting_for_parts', 'completed', 'cancelled']),
      technician: text(120),
      repairDetails: z.string().trim().max(1000).nullish(),
      cost: money.nullish(),
      nextServiceDate: isoDate.nullish(),
      condition: condition.optional(),
      parts: z
        .array(z.object({ ...lineKey, storeId: id, quantity: positiveQuantity }))
        .max(20)
        .default([]),
    }),
    handler: async (context, i) => {
      const ref = context.doc(`inventoryMaintenanceJobs/${i.id}`);
      const maintenanceJob = (await context.transaction.get(ref)).data();
      if (!maintenanceJob) throw missing('Maintenance request');
      context.requireCampus(maintenanceJob.campusId);
      if (!LIVE.includes(maintenanceJob.status))
        throw failed(`Request is ${maintenanceJob.status}`);
      const technician = i.technician ?? maintenanceJob.technician;
      const cost = i.cost ?? maintenanceJob.cost;
      if (i.status === 'assigned' && !technician) throw failed('Technician required');
      if (i.status === 'completed' && cost == null) throw failed('Repair cost required');
      const { ref: aRef, asset } = await loadAsset(context, maintenanceJob.assetId);

      const used = [];
      if (i.parts.length) {
        if (!context.access.permissions.includes('inventory.stock.operate'))
          throw failed('Drawing parts needs stock access');
        const stock = new Stock(context);
        for (const part of i.parts) {
          await stock.store(part.storeId);
          const item = await stock.item(part.itemId, part.variantId);
          for (const balance of await stock.allocate(
            part.storeId,
            item,
            part.variantId,
            part.quantity,
          )) {
            stock.move(balance.bal, 'available', -balance.quantity, {
              type: 'issue',
              referenceType: 'maintenance',
              referenceId: ref.id,
            });
            used.push({
              itemId: part.itemId,
              variantId: part.variantId ?? null,
              storeId: part.storeId,
              balanceId: balance.bal.id,
              quantity: balance.quantity,
              unitCost: balance.bal.data.unitCost,
            });
          }
        }
        await stock.finish();
      }

      const done = i.status === 'completed' || i.status === 'cancelled';
      context.update(ref, {
        status: i.status,
        technician: technician ?? null,
        cost: cost ?? null,
        repairDetails: i.repairDetails ?? maintenanceJob.repairDetails,
        nextServiceDate: i.nextServiceDate
          ? dayTimestamp(i.nextServiceDate)
          : maintenanceJob.nextServiceDate,
        partsUsed: [...maintenanceJob.partsUsed, ...used],
        completedDate: done ? dayTimestamp(todayIST()) : null,
        updatedAt: serverTimestamp(),
      });
      const patch: Record<string, unknown> = { updatedAt: serverTimestamp() };
      if (done) {
        // A repaired `damaged` asset is usable again; cancelling leaves it as it was.
        Object.assign(patch, {
          status:
            i.status === 'completed' && maintenanceJob.restoreTo === 'damaged'
              ? 'available'
              : maintenanceJob.restoreTo,
          activeMaintenanceId: null,
          ...(i.status === 'completed' && {
            nextServiceDate: i.nextServiceDate
              ? dayTimestamp(i.nextServiceDate)
              : maintenanceJob.nextServiceDate,
            ...(i.condition && { condition: i.condition }),
          }),
        });
      } else {
        patch.status = WORKING[i.status as keyof typeof WORKING];
      }
      context.update(aRef, patch);
      hist(context, aRef, asset, `maintenance.${i.status}`, {
        number: maintenanceJob.number,
        cost: cost ?? null,
      });
      context.audit({
        action: 'inventoryMaintenanceJobs.setStatus',
        documentPath: ref.path,
        before: { status: maintenanceJob.status },
        after: { status: i.status, cost: cost ?? null },
      });
      return { id: ref.id, status: i.status };
    },
  }),
};
