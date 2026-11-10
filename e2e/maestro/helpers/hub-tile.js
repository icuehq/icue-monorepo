// Screen position (% of width, % of height) of the Inventory hub tiles that are on screen when it opens, on the
// 1344x2992 emulator. Tapping a coordinate takes ~1 s; tapping by label costs ~2.5 s (two hierarchy reads).
// Lower tiles (purchase orders, invoices, assets, vendors, stores) need a scroll and are tapped by label.
var tiles = {
  'Dashboard': [26, 21],
  'Import': [26, 40], 'Reports': [74, 40],
  'Items': [26, 58], 'Categories': [74, 58],
  'Units': [26, 77], 'Stock': [74, 77],
};
var p = tiles[PAGE];
output.direct = !!p;
output.point = p ? p[0] + '%,' + p[1] + '%' : '';
