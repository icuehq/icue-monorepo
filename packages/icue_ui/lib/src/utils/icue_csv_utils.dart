/// RFC 4180 CSV (quotes only where needed).
String toCsv(List<String> header, List<List<String>> rows) {
  String cell(String v) =>
      v.contains(RegExp('[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
  return [header, ...rows].map((r) => r.map(cell).join(',')).join('\n');
}

/// Parses RFC 4180 CSV (quoted cells, `""` escapes, CRLF) into rows of cells; blank lines are skipped.
List<List<String>> parseCsvRows(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    row = [];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c != '"') {
        cell.write(c);
      } else if (i + 1 < text.length && text[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = false;
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      endCell();
    } else if (c == '\n') {
      endRow();
    } else if (c != '\r') {
      cell.write(c);
    }
  }
  endRow();
  return rows;
}

/// [parseCsvRows] as maps keyed by the (trimmed) header row.
List<Map<String, String>> parseCsv(String text) {
  final rows = parseCsvRows(text);
  if (rows.isEmpty) return [];
  final header = [for (final h in rows.first) h.trim()];
  return [
    for (final r in rows.skip(1))
      {
        for (var k = 0; k < header.length; k++)
          header[k]: k < r.length ? r[k].trim() : '',
      },
  ];
}
