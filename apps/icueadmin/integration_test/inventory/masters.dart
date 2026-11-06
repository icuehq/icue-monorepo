import 'package:flutter_test/flutter_test.dart';
import 'package:inventory/inventory.dart';

import '../support/driver.dart';

/// Guide 1.1 (masters). Create steps are skipped when the record already exists.
Future<void> mastersSteps(WidgetTester tester) async {
  await step(tester, '1.1.1 default categories', () async {
    await open(tester, InventoryRoutes.inventoryCategories);
    if (await appears(tester, find.text('Add default categories & units'))) {
      await tapText(tester, 'Add default categories & units');
    }
    await waitFor(tester, find.textContaining(RegExp(r'\d+ categories')));
    await waitFor(tester, find.text('Stationery'));
  });

  await step(tester, '1.1.2 subcategory WRI', () async {
    await open(tester, InventoryRoutes.inventoryCategories);
    await waitFor(tester, find.text('Stationery'));
    if (await appears(tester, find.text('Writing Instruments'))) return;
    await tapNear(tester, find.text('Stationery'), find.byTooltip('Actions'));
    await tapText(tester, 'Add subcategory');
    await fill(tester, 'Code *', 'WRI');
    await fill(tester, 'Name *', 'Writing Instruments');
    await tapText(tester, 'Create Category');
    await waitFor(tester, find.text('Writing Instruments'));
  });

  await step(tester, '1.1.3 root category ART', () async {
    await open(tester, InventoryRoutes.inventoryCategories);
    await waitFor(tester, find.text('Stationery'));
    if (await appears(tester, find.text('Art & Craft Supplies'))) return;
    await tapLabel(tester, 'Category');
    await fill(tester, 'Code *', 'ART');
    await fill(tester, 'Name *', 'Art & Craft Supplies');
    await tapText(tester, 'Create Category');
    await waitFor(tester, find.text('Art & Craft Supplies'));
  });

  await step(tester, '1.1.4 duplicate category code is rejected', () async {
    await open(tester, InventoryRoutes.inventoryCategories);
    await waitFor(tester, find.text('Stationery'));
    await tapLabel(tester, 'Category');
    await fill(tester, 'Code *', 'STA');
    await fill(tester, 'Name *', 'Duplicate Stationery');
    await tapText(tester, 'Create Category');
    await waitFor(tester, find.textContaining('already exists'));
    await back(tester);
  });

  await step(tester, '1.1.6-1.1.7 units', () async {
    await open(tester, InventoryRoutes.inventoryUnits);
    await waitFor(tester, find.text('Pieces'));
    await waitFor(tester, find.text('Boxes'));
    if (await appears(tester, find.textContaining('Ream'))) return;
    await tapLabel(tester, 'Add unit');
    await fill(tester, 'Unit name *', 'Ream (500 sheets)');
    await tapLabel(tester, 'Add unit', last: true);
    await waitFor(tester, find.textContaining('Ream'));
  });

  await step(tester, '1.1.8-1.1.9 stores', () async {
    await open(tester, InventoryRoutes.inventoryStores);
    await waitFor(tester, find.textContaining(RegExp('stores?|No stores yet')));
    if (!await appears(tester, find.text('Central Main Store'))) {
      await tapLabel(tester, 'Add store');
      await fill(tester, 'Store name *', 'Central Main Store');
      await fill(tester, 'Location', 'Admin Building Ground Floor');
      await fill(tester, 'Description', 'Main central distribution store');
      await fill(tester, 'Store Keepers', '884');
      await tapFinder(tester, find.textContaining('ID #884'));
      await tapText(tester, 'Save store');
      await waitFor(tester, find.text('Central Main Store'));
    }
    if (!await appears(tester, find.text('Science Lab Store'))) {
      await tapLabel(tester, 'Add store');
      await fill(tester, 'Store name *', 'Science Lab Store');
      await fill(tester, 'Location', 'Science Block 2nd Floor');
      await fill(
        tester,
        'Description',
        'Laboratory chemicals and apparatus store',
      );
      await tapText(tester, 'Save store');
      await waitFor(tester, find.text('Science Lab Store'));
    }
    await waitFor(tester, find.textContaining('1 keeper'));
  });

  Future<void> addItem({
    required String code,
    required String name,
    required String category,
    String? subcategory,
    String? tracking,
    required String reorder,
    required String price,
  }) async {
    await tapLabel(tester, 'Add item');
    await fill(tester, 'Item code / SKU *', code);
    await fill(tester, 'Item name *', name);
    await tapText(tester, 'Category *');
    await tapText(tester, category, index: 1);
    await tapText(tester, 'Stock unit *');
    await tapText(tester, 'Pieces', index: 1);
    if (subcategory != null) {
      await tapText(tester, 'Subcategory');
      await tapText(tester, subcategory, index: 1);
    }
    if (tracking != null) {
      await tapText(tester, 'Tracking method *');
      await tapText(tester, tracking, index: 1);
    }
    await fill(tester, 'Reorder level', reorder);
    await fill(tester, 'Default purchase price', price);
    await tapText(tester, 'Save item');
  }

  await step(tester, '1.1.11-1.1.13 items', () async {
    await open(tester, InventoryRoutes.inventoryItems);
    await waitFor(tester, find.textContaining(RegExp(r'\d+ items?|No items')));
    if (!await appears(tester, find.textContaining('PEN-BLU-01'))) {
      await addItem(
        code: 'PEN-BLU-01',
        name: 'Ballpoint Pen (Blue, 0.7mm)',
        category: 'Stationery',
        subcategory: 'Writing Instruments',
        reorder: '50',
        price: '15.00',
      );
      await waitFor(tester, find.textContaining('PEN-BLU-01'));
    }
    if (!await appears(tester, find.textContaining('MILK-PAST-01'))) {
      await addItem(
        code: 'MILK-PAST-01',
        name: 'Pasteurized Milk (500ml pouch)',
        category: 'Kitchen supplies',
        tracking: 'Batch',
        reorder: '15',
        price: '30.00',
      );
      await waitFor(tester, find.textContaining('MILK-PAST-01'));
    }
    if (!await appears(tester, find.textContaining('LAP-DELL-15'))) {
      await addItem(
        code: 'LAP-DELL-15',
        name: 'Dell Latitude 15 Core i5 Laptop',
        category: 'IT equipment',
        tracking: 'Individual asset',
        reorder: '3',
        price: '45000.00',
      );
      await waitFor(tester, find.textContaining('LAP-DELL-15'));
    }
  });

  await step(tester, '1.1.14 duplicate item code is rejected', () async {
    await open(tester, InventoryRoutes.inventoryItems);
    await waitFor(tester, find.textContaining('PEN-BLU-01'));
    await addItem(
      code: 'PEN-BLU-01',
      name: 'Duplicate Pen',
      category: 'Stationery',
      reorder: '1',
      price: '1',
    );
    await waitFor(tester, find.textContaining('already exists'));
    await back(tester);
  });
}
