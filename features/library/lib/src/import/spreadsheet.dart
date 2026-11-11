import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:xml/xml.dart';

/// Rows (first row is the header) of a `.csv` or `.xlsx` file's first sheet, as text.
/// Throws [FormatException] when the file is not readable.
List<List<String>> readSheetRows(String fileName, List<int> bytes) {
  if (fileName.toLowerCase().endsWith('.xlsx')) return _readXlsx(bytes);
  final text = utf8.decode(bytes, allowMalformed: true).replaceAll('﻿', '');
  return parseCsvRows(text);
}

String _text(XmlElement element) =>
    element.findAllElements('t').map((node) => node.innerText).join();

List<List<String>> _readXlsx(List<int> bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } on Object {
    throw const FormatException('This is not a valid .xlsx file');
  }
  String? read(String path) {
    final file = archive.findFile(path);
    return file == null ? null : utf8.decode(file.content);
  }

  // The first sheet is whichever workbook.xml lists first, not necessarily sheet1.xml.
  final workbook = read('xl/workbook.xml');
  final relations = read('xl/_rels/workbook.xml.rels');
  if (workbook == null || relations == null) {
    throw const FormatException('This is not a valid .xlsx file');
  }
  final firstSheet = XmlDocument.parse(workbook).findAllElements('sheet').first;
  final relationId = firstSheet.attributes
      .firstWhere((attribute) => attribute.name.local == 'id')
      .value;
  final target = XmlDocument.parse(relations)
      .findAllElements('Relationship')
      .firstWhere((node) => node.getAttribute('Id') == relationId)
      .getAttribute('Target')!;
  final sheet = read(
    target.startsWith('/') ? target.substring(1) : 'xl/$target',
  );
  if (sheet == null) throw const FormatException('The sheet is empty');

  final sharedXml = read('xl/sharedStrings.xml');
  final shared = sharedXml == null
      ? const <String>[]
      : [
          for (final item in XmlDocument.parse(sharedXml).findAllElements('si'))
            _text(item),
        ];

  final rows = <List<String>>[];
  for (final row in XmlDocument.parse(sheet).findAllElements('row')) {
    final cells = <String>[];
    for (final cell in row.findElements('c')) {
      final column = _columnIndex(cell.getAttribute('r') ?? '');
      while (cells.length < column) {
        cells.add('');
      }
      final type = cell.getAttribute('t');
      final value = cell.getElement('v')?.innerText ?? '';
      var text = switch (type) {
        's' => shared[int.parse(value)],
        'inlineStr' => _text(cell),
        _ => value,
      };
      // Excel stores whole numbers like 1999 as "1999", but a formula may give "1999.0".
      if (type == null || type == 'n') {
        text = text.replaceFirst(RegExp(r'\.0+$'), '');
      }
      cells.add(text.trim());
    }
    rows.add(cells);
  }
  return rows;
}

/// Zero-based column of a cell reference such as `C7`.
int _columnIndex(String reference) {
  var index = 0;
  for (final unit in reference.codeUnits) {
    if (unit < 65 || unit > 90) break;
    index = index * 26 + unit - 64;
  }
  return index == 0 ? 0 : index - 1;
}

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _reference(int column, int row) {
  var letters = '';
  for (var rest = column + 1; rest > 0; rest = (rest - 1) ~/ 26) {
    letters = String.fromCharCode(65 + (rest - 1) % 26) + letters;
  }
  return '$letters${row + 1}';
}

/// A minimal `.xlsx` with one worksheet per entry of [sheets] (text cells only).
List<int> buildXlsx(Map<String, List<List<String>>> sheets) {
  final archive = Archive();
  void add(String path, String content) =>
      archive.addFile(ArchiveFile.string(path, content));
  const header = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
  const namespace = 'http://schemas.openxmlformats.org/';
  final names = sheets.keys.toList();
  add(
    '[Content_Types].xml',
    '$header<Types xmlns="${namespace}package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '${[for (var i = 0; i < names.length; i++) '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
        '</Types>',
  );
  add(
    '_rels/.rels',
    '$header<Relationships xmlns="${namespace}package/2006/relationships">'
        '<Relationship Id="rId1" Type="${namespace}officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>',
  );
  add(
    'xl/workbook.xml',
    '$header<workbook xmlns="${namespace}spreadsheetml/2006/main" xmlns:r="${namespace}officeDocument/2006/relationships"><sheets>'
        '${[for (var i = 0; i < names.length; i++) '<sheet name="${_escape(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
        '</sheets></workbook>',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '$header<Relationships xmlns="${namespace}package/2006/relationships">'
        '${[for (var i = 0; i < names.length; i++) '<Relationship Id="rId${i + 1}" Type="${namespace}officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>'].join()}'
        '</Relationships>',
  );
  for (var i = 0; i < names.length; i++) {
    final rows = sheets[names[i]]!;
    final width = rows.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    add(
      'xl/worksheets/sheet${i + 1}.xml',
      '$header<worksheet xmlns="${namespace}spreadsheetml/2006/main">'
          '<cols><col min="1" max="$width" width="24" customWidth="1"/></cols><sheetData>'
          '${[
            for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) '<row r="${rowIndex + 1}">${[for (var column = 0; column < rows[rowIndex].length; column++)
                if (rows[rowIndex][column].isNotEmpty) '<c r="${_reference(column, rowIndex)}" t="inlineStr"><is><t xml:space="preserve">${_escape(rows[rowIndex][column])}</t></is></c>'].join()}</row>',
          ].join()}'
          '</sheetData></worksheet>',
    );
  }
  return ZipEncoder().encode(archive);
}
